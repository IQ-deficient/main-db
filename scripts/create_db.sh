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
  echo "Usage: $0 <database_name> [--db=mysql,postgres,mongo] [--username=<username>] [--password=<password>]"
  echo "  database_name  Alphanumeric and underscores only."
  echo "  --db           Comma-separated list: mysql, postgres, mongo (default: all)."
  exit 1
}

# Display usage information if no arguments are provided
if [ -z "$1" ]; then
  usage
fi

DB_NAME=$1
# Validate database name (alphanumeric and underscore only)
if ! [[ "$DB_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
  echo "Error: Database name must contain only letters, numbers, and underscores."
  exit 1
fi

DB_ENGINES="mysql,postgres,mongo"
# Shift the first argument (database name) so that the remaining arguments are processed
shift

# Parse optional parameters and replace loaded environment variables if provided
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --db=*)
      DB_ENGINES="${1#--db=}"
      ;;
    --username=*)
      DB_USERNAME="${1#--username=}"
      ;;
    --password=*)
      DB_PASSWORD="${1#--password=}"
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
  shift
done

# Ensure required env vars are set
if [ -z "${DB_USERNAME:-}" ] || [ -z "${DB_PASSWORD:-}" ]; then
  echo "Error: Database username and password must be set in .env or provided via --username and --password command arguments."
  exit 1
fi

# Function to check if a container is running
container_running() {
  docker ps -q -f "name=^${1}\$" | grep -q .
}

# Function to create database in MySQL
create_mysql_db() {
  echo "> Creating database '$DB_NAME' in MySQL..."

  if ! container_running "mysql${DB_NAME_SUFFIX}"; then
    echo "Error: MySQL container 'mysql${DB_NAME_SUFFIX}' is not running. Start with: docker compose up -d mysql"
    return 1
  fi

  # Create the database if it doesn't exist
  docker exec -i mysql"${DB_NAME_SUFFIX}" mysql -u root -p"${ADMIN_DB_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
  
  # Create a user with full privileges on the new database
  docker exec -i mysql"${DB_NAME_SUFFIX}" mysql -u root -p"${ADMIN_DB_PASSWORD}" -e "
    CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '${DB_USERNAME}'@'%';
    FLUSH PRIVILEGES;
  "
}

# Function to create database in PostgreSQL
create_postgres_db() {
  echo "> Creating database '$DB_NAME' in PostgreSQL..."

  if ! container_running "postgres${DB_NAME_SUFFIX}"; then
    echo "Error: Postgres container 'postgres${DB_NAME_SUFFIX}' is not running. Start with: docker compose up -d postgres"
    return 1
  fi

  # Escape single quotes in password for use inside SQL single-quoted string
  PG_PWD="${DB_PASSWORD//\'/\'\'}"

  # Create the database if it does not already exist
  docker exec -i postgres"${DB_NAME_SUFFIX}" psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
    docker exec -i postgres"${DB_NAME_SUFFIX}" psql -U postgres -c "CREATE DATABASE \"$DB_NAME\";"

  # Create a dedicated user with username and password, or update password if the user already exists
  docker exec -i postgres"${DB_NAME_SUFFIX}" psql -U postgres -c "
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_USERNAME') THEN
        CREATE USER \"$DB_USERNAME\" WITH PASSWORD '$PG_PWD';
      ELSE
        ALTER USER \"$DB_USERNAME\" WITH PASSWORD '$PG_PWD';
      END IF;
    END \$\$;
  "

  # Allow the user to connect to this database and grant full access to the public schema and its objects
  docker exec -i postgres"${DB_NAME_SUFFIX}" psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USERNAME\";"
  docker exec -i postgres"${DB_NAME_SUFFIX}" psql -U postgres -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USERNAME\"; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"$DB_USERNAME\"; GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"$DB_USERNAME\";"
}

# Function to create database in MongoDB
create_mongo_db() {
  echo "> Creating database '$DB_NAME' in MongoDB..."

  if ! container_running "mongo${DB_NAME_SUFFIX}"; then
    echo "Error: Mongo container 'mongo${DB_NAME_SUFFIX}' is not running. Start with: docker compose up -d mongo"
    return 1
  fi

  # Authenticate and create the database with a default collection
  docker exec -i mongo"${DB_NAME_SUFFIX}" mongosh --username "$ADMIN_DB_USERNAME" --password "$ADMIN_DB_PASSWORD" --authenticationDatabase "admin" --eval "db.getSiblingDB('$DB_NAME').createCollection('default');"
  
  # Create a user with roles for the new database (drop and recreate so password updates take effect)
  docker exec -i mongo"${DB_NAME_SUFFIX}" mongosh admin --username "$ADMIN_DB_USERNAME" --password "$ADMIN_DB_PASSWORD" --authenticationDatabase "admin" --eval "
    var d = db.getSiblingDB('$DB_NAME');
    try { d.dropUser('$DB_USERNAME'); } catch (e) {}
    d.createUser({
      user: '$DB_USERNAME',
      pwd: '$DB_PASSWORD',
      roles: [{ role: 'readWrite', db: '$DB_NAME' }]
    });
  "
}

# Note: Redis does not support multiple databases in the same way as other databases.

# Create databases based on specified engines
IFS=',' read -ra ENGINES <<< "$DB_ENGINES"
for ENGINE in "${ENGINES[@]}"; do
  case $ENGINE in
    mysql)
      create_mysql_db
      ;;
    postgres)
      create_postgres_db
      ;;
    mongo)
      create_mongo_db
      ;;
    *)
      echo "Unknown database engine: $ENGINE"
      ;;
  esac
  echo "------------------------------------------------------------"
done

echo "Database '$DB_NAME' created in specified databases."
