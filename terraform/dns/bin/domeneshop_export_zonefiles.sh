#!/bin/sh
set -eu

# ./domeneshop_export_zonefiles.sh <fqdn>
main()
{
    fqdn="$1"
    set -a; . ./.domeneshop.env; set +a

    sed 1d ../zones.csv | grep -v -E '^#' | grep ',domeneshop,' | grep -E "^$fqdn," | while IFS=, read _ registrar ns cf_zone_id; do
        # Is the NS provider Domeneshop?
        echo ',domeneshop,' | grep -q ",$ns," || continue

        ds_zone_id="$(lib/domeneshop_get_domains | jq -cr ".[] | select(.domain == \"$fqdn\") | .id")"
        printf -- 'Exporting zonefile for "%s" (Domeneshop domain ID: %s)\n' "$fqdn" "$ds_zone_id"
        lib/domeneshop_export_zonefile "$ds_zone_id" > "../zonefiles/${fqdn}.zone"
    done
}

main "$@"
