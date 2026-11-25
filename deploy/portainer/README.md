# deploy/portainer — Vexa Lite as a Portainer stack

Portainer stack for a small single host (works on a 4 GB box with swap). It runs
**Vexa Lite** — the whole control plane in one container — plus the Postgres and
versitygw storage sidecars, mirroring `make -C deploy/lite up`. Lite runs meeting
bots as in-container processes, so this stack needs no Docker socket and builds
nothing from source.

For a bigger host, deploy the full compose stack (`deploy/compose`, the
multi-service P4 stack) instead; this directory is the low-footprint path.

## Git topology

```
Vexa-ai/vexa  (upstream)
   └── fork: <you>/vexa  (origin)     ← Portainer deploys from here
```

The fork keeps the link to upstream. To pull upstream into the fork, press
**Sync fork** on GitHub or run:

```bash
git fetch upstream && git merge upstream/main && git push origin main
```

Portainer picks the change up on **Action → Pull and re-deploy**
(API: `POST /api/stacks/<id>/update`).

## Creating the stack in Portainer

Environments → **Stacks** → **Deploy a new stack** →
**Repository** (that's the "git-based stack" method).

| Field | Value |
|---|---|
| Repository | `https://github.com/<you>/vexa.git` |
| Reference | `main` (or a tag, e.g. `v0.12.29`) |
| Compose Path | `deploy/portainer/docker-compose.yml` |

Before the first deploy, add the stack's **Environment** variables (they are NOT
committed — a re-scan overwrites files, never the stack env):

```
DB_PASSWORD=*** rand -hex 32>
ADMIN_TOKEN=*** rand -hex 32>
MINIO_ACCESS_KEY=*** rand -hex 16>
MINIO_SECRET_KEY=*** rand -hex 32>
IMAGE_TAG=v0.12.29
VEXA_PUBLIC_API_URL=http://<host>:8056
TERMINAL_PUBLIC_URL=http://<host>:3001
```

`stack.env.example` lists every supported key. Values published in the Vexa
repository (`changeme`, `vexa-access-key`, …) are refused at boot by design.

## Front doors

| Port | What |
|---|---|
| `8056` | gateway — the REST API (`/health`, `POST /bots`) |
| `3001` | terminal — the web workbench |
| `8100` | agent-api — the agent control plane |

Bind everything to loopback or a private interface with `BIND_ADDR=127.0.0.1`
in the stack env; the gateway has no TLS.

## Transcription

Without `TRANSCRIPTION_SERVICE_URL` bots join and record but produce no text
(`POST /bots` answers 503 unless the spawn opts out). Point it at any
OpenAI-compatible STT endpoint. The bundled `whisper` service
(`COMPOSE_PROFILES=local-stt`) is a CPU smoke test only — its default model is
English-only, so Polish meetings need a `whisper-large-v3` class endpoint
(Groq, vLLM, or your own GPU container).

## Volumes

| Volume | Content |
|---|---|
| `<stack>_vexa-pgdata` | users, meetings, transcripts |
| `<stack>_vexa-storagedata` | recordings, one plain file per object — back up with `rsync -aX` (xattrs carry S3 metadata) |
| `<stack>_vexa-state` | minted secrets that must survive container replacement |
