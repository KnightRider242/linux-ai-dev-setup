find_container_engine() {
  if command -v podman >/dev/null 2>&1; then
    printf 'podman'
  elif command -v docker >/dev/null 2>&1; then
    printf 'docker'
  else
    printf 'none'
  fi
}

CONTAINER_ENGINE="$(find_container_engine)"
if ((INSTALL_DB_CONTAINERS)); then
  if [[ "$CONTAINER_ENGINE" == "none" ]]; then
    warn "Neither Podman nor Docker is available; database containers will be skipped."
  else
    info "Creating PostgreSQL and MongoDB development services using ${CONTAINER_ENGINE}"
    mkdir -p "$SERVICES_DIR"
    ENV_PATH="${SERVICES_DIR}/.env"
    if [[ ! -f "$ENV_PATH" ]]; then
      umask 077
      cat > "$ENV_PATH" <<EOF
POSTGRES_USER=developer
POSTGRES_PASSWORD=$(openssl rand -hex 18)
POSTGRES_DB=appdb
MONGO_USER=developer
MONGO_PASSWORD=$(openssl rand -hex 18)
EOF
      chmod 600 "$ENV_PATH"
    fi

    cat > "${SERVICES_DIR}/compose.yml" <<'YAML'
services:
  postgres:
    image: docker.io/library/postgres:17
    container_name: postgres-dev
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "127.0.0.1:5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  mongo:
    image: docker.io/library/mongo:8
    container_name: mongo-dev
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_USER}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_PASSWORD}
    ports:
      - "127.0.0.1:27017:27017"
    volumes:
      - mongo_data:/data/db

volumes:
  postgres_data:
  mongo_data:
YAML

    cat > "${SERVICES_DIR}/compose-command.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if command -v podman-compose >/dev/null 2>&1; then
  exec podman-compose "$@"
elif command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
  exec podman compose "$@"
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  exec docker compose "$@"
else
  echo "No working Compose implementation found." >&2
  exit 1
fi
SH

    cat > "${SERVICES_DIR}/start.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./compose-command.sh up -d
if command -v podman >/dev/null 2>&1; then
  podman ps --filter name=postgres-dev --filter name=mongo-dev
else
  docker ps --filter name=postgres-dev --filter name=mongo-dev
fi
SH

    cat > "${SERVICES_DIR}/stop.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./compose-command.sh down
SH

    cat > "${SERVICES_DIR}/psql.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
set -a
# shellcheck disable=SC1091
source ./.env
set +a
ENGINE=podman
command -v podman >/dev/null 2>&1 || ENGINE=docker
"$ENGINE" exec -it postgres-dev psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
SH

    cat > "${SERVICES_DIR}/mongosh.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
set -a
# shellcheck disable=SC1091
source ./.env
set +a
ENGINE=podman
command -v podman >/dev/null 2>&1 || ENGINE=docker
"$ENGINE" exec -it mongo-dev mongosh --username "$MONGO_USER" --password "$MONGO_PASSWORD" --authenticationDatabase admin
SH

    chmod +x "${SERVICES_DIR}"/*.sh
    (
      cd "$SERVICES_DIR"
      ./compose-command.sh up -d
    ) || warn "Database services were configured but did not start. Run ${SERVICES_DIR}/start.sh later."
  fi
fi
