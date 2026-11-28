#!/bin/sh
# Brings Zabbix's templates in line with Git (Job.template-sync.yaml, after every Argo CD sync):
#
# 1. Imports every /templates/*.yaml (configuration.import): created or updated, and within each template, what Git
#    no longer has (items, triggers, graphs, discovery rules, web scenarios, dashboards, value maps) is deleted.
# 2. Deletes our templates no longer in Git: only those tagged managed-by=homelab (each template here carries the tag).
#    Never deleteMissing on templates themselves: that would delete every template the import lacks, official ones too.
# 3. Links our templates to the hosts /links/template-links.json lists ({"<template>": ["<host>", ...]}), and unlinks
#    and clears them from the hosts it no longer lists.
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

# 1. Import
: > "$WORK/managed"
for file in /templates/*.yaml; do
    [ -e "$file" ] || continue
    jq -Rs --argjson rules "$rules" '{format: "yaml", rules: $rules, source: .}' "$file" > "$WORK/import.json"
    call configuration.import "@$WORK/import.json" > /dev/null
    # The template's technical name: "template:" under "templates:" in Zabbix's export format
    names="$(sed -n 's/^      template: *//p' "$file" | sed "s/^'\(.*\)'$/\1/; s/^\"\(.*\)\"$/\1/")"
    [ -n "$names" ] || { echo "$file: no template name found" >&2; exit 1; }
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

# 3. Host links, for each of our templates
printf '%s' "$managed" | jq -r '.[]' | while IFS= read -r name; do
    template="$(call template.get "$(jq -cn --arg n "$name" '{output: ["templateid"], filter: {host: [$n]}, selectHosts: ["hostid", "host"]}')" | jq -c '.[0]')"
    [ "$template" != null ] || { printf '%s: not found after import\n' "$name" >&2; exit 1; }
    tid="$(printf '%s' "$template" | jq -r '.templateid')"
    wanted="$(jq -c --arg n "$name" '.[$n] // []' /links/template-links.json)"
    hosts="$(call host.get "$(jq -cn --argjson h "$wanted" '{output: ["hostid", "host"], filter: {host: $h}}')")"
    missing="$(jq -cn --argjson w "$wanted" --argjson f "$hosts" '$w - ($f | map(.host))')"
    [ "$missing" = '[]' ] || { printf '%s: hosts not found in Zabbix: %s\n' "$name" "$missing" >&2; exit 1; }
    add="$(jq -cn --argjson f "$hosts" --argjson t "$template" '[$f[] | select(.hostid as $i | $t.hosts | map(.hostid) | index($i) | not)]')"
    remove="$(jq -cn --argjson f "$hosts" --argjson t "$template" '[$t.hosts[] | select(.hostid as $i | $f | map(.hostid) | index($i) | not)]')"
    if [ "$add" != '[]' ]; then
        call template.massadd "$(jq -cn --arg t "$tid" --argjson h "$add" '{templates: [{templateid: $t}], hosts: ($h | map({hostid}))}')" > /dev/null
        printf '%s: linked to %s\n' "$name" "$(printf '%s' "$add" | jq -r 'map(.host) | join(", ")')"
    fi
    if [ "$remove" != '[]' ]; then
        call host.massremove "$(jq -cn --arg t "$tid" --argjson h "$remove" '{hostids: ($h | map(.hostid)), templateids_clear: [$t]}')" > /dev/null
        printf '%s: unlinked and cleared from %s\n' "$name" "$(printf '%s' "$remove" | jq -r 'map(.host) | join(", ")')"
    fi
done
echo 'templates in sync'
