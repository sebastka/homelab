#!/bin/sh
# Report, and optionally turn off, Universal SSL on the Cloudflare zones.
#
#   ./universal_ssl.sh             # report the current state
#   ./universal_ssl.sh --disable   # turn it off everywhere
#
# Why bother: nothing in these zones is proxied, so the edge certificates
# Universal SSL provisions are never presented -- certificates come from
# cert-manager over DNS-01. Its one observable effect here is that it replaces
# the served CAA set with Cloudflare's five partner CAs, as issue *and*
# issuewild at flag 0, which silently defeats the
#
#     CAA 128 issue "letsencrypt.org"
#
# declared in zones.tf. Turning it off lets that record actually be served.
# Turn it back on before proxying anything through Cloudflare.
#
# The DNS token in secrets.auto.tfvars cannot reach this endpoint. Mint one
# with Zone > SSL and Certificates > Edit and pass it in:
#
#   CLOUDFLARE_SSL_TOKEN=... ./universal_ssl.sh --disable

. "$(dirname "$0")/lib/common"

main()
{
    action="${1:-report}"
    case "$action" in
        report|--disable) ;;
        *) echo "usage: $0 [--disable]" >&2; exit 2 ;;
    esac

    token="${CLOUDFLARE_SSL_TOKEN:-$(cf_token)}"

    cf_zones | while read -r fqdn; do
        zone_id="$(cf_zone_id "$fqdn")"
        [ -n "$zone_id" ] || { printf -- '  %-20s no Cloudflare zone\n' "$fqdn" >&2; continue; }

        if [ "$action" = '--disable' ]; then
            state="$(ssl_set "$token" "$zone_id" false)"
        else
            state="$(ssl_get "$token" "$zone_id")"
        fi

        printf -- '  %-20s universal_ssl=%s\n' "$fqdn" "$state"
    done

    [ "$action" = '--disable' ] || return 0

    printf -- '\nCloudflare stops serving its CAA set within a few minutes. Confirm with:\n'
    printf -- '  ./check_zones.sh caa\n'
}

# ssl_get <token> <zone_id>
ssl_get()
{
    curl --silent -H "Authorization: Bearer $1" \
        "https://api.cloudflare.com/client/v4/zones/$2/ssl/universal/settings" \
        | ssl_result
}

# ssl_set <token> <zone_id> <enabled>
ssl_set()
{
    curl --silent -X PATCH \
        -H "Authorization: Bearer $1" \
        -H 'Content-Type: application/json' \
        --data "{\"enabled\":$3}" \
        "https://api.cloudflare.com/client/v4/zones/$2/ssl/universal/settings" \
        | ssl_result
}

ssl_result()
{
    python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except ValueError:
    print("unreadable response"); sys.exit()
if d.get("success"):
    print(d["result"]["enabled"])
else:
    msg = (d.get("errors") or [{}])[0].get("message", "unknown error")
    print(f"ERROR: {msg}")'
}

main "$@"
