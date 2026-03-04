# Main Database Composer

Run and manage multiple databases in a containerized environment. Use one stack for local development and create a database with specific credentials per project.

## Services

| Service    | Image         | Port  | Per-project DB creation |
| ---------- | ------------- | ----- | ----------------------- |
| MySQL      | mysql:9.6.0   | 3306  | Yes                     |
| PostgreSQL | postgres:17.7 | 5432  | Yes                     |
| MongoDB    | mongo:8.2.4   | 27017 | Yes                     |
| Redis      | redis:8.4.0   | 6379  | No (single instance)    |

Containers use `restart: unless-stopped` so the database service stays running across reboots.

## Setup

1. Copy `.env.example` to `.env` in the project root and set:
   - **ADMIN_DB_USERNAME** / **ADMIN_DB_PASSWORD** — root/admin credentials for the servers (used by scripts and by you for admin access).
   - **PORT_HOST_PREFIX** — by default `127.0.0.1:` so ports bind to localhost only. Set to empty in `.env` to listen on all interfaces (e.g. for LAN access).
   - **DB_NAME_SUFFIX** — suffix for container names (e.g. `-main` → `mysql-main`). Change if you run multiple stacks.
   - **DB_USERNAME** / **DB_PASSWORD** — default credentials for each new database; override per run with `--username` and `--password`.

2. Start the stack (from project root):

   ```bash
   docker compose up -d
   ```

   Wait for healthchecks to pass (or a few seconds) before creating databases.

## Creating a database for a project

From the project root:

```bash
bash scripts/create_db.sh <database_name> [--db=mysql,postgres,mongo] [--username=<user>] [--password=<pass>]
```

- **database_name** — letters, numbers, and underscores only.
- **--db** — comma-separated list of engines (default: `mysql,postgres,mongo`).
- **--username** / **--password** — optional; if omitted, values from `.env` are used.

Example:

```bash
bash scripts/create_db.sh myapp --db=mysql,postgres --username=myapp --password=secret
```

This creates the database and a dedicated user with full access on MySQL and PostgreSQL (and MongoDB when `mongo` is included). Scripts check that the relevant containers are running and print clear errors if not.

## Checking if a database exists

From the project root:

```bash
bash scripts/find_db.sh <database_name> [--db=mysql,postgres,mongo]
```

Example:

```bash
bash scripts/find_db.sh myapp --db=mysql,postgres,mongo
```

Reports for each engine whether the database exists. Containers are checked first; if one is not running, you get a short message instead of a docker error.

## Connection examples

With default ports and `.env` values (e.g. `DB_NAME_SUFFIX=-main`):

- **MySQL:** `mysql -h 127.0.0.1 -P 3306 -u <DB_USERNAME> -p <database_name>`
- **PostgreSQL:** `psql -h 127.0.0.1 -p 5432 -U <DB_USERNAME> -d <database_name>`
- **MongoDB:** `mongosh "mongodb://<DB_USERNAME>:<DB_PASSWORD>@127.0.0.1:27017/<database_name>?authSource=<database_name>"`
- **Redis:** `redis-cli -h 127.0.0.1 -p 6379`

Scripts resolve paths from their own location, so you can run them from any directory; they change to the project root and load `.env` from there.
