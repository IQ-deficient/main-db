#!/bin/bash

# Load environment variables from .env file properly (without line endings)
set -o allexport
source <(sed -e "s/\r//" -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/=\"\1\"/g" ".env")
set +o allexport

# Function to display usage information
usage() {
  echo "Usage: $0 <database_name> [--db:mysql,postgres,mongo]"
  exit 1
}

# Check if database name is provided
if [ -z "$1" ]; then
  usage
fi

DB_NAME=$1
DB_ENGINES="mysql,postgres,mongo"  # Default to all databases

# Parse optional parameters
if [[ "$2" == --db=* ]]; then
  DB_ENGINES="${2#--db=}"
fi

# Function to create database in MySQL
create_mysql_db() {
  echo "Creating database '$DB_NAME' in MySQL..."
  docker exec -i mysql"${DB_NAME_SUFFIX}" mysql -uroot -p"${DB_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
}

# Function to create database in PostgreSQL
create_postgres_db() {
  echo "Creating database '$DB_NAME' in PostgreSQL..."
  docker exec -i postgres"${DB_NAME_SUFFIX}" psql -U postgres -c "CREATE DATABASE \"$DB_NAME\";"
}

# Function to create database in MongoDB
create_mongo_db() {
  echo "Creating database '$DB_NAME' in MongoDB..."
  docker exec -i mongo"${DB_NAME_SUFFIX}" mongo --eval "db.getSiblingDB('$DB_NAME').createCollection('dummyCollection');"
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
