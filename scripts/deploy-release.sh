#!/usr/bin/env bash
# Deploy TURN only from a schema-v2 release manifest.
set -euo pipefail
RELEASE_MANIFEST_PATH="${RELEASE_MANIFEST_PATH:?ERROR: RELEASE_MANIFEST_PATH is required}"
REGISTRY="${REGISTRY:-ghcr.io/openware-io}"; REPOSITORY_NAMESPACE="${REPOSITORY_NAMESPACE:-}"; IMAGE_NAME="${IMAGE_NAME:-open-chat-turn}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "${RELEASE_MANIFEST_PATH}" ]] || { echo "ERROR: release manifest not found" >&2; exit 1; }
IMAGE="$(python3 - "${RELEASE_MANIFEST_PATH}" "${REGISTRY}" "${REPOSITORY_NAMESPACE}" "${IMAGE_NAME}" <<'PY'
import json,re,sys
p,registry,namespace,name=sys.argv[1:]; m=json.load(open(p,encoding='utf-8')); e=m.get('services',{}).get(name,{})
prefix=registry.rstrip('/') + (('/'+namespace.strip('/')) if namespace else ''); tag=e.get('tag',''); image=e.get('image',''); digest=e.get('digest','')
if m.get('schemaVersion') != 2 or m.get('releaseType') not in ('development','formal'): raise SystemExit('invalid schema-v2 manifest')
if not re.fullmatch(r'\d+\.\d+\.\d+(-SNAPSHOT)?',tag) or e.get('moduleVersion') != tag: raise SystemExit('invalid tag')
if m['releaseType']=='development' and not tag.endswith('-SNAPSHOT'): raise SystemExit('development tag must end in -SNAPSHOT')
if m['releaseType']=='formal' and tag.endswith('-SNAPSHOT'): raise SystemExit('formal tag cannot be SNAPSHOT')
if image != f'{prefix}/{name}:{tag}' or '@sha256:' in image or not re.fullmatch(r'sha256:[a-f0-9]{64}',digest): raise SystemExit('invalid release image')
print(image)
PY
)"
RENDERED="$(mktemp)"; trap 'rm -f "${RENDERED}"' EXIT
sed "s|__APP_IMAGE_OPEN_CHAT_TURN__|${IMAGE}|g" "${ROOT}/k8s/turn.yaml" > "${RENDERED}"
grep -q '__APP_IMAGE_' "${RENDERED}" && { echo 'ERROR: unresolved image placeholder' >&2; exit 1; }
kubectl apply -f "${RENDERED}"
kubectl -n im-business rollout status deployment/open-chat-turn --timeout=300s
ACTUAL_IMAGE="$(kubectl -n im-business get deployment open-chat-turn -o jsonpath='{.spec.template.spec.containers[0].image}')"
[[ "${ACTUAL_IMAGE}" == "${IMAGE}" ]] || { echo "ERROR: deployment image drift: ${ACTUAL_IMAGE}" >&2; exit 1; }
echo "TURN deployment is ready: ${IMAGE}"
