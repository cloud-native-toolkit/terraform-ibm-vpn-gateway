#!/usr/bin/env bash

REGION="$1"
RESOURCE_GROUP="$2"
SUBNET_IDS="$3"

JQ=$(command -v jq | command -v ./bin/jq)

if [[ -z "${JQ}" ]]; then
  echo "jq missing. Installing"
  mkdir -p bin && curl -Lo ./bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  chmod +x ./bin/jq
  JQ=$(command -v ./bin/jq)
fi

IAM_TOKEN=$(curl -s -X POST "https://iam.cloud.ibm.com/identity/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=${IBMCLOUD_API_KEY}" | ${JQ} -r '.access_token')

API_ENDPOINT="https://${REGION}.iaas.cloud.ibm.com"
API_VERSION="2021-06-18"

VPN_GATEWAYS=$(curl -X GET "${API_ENDPOINT}/v1/vpn_gateways?version=${API_VERSION}&generation=2&resource_group.id=${RESOURCE_GROUP}" -H "Authorization: Bearer ${IAM_TOKEN}")

IFS=','
subnet_ids=$SUBNET_IDS
for id in $subnet_ids; do
  echo "${VPN_GATEWAYS}" | ${JQ} -r --arg ID "${id}" '.vpn_gateways[] | select(.subnet.id == $ID) | .id' | \
    while read vpn_gateway_id;
  do
    curl -X DELETE "${API_ENDPOINT}/v1/vpn_gateways/${vpn_gateway_id}?version=${API_VERSION}&generation=2" -H "Authorization: ${IAM_TOKEN}"

    count=0
    while [[ $count -lt 20 ]]; do
      RESULT=$(curl -X GET "${API_ENDPOINT}/v1/vpn_gateways?version=${API_VERSION}&generation=2&resource_group.id=${RESOURCE_GROUP}" -H "Authorization: Bearer ${IAM_TOKEN}" | ${JQ} -r '.vpn_gateways[] | .id' | grep "$vpn_gateway_id")

      if [[ -z "$RESULT" ]]; then
        echo "VPN Gateway has been deleted: $vpn_gateway_id"
        break
      fi

      count=$((count + 1))
      echo "Waiting for VPN Gateway to be deleted: $vpn_gateway_id"
      sleep 30
    done

    if [[ $count -eq 20 ]]; then
      echo "Timed out waiting for VPN Gateway to be deleted"
    fi
  done
done
