#!/bin/sh
set -eu

NS=8.8.8.8
# NS=1.1.1.1

# /.check.sh
main()
{
    check_ns
    check_mx
    # check_caa
    check_spf
    check_dmarc
    # check_domainkey "mailcore"
    # check_domainkey "zendesk1"
    # check_domainkey "zendesk2"
}

check_ns()
{
    printf -- 'Check NS:\n'
    sed 1d ../zones.csv | grep -v -E '^#' | while IFS=, read fqdn registrar ns cf_zone_id; do
        printf -- '\t%-20s\t\t' "$fqdn"
        dig +short "@$NS" NS "$fqdn" | sort | tr '\n' ',' | sed 's/\.,/ /g'
        echo
    done
}

check_mx()
{
    printf -- 'Check MX:\n'
    sed 1d ../zones.csv | grep -v -E '^#' | while IFS=, read fqdn registrar ns cf_zone_id; do
        printf -- '\t%-20s\t\t' "$fqdn"
        dig +short "@$NS" MX "$fqdn"
    done
}

check_caa()
{
    printf -- 'Check CAA:\n'
    sed 1d ../zones.csv | grep -v -E '^#' | while IFS=, read fqdn registrar ns cf_zone_id; do
        printf -- '\t%-20s\t\t' "$fqdn"
        dig +short "@$NS" CAA "$fqdn" | tr '\n' ','
        echo
    done
}

check_spf()
{
    printf -- 'Check SPF:\n'
    sed 1d ../zones.csv | grep -v -E '^#' | while IFS=, read fqdn registrar ns cf_zone_id; do
        printf -- '\t%-20s\t\t' "$fqdn"
        dig +short "@$NS" TXT "$fqdn" | grep spf
    done
}

check_dmarc()
{
    printf -- 'Check DMARC:\n'
    sed 1d ../zones.csv | grep -v -E '^#' | while IFS=, read fqdn registrar ns cf_zone_id; do
        printf -- '\t%-20s\t\t' "$fqdn"
        dig +short "@$NS" TXT "_dmarc.$fqdn"
    done
}

# check_domainkey <selector>
check_domainkey()
{
    printf -- 'Check DKIM: "%s"\n' "$2"
    sed 1d ../zones.csv | grep -v -E '^#' | while IFS=, read fqdn registrar ns cf_zone_id; do
        printf -- '\t%-20s\t\t' "$fqdn"
        dig +short "@$NS" TXT "$2._domainkey.$fqdn"
    done
}

main "$@"
