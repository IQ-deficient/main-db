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

# Function to check database in MySQL
check_mysql_db() {
  echo "Checking database '$DB_NAME' in MySQL..."
  RESULT=$(docker exec -i mysql"${DB_NAME_SUFFIX}" mysql -uroot -p"${DB_PASSWORD}" -e "SHOW DATABASES LIKE '$DB_NAME';" | awk '/^'"$DB_NAME"'$/ {print $1}')
  if [ "$RESULT" == "$DB_NAME" ]; then
    echo "Database '$DB_NAME' exists in MySQL."
  else
    echo "Database '$DB_NAME' does not exist in MySQL."
  fi
}

# Function to check database in PostgreSQL
check_postgres_db() {
  echo "Checking database '$DB_NAME' in PostgreSQL..."
  RESULT=$(docker exec -i postgres"${DB_NAME_SUFFIX}" psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';")
  if [ "$RESULT" == "1" ]; then
    echo "Database '$DB_NAME' exists in PostgreSQL."
  else
    echo "Database '$DB_NAME' does not exist in PostgreSQL."
  fi
}

# Function to check database in MongoDB
check_mongo_db() {
  echo "Checking database '$DB_NAME' in MongoDB..."
  RESULT=$(docker exec -i mongo"${DB_NAME_SUFFIX}" mongo --eval "db.adminCommand('listDatabases').databases" | grep "$DB_NAME")
  if [[ "$RESULT" == *"$DB_NAME"* ]]; then
    echo "Database '$DB_NAME' exists in MongoDB."
  else
    echo "Database '$DB_NAME' does not exist in MongoDB."
  fi
}

# Find databases based on specified engines and provided name
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
