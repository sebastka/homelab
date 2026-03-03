#!/bin/sh
set -eu

# Inspired by:
# https://blog.ari.lt/b/openpgpkey-records-are-cool/

# Usage: ./gen_openpgpkey_record.sh <localpart> <gpg_key_id>

readonly localpart="$1"
readonly gpg_key_id="$2"
readonly localpart_digest="$(printf -- '%s' "$localpart" | sha256sum | cut -d' ' -f1 | cut -c1-56)"
readonly gpg_public_key_b64="$(gpg --export --export-options export-minimal,no-export-attributes -- "$gpg_key_id" | base64 -w 0)"

printf -- '%s._openpgpkey. IN OPENPGPKEY "%s"\n' "$localpart_digest" "$gpg_public_key_b64"
