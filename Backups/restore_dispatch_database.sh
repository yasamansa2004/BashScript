```bash
#!/bin/bash

backup_path=/srv/db/postgres/dispatch-backups

echo -e "------------ start restore -------------"
echo -e "\n------------ $(date) -------------\n"

# ---------------------------------------------------------
# Ask for database name
# ---------------------------------------------------------

read -r -p "Enter the new database name: " NEW_DB_NAME

NEW_DB_NAME=$(echo "$NEW_DB_NAME" | xargs)

if [[ -z "$NEW_DB_NAME" ]]; then
    echo -e "\nERROR: Database name cannot be empty!"
    exit 1
fi

if [[ ! "$NEW_DB_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo -e "\nERROR: Invalid database name: $NEW_DB_NAME"
    echo "Use only letters, numbers and underscore."
    echo "The name must start with a letter or underscore."
    exit 1
fi

# ---------------------------------------------------------
# Ask for database user
# ---------------------------------------------------------

read -r -p "Enter the database username: " DB_USER

DB_USER=$(echo "$DB_USER" | xargs)

if [[ -z "$DB_USER" ]]; then
    echo -e "\nERROR: Database username cannot be empty!"
    exit 1
fi

if [[ ! "$DB_USER" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo -e "\nERROR: Invalid database username: $DB_USER"
    echo "Use only letters, numbers and underscore."
    echo "The username must start with a letter or underscore."
    exit 1
fi

# ---------------------------------------------------------
# Ask for database password
# ---------------------------------------------------------

read -r -s -p "Enter the database password: " DB_PASSWORD
echo

if [[ -z "$DB_PASSWORD" ]]; then
    echo -e "\nERROR: Database password cannot be empty!"
    exit 1
fi

echo
echo "-- New database name : $NEW_DB_NAME --"
echo "-- Database user     : $DB_USER --"
echo

# ---------------------------------------------------------
# Check backup
# ---------------------------------------------------------

latest_backup_name=$(ls -1t "$backup_path" | head -1)

if [[ -z "$latest_backup_name" ]]; then
    echo -e "\nERROR: No backup found in $backup_path"
    exit 1
fi

latest_backup_full_path=$(readlink -f "$backup_path/$latest_backup_name")

echo -e "\n-- Latest backup --"
echo -e "Backup name: $latest_backup_name"
echo -e "Backup path: $latest_backup_full_path"

# ---------------------------------------------------------
# Check if database already exists
# ---------------------------------------------------------

echo -e "\n-- Checking database existence... --"

DB_EXISTS=$(docker exec postgres psql \
    -U postgres \
    -h 127.0.0.1 \
    -tAc "SELECT 1 FROM pg_database WHERE datname = '$NEW_DB_NAME';")

if [[ "$DB_EXISTS" == "1" ]]; then
    echo -e "\nERROR: Database '$NEW_DB_NAME' already exists!"
    echo "Restore was cancelled to prevent overwriting an existing database."
    exit 1
fi

echo -e "-- Database '$NEW_DB_NAME' does not exist. --"

# ---------------------------------------------------------
# Check if database user already exists
# ---------------------------------------------------------

echo -e "\n-- Checking database user '$DB_USER'... --"

USER_EXISTS=$(docker exec postgres psql \
    -U postgres \
    -h 127.0.0.1 \
    -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER';")

if [[ "$USER_EXISTS" == "1" ]]; then
    echo -e "\nERROR: Database user '$DB_USER' already exists!"
    echo "Please use another username."
    exit 1
fi

echo -e "-- Database user '$DB_USER' does not exist. --"

# ---------------------------------------------------------
# Create database user
# ---------------------------------------------------------

echo -e "\n-- Creating database user '$DB_USER'... --"

docker exec -e DB_PASSWORD="$DB_PASSWORD" postgres psql \
    -U postgres \
    -h 127.0.0.1 \
    -v ON_ERROR_STOP=1 \
    -c "CREATE USER \"$DB_USER\" WITH PASSWORD :'DB_PASSWORD';"

if [[ $? -eq 0 ]]; then
    echo -e "-- Database user created successfully! --"
else
    echo -e "\nERROR: Database user creation failed!"
    exit 1
fi

# ---------------------------------------------------------
# Create database
# ---------------------------------------------------------

echo -e "\n-- Creating database '$NEW_DB_NAME'... --"

docker exec postgres psql \
    -U postgres \
    -h 127.0.0.1 \
    -v ON_ERROR_STOP=1 \
    -c "CREATE DATABASE \"$NEW_DB_NAME\" OWNER \"$DB_USER\";"

if [[ $? -eq 0 ]]; then
    echo -e "-- Database created successfully! --"
else
    echo -e "\nERROR: Database creation failed!"
    exit 1
fi

# ---------------------------------------------------------
# Restore backup
# ---------------------------------------------------------

echo -e "\n-- Restoring backup into '$NEW_DB_NAME'... --"

docker exec postgres pg_restore \
    --username "postgres" \
    --no-password \
    --role "postgres" \
    --dbname "$NEW_DB_NAME" \
    --verbose \
    "/opt/dispatch-backups/$latest_backup_name"

restore_exit_code=$?

if [[ "$restore_exit_code" -eq 0 ]]; then
    echo -e "\n-- Restored without errors! --"
else
    echo -e "\n-- Restore finished with exit code $restore_exit_code --"
    echo -e "-- Please check the pg_restore output above. --"
fi

# ---------------------------------------------------------
# Set database owner
# ---------------------------------------------------------

echo -e "\n-- Setting database owner to '$DB_USER'... --"

docker exec postgres psql \
    -U postgres \
    -h 127.0.0.1 \
    -d "$NEW_DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "ALTER DATABASE \"$NEW_DB_NAME\" OWNER TO \"$DB_USER\";"

# ---------------------------------------------------------
# Grant all privileges to new user
# ---------------------------------------------------------

echo -e "\n-- Granting privileges to '$DB_USER'... --"

docker exec postgres psql \
    -U postgres \
    -h 127.0.0.1 \
    -d "$NEW_DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "
        GRANT ALL PRIVILEGES ON DATABASE \"$NEW_DB_NAME\" TO \"$DB_USER\";
        GRANT ALL PRIVILEGES ON SCHEMA public TO \"$DB_USER\";
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"$DB_USER\";
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"$DB_USER\";
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO \"$DB_USER\";

        ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT ALL PRIVILEGES ON TABLES TO \"$DB_USER\";

        ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT ALL PRIVILEGES ON SEQUENCES TO \"$DB_USER\";

        ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT ALL PRIVILEGES ON FUNCTIONS TO \"$DB_USER\";
    "

if [[ $? -eq 0 ]]; then
    echo -e "-- Privileges granted successfully! --"
else
    echo -e "\nERROR: Granting privileges failed!"
    exit 1
fi

# ---------------------------------------------------------
# Run database scripts
# ---------------------------------------------------------

echo -e "\n-- Running scripts... --"

echo -e "\n-- Dispatch_admin --"
docker exec postgres psql \
    -U postgres \
    -d "$NEW_DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "\ir /opt/scripts/dispatch_admin"

echo -e "\n-- arshady grant --"
docker exec postgres psql \
    -U postgres \
    -d Beroozresaan \
    -v ON_ERROR_STOP=1 \
    -c "\ir /opt/scripts/arshadi_grant"

echo -e "\n-- BI grant --"
docker exec postgres psql \
    -U postgres \
    -d Beroozresaan \
    -v ON_ERROR_STOP=1 \
    -c "\ir /opt/scripts/BI_grant"

echo -e "\n-- fawzi grant --"
docker exec postgres psql \
    -U postgres \
    -d Beroozresaan \
    -v ON_ERROR_STOP=1 \
    -c "\ir /opt/scripts/fawzi_grant"

echo -e "\n-- jazayeri_grant_dispatch --"
docker exec postgres psql \
    -U postgres \
    -d "$NEW_DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "\ir /opt/scripts/jazayeri_grant_dispatch"

echo -e "\n-- dispatch_permission_admin --"
docker exec postgres psql \
    -U postgres \
    -d "$NEW_DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "\ir /opt/scripts/dispatch_permission_admin"

echo -e "\n-- customer_permission_admin --"
docker exec postgres psql \
    -U postgres \
    -d "$NEW_DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "\ir /opt/scripts/customer-seller-dispatch-permision"

echo -e "\n-- pouya-grant --"
docker exec postgres psql \
    -U postgres \
    -d "$NEW_DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "\ir /opt/scripts/pouya_agh_grant"

echo -e "\n-- run scripts finished! --"

# ---------------------------------------------------------
# Show restore information
# ---------------------------------------------------------

echo -e "\n-- Restore information --"
echo -e "Database name : $NEW_DB_NAME"
echo -e "Database user : $DB_USER"
echo -e "Backup name   : $latest_backup_name"
echo -e "Backup path   : $latest_backup_full_path"

# ---------------------------------------------------------
# Bring pictures
# ---------------------------------------------------------

echo -e "\n-- bring picture from worker to monitor... --"

ssh -p 233 monitor@185.13.228.99 \
    /home/monitor/bring-images-dispatch.sh

echo -e "\n-- bring picture from monitor to here... --"

ssh support@192.168.7.10 \
    "rsync -avz -e 'ssh -p 233' monitort@185.13.228.99:/home/monitor/image-backup-dispatch/files/ /srv/Beroozresaan/dispatch-new_static/"

echo -e "\n-- images synced! --"

# ---------------------------------------------------------
# Restart dispatch services
# ---------------------------------------------------------

echo -e "\n-- dispatch-new restarting... --"

ssh support@192.168.7.10 \
    docker restart dispatch-new customer-dispatch

# ---------------------------------------------------------
# Copy backup to stage DB
# ---------------------------------------------------------

echo -e "\n------- copy backup to stage db -------"

scp "$latest_backup_full_path" \
    support@192.168.7.149:/srv/db/postgres/dispatch-backups/

echo -e "\n------------ end -------------"
echo -e "\n------------ $(date) -------------\n"
```
