#!/bin/sh
# Brings Zabbix's templates in line with Git (Job.template-sync.yaml, after every Argo CD sync):
#
# 0. Imports the official templates /official/official-templates.txt lists (paths under templates/ in Zabbix's
#    repository), from the tag of the server's version (apiinfo.version): they follow Zabbix's upgrades. Same rules as
#    ours: what the new version no longer has is deleted, history included.
# 1. Imports every /templates/*.yaml (configuration.import): created or updated, and within each template, what Git
#    no longer has (items, triggers, graphs, discovery rules, web scenarios, dashboards, value maps) is deleted.
# 2. Deletes our templates no longer in Git: only those tagged managed-by=homelab (each template here carries the tag).
#    Never deleteMissing on templates themselves: that would delete every template the import lacks, official ones too.
# 3. Host links, of every template (ours and official): /links/template-links.json ({"<template>": ["<host>", ...]}) lists
#    them all. Missing links are added; links it doesn't list are removed (unlinked and cleared), on every host but
#    discovered ones.
#
# Any API error stops it, with the error: the Job fails, and Argo CD shows the sync's hook as failed.
set -eu

API="${ZABBIX_API:-http://zabbix-web.zabbix.svc.cluster.local/api_jsonrpc.php}"
TAG='managed-by'
TAG_VALUE='homelab'
WORK="$(mktemp -d)"

# call <method> <params as JSON, or @file>: prints the result, stops on an error
call() {
    if [ "${2#@}" != "$2" ]; then
        jq -c --arg m "$1" '{jsonrpc: "2.0", method: $m, params: ., id: 1}' "${2#@}" > "$WORK/request.json"
    else
        jq -cn --arg m "$1" --argjson p "$2" '{jsonrpc: "2.0", method: $m, params: $p, id: 1}' > "$WORK/request.json"
    fi
    curl -sS --max-time 120 -H 'Content-Type: application/json-rpc' \
        -H "Authorization: Bearer $TEMPLATE_SYNC_API_TOKEN" --data "@$WORK/request.json" "$API" > "$WORK/response.json"
    if jq -e '.error' "$WORK/response.json" > /dev/null; then
        printf '%s: %s\n' "$1" "$(jq -c '.error' "$WORK/response.json")" >&2
        exit 1
    fi
    jq -c '.result' "$WORK/response.json"
}

rule='{"createMissing": true, "updateExisting": true, "deleteMissing": true}'
rules="$(jq -cn --argjson r "$rule" '{
    template_groups: {createMissing: true, updateExisting: true},
    templates: {createMissing: true, updateExisting: true},
    templateLinkage: {createMissing: true, deleteMissing: true},
    items: $r, triggers: $r, graphs: $r, discoveryRules: $r, httptests: $r, templateDashboards: $r, valueMaps: $r
}')"

# import <file>: imports a template file, prints its templates' technical names ("template:" under "templates:" in
# Zabbix's export format), one per line
import() {
    names="$(sed -n 's/^      template: *//p' "$1" | sed "s/^'\(.*\)'$/\1/; s/^\"\(.*\)\"$/\1/")"
    [ -n "$names" ] || { echo "$1: no template name found" >&2; exit 1; }
    jq -Rs --argjson rules "$rules" '{format: "yaml", rules: $rules, source: .}' "$1" > "$WORK/import.json"
    call configuration.import "@$WORK/import.json" > /dev/null
    printf '%s\n' "$names"
}

# 0. Official templates, at the server's version
version="$(call apiinfo.version '[]' | jq -r '.')"
while IFS= read -r path; do
    case "$path" in '#'* | '') continue ;; esac
    curl -sSf --max-time 120 -o "$WORK/official.yaml" "https://raw.githubusercontent.com/zabbix/zabbix/$version/templates/$path"
    names="$(import "$WORK/official.yaml")"
    printf 'imported %s (Zabbix %s): %s\n' "$path" "$version" "$(printf '%s' "$names" | tr '\n' ',')"
done < /official/official-templates.txt

