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
- Secret rotation procedure
- Secure workload defaults
- CI manifest and Helm validation

HashiCorp documents the Vault Helm chart as the recommended way to install the Agent Injector. The injector uses a pod ServiceAccount to authenticate to Vault through the Kubernetes auth method and renders secrets to a shared volume. citeturn138927search9turn138927search0

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

The bootstrap script configures the Kubernetes auth method, Vault policy, KV secret, and Vault role. It requires a Vault operator token and the initial application password to be supplied outside Git.

```bash
export VAULT_TOKEN='<operator-token>'
export VAULT_APP_PASSWORD='<initial-secret>'
./scripts/bootstrap-vault.sh
```

No application credential is committed to this repository.

## Deploy the application

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/vault-token-reviewer-binding.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

The application does not receive the secret through a Kubernetes Secret. Vault Agent writes it to `/vault/secrets/app.env` in the injected shared volume.

## Verify

```bash
kubectl -n vault-demo get pods
kubectl -n vault-demo exec deploy/vault-demo-app -- test -s /vault/secrets/app.env
```

Do not print secret material into CI logs or commit it to the repository.

## Rotation

```bash
export VAULT_TOKEN='<operator-token>'
export NEW_PASSWORD='<new-secret>'
./scripts/rotate-secret.sh
```

The script updates the KV value and restarts the workload so the injected file is rendered again.

## Production hardening

- Replace the local standalone profile with Raft HA storage.
- Enable TLS between Vault and clients.
- Use auto-unseal with a cloud KMS/HSM appropriate to the environment.
- Restrict Vault policies to exact secret paths.
- Protect Vault operator credentials and audit logs.
- Use short Vault token TTLs and rotation.
- Consider dynamic database secrets where appropriate.
- Consider the Secrets Store CSI Driver or another integration when file-based injection is not appropriate.

## Validation

```bash
./tests/test_manifests.sh
```

A live Vault/Kubernetes integration test requires a real Kubernetes cluster and Vault instance; this repository's CI validates syntax and security assertions without creating external infrastructure.

## License

MIT
