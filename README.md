# Main Database Composer
Multiple dockerized all-purpose databases for my projects local development

## Setup

Create a `.env` file on project root, copy `.env.example` into it and update variables if needed.

Alter `ADMIN_DB_USERNAME` and `ADMIN_DB_PASSWORD` as root credentials.

Alter `DB_USERNAME` and `DB_PASSWORD` as default database specific credentials.

## Execution

Run the `create_db.sh` script with the following command on project root.

> bash scripts/create_db.sh `database name` --db=mysql,postgres,mongo --username=<i>db_user</i> --password=<i>db_pass</i>

## Validating

Run the `find_db.sh` script with the following command on project root.

> bash scripts/find_db.sh `database name` --db=mysql,postgres,mongo

