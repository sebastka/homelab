#!/bin/sh
# Compare what the zones actually serve against what we expect.
# Reads the secret zone names from sops, so nothing is hardcoded here.
#
#   ./check_zones.sh [ns|mx|spf|dmarc|dkim|caa|mta-sts|dnssec]

. "$(dirname "$0")/lib/common"

NS=${NS:-1.1.1.1}

main()
{
    case "${1:-all}" in
        all) check_ns; check_mx; check_spf; check_dmarc; check_dkim; check_caa; check_mta_sts; check_dnssec ;;
        ns) check_ns ;; mx) check_mx ;; spf) check_spf ;; dmarc) check_dmarc ;;
        dkim) check_dkim ;; caa) check_caa ;; mta-sts) check_mta_sts ;; dnssec) check_dnssec ;;
        *) echo "usage: $0 [all|ns|mx|spf|dmarc|dkim|caa|mta-sts|dnssec]" >&2; exit 2 ;;
    esac
}

# row <zone> <value...>
row() { printf -- '\t%-22s%s\n' "$1" "$2"; }

check_ns()
{
    printf -- 'NS:\n'
    all_zones | while read -r z; do
        row "$z" "$(dig +short "@$NS" NS "$z" | sort | tr '\n' ' ')"
    done
}

check_mx()
{
    printf -- 'MX:\n'
    all_zones | while read -r z; do
        row "$z" "$(dig +short "@$NS" MX "$z" | tr '\n' ' ')"
    done
}

check_spf()
{
    printf -- 'SPF:\n'
    all_zones | while read -r z; do
        row "$z" "$(dig +short "@$NS" TXT "$z" | grep -F 'v=spf1' || echo '-- none --')"
    done
}

check_dmarc()
{
    printf -- 'DMARC:\n'
    all_zones | while read -r z; do
        row "$z" "$(dig +short "@$NS" TXT "_dmarc.$z" | grep -F 'v=DMARC1' | head -1 || echo '-- none --')"
    done
}

# DKIM selectors are per-zone and rotate; probe the ones Domeneshop issues.
# Match on v=DKIM1, not on merely getting an answer: a wildcard CNAME (as on
# karlsen.app) answers for every name and would otherwise look like a hit.
check_dkim()
{
    printf -- 'DKIM (ds* selectors):\n'
    all_zones | while read -r z; do
        found=''
        for sel in ds202503 ds202509; do
            dig +short "@$NS" TXT "$sel._domainkey.$z" | grep -qF 'v=DKIM1' \
                && found="$found $sel"
        done
        row "$z" "${found:- -- none --}"
    done
}

check_caa()
{
    printf -- 'CAA (as served -- Cloudflare Universal SSL rewrites this):\n'
    all_zones | while read -r z; do
        row "$z" "$(dig +short "@$NS" CAA "$z" | sort | tr '\n' ' ' | cut -c1-90)"
    done
}

# As with DKIM, match on the policy string so a wildcard CNAME cannot pose as
# a policy record.
check_mta_sts()
{
    printf -- 'MTA-STS / TLS-RPT:\n'
    all_zones | while read -r z; do
        sts="$(dig +short "@$NS" TXT "_mta-sts.$z" | grep -F 'v=STSv1' | head -1)"
        rpt="$(dig +short "@$NS" TXT "_smtp._tls.$z" | grep -F 'v=TLSRPTv1' | head -1)"
        row "$z" "sts=${sts:-none} rpt=${rpt:-none}"
    done
}

check_dnssec()
{
    printf -- 'DNSSEC (DS at parent):\n'
    all_zones | while read -r z; do
        row "$z" "$(dig +short "@$NS" DS "$z" | head -1 | cut -c1-60 || echo '-- none --')"
    done
}

main "$@"
