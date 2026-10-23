#!/bin/sh
# Reconciles this server against databases.csv and users.csv (overlay assets), both AUTHORITATIVE.
# Runs on every Argo CD sync as a PostSync hook; see Job.ensure-databases.yaml. Same structure as
# postgres' ensure-databases.sh.
#
# THIS SCRIPT DROPS THINGS. A database on the server but not in databases.csv is dropped, with its
# contents; a user not in users.csv is dropped. Hence the guards below, which refuse to run on an
# empty or unreadable CSV: the failure mode of a file that did not mount would otherwise be "drop
# the entire server".
#
# Idempotent: a second run changes nothing.
set -eu

DATABASES_CSV=/mnt/users-databases/databases.csv
USERS_CSV=/mnt/users-databases/users.csv
PASSWORD_DIR=/mnt/passwords  # The mariadb-users Secret: one key (file) per user

# Never touched, whatever the CSVs say.
PROTECTED_DATABASES="information_schema mysql performance_schema sys"
PROTECTED_USERS="root mariadb.sys PUBLIC"

# Exact privilege names, matched whole: they are interpolated into a GRANT run as root, so a value
# must not merely look unusual, it must be impossible. One per line, matched with grep -xF.
ALLOWED_PRIVILEGES='ALL
SELECT
INSERT
UPDATE
DELETE
CREATE
DROP
ALTER
INDEX
REFERENCES
TRIGGER
EXECUTE
CREATE TEMPORARY TABLES
LOCK TABLES
CREATE VIEW
SHOW VIEW
CREATE ROUTINE
ALTER ROUTINE'

# Through the environment rather than -p, so the password never shows in the process list.
MYSQL_PWD="$MARIADB_ROOT_PASSWORD"
export MYSQL_PWD

sql() { mariadb -h "$MARIADB_HOST" -u root "$@"; }
sql_value() { mariadb -h "$MARIADB_HOST" -u root -N -B "$@"; }

# Strip comments, blank lines, the header row and any trailing CR
rows() { tr -d '\r' < "$1" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' | tail -n +2; }

valid_identifier() {
    case "$1" in
        '' | *[!A-Za-z0-9_]*) return 1 ;;
        *) return 0 ;;
    esac
}

contains_word() {  # contains_word <needle> <space or newline separated haystack>
    for w in $2; do [ "$w" = "$1" ] && return 0; done
    return 1
}

# PostSync waits for the Deployment to be healthy, so this returns at once in practice; it is for
# a run started by hand against a server still coming up.
until mariadb-admin ping -h "$MARIADB_HOST" -u root --silent 2>/dev/null; do
    echo "waiting for ${MARIADB_HOST}:3306"
    sleep 2
done

# The hardened image keeps mariadb-install-db's leftovers: anonymous ''@'localhost' accounts, which
# SHADOW real users connecting from localhost (the most specific host matches first), a `test`
# database, PUBLIC (every user) holding near-ALL on `test` and any `test_%` database, so any user
# could create one, and root rows for the hostname of the pod that initialised the volume (never
# seen again, and logged as ignored on every privilege reload with --skip-name-resolve), 127.0.0.1
# and ::1. Two root rows remain: localhost (the socket, used by the probes) and % (this Job, TCP).
sql <<'SQL'
DELETE FROM mysql.global_priv WHERE User = '';
DELETE FROM mysql.global_priv WHERE User = 'root' AND Host NOT IN ('localhost', '%');
DELETE FROM mysql.proxies_priv WHERE Host NOT IN ('localhost', '%');
DELETE FROM mysql.db WHERE Db IN ('test', 'test\\_%');
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
SQL

# ---------------------------------------------------------------- read and validate the CSVs ---
#
# Everything is parsed and checked before a single statement changes anything: a file that failed
# to mount, or a row naming a database that does not exist, must stop the run before the drops.

[ -r "$DATABASES_CSV" ] || { echo "cannot read $DATABASES_CSV" >&2; exit 1; }
[ -r "$USERS_CSV" ] || { echo "cannot read $USERS_CSV" >&2; exit 1; }

desired_dbs=''
db_specs=''
while IFS=, read -r db charset collate _rest; do
    [ -n "${db:-}" ] || continue
    : "${charset:=utf8mb4}"
    : "${collate:=utf8mb4_general_ci}"
    for field in "$db" "$charset" "$collate"; do
        valid_identifier "$field" || { echo "databases.csv: '${field}' is not a bare identifier" >&2; exit 1; }
    done
    desired_dbs="${desired_dbs}${db} "
    db_specs="${db_specs}${db}:${charset}:${collate}
