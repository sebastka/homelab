#!/bin/sh
set -eux

main()
{
      set -a; . ./.env; set +a

      synapse_list_registration_tokens | jq
      synapse_create_registration_tokens | jq
      synapse_list_registration_tokens | jq
}

synapse_list_registration_tokens()
{
    curl -X GET \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      "https://${MATRIX_DOMAIN}/_synapse/admin/v1/registration_tokens"
}

synapse_create_registration_tokens()
{
    curl -X POST \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
           \"token\": \"$(uuidgen)\",
           \"uses_allowed\": 1,
           \"expiry_time\": 1776902533000
        }" \
      "https://${MATRIX_DOMAIN}/_synapse/admin/v1/registration_tokens/new"
}


main
