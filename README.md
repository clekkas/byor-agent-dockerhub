# byor-agent-dockerhub — anonymous-pull proof (Docker Hub)

Proves a Microsoft Foundry **hosted agent** can pull its container image from a **public Docker
Hub repository** with **zero Foundry registry connection and zero OIDC token exchange**
configured — only possible because Docker Hub allows anonymous pulls of public images by default.

See `knowledge/overview.md` for the full "why this repo exists" context and how it relates to the
sibling repos `byor-agent` (JFrog, authenticated, OIDC) and `byor-agent-docker` (self-hosted
registry, anonymous).

## Files

| File | Purpose |
|---|---|
| `app.py` | Same minimal Foundry hosted-agent app as `byor-agent` (Responses protocol + health probes). Registry-agnostic. |
| `Dockerfile` | `linux/amd64`, python:3.12-slim, non-root uid 10001, listens on `$PORT` (8088) |
| `build-and-push.sh` | Build → local smoke test → push to Docker Hub |
| `infra/hosted-agent/` | Terraform (AzAPI data-plane) for the logical hosted agent. `container_configuration` has **no `registry_connection_id` key at all** — the proof point. |
| `scripts/test-hosted-agent.py` | Waits for the new version to become active, verifies its image, and invokes its Responses endpoint |
| `.github/workflows/deploy-agent.yml` | `workflow_dispatch`-only: takes an image digest, deploys via Terraform, smoke-tests |

## Run it

```bash
export DOCKERHUB_NAMESPACE="clekkas"
export IMAGE_TAG="0.1"

docker login   # your Docker Hub credentials
./build-and-push.sh
```

The script prints the pushed image's immutable digest, e.g.:

```
docker.io/clekkas/byor-agent-dockerhub@sha256:<64 hex chars>
```

**Important:** make sure the repository `clekkas/byor-agent-dockerhub` is set to **Public** on
Docker Hub (Repository settings → Visibility) — this is what makes anonymous pulls possible at
all. A private repo would require Docker Hub credentials, defeating the point of this proof.

## Deploy to Foundry (the actual proof)

In GitHub: **Actions → "Deploy hosted agent (Foundry, anonymous Docker Hub pull)" → Run workflow**,
paste the digest from the previous step as `image_digest`.

The workflow:
1. Logs into Azure via OIDC (no stored secret — federated credential on the shared deploy app).
2. Runs `terraform apply` against `infra/hosted-agent/`, whose `main.tf` **omits**
   `registry_connection_id` entirely.
3. Waits for the new agent version to reach `active` and calls its Responses endpoint.

If step 3 succeeds, that is direct, reproducible proof that Foundry pulled the image with no
registry connection configured — the opposite of the JFrog case, where the same experiment
(`byor-agent`'s `test-registry-no-auth.py`) failed without one.

## Local check (optional)

```bash
docker run --rm -p 8088:8088 docker.io/clekkas/byor-agent-dockerhub:0.1
curl localhost:8088/healthz
curl -X POST localhost:8088/responses -H 'Content-Type: application/json' \
  -d '{"input":"Respond with a short deployment confirmation."}'
```

Expected: a JSON envelope with `status: "completed"` and an `output_text` field.

## Foundry project used

This deploys to the shared, disposable `workshop-demo-project` Foundry project (see
`INFRA-NOTES.md` in the `byor-variants` working directory for full resource details) — not a KP
production project.