# 1. Ours
: > "$WORK/managed"
for file in /templates/*.yaml; do
    [ -e "$file" ] || continue
    names="$(import "$file")"
    printf '%s\n' "$names" >> "$WORK/managed"
    printf 'imported %s: %s\n' "$(basename "$file")" "$(printf '%s' "$names" | tr '\n' ',')"
done
[ -s "$WORK/managed" ] || { echo 'no template found in /templates: nothing deleted or unlinked' >&2; exit 1; }
managed="$(jq -Rsc 'split("\n") | map(select(length > 0))' "$WORK/managed")"

# 2. Delete our templates no longer in Git
ours="$(call template.get "$(jq -cn --arg t "$TAG" --arg v "$TAG_VALUE" \
    '{output: ["templateid", "host"], evaltype: 0, tags: [{tag: $t, value: $v, operator: 1}]}')")"
gone="$(printf '%s' "$ours" | jq -c --argjson keep "$managed" '[.[] | select(.host as $h | $keep | index($h) | not)]')"
if [ "$(printf '%s' "$gone" | jq 'length')" -gt 0 ]; then
    call template.delete "$(printf '%s' "$gone" | jq -c 'map(.templateid)')" > /dev/null
    printf 'deleted: %s\n' "$(printf '%s' "$gone" | jq -r 'map(.host) | join(", ")')"
fi

# 3. Host links: the file lists every template-host link, ours and official templates alike. Each template it lists,
#    or that a host has, gets the listed hosts and only them. Discovered hosts (flags 4) are left alone: their templates
#    come from their host prototype.
hosts="$(call host.get '{"output": ["hostid", "host"], "filter": {"flags": 0}, "selectParentTemplates": ["templateid", "host"]}')"
wanted="$(jq -c '[keys[]]' /links/template-links.json)"
templates="$(call template.get "$(jq -cn --argjson n "$wanted" '{output: ["templateid", "host"], filter: {host: $n}}')")"
missing="$(jq -cn --argjson w "$wanted" --argjson f "$templates" '$w - ($f | map(.host))')"
[ "$missing" = '[]' ] || { printf 'templates not found in Zabbix: %s\n' "$missing" >&2; exit 1; }
missing="$(jq -c --argjson f "$hosts" '[.[][]] - ($f | map(.host)) | unique' /links/template-links.json)"
[ "$missing" = '[]' ] || { printf 'hosts not found in Zabbix: %s\n' "$missing" >&2; exit 1; }
jq -c --argjson hosts "$hosts" --argjson templates "$templates" '. as $links
    | ([$templates[], $hosts[].parentTemplates[]] | map({key: .host, value: .templateid}) | from_entries) as $ids
    | [($links | keys[]), $hosts[].parentTemplates[].host] | unique | .[]
    | . as $t | ($links[$t] // []) as $w
    | {name: $t, tid: $ids[$t],
       add: [$hosts[] | select((.host | IN($w[])) and (.parentTemplates | any(.host == $t) | not)) | {hostid, host}],
       remove: [$hosts[] | select((.parentTemplates | any(.host == $t)) and (.host | IN($w[]) | not)) | {hostid, host}]}
    | select(.add != [] or .remove != [])' /links/template-links.json > "$WORK/plan"
while IFS= read -r change; do
    name="$(printf '%s' "$change" | jq -r '.name')"
    tid="$(printf '%s' "$change" | jq -r '.tid')"
    add="$(printf '%s' "$change" | jq -c '.add')"
    remove="$(printf '%s' "$change" | jq -c '.remove')"
    if [ "$add" != '[]' ]; then
        # From the host side: since Zabbix 6.0, template.massadd no longer links hosts
        call host.massadd "$(jq -cn --arg t "$tid" --argjson h "$add" '{hosts: ($h | map({hostid})), templates: [{templateid: $t}]}')" > /dev/null
        printf '%s: linked to %s\n' "$name" "$(printf '%s' "$add" | jq -r 'map(.host) | join(", ")')"
    fi
    if [ "$remove" != '[]' ]; then
        call host.massremove "$(jq -cn --arg t "$tid" --argjson h "$remove" '{hostids: ($h | map(.hostid)), templateids_clear: [$t]}')" > /dev/null
        printf '%s: unlinked and cleared from %s\n' "$name" "$(printf '%s' "$remove" | jq -r 'map(.host) | join(", ")')"
    fi
done < "$WORK/plan"
echo 'templates in sync'
