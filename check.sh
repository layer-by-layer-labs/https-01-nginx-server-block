#!/usr/bin/env bash
# check.sh — Verificador automático del laboratorio HTTPS-01.
# Evalúa el comportamiento REAL del servidor (peticiones HTTP), no los comandos que ejecutaste.
# Compatible con Bash 3.2 (macOS) y Bash 5 (Linux).
# Uso: ./check.sh
set -u

cd "$(dirname "$0")" || exit 2

URL="${LAB_URL:-http://127.0.0.1:8080}"
HOST_OK="sitio1.lab.test"
HOST_OTRO="otro.lab.test"
SERVICIO="web"

if [ -t 1 ]; then V=$'\033[32m'; R=$'\033[31m'; A=$'\033[33m'; N=$'\033[0m'; else V=""; R=""; A=""; N=""; fi

aprobadas=0
total=0
TMP="$(mktemp -d)"
TOKEN="$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
ARCHIVO_TOKEN="html/sitio1/check-${TOKEN}.txt"

# shellcheck disable=SC2317  # se invoca desde trap
limpiar() { rm -rf "$TMP"; rm -f "$ARCHIVO_TOKEN"; }
trap limpiar EXIT

ok()    { aprobadas=$((aprobadas + 1)); total=$((total + 1)); echo "${V}✔${N} $1"; }
falla() { total=$((total + 1)); echo "${R}✘${N} $1"; shift; for pista in "$@"; do echo "    ${A}→${N} $pista"; done; }

# peticion HOST RUTA  → deja el código en $CODIGO, el cuerpo en $TMP/body y el encabezado X-Bloque en $BLOQUE
peticion() {
  CODIGO="$(curl -s --max-time 5 -o "$TMP/body" -D "$TMP/headers" -w '%{http_code}' -H "Host: $1" "$URL$2" 2>/dev/null)"
  [ -n "$CODIGO" ] || CODIGO="000"
  BLOQUE="$(grep -i '^x-bloque:' "$TMP/headers" 2>/dev/null | tr -d '\r' | awk '{print $2}')"
  [ -n "$BLOQUE" ] || BLOQUE="(ninguno)"
}

echo "Laboratorio HTTPS-01 · verificando $URL"
echo

# --- Requisitos previos (si fallan, no tiene sentido seguir) -------------------
command -v curl >/dev/null 2>&1 || { echo "${R}✘${N} curl no está instalado."; exit 2; }
command -v docker >/dev/null 2>&1 || { echo "${R}✘${N} docker no está instalado."; exit 2; }
docker info >/dev/null 2>&1 || { echo "${R}✘${N} Docker no está en ejecución. Abre Docker Desktop (o inicia el servicio) y reintenta."; exit 2; }

# --- 1. El contenedor está en ejecución ----------------------------------------
if docker compose ps --status running --services 2>/dev/null | grep -qx "$SERVICIO"; then
  ok "El contenedor '$SERVICIO' está en ejecución."
else
  falla "El contenedor '$SERVICIO' no está en ejecución." \
        "Arráncalo con: docker compose up -d" \
        "Si se detiene solo, mira por qué con: docker compose logs $SERVICIO"
  echo; echo "Resultado: ${R}NO APROBADO${N} (sin servidor no hay más pruebas posibles)."; exit 1
fi

# --- 2. La configuración en disco es sintácticamente válida ----------------------
if docker compose exec -T "$SERVICIO" nginx -t >"$TMP/nginx-t" 2>&1; then
  ok "La configuración de Nginx es válida (nginx -t)."
else
  falla "La configuración de Nginx tiene errores:" \
        "$(grep -m1 -E 'emerg|error' "$TMP/nginx-t")" \
        "Corrígela y vuelve a ejecutar: docker compose exec $SERVICIO nginx -t"
fi

# --- 3. sitio1.lab.test responde 200 en la raíz ----------------------------------
peticion "$HOST_OK" "/"
if [ "$CODIGO" = "200" ] && [ "$BLOQUE" = "sitio1" ]; then
  ok "GET / con Host: $HOST_OK → 200, servido por el bloque sitio1."
elif [ "$CODIGO" = "000" ]; then
  falla "No hubo respuesta en $URL." \
        "¿Está publicado el puerto? Revisa: docker compose ps"
else
  falla "GET / con Host: $HOST_OK → $CODIGO, servido por el bloque '$BLOQUE' (se esperaba 200 del bloque sitio1)." \
        "Observa la respuesta completa: curl -v -H 'Host: $HOST_OK' $URL/" \
        "¿Qué server block atendió la petición? ¿Por qué ese y no otro?" \
        "Si ya editaste la configuración, ¿la recargaste? docker compose exec $SERVICIO nginx -s reload"
fi

# --- 4. Antitrampa: el bloque sitio1 sirve archivos reales desde su root -------------
echo "$TOKEN" > "$ARCHIVO_TOKEN"
peticion "$HOST_OK" "/check-${TOKEN}.txt"
if [ "$CODIGO" = "200" ] && [ "$(tr -d '\r\n' < "$TMP/body")" = "$TOKEN" ]; then
  ok "sitio1 sirve archivos nuevos desde su directorio raíz (prueba con archivo aleatorio)."
elif [ "$BLOQUE" != "sitio1" ]; then
  falla "sitio1 no sirvió un archivo recién creado en html/sitio1/: la petición la atendió el bloque '$BLOQUE'." \
        "Esta prueba depende de la 3: resuelve primero por qué el bloque sitio1 no recibe sus peticiones."
else
  falla "sitio1 no sirvió un archivo recién creado en html/sitio1/ (código $CODIGO)." \
        "El servidor debe servir el contenido real del directorio, no una respuesta fija." \
        "Revisa las directivas root y location del bloque sitio1."
fi

# --- 5. Prueba negativa: otro nombre NO debe recibir el contenido de sitio1 -----------
peticion "$HOST_OTRO" "/check-${TOKEN}.txt"
if [ "$CODIGO" = "404" ] && [ "$BLOQUE" = "default" ]; then
  ok "Un Host desconocido ($HOST_OTRO) lo atiende el sitio por defecto, no sitio1."
else
  falla "Con Host: $HOST_OTRO se obtuvo $CODIGO del bloque '$BLOQUE' (se esperaba 404 del bloque default)." \
        "sitio1 no debe responder a cualquier nombre: revisa server_name y default_server."
fi

# --- 6. Una ruta inexistente en sitio1 devuelve 404 ------------------------------
peticion "$HOST_OK" "/no-existe-${TOKEN}"
if [ "$CODIGO" = "404" ]; then
  ok "Una ruta inexistente en sitio1 devuelve 404."
else
  falla "Una ruta inexistente en sitio1 devolvió $CODIGO (se esperaba 404)." \
        "Un servidor que responde 200 a todo oculta errores. Revisa try_files."
fi

echo
if [ "$aprobadas" -eq "$total" ]; then
  echo "Resultado: ${V}APROBADO${N} ($aprobadas/$total pruebas)."
  exit 0
else
  echo "Resultado: ${R}NO APROBADO${N} ($aprobadas/$total pruebas). Corrige y vuelve a ejecutar ./check.sh"
  exit 1
fi
