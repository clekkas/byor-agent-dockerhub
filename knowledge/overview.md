<!-- scope: dockerhub, anonymous, byor, registry connection -->
# byor-agent-dockerhub — what this proves

Generated 2026-10-16.

This is a Microsoft Foundry **hosted agent** deployed with its container image pulled from a
**public Docker Hub repository** (`docker.io/clekkas/byor-agent-dockerhub`), with **no Foundry
registry connection and no OIDC token exchange configured at all**.

## Why this repo exists

The companion repo `byor-agent` proves the BYOR (bring-your-own-registry) pattern against a
**private, authenticated** JFrog Artifactory registry using Entra/GitHub OIDC federation and a
Foundry registry connection (`oauth_token_exchange` mode).

A related open question was whether Foundry's hosted-agent runtime can pull a container image
**anonymously** — with no registry connection resource at all — when the registry itself allows
unauthenticated pulls. A JFrog trial account could not be configured to allow anonymous access
(the toggle was unavailable), so this repo validates the same mechanism against Docker Hub
instead, which is anonymously pullable by default for any public repository.

## Mechanism

`infra/hosted-agent/main.tf`'s `azapi_data_plane_resource` body's `container_configuration` block
contains only `image` — the `registry_connection_id` field is omitted entirely, not set to null or
an empty string. If the hosted agent still reaches `active` and its Responses endpoint answers,
that is direct proof Foundry can pull anonymously from a registry that permits it.

## Scope of this proof

This proves the pull mechanism works against Docker Hub specifically. It does not by itself prove
anything about JFrog's behavior, since Docker Hub and JFrog Artifactory may implement the Docker
Registry v2 anonymous-access path differently. See the sibling repo `byor-agent-docker` for the
same proof against a self-hosted, vendor-neutral `registry:2` instance, which is the closer match
to JFrog's deployment model (a private, independently operated Docker Registry v2 API, just
configured for anonymous reads).
