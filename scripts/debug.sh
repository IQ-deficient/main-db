#!/bin/bash

# Enable debug mode to print each command as it is executed
# set -x

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f ".env" ]; then
  echo "Error: File .env not found in project root ($PROJECT_ROOT). Copy .env.example to .env and configure."
  exit 1
fi

# Load environment variables from .env file properly (without line endings)
set -o allexport
source <(sed -e "s/\r//" -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/=\"\1\"/g" ".env")
set +o allexport

echo "DB_NAME_SUFFIX: ${DB_NAME_SUFFIX}"

# Review running containers for this stack (names include DB_NAME_SUFFIX)
echo "Running containers:"
docker ps --filter "name=${DB_NAME_SUFFIX}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Helper: container is running when this returns 0
container_running() {
  docker ps -q -f "name=^${1}\$" | grep -q .
}

# Print database entries for each running database service
echo ""
if container_running "mysql${DB_NAME_SUFFIX}"; then
  echo "--- MySQL (mysql${DB_NAME_SUFFIX}) databases ---"
  docker exec -i mysql"${DB_NAME_SUFFIX}" mysql -u root -p"${ADMIN_DB_PASSWORD}" -e "SHOW DATABASES;" 2>/dev/null || echo "(failed to list)"
  echo ""
fi

if container_running "postgres${DB_NAME_SUFFIX}"; then
  echo "--- PostgreSQL (postgres${DB_NAME_SUFFIX}) databases ---"
  docker exec -i postgres"${DB_NAME_SUFFIX}" psql -U postgres -tAc "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;" 2>/dev/null || echo "(failed to list)"
  echo ""
fi

if container_running "mongo${DB_NAME_SUFFIX}"; then
  echo "--- MongoDB (mongo${DB_NAME_SUFFIX}) databases ---"
  docker exec -i mongo"${DB_NAME_SUFFIX}" mongosh --username "$ADMIN_DB_USERNAME" --password "$ADMIN_DB_PASSWORD" --authenticationDatabase "admin" --quiet --eval "db.adminCommand('listDatabases').databases.forEach(function(d){print(d.name);})" 2>/dev/null || echo "(failed to list)"
  echo ""
fi
