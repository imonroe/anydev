#!/bin/bash
# lando - Path-translation wrapper for Lando CLI
#
# Problem: Inside this container, the code directory lives at /home/coder/code,
# but Lando registers project roots at their host filesystem paths
# (e.g., /home/ian/code/myproject). This wrapper translates the CWD to the
# equivalent host path before invoking Lando so project lookups succeed and
# volume mounts created by "lando start" point to valid host paths.
#
# Requirements:
#   - HOST_CODE_DIR env var must be set (injected via docker-compose.yml)
#   - ${HOST_CODE_DIR} must also be mounted at the same absolute path inside
#     the container (see the matching volume in docker-compose.yml)

CONTAINER_CODE="/home/coder/code"
HOST_CODE="${HOST_CODE_DIR:-}"

if [ -n "$HOST_CODE" ]; then
    # Normalize: strip trailing slash
    HOST_CODE="${HOST_CODE%/}"
    CURRENT_DIR="$(pwd)"

    if [[ "$CURRENT_DIR" == "$CONTAINER_CODE"* ]]; then
        RELATIVE="${CURRENT_DIR#$CONTAINER_CODE}"
        HOST_DIR="${HOST_CODE}${RELATIVE}"

        if [ -d "$HOST_DIR" ]; then
            cd "$HOST_DIR"
        fi
    fi
fi

exec /usr/local/bin/lando.real "$@"