"
done <<EOF
$(rows "$DATABASES_CSV")
EOF

desired_users=''
grants=''
while IFS=, read -r user db privs _rest; do
    [ -n "${user:-}" ] || continue
    : "${privs:=ALL}"
    valid_identifier "$user" || { echo "users.csv: '${user}' is not a bare identifier" >&2; exit 1; }
    valid_identifier "$db" || { echo "users.csv: '${db}' is not a bare identifier" >&2; exit 1; }
    contains_word "$db" "$desired_dbs" || { echo "users.csv: '${db}' is not in databases.csv" >&2; exit 1; }

    # Privileges are '|' separated; each must match the allowlist exactly
    old_ifs=$IFS; IFS='|'
    for p in $privs; do
        printf '%s\n' "$ALLOWED_PRIVILEGES" | grep -qxF "$p" \
            || { IFS=$old_ifs; echo "users.csv: privilege '${p}' is not allowed" >&2; exit 1; }
    done
    IFS=$old_ifs

    contains_word "$user" "$desired_users" || desired_users="${desired_users}${user} "
    grants="${grants}${user}:${db}:${privs}
"
done <<EOF
$(rows "$USERS_CSV")
EOF

# What makes the drops survivable: an empty CSV is always a mistake (a ConfigMap that lost its key,
# a bad edit), and would otherwise read as "nothing is wanted" and empty the server.
[ -n "$desired_dbs" ] || { echo "databases.csv yielded no rows; refusing to drop every database" >&2; exit 1; }
[ -n "$desired_users" ] || { echo "users.csv yielded no rows; refusing to drop every user" >&2; exit 1; }

# Every password must be present, and alphanumeric: it is interpolated into a quoted SQL literal.
for user in $desired_users; do
    [ -r "${PASSWORD_DIR}/${user}" ] || {
        echo "no password for '${user}': add it as key '${user}' to Secret.mariadb-users.yaml (overlay) and reseal" >&2
        exit 1
    }
    case "$(cat "${PASSWORD_DIR}/${user}")" in
        '' | *[!A-Za-z0-9]*) echo "password for '${user}' is empty or not alphanumeric" >&2; exit 1 ;;
    esac
done

echo "desired databases: ${desired_dbs}"
echo "desired users:     ${desired_users}"

# ------------------------------------------------------------------------------ create/update ---

printf '%s' "$db_specs" | while IFS=: read -r db charset collate; do
    [ -n "${db:-}" ] || continue
    sql <<SQL
CREATE DATABASE IF NOT EXISTS \`${db}\` CHARACTER SET ${charset} COLLATE ${collate};
ALTER DATABASE \`${db}\` CHARACTER SET ${charset} COLLATE ${collate};
SQL
    echo "ensured database ${db} (${charset}/${collate})"
done

for user in $desired_users; do
    password=$(cat "${PASSWORD_DIR}/${user}")
    # CREATE for a fresh volume; ALTER makes the password self-healing when the Secret and the
    # server have drifted; REVOKE makes users.csv authoritative over grants: everything goes, then
    # only what the file says comes back.
    sql <<SQL
CREATE USER IF NOT EXISTS '${user}'@'%' IDENTIFIED BY '${password}';
ALTER USER '${user}'@'%' IDENTIFIED BY '${password}';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '${user}'@'%';
SQL
    echo "ensured user ${user}"
done

printf '%s' "$grants" | while IFS=: read -r user db privs; do
    [ -n "${user:-}" ] || continue
    sql -e "GRANT $(printf '%s' "$privs" | sed 's/|/, /g') ON \`${db}\`.* TO '${user}'@'%';"
    echo "granted ${privs} on ${db} to ${user}"
done

# ------------------------------------------------------------------------------------- drops ---
#
# Last, once everything above has succeeded.

for db in $(sql_value -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA"); do
    contains_word "$db" "$PROTECTED_DATABASES" && continue
    contains_word "$db" "$desired_dbs" && continue
    echo "DROPPING database ${db}: not in databases.csv"
    sql -e "DROP DATABASE \`${db}\`;"
done

for user in $(sql_value -e "SELECT DISTINCT User FROM mysql.user WHERE User <> ''"); do
    contains_word "$user" "$PROTECTED_USERS" && continue
    contains_word "$user" "$desired_users" && continue
    echo "DROPPING user ${user}: not in users.csv"
    sql -e "DROP USER IF EXISTS '${user}'@'%';"
done

sql -e "FLUSH PRIVILEGES;"
echo "reconciled"
