# Project 38 — Kubernetes Secrets with HashiCorp Vault

Production-style secret delivery for Kubernetes using HashiCorp Vault, Kubernetes authentication, and Vault Agent Injector.

## Architecture

```text
Kubernetes ServiceAccount
        |
        | short-lived SA JWT
        v
Vault Kubernetes Auth
        |
        v
Vault Role -> Vault Policy -> KV v2 Secret
        |
        v
Vault Agent Injector
        |
        v
In-memory shared secret volume
        |
        v
Application Pod
```

## What this demonstrates

- Vault deployed by the official Helm chart
- Vault Agent Injector
- Kubernetes auth method
- Namespace/service-account scoped Vault role
- Least-privilege Vault policy
- KV v2 secret storage
- Secret rendering through Vault Agent templates
- No Kubernetes Secret containing the application secret
- Secret data excluded from Git
- Pod restart/rotation procedure
- CI manifest validation

HashiCorp documents the Vault Helm chart as the recommended way to install the Agent Injector. The injector uses a pod ServiceAccount to authenticate to Vault through the Kubernetes auth method and renders secrets into a shared volume. citeturn138927search9turn138927search0

## Install Vault

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --version 0.34.0 \
  -f vault/values.yaml \
  --wait
```

Run a Helm dry run before changing an existing release.

## Bootstrap

The bootstrap script configures the Kubernetes auth method, Vault policy, KV secret, and Vault role. It requires a Vault operator token to be supplied interactively or through `VAULT_TOKEN`; no token is committed.

```bash
export VAULT_ADDR=http://vault.vault.svc:8200
export VAULT_TOKEN='<operator-token>'
./scripts/bootstrap-vault.sh
```

## Deploy the application

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml
```

The application does not receive the secret through a Kubernetes Secret. Vault Agent writes it to `/vault/secrets/app.env` in the injected shared volume.

## Verify

```bash
kubectl -n vault-demo get pods
kubectl -n vault-demo exec deploy/vault-demo-app -- cat /vault/secrets/app.env
```

Do not print secret material into CI logs or commit it to the repository.

## Rotation

Update the KV value in Vault, then restart or re-render the workload according to the chosen application reload strategy. The repository demonstrates the explicit restart path because not every application watches secret files automatically.

## Production hardening

- Replace the local lab storage profile with Raft HA storage.
- Enable TLS between Vault and clients.
- Use auto-unseal with a cloud KMS/HSM appropriate to the environment.
- Restrict Vault policies to exact secret paths.
- Protect Vault operator credentials and audit logs.
- Use short Vault token TTLs and rotation.
- Consider the Secrets Store CSI Driver or other integrations when file-based injection is not appropriate.

## Validation

```bash
./tests/test_manifests.sh
```

A live Vault/Kubernetes integration test requires a real Kubernetes cluster and Vault instance; this repository's CI validates syntax and security assertions without creating external infrastructure.

## License

MIT
