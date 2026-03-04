#!/bin/bash

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

# Function to display usage information
usage() {
  echo "Usage: $0 <database_name> [--db=mysql,postgres,mongo]"
  echo "  database_name  Name of the database to check."
  echo "  --db           Comma-separated list: mysql, postgres, mongo (default: all)."
  exit 1
}

# Display usage information if no arguments are provided
if [ -z "$1" ]; then
  usage
fi

DB_NAME=$1
DB_ENGINES="mysql,postgres,mongo"
# Shift the first argument (database name) so that the remaining arguments are processed
shift

# Parse optional parameters
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --db=*)
      DB_ENGINES="${1#--db=}"
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
  shift
done

# Function to check if a container is running
container_running() {
  docker ps -q -f "name=^${1}\$" | grep -q .
}

# Function to check database presence in MySQL
check_mysql_db() {
  echo "Checking database '$DB_NAME' in MySQL..."
  if ! container_running "mysql${DB_NAME_SUFFIX}"; then
    echo "> MySQL container 'mysql${DB_NAME_SUFFIX}' is not running. Start with: docker compose up -d mysql"
    return
  fi

  RESULT=$(docker exec -i mysql"${DB_NAME_SUFFIX}" mysql -u root -p"${ADMIN_DB_PASSWORD}" -e "SHOW DATABASES LIKE '$DB_NAME';" 2>/dev/null | awk '/^'"$DB_NAME"'$/ {print $1}')
  if [ "$RESULT" = "$DB_NAME" ]; then
    echo "> Database '$DB_NAME' EXISTS in MySQL."
  else
    echo "> Database '$DB_NAME' DOES NOT EXIST in MySQL."
  fi
}

# Function to check database presence in PostgreSQL
check_postgres_db() {
  echo "Checking database '$DB_NAME' in PostgreSQL..."

  if ! container_running "postgres${DB_NAME_SUFFIX}"; then
    echo "> Postgres container 'postgres${DB_NAME_SUFFIX}' is not running. Start with: docker compose up -d postgres"
    return
  fi

  RESULT=$(docker exec -i postgres"${DB_NAME_SUFFIX}" psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" 2>/dev/null)
  if [ "$RESULT" = "1" ]; then
    echo "> Database '$DB_NAME' EXISTS in PostgreSQL."
  else
    echo "> Database '$DB_NAME' DOES NOT EXIST in PostgreSQL."
  fi
}

# Function to check database presence in MongoDB (exact name match to avoid substring false positives)
check_mongo_db() {
  echo "Checking database '$DB_NAME' in MongoDB..."

  if ! container_running "mongo${DB_NAME_SUFFIX}"; then
    echo "> Mongo container 'mongo${DB_NAME_SUFFIX}' is not running. Start with: docker compose up -d mongo"
    return
  fi

  RESULT=$(docker exec -i mongo"${DB_NAME_SUFFIX}" mongosh --username "$ADMIN_DB_USERNAME" --password "$ADMIN_DB_PASSWORD" --authenticationDatabase "admin" --quiet --eval "db.adminCommand('listDatabases').databases.some(function(d){return d.name==='$DB_NAME';})" 2>/dev/null)
  if [ "$RESULT" = "true" ]; then
    echo "> Database '$DB_NAME' EXISTS in MongoDB."
  else
    echo "> Database '$DB_NAME' DOES NOT EXIST in MongoDB."
  fi
}

# Check database presence for each specified engine
IFS=',' read -ra ENGINES <<< "$DB_ENGINES"
for ENGINE in "${ENGINES[@]}"; do
  case $ENGINE in
    mysql)
      check_mysql_db
      ;;
    postgres)
      check_postgres_db
      ;;
    mongo)
      check_mongo_db
      ;;
    *)
      echo "Unknown database engine: $ENGINE"
      ;;
  esac
  echo "------------------------------------------------------------"
done

echo "Database '$DB_NAME' verification completed for specified engines."
