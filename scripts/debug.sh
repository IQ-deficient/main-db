#!/bin/bash

# Enable debug mode to print each command as it is executed
set -x

# Load environment variables from .env file properly (without line endings)
set -o allexport
source <(sed -e "s/\r//" -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/=\"\1\"/g" ".env")
set +o allexport

# Print loaded environment variables for debugging
echo "DB_PASSWORD: ${DB_PASSWORD}"
echo "DB_NAME_SUFFIX: ${DB_NAME_SUFFIX}"

# Construct and print container name
CONTAINER_NAME="mysql${DB_NAME_SUFFIX}"
echo "CONTAINER_NAME: '${CONTAINER_NAME}'"

# Check for leading/trailing spaces or hidden characters
printf "CONTAINER_NAME (with quotes): '%s'\n" "$CONTAINER_NAME"

# Check if the container exists
docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Names}}"

# Execute command in container
docker exec -i "${CONTAINER_NAME}" mysql -uroot -p"${DB_PASSWORD}" -e "SHOW DATABASES;"