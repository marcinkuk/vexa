# deploy/portainer — Vexa Lite jako stack Portainer

Stack dla małego hosta pojedynczego (działa na 4 GB z swapem). Uruchamia
**Vexa Lite** — cały control-plane w jednym kontenerie — plus sidecary Postgres
i versitygw (storage nagrań), odwzorowując `make -C deploy/lite up`. Lite
uruchamia boty spotkań jako procesy w kontenerze, więc stack nie potrzebuje
doksocka i nic nie buduje.

Dla większego hosta: pełny stack compose (`deploy/compose`); ten katalog to
ścieżka niskiego footprintu.

## Topologia Git (wzorzec taki jak oc8)

```
Vexa-ai/vexa  (upstream)
   └── fork: marcinkuk/vexa  (origin)   ← Portainer deployuje stąd
```

Ten typ integracji nazywa się **git-based stack** (w UI Portainera:
„Deploy a new stack → Repository”): Portainer klonuje repo do
`/data/compose/<id>`, a aktualizacja to „Build the image again and re-deploy”
(„Pull and re-deploy”) — API: `POST /api/stacks/<id>/update`.
Fork z linkiem do upstream: synchronizacja „Sync fork” na GitHubie albo
`git merge upstream/main` i `git push`.

## Uruchomienie

1. Na hoście (raz): `sh deploy/portainer/init-host.sh`
   — tworzy `/opt/vexa/stack.secrets.env` (0600, wygenerowane hasła) i
   `/opt/vexa/seccomp-userns.json`.
2. W Portainerze: Environments → Stacks → Deploy a new stack → Repository:
   - Repository: `https://github.com/marcinkuk/vexa.git`
   - Reference: `refs/heads/main` (albo tag, np. `v0.12.29`)
   - Compose Path: `deploy/portainer/docker-compose.yml`
3. W zakładce Environment stacka ustaw zmienne z `stack.env.example`
   (non-secret). Sekrety zostają w pliku hosta — `env_file` wskazuje je
   w trakcie deployu; re-scan gita nadpisuje pliki projektowe, dlatego
   sekrety NIGDY nie mogą leżeć w repo ani w bazie Portainera.

## Front doors

| Port | Co |
|---|---|
| `8056` | gateway — REST API (`/health`, `POST /bots`) |
| `3001` | terminal — workbench WWW |
| `8100` | agent-api — control plane agentów |

Bind na loopback/prywatny interfejs: `BIND_ADDR=127.0.0.1`; gateway nie ma TLS.

## Transkrypcja

Bez `TRANSCRIPTION_SERVICE_URL` boty dołączają i nagrywają, ale nie dają tekstu
(`POST /bots` → 503, chyba że spawn wyłączy transkrypcję). Usług `whisper`
(`COMPOSE_PROFILES=local-stt`) służy tylko do testów — domyślny model jest
angielski; na spotkania po polsku potrzebny endpoint klasy `whisper-large-v3`
(Groq, vLLM, własny kontener na GPU).

## Wolumeny

| Wolumen | Zawartość |
|---|---|
| `vexa_vexa-pgdata` | użytkownicy, spotkania, transkrypty |
| `vexa_vexa-storagedata` | nagrania — jeden plik na obiekt; backup `rsync -aX` (xattrs niosą metadane S3) |
| `vexa_vexa-state` | wygenerowane sekrety przetrwalnikowe (key sign-in, self-host key) |
