#!/bin/sh
# Reconciles this server against databases.csv and users.csv (overlay assets), both AUTHORITATIVE.
# Runs on every Argo CD sync as a PostSync hook; see Job.ensure-databases.yaml. Same structure as
# mariadb's ensure-databases.sh.
#
# THIS SCRIPT DROPS THINGS. A database on the server but not in databases.csv is dropped, with its
# contents; a role not in users.csv is dropped. Hence the guards below, which refuse to run on an
# empty or unreadable CSV: the failure mode of a file that did not mount would otherwise be "drop
# the entire server".
#
# Idempotent: a second run changes nothing.
set -eu

DATABASES_CSV=/mnt/users-databases/databases.csv
USERS_CSV=/mnt/users-databases/users.csv
PASSWORD_DIR=/mnt/passwords  # The postgres-users Secret: one key (file) per role

# Never touched, whatever the CSVs say. The built-in pg_* roles are matched by prefix further down.
PROTECTED_DATABASES="postgres template0 template1"
PROTECTED_ROLES="postgres"

# Exact privilege names, matched whole: they are interpolated into a GRANT run as the superuser.
# This is every database-level privilege PostgreSQL has; ALL is turned into ownership below, which
# is what an application running its own migrations needs.
ALLOWED_PRIVILEGES='ALL
CONNECT
CREATE
TEMPORARY'

PGPASSWORD="$POSTGRES_PASSWORD"
export PGPASSWORD

# ON_ERROR_STOP makes `set -e` mean something: without it psql reports a failed statement on stderr
# and still exits 0, and the drops would run after a broken GRANT. The first argument is the
# database to connect to: CREATE DATABASE and ALTER SCHEMA need different connections. It is _db,
# not db, because sh has no local variables and `db` would overwrite the callers' loop variable.
sql() { _db="$1"; shift; psql -v ON_ERROR_STOP=1 -q -h "$POSTGRES_HOST" -U postgres -d "$_db" "$@"; }
sql_value() { _db="$1"; shift; psql -v ON_ERROR_STOP=1 -tAq -h "$POSTGRES_HOST" -U postgres -d "$_db" "$@"; }

# Strip comments, blank lines, the header row and any trailing CR
rows() { tr -d '\r' < "$1" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' | tail -n +2; }

# Letters, digits, _ and - (db02 had a stork-server role). Always double-quoted in the SQL below,
# so - is safe; no quote character can get through.
valid_identifier() {
    case "$1" in
        '' | -* | *[!A-Za-z0-9_-]*) return 1 ;;
        *) return 0 ;;
    esac
}

contains_word() {  # contains_word <needle> <space or newline separated haystack>
    for w in $2; do [ "$w" = "$1" ] && return 0; done
    return 1
}

# PostSync waits for the Deployment to be healthy, so this returns at once in practice; it is for
# a run started by hand against a server still coming up.
until pg_isready -h "$POSTGRES_HOST" -U postgres >/dev/null 2>&1; do
    echo "waiting for ${POSTGRES_HOST}:5432"
    sleep 2
done

# ---------------------------------------------------------------- read and validate the CSVs ---
#
# Everything is parsed and checked before a single statement changes anything: a file that failed
# to mount, or a row naming a database that does not exist, must stop the run before the drops.

[ -r "$DATABASES_CSV" ] || { echo "cannot read $DATABASES_CSV" >&2; exit 1; }
[ -r "$USERS_CSV" ] || { echo "cannot read $USERS_CSV" >&2; exit 1; }

desired_dbs=''
db_specs=''
while IFS=, read -r db locale _rest; do
    [ -n "${db:-}" ] || continue
    : "${locale:=default}"
    valid_identifier "$db" || { echo "databases.csv: '${db}' is not a valid name" >&2; exit 1; }
    case "$locale" in
        default | C) ;;
        *) echo "databases.csv: locale '${locale}' for '${db}' is neither 'default' nor 'C'" >&2; exit 1 ;;
    esac
    desired_dbs="${desired_dbs}${db} "
    db_specs="${db_specs}${db}:${locale}
"
done <<EOF
$(rows "$DATABASES_CSV")
EOF

desired_roles=''
grants=''
while IFS=, read -r role db privs _rest; do
    [ -n "${role:-}" ] || continue
    : "${privs:=ALL}"
    valid_identifier "$role" || { echo "users.csv: '${role}' is not a valid name" >&2; exit 1; }
    valid_identifier "$db" || { echo "users.csv: '${db}' is not a valid name" >&2; exit 1; }
    contains_word "$db" "$desired_dbs" || { echo "users.csv: '${db}' is not in databases.csv" >&2; exit 1; }

    old_ifs=$IFS; IFS='|'
    for p in $privs; do
        printf '%s\n' "$ALLOWED_PRIVILEGES" | grep -qxF "$p" \
            || { IFS=$old_ifs; echo "users.csv: privilege '${p}' is not allowed" >&2; exit 1; }
    done
    IFS=$old_ifs

    contains_word "$role" "$desired_roles" || desired_roles="${desired_roles}${role} "
    grants="${grants}${role}:${db}:${privs}
"
done <<EOF
$(rows "$USERS_CSV")
EOF

# What makes the drops survivable: an empty CSV is always a mistake (a ConfigMap that lost its key,
# a bad edit), and would otherwise read as "nothing is wanted" and empty the server.
[ -n "$desired_dbs" ] || { echo "databases.csv yielded no rows; refusing to drop every database" >&2; exit 1; }
[ -n "$desired_roles" ] || { echo "users.csv yielded no rows; refusing to drop every role" >&2; exit 1; }

