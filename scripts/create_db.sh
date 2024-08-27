#!/bin/bash

# Load environment variables from .env file properly (without line endings)
set -o allexport
source <(sed -e "s/\r//" -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/=\"\1\"/g" ".env")
set +o allexport

# Function to display usage information
usage() {
  echo "Usage: $0 <database_name> [--db=mysql,postgres,mongo] [--username=<username>] [--password=<password>]"
  exit 1
}

# Check if database name is provided
if [ -z "$1" ]; then
  usage
fi

DB_NAME=$1
DB_ENGINES="mysql,postgres,mongo"  # Default to all databases

# Shift past the first argument, which is the database name
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

# Function to create database in MySQL
create_mysql_db() {
  echo "> Creating database '$DB_NAME' in MySQL..."

  # Create the database
  docker exec -i mysql"${DB_NAME_SUFFIX}" mysql -u root -p"${ADMIN_DB_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"

  # Create a user and grant privileges
  docker exec -i mysql"${DB_NAME_SUFFIX}" mysql -u root -p"${ADMIN_DB_PASSWORD}" -e "
    CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '${DB_USERNAME}'@'%';
    FLUSH PRIVILEGES;
  "
}

# Function to create database in PostgreSQL
create_postgres_db() {
  echo "> Creating database '$DB_NAME' in PostgreSQL..."
  docker exec -i postgres"${DB_NAME_SUFFIX}" psql -U postgres -c "CREATE DATABASE \"$DB_NAME\";"
}

# Function to create database in MongoDB
create_mongo_db() {
  echo "> Creating database '$DB_NAME' in MongoDB..."

  # Authenticate and create the database and a dummy collection
  docker exec -i mongo"${DB_NAME_SUFFIX}" mongosh --username "$ADMIN_DB_USERNAME" --password "$ADMIN_DB_PASSWORD" --authenticationDatabase "admin" --eval "db.getSiblingDB('$DB_NAME').createCollection('default');"

   # Create a user with a username, password, and roles for the new database
  docker exec -i mongo"${DB_NAME_SUFFIX}" mongosh admin --username "$ADMIN_DB_USERNAME" --password "$ADMIN_DB_PASSWORD" --authenticationDatabase "admin" --eval "
      db.getSiblingDB('$DB_NAME').createUser({
        user: '$DB_USERNAME',
        pwd: '$DB_PASSWORD',
        roles: [{ role: 'readWrite', db: '$DB_NAME' }]
      });
    "
}

# Note: Redis does not support multiple databases in the same way as SQL databases.

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
