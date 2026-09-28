#!/usr/bin/env bash
# Build the TURN service as a schema-v2 release image.
set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io/openware-io}"
REPOSITORY_NAMESPACE="${REPOSITORY_NAMESPACE:-}"
IMAGE_NAME="${IMAGE_NAME:-open-chat-turn}"
PLATFORM="${PLATFORM:-linux/amd64}"
FORMAL_RELEASE="${FORMAL_RELEASE:-0}"
RELEASE_MANIFEST_PATH="${RELEASE_MANIFEST_PATH:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

VERSION="$(node -p "require('./package.json').version")"
[[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'ERROR: package version must be SemVer' >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo 'ERROR: release worktree must be clean' >&2; exit 1; }
REVISION="$(git rev-parse --short HEAD)"; CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPOSITORY="${REGISTRY%/}"; [[ -z "${REPOSITORY_NAMESPACE}" ]] || REPOSITORY="${REPOSITORY}/${REPOSITORY_NAMESPACE#/}"
if [[ "${FORMAL_RELEASE}" == 1 ]]; then
  TAG="${VERSION}"; RELEASE_TYPE=formal; ALLOW_TAG_OVERWRITE=false
  docker buildx imagetools inspect "${REPOSITORY}/${IMAGE_NAME}:${TAG}" >/dev/null 2>&1 && { echo "ERROR: immutable formal tag exists" >&2; exit 1; }
else
  TAG="${VERSION}-SNAPSHOT"; RELEASE_TYPE=development; ALLOW_TAG_OVERWRITE=true
fi
IMAGE="${REPOSITORY}/${IMAGE_NAME}:${TAG}"
docker build --platform "${PLATFORM}" --pull=false \
  --build-arg "IMAGE_NAME=${IMAGE_NAME}" --build-arg "IMAGE_VERSION=${TAG}" \
  --build-arg "IMAGE_REVISION=${REVISION}" --build-arg "IMAGE_CREATED=${CREATED_AT}" \
  --build-arg "IMAGE_SOURCE=https://github.com/openware-io/open-chat-turn" -t "${IMAGE}" .
if [[ -n "${REGISTRY_USERNAME:-}" && -n "${REGISTRY_PASSWORD:-}" ]]; then printf '%s' "${REGISTRY_PASSWORD}" | docker login "${REGISTRY}" -u "${REGISTRY_USERNAME}" --password-stdin; fi
docker push "${IMAGE}"
DIGEST="$(docker buildx imagetools inspect "${IMAGE}" --format '{{json .Manifest}}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["digest"])')"
[[ "${DIGEST}" =~ ^sha256:[a-f0-9]{64}$ ]] || { echo 'ERROR: invalid registry digest' >&2; exit 1; }
RELEASE_MANIFEST_PATH="${RELEASE_MANIFEST_PATH:-.outputs/releases/open-chat-turn-${TIMESTAMP}-${REVISION}.json}"
mkdir -p "$(dirname "${RELEASE_MANIFEST_PATH}")"
printf '{"schemaVersion":2,"createdAt":"%s","buildIdentity":"%s.%s.%s","releaseType":"%s","allowTagOverwrite":%s,"sourceRevision":"%s","registry":"%s","deploymentTargets":["%s"],"services":{"%s":{"moduleVersion":"%s","tag":"%s","sourceRevision":"%s","registry":"%s","image":"%s","digest":"%s"}}}\n' \
  "${CREATED_AT}" "${RELEASE_TYPE}" "${TIMESTAMP}" "${REVISION}" "${RELEASE_TYPE}" "${ALLOW_TAG_OVERWRITE}" "${REVISION}" "${REPOSITORY}" "${IMAGE_NAME}" "${IMAGE_NAME}" "${TAG}" "${TAG}" "${REVISION}" "${REPOSITORY}" "${IMAGE}" "${DIGEST}" > "${RELEASE_MANIFEST_PATH}"
echo "RELEASE_MANIFEST=${RELEASE_MANIFEST_PATH}"
