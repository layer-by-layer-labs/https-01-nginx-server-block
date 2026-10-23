# HTTPS-01 · Nginx no sirve tu sitio: diagnostica y corrige un server block

[![Probar laboratorio](https://github.com/layer-by-layer-labs/https-01-nginx-server-block/actions/workflows/test-lab.yml/badge.svg)](https://github.com/layer-by-layer-labs/https-01-nginx-server-block/actions/workflows/test-lab.yml)

> Serie **HTTPS en Linux: del servidor vacío al sitio seguro** · Unidad 01
> 🎬 Vídeo conceptual: *(enlace pendiente)* · 🛠️ Vídeo tutorial: *(enlace pendiente)*

Tienes un servidor Nginx que debería publicar `sitio1.lab.test`, pero los visitantes reciben otra página. Tu trabajo es **averiguar por qué** y corregirlo, como lo haría un administrador de infraestructura.

## Objetivos de aprendizaje

Al terminar podrás:

1. Explicar cómo elige Nginx qué *server block* atiende una petición a partir del encabezado `Host`.
2. Usar `curl -v` para ver la petición y la respuesta completas.
3. Validar una configuración con `nginx -t` y aplicarla sin reiniciar con `nginx -s reload`.
4. Distinguir entre la configuración guardada en disco y la configuración que el servidor está usando.

## Requisitos previos

- **Docker** con Docker Compose v2: Docker Desktop en macOS/Windows, o Docker Engine en Linux.
- `curl` y `git`.
- Saber moverte en la terminal y editar un archivo de texto.

Probado en macOS (Apple Silicon) y Linux (Ubuntu). En Windows debería funcionar desde WSL2, pero aún no se ha probado.

## Puesta en marcha

```bash
git clone https://github.com/layer-by-layer-labs/https-01-nginx-server-block.git
cd https-01-nginx-server-block
docker compose up -d        # arranca Nginx en segundo plano
docker compose ps           # el servicio "web" debe aparecer como "running"
```

El servidor queda en `http://127.0.0.1:8080`, accesible solo desde tu equipo.

## La misión

Pide la página de `sitio1.lab.test`. No hace falta tocar DNS ni el archivo `hosts`: con `-H` enviamos el nombre directamente en el encabezado `Host`.

```bash
curl -H "Host: sitio1.lab.test" http://127.0.0.1:8080/
```

Deberías ver *"Bienvenido a sitio1.lab.test"*, pero ves otra cosa. **Diagnostica la causa y corrígela.**

### Herramientas que te ayudarán

| Pregunta | Comando |
|---|---|
| ¿Qué respondió exactamente el servidor? | `curl -v -H "Host: sitio1.lab.test" http://127.0.0.1:8080/` |
| ¿Qué server block atendió la petición? | Busca el encabezado `X-Bloque` en la salida de `curl -v` |
| ¿Qué dicen los registros? | `docker compose logs web` |
| ¿Es válida la configuración? | `docker compose exec web nginx -t` |
| ¿Cómo aplico un cambio? | `docker compose exec web nginx -s reload` |

Los archivos de configuración están en `nginx/conf.d/` y el contenido de los sitios en `html/`.

## Verifica tu trabajo

```bash
./check.sh
```

El verificador hace peticiones HTTP reales a tu servidor y te dice qué falla, con pistas pero sin la solución.

### Criterios de aprobación

| # | Prueba |
|---|---|
| 1 | El contenedor `web` está en ejecución |
| 2 | `nginx -t` no reporta errores |
| 3 | `Host: sitio1.lab.test` recibe 200 desde el bloque `sitio1` |
| 4 | sitio1 sirve un archivo recién creado en `html/sitio1/`, lo que comprueba que sirve contenido real y no una respuesta fija |
| 5 | Un nombre desconocido **no** recibe sitio1 (lo atiende el sitio por defecto con 404) |
| 6 | Una ruta inexistente en sitio1 devuelve 404 |

Apruebas cuando ves `Resultado: APROBADO (6/6 pruebas)`.

## Preguntas de comprobación

<details><summary>1. ¿Por qué Nginx respondió con el sitio por defecto y no con un error?</summary>

Porque ningún `server_name` coincidió con el encabezado `Host`. En ese caso Nginx no rechaza la petición: se la entrega al bloque marcado como `default_server`.
</details>

<details><summary>2. Corregiste el archivo, pero ./check.sh sigue fallando. ¿Qué pasó?</summary>

Nginx sigue usando la configuración que cargó al arrancar. Los cambios en disco solo se aplican al recargar (`nginx -s reload`) o reiniciar. `nginx -t` valida el archivo, no lo que está en ejecución.
</details>

<details><summary>3. ¿Por qué la prueba 5 es tan importante como la 3?</summary>

Porque hacer que sitio1 responda a *cualquier* nombre también haría pasar la prueba 3, pero publicaría tu sitio con nombres ajenos. Una configuración correcta acepta lo esperado **y** rechaza lo inesperado.
</details>

## Reto adicional

Crea `sitio2.lab.test` con su propio directorio y su propio server block. Comprueba con `curl -v` que cada nombre recibe su contenido y su valor de `X-Bloque`.

## Solución

La solución de referencia está en [`solucion/`](solucion/). Intenta resolverlo antes de abrirla: el valor del laboratorio está en el diagnóstico.

## Limpieza

```bash
docker compose down
```

## Licencia

- Código y configuraciones: [MIT](LICENSE).
- Textos y documentación: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/deed.es).

© 2026 Oscar H. Mondragón
