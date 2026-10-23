#!/usr/bin/env bash
# tests/ci-test.sh — Prueba el propio laboratorio (no al estudiante).
# Garantiza dos propiedades:
#   1. El estado inicial FALLA el verificador (el laboratorio tiene una avería real).
#   2. La solución de referencia APRUEBA el verificador.
# Uso (desde la raíz del repositorio): ./tests/ci-test.sh
set -u
cd "$(dirname "$0")/.." || exit 2

CONF="nginx/conf.d/sitio1.conf"
RESPALDO="$(mktemp)"
cp "$CONF" "$RESPALDO"
fallos=0

# shellcheck disable=SC2317  # se invoca desde trap
restaurar() { cp "$RESPALDO" "$CONF"; rm -f "$RESPALDO"; docker compose down >/dev/null 2>&1; }
trap restaurar EXIT

esperar_servidor() {
  for _ in $(seq 1 20); do
    curl -s -o /dev/null --max-time 2 http://127.0.0.1:8080/ && return 0
    sleep 1
  done
  echo "El servidor no respondió a tiempo."; docker compose logs web; return 1
}

# La prueba debe partir del estado inicial PUBLICADO, no del que haya dejado quien practicó.
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  if ! git diff --quiet HEAD -- nginx html; then
    echo "ERROR: hay cambios sin confirmar en nginx/ o html/ (¿practicaste el laboratorio?)."
    echo "Restaura el estado inicial con: git checkout -- nginx html"
    exit 2
  fi
fi

echo "== Arrancando el laboratorio en su estado inicial =="
docker compose down >/dev/null 2>&1           # un contenedor previo podría tener otra configuración en memoria
docker compose up -d --quiet-pull --force-recreate || exit 2
esperar_servidor || exit 2

echo "== Propiedad 1: el estado inicial debe FALLAR =="
if ./check.sh; then echo "ERROR: el estado inicial aprobó; la avería no existe."; fallos=$((fallos + 1));
else echo "OK: el estado inicial falla, como se espera."; fi

echo "== Propiedad 2: la solución de referencia debe APROBAR =="
cp solucion/sitio1.conf "$CONF"
docker compose exec -T web nginx -s reload
sleep 1
if ./check.sh; then echo "OK: la solución aprueba."
else echo "ERROR: la solución de referencia no aprueba."; fallos=$((fallos + 1)); fi

echo
if [ "$fallos" -eq 0 ]; then echo "PRUEBAS DEL LABORATORIO: OK"; exit 0
else echo "PRUEBAS DEL LABORATORIO: $fallos fallo(s)"; exit 1; fi
