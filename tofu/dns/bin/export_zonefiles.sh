#!/bin/sh
# Dump a BIND zonefile for every domain in the Domeneshop account.
#
#   ./export_zonefiles.sh [output-dir]      # default: dns/zonefiles
#
# The domain list comes from the registrar, not from this repo, so a domain
# bought and forgotten still shows up here. Where the zone is served decides
# how it is dumped:
#
#   Cloudflare  GET /zones/<id>/dns_records/export -- a real BIND export
#   Domeneshop  rebuilt from dns:list; the API has no export endpoint, so the
#               result has no SOA and is reconstructed record by record
#
# The dumps are reference copies, never an input to OpenTofu. Five of the eight
# zones are ones we do not publish, and a zonefile is the domain name written
# out a hundred times over -- filename included -- so the output directory is
# gitignored wholesale rather than per zone, which would leak the names in
# .gitignore itself.

. "$(dirname "$0")/lib/common"

main()
{
    out="${1:-$TOFU_DIR/dns/zonefiles}"
    mkdir -p "$out"

    zone_hosts | while read -r id fqdn where; do
        case "$where" in
            cloudflare) export_cloudflare "$fqdn" "$out/$fqdn.zone" ;;
            domeneshop) export_domeneshop "$id" "$fqdn" "$out/$fqdn.zone" ;;
            *)          printf -- '  %-20s skipped -- delegated elsewhere\n' "$fqdn" ;;
        esac
    done

    printf -- '\nWrote %s zonefiles to %s\n' "$(find "$out" -name '*.zone' | wc -l)" "$out"
}

# export_cloudflare <fqdn> <path>
export_cloudflare()
{
    # A domain can sit in the registrar account with its delegation still
    # pointing at Cloudflare while the zone itself has been deleted -- that is
    # what a domain left to lapse looks like. Nothing to dump, and not an
    # error, so say so and carry on rather than aborting the run.
    zone_id="$(cf_zone_id "$1")"
    if [ -z "$zone_id" ]; then
        printf -- '  %-20s skipped -- registered, but no Cloudflare zone\n' "$1"
        return 0
    fi

    # Cloudflare writes the SOA owner without a trailing dot, so BIND reads it
    # relative and lands on <zone>.<zone> -- "SOA record not at top of zone".
    # Every other line in their export is fully qualified; fix just this one.
    cf_api "zones/$zone_id/dns_records/export" \
        | sed -E '/[[:space:]]IN[[:space:]]+SOA[[:space:]]/ s/^([^[:space:]]+[^.[:space:]])([[:space:]])/\1.\2/' \
        > "$2"

    printf -- '  %-20s cloudflare  %s records\n' "$1" "$(grep -cvE '^\s*(;|$)' "$2")"
}

# export_domeneshop <domain_id> <fqdn> <path>
export_domeneshop()
{
    # The heredoc below is python3's stdin, so the records cannot be piped in;
    # hand them over as a file instead.
    records="$(mktemp)"
    domeneshop dns:list "$1" --json > "$records"
    domeneshop domains:get "$1" --json > "$records.domain"

    python3 - "$records" "$2" > "$3" <<'PY'
import datetime, json, sys

path, fqdn = sys.argv[1], sys.argv[2]
records = json.load(open(path))
ns = json.load(open(path + '.domain')).get('nameservers') or []

print(f''';;
;; Domain:     {fqdn}.
;; Exported:   {datetime.datetime.now():%Y-%m-%d %H:%M:%S}
;; Source:     Domeneshop API, rebuilt from dns:list
;;
;; Reference copy only. The API exposes no SOA record, so add one -- and check
;; the NS set below -- before loading this anywhere.
;;''')

if ns:
    print('\n;; NS Records')
    for n in ns:
        print(f'{fqdn}.\t3600\tIN\tNS\t{n.rstrip(".")}.')


def owner(host):
    return f'{fqdn}.' if host == '@' else f'{host}.{fqdn}.'


def rdata(r):
    t, d = r['type'], r['data']
    if t == 'MX':
        return f"{r['priority']} {d}"
    if t == 'SRV':
        return f"{r['priority']} {r['weight']} {r['port']} {d}"
    if t == 'TLSA':
        return f"{r['usage']} {r['selector']} {r['dtype']} {d}"
    return d


for t in sorted({r['type'] for r in records}):
    print(f'\n;; {t} Records')
    for r in sorted((r for r in records if r['type'] == t), key=lambda x: x['host']):
        print(f"{owner(r['host'])}\t{r['ttl']}\tIN\t{t}\t{rdata(r)}")
PY
    rm -f "$records" "$records.domain"
    printf -- '  %-20s domeneshop  %s records\n' "$2" "$(grep -cvE '^\s*(;|$)' "$3")"
}

main "$@"
