#!/usr/bin/env bash
# Build the agent image and push it to Docker Hub (public repository).
#
#   export DOCKERHUB_NAMESPACE="clekkas"
#   export IMAGE_TAG="0.1"
#   ./build-and-push.sh
#
# Requires: docker login (interactive) or DOCKERHUB_TOKEN set for non-interactive login.
set -euo pipefail

DOCKERHUB_NAMESPACE="${DOCKERHUB_NAMESPACE:-clekkas}"
IMAGE_TAG="${IMAGE_TAG:-0.1}"
IMAGE="docker.io/${DOCKERHUB_NAMESPACE}/byor-agent-dockerhub:${IMAGE_TAG}"

echo "==> Building ${IMAGE} (linux/amd64)"
docker build --platform linux/amd64 -t "${IMAGE}" .

echo "==> Smoke testing locally on :8088"
CID=$(docker run -d --rm -p 8088:8088 "${IMAGE}")
trap 'docker stop "${CID}" >/dev/null 2>&1 || true' EXIT
sleep 4
curl -fsS http://localhost:8088/healthz; echo
curl -fsS -X POST http://localhost:8088/responses \
  -H 'Content-Type: application/json' \
  -d '{"input":"Respond with a short deployment confirmation."}' | head -c 600; echo
docker stop "${CID}" >/dev/null
trap - EXIT

echo "==> Pushing to Docker Hub (docker login first if this fails; this repo must be PUBLIC)"
docker push "${IMAGE}"

echo
IMAGE_DIGEST="$(docker image inspect --format '{{index .RepoDigests 0}}' "${IMAGE}")"
echo "Image pushed: ${IMAGE}"
echo "Immutable digest: ${IMAGE_DIGEST}"
echo "Use this value as 'image_digest' input to the 'Deploy hosted agent' workflow."
