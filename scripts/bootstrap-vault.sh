#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${VAULT_NAMESPACE:-vault}
POD=${VAULT_POD:-vault-0}
AUTH_MOUNT=${VAULT_AUTH_MOUNT:-kubernetes}
POLICY=${VAULT_POLICY_NAME:-vault-demo-app}
ROLE=${VAULT_ROLE_NAME:-vault-demo-app}

: "${VAULT_TOKEN:?Set VAULT_TOKEN to a Vault operator token}"

kubectl -n "$NAMESPACE" cp vault/policy.hcl "$POD":/tmp/policy.hcl

kubectl -n "$NAMESPACE" exec "$POD" -- env VAULT_TOKEN="$VAULT_TOKEN" sh -ceu '
  export VAULT_ADDR="http://127.0.0.1:8200"
  vault status >/dev/null
  vault token lookup >/dev/null

  vault secrets list -format=json | grep -q '"secret/"' || vault secrets enable -path=secret kv-v2
  vault policy write "$POLICY" /tmp/policy.hcl
  vault auth list -format=json | grep -q '"'$AUTH_MOUNT'/"' || vault auth enable "$AUTH_MOUNT"

  TOKEN_REVIEW_JWT="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
  KUBE_HOST="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"

  vault write auth/'$AUTH_MOUNT'/config \
    token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
    kubernetes_host="$KUBE_HOST" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

  vault kv put secret/demo/app \
    username="demo-user" \
    password="change-me-in-vault"

  vault write auth/'$AUTH_MOUNT'/role/'$ROLE' \
    bound_service_account_names=vault-demo-app \
    bound_service_account_namespaces=vault-demo \
    policies="$POLICY" \
    ttl=15m \
    max_ttl=30m
'

echo "Vault bootstrap complete. Replace the lab password in Vault before real use."
