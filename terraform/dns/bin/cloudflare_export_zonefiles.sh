#!/bin/sh
set -eu

# ./cloudflare_export_zonefiles.sh <fqdn>
main()
{
    fqdn="$1"
    set -a; . ./.cloudflare.env; set +a

    sed 1d ../zones.csv | grep -v -E '^#' | grep ',cloudflare,' | grep -E "^$fqdn," | while IFS=, read _ registrar ns cf_zone_id; do
        # Is the NS provider Cloudflare?
        echo ',cloudflare,' | grep -q ",$ns," || continue
        [ ! -z "$(echo "$cf_zone_id" | tr -d 'X')" ] || continue

        printf -- 'Exporting zonefile for "%s" (Cloudflare Zone ID: %s)\n' "$fqdn" "$cf_zone_id"
        lib/cloudflare_export_zonefile "$cf_zone_id" > "../zonefiles/${fqdn}.zone"
    done
}

main "$@"
