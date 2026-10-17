# byor-agent-dockerhub — anonymous pull proof (Docker Hub) 🐳

**Proves a Microsoft Foundry hosted agent can pull its container image from a public Docker Hub repository with zero Foundry registry connection and zero OIDC token exchange configured** — relying only on Docker Hub's default anonymous-pull behavior for public images.

[![Deploy](https://github.com/clekkas/byor-agent-dockerhub/actions/workflows/deploy-agent.yml/badge.svg)](https://github.com/clekkas/byor-agent-dockerhub/actions/workflows/deploy-agent.yml)

> One sibling repo for the other half of the proof: [`byor-agent-docker`](https://github.com/clekkas/byor-agent-docker) validates the same mechanism against a self-hosted, vendor-neutral registry — the closer analog to the production JFrog scenario this follows up on (see `byor-agent`).

## 🎯 What This Proves

- A Microsoft Foundry **hosted agent** running an image pulled straight from `docker.io/clekkas/byor-agent-dockerhub`
- **No `registry_connection_id`** anywhere in the Terraform-managed agent definition — not null, not empty, the key is absent
- **No Entra app, no federated credential, no OIDC token endpoint** configured for the pull path
- A fully automated, reproducible pipeline: GitHub Actions builds → pushes → deploys → smoke-tests, start to finish, with no manual steps and no local Docker required
- Direct evidence that Foundry's anonymous-pull mechanism is real — resolving an open question left by an inconclusive JFrog trial-account experiment

## 🚀 Quick Start

### Prerequisites

- A GitHub repository with Actions enabled (this one, forked or as-is)
- A Docker Hub account + [access token](https://hub.docker.com/settings/security) stored as the `DOCKERHUB_TOKEN` secret
- An Entra app with GitHub OIDC federation, scoped RBAC on the target Foundry project (already wired for `workshop-demo-project` — see `INFRA-NOTES.md`)
- A private self-hosted GitHub Actions runner reachable to the Terraform state storage account (label `byor-private`) — required because this subscription's state storage is private-network-only by policy

### Deploy

```bash
# Push to main (any tracked path) — GitHub Actions does the rest
git push origin main
```

```bash
# ...or trigger manually, optionally skipping the build with an existing digest
gh workflow run deploy-agent.yml -f image_digest=""
```

The workflow builds the image on a GitHub-hosted runner, pushes it to Docker Hub, then hands off to a private self-hosted runner to run `terraform apply` against the Foundry project and smoke-test the result.

> 💡 **Tip**: Watch it live with `gh run watch $(gh run list --limit 1 --json databaseId -q '.[0].databaseId')`.

## 🔑 The Key Difference (vs. OIDC/JFrog)

The entire proof point is one Terraform key, present in `byor-agent` (JFrog) and absent here:

```hcl
# infra/hosted-agent/main.tf
container_configuration = {
  image = var.image_uri
  # registry_connection_id intentionally omitted.
}
```

No connection resource, no Entra audience/issuer config, no token-exchange endpoint. If the agent still reaches `active` and answers its Responses endpoint, Foundry pulled the image with zero credentials presented to the registry.

## 🔁 Pipeline

| Stage | Runner | What happens |
|---|---|---|
| **build** | `ubuntu-latest` (GitHub-hosted) | Docker Buildx builds `linux/amd64`, logs in with `DOCKERHUB_TOKEN`, pushes to `docker.io/clekkas/byor-agent-dockerhub`, smoke-tests the pushed image locally |
| **deploy** | `[self-hosted, linux, byor-private]` | Azure OIDC login (no stored secret), `terraform init/plan/apply` against `infra/hosted-agent/`, waits for the new agent version to go `active`, calls its Responses endpoint |

```
Push to main ──▶ build (GitHub-hosted) ──▶ deploy (private runner) ──▶ ACTIVE agent ✅
                     │                           │
                     ▼                           ▼
            docker.io/clekkas/…          Microsoft.Foundry/agents@v1
```

## 📁 Repository Layout

```
byor-agent-dockerhub/
├── app.py                          # Minimal Foundry hosted-agent app (Responses protocol + health probes)
├── Dockerfile                      # linux/amd64, python:3.12-slim, non-root uid 10001
├── build-and-push.sh               # Optional manual/local build → push alternative
├── requirements.txt
├── infra/
│   └── hosted-agent/
│       ├── main.tf                 # The proof point: no registry_connection_id key
│       ├── variables.tf            # import_existing_agent nuance documented here
│       ├── outputs.tf
│       ├── versions.tf
│       └── backend.hcl.example
├── scripts/
│   └── test-hosted-agent.py        # Waits for ACTIVE, verifies image, calls /responses
├── knowledge/
│   └── overview.md                 # Full "why this repo exists" context
└── .github/
    └── workflows/
        └── deploy-agent.yml        # build → deploy, push-triggered + workflow_dispatch
```

## 🛠️ Commands Reference

| Command | Description |
|---|---|
| `git push origin main` | Triggers the full build → push → deploy pipeline automatically |
| `gh workflow run deploy-agent.yml` | Manually trigger a build-and-deploy run |
| `gh workflow run deploy-agent.yml -f image_digest=<digest>` | Skip the build, deploy an already-published digest |
| `./build-and-push.sh` | Local/manual build → smoke test → push (requires `docker login` to Docker Hub first) |
| `docker run --rm -p 8088:8088 docker.io/clekkas/byor-agent-dockerhub:<tag>` | Run the image locally to poke at it directly |

### Local check (optional)

```bash
docker run --rm -p 8088:8088 docker.io/clekkas/byor-agent-dockerhub:0.1
curl localhost:8088/healthz
curl -X POST localhost:8088/responses -H 'Content-Type: application/json' \
  -d '{"input":"Respond with a short deployment confirmation."}'
```

Expected: a JSON envelope with `status: "completed"` and a populated `output_text` field.

## 📚 Documentation

- [`knowledge/overview.md`](knowledge/overview.md) — why this repo exists, how it relates to `byor-agent` (JFrog/OIDC) and `byor-agent-docker` (self-hosted registry)
- `INFRA-NOTES.md` (in the working directory, not this repo) — Foundry project, Entra app, RBAC, and runner details shared across all three repos

## ⚠️ Important Notes

- The Docker Hub repository (`clekkas/byor-agent-dockerhub`) **must be Public** (Repository settings → Visibility) — this is what makes anonymous *pulls* possible. **Pushing** still always requires the `DOCKERHUB_TOKEN` secret; only pulling needs to be anonymous.
- This deploys to the shared, disposable `workshop-demo-project` Foundry project — **not** a production project.
- Anonymous pull is a proof-of-concept pattern. For production JFrog workloads, OIDC token exchange via a registry connection (see `byor-agent`) remains the correct, auditable approach.

## 🤝 Contributing

This is a proof-of-concept repo built for a specific workshop engagement. Issues and suggestions are welcome, but expect the scope to stay narrow and disposable by design.

## 📄 License

Internal proof-of-concept — no license file; not intended for redistribution outside this engagement.
