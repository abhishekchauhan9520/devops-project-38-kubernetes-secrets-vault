#!/usr/bin/env bash
set -euo pipefail

python - <<'PY'
from pathlib import Path

files = list(Path('k8s').glob('*.yaml'))
assert files, 'no Kubernetes manifests found'

for path in files:
    text = path.read_text()
    assert '\n---' not in text, f'unexpected multi-doc file: {path}'

svc = Path('k8s/serviceaccount.yaml').read_text()
assert 'name: vault-demo-app' in svc
assert 'automountServiceAccountToken: true' in svc

dep = Path('k8s/deployment.yaml').read_text()
for marker in [
    'vault.hashicorp.com/agent-inject: "true"',
    'vault.hashicorp.com/role: "vault-demo-app"',
    'vault.hashicorp.com/agent-inject-secret-app.env',
    'secret/data/demo/app',
    'runAsNonRoot: true',
    'readOnlyRootFilesystem: true',
    'allowPrivilegeEscalation: false',
    'type: RuntimeDefault',
]:
    assert marker in dep, f'missing security/injection marker: {marker}'

policy = Path('vault/policy.hcl').read_text()
assert 'secret/data/demo/app' in policy
assert 'capabilities = ["read"]' in policy
assert 'create' not in policy
assert 'update' not in policy

script = Path('scripts/bootstrap-vault.sh').read_text()
assert 'kubectl -n "$NAMESPACE" cp vault/policy.hcl' in script
assert 'token_reviewer_jwt' in script
assert 'bound_service_account_names=vault-demo-app' in script
assert 'bound_service_account_namespaces=vault-demo' in script

# Check source/config files for obvious hard-coded secret material.
for root in [Path('k8s'), Path('vault'), Path('scripts')]:
    for p in root.rglob('*'):
        if p.is_file():
            text = p.read_text(errors='ignore').lower()
            assert 'supersecret' not in text
            assert 'real-password' not in text
            assert 'aws_secret_access_key' not in text

print('Project 38 manifest/security assertions passed.')
PY
