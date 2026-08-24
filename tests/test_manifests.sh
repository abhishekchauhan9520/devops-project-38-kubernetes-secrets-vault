#!/usr/bin/env bash
set -euo pipefail

python - <<'PY'
from pathlib import Path
import re

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

for p in Path('.').rglob('*'):
    if p.is_file() and '.git' not in p.parts:
        text = p.read_text(errors='ignore')
        assert 'supersecret' not in text.lower(), f'possible secret in {p}'
        assert 'password=change-me' not in text.lower(), f'possible secret in {p}'

print('Project 38 manifest/security assertions passed.')
PY
