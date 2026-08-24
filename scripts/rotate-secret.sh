#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${VAULT_NAMESPACE:-vault}
POD=${VAULT_POD:-vault-0}
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"
: "${NEW_PASSWORD:?Set NEW_PASSWORD without echoing it}
"

kubectl -n "$NAMESPACE" exec "$POD" -- env VAULT_TOKEN="$VAULT_TOKEN" NEW_PASSWORD="$NEW_PASSWORD" sh -ceu '
  export VAULT_ADDR="http://127.0.0.1:8200"
  vault kv put secret/demo/app username="demo-user" password="$NEW_PASSWORD" >/dev/null
'

kubectl -n vault-demo rollout restart deployment/vault-demo-app
kubectl -n vault-demo rollout status deployment/vault-demo-app --timeout=120s

echo "Secret rotated and workload restarted."