# Every password must be present, and alphanumeric: it is interpolated into a quoted SQL literal.
for role in $desired_roles; do
    [ -r "${PASSWORD_DIR}/${role}" ] || {
        echo "no password for '${role}': add it as key '${role}' to Secret.postgres-users.yaml (overlay) and reseal" >&2
        exit 1
    }
    case "$(cat "${PASSWORD_DIR}/${role}")" in
        '' | *[!A-Za-z0-9]*) echo "password for '${role}' is empty or not alphanumeric" >&2; exit 1 ;;
    esac
done

echo "desired databases: ${desired_dbs}"
echo "desired roles:     ${desired_roles}"

# ------------------------------------------------------------------------------ create/update ---
#
# Roles first: a database is created with an owner, so the role has to exist by then.

for role in $desired_roles; do
    password=$(cat "${PASSWORD_DIR}/${role}")
    exists=$(sql_value postgres -c "SELECT 1 FROM pg_roles WHERE rolname = '${role}'")
    if [ -z "$exists" ]; then
        sql postgres -c "CREATE ROLE \"${role}\" LOGIN PASSWORD '${password}';"
    else
        # What makes the password self-healing when the Secret and the server have drifted apart
        sql postgres -c "ALTER ROLE \"${role}\" LOGIN PASSWORD '${password}';"
    fi
    echo "ensured role ${role}"
done

printf '%s' "$db_specs" | while IFS=: read -r db locale; do
    [ -n "${db:-}" ] || continue
    exists=$(sql_value postgres -c "SELECT 1 FROM pg_database WHERE datname = '${db}'")
    if [ -n "$exists" ]; then
        echo "ensured database ${db}"
        continue
    fi
    # template0: template1 could carry other settings, and CREATE DATABASE refuses to change the
    # locale when copying it. 'default' inherits the cluster's builtin C.UTF-8 (Deployment.yaml).
    # 'C' is libc's C, for applications that check for it: Synapse refuses anything else.
    case "$locale" in
        C) sql postgres -c "CREATE DATABASE \"${db}\" ENCODING 'UTF8' LOCALE_PROVIDER libc LOCALE 'C' TEMPLATE template0;" ;;
        *) sql postgres -c "CREATE DATABASE \"${db}\" ENCODING 'UTF8' TEMPLATE template0;" ;;
    esac
    echo "created database ${db} (locale ${locale})"
done

# Revoke everything the CSV did not ask for, then grant only what it does: users.csv is
# authoritative over grants, not additive. PUBLIC included: by default every role may CONNECT to
# every new database (and list its tables), so one application could open another's database.
for db in $desired_dbs; do
    sql postgres -c "REVOKE ALL PRIVILEGES ON DATABASE \"${db}\" FROM PUBLIC;"
    for role in $desired_roles; do
        sql postgres -c "REVOKE ALL PRIVILEGES ON DATABASE \"${db}\" FROM \"${role}\";"
    done
done

printf '%s' "$grants" | while IFS=: read -r role db privs; do
    [ -n "${role:-}" ] || continue
    old_ifs=$IFS; IFS='|'
    for p in $privs; do
        IFS=$old_ifs
        if [ "$p" = ALL ]; then
            # Ownership, not just GRANT ALL: an application running its own migrations must be able
            # to CREATE in the public schema, which PUBLIC no longer may since PostgreSQL 15. As
            # on db02, where each database was owned by its role.
            sql postgres -c "ALTER DATABASE \"${db}\" OWNER TO \"${role}\";"
            sql postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"${db}\" TO \"${role}\";"
            sql "${db}" -c "ALTER SCHEMA public OWNER TO \"${role}\";"
        else
            sql postgres -c "GRANT ${p} ON DATABASE \"${db}\" TO \"${role}\";"
        fi
        echo "granted ${p} on ${db} to ${role}"
        IFS='|'
    done
    IFS=$old_ifs
done

# ------------------------------------------------------------------------------------- drops ---
#
# Last, once everything above has succeeded.

for db in $(sql_value postgres -c "SELECT datname FROM pg_database WHERE datistemplate = false"); do
    contains_word "$db" "$PROTECTED_DATABASES" && continue
    contains_word "$db" "$desired_dbs" && continue
    echo "DROPPING database ${db}: not in databases.csv"
    sql postgres -c "DROP DATABASE \"${db}\" WITH (FORCE);"  # FORCE: disconnects remaining sessions
done

for role in $(sql_value postgres -c "SELECT rolname FROM pg_roles WHERE rolname NOT LIKE 'pg\_%'"); do
    contains_word "$role" "$PROTECTED_ROLES" && continue
    contains_word "$role" "$desired_roles" && continue
    echo "DROPPING role ${role}: not in users.csv"
    # A role cannot be dropped while it owns anything or holds a grant, and both are per database,
    # so every remaining database is visited: REASSIGN moves what it owns to the superuser, DROP
    # OWNED clears the privileges REASSIGN leaves.
    for db in postgres $desired_dbs; do
        sql "${db}" -c "REASSIGN OWNED BY \"${role}\" TO postgres;" || true
        sql "${db}" -c "DROP OWNED BY \"${role}\";" || true
    done
    sql postgres -c "DROP ROLE IF EXISTS \"${role}\";"
done

echo "reconciled"
