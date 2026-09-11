# agendeepseek

Runs [opencode](https://opencode.ai)'s web interface in a container, with
DeepSeek as the only model provider. You open a browser, chat with a coding
agent, and it reads and edits the project directory you mounted.

The server is started with `opencode serve`, which embeds the same web UI that
`opencode web` opens, minus the attempt to launch a local browser.

## Requirements

- A DeepSeek API key from <https://platform.deepseek.com/api_keys>.
- Docker with the Compose plugin, **or** Node.js 22+ for the local path below.
  A [Codespace](#running-it-in-a-codespace) needs neither and runs in the
  browser.

## Quick start

```bash
cp .env.example .env        # then put your real key in .env
docker compose up -d --build
```

Open <http://127.0.0.1:4096>. Put the code you want the agent to work on in
`workspace/`, or point the mount somewhere else (see
[Working on another project](#working-on-another-project)).

Follow the logs, check readiness, and stop it with:

```bash
docker compose logs -f
docker compose ps            # the container reports "healthy" once it answers
docker compose down
```

Sessions live in a named volume, so `docker compose down` keeps your history.
`docker compose down -v` deletes it.

## Without Docker

`run-local.sh` starts the same server with the same `opencode.json`:

```bash
npm install -g opencode-ai@1.18.30
cp .env.example .env        # then put your real key in .env
./run-local.sh
```

It reads `.env`, but a variable already set in your shell wins, so
`PORT=4200 ./run-local.sh` works for a one-off. It refuses to start when
`DEEPSEEK_API_KEY` is missing rather than failing later on the first prompt.

## Running it in a Codespace

Needs no Docker and no local install. Everything runs in the browser.

1. Add a Codespaces secret named `DEEPSEEK_API_KEY` under **Settings >
   Codespaces > Secrets**, and grant it access to this repository. Codespaces
   also offers to prompt for it when you create the Codespace.
2. **Code > Codespaces > Create codespace.**
3. Wait for the build. The port opens in a browser tab once the server answers;
   it is also in the **Ports** panel, labelled **OpenCode Web**.

In a Codespace the agent works on the repository checked out there, not on
`workspace/`, so copying `.devcontainer/` into another repository gives you an
agent for that project.

Two things about the forwarded URL catch people out. It exists only while the
Codespace is running, and Codespaces stop after about 30 minutes idle, so a
saved link returns `404` until you start the Codespace again. The hostname also
changes with every new Codespace, so there is nothing stable to bookmark.

**Keep the port Private.** Private is the default, and a private port still
opens normally in a browser signed in to GitHub. Making it Public hands anyone
with the URL an agent that runs commands in your repository, with no password in
the way. The rest of [Security](#security) applies here too.

`devcontainer.json` is read when the container is **built**, so after changing
it run **Codespaces: Rebuild Container**. Editing it in git does not change a
Codespace that already exists.

## Security

**The server has no password.** `OPENCODE_SERVER_PASSWORD` is unset, so
opencode accepts every request and prints `server is unsecured` at startup.
Three consequences are worth understanding before you expose the port:

- Anyone who can reach it can make the agent **run shell commands** in the
  mounted workspace, as the container's unprivileged `node` user.
- `GET /config` returns your **DeepSeek API key in plaintext**, without
  authentication. Reaching the port is enough to read the key.
- There is no audit trail tying an action to a person.

This is why Compose publishes the port as `127.0.0.1:4096:4096` rather than
`4096:4096`. Only the machine running Docker can reach it. Keep it that way.

To use it from another machine, forward the port over SSH instead of binding
the server to a public interface:

```bash
ssh -N -L 4096:127.0.0.1:4096 you@your-server
```

If you later decide you do want a password, set `OPENCODE_SERVER_PASSWORD` (and
optionally `OPENCODE_SERVER_USERNAME`, which defaults to `opencode`) in the
service environment. Nothing else needs to change, though the container
healthcheck will then need the same credentials to keep reporting healthy.

## Models

`opencode.json` selects two DeepSeek models. opencode uses `model` for your
conversation and `small_model` for cheap internal work such as titling
sessions.

| Setting | Model | Notes |
| --- | --- | --- |
| `model` | `deepseek/deepseek-v4-pro` | DeepSeek V4 Pro. Reasoning effort `high` or `max`. |
| `small_model` | `deepseek/deepseek-v4-flash` | Cheaper and faster. Reasoning effort `low`, `high` or `max`. |

Two things about these identifiers are worth knowing:

- `deepseek-v4-flash` is an **alias**. The original V4-Flash is retired and
  requests are served by DeepSeek-V4.1-Flash at the Flash price. The registry
  marks it for deprecation, and the newer canonical name for the same model is
  `deepseek-flash`. Switch once `deepseek-flash` shows up in the command below;
  it is newer than the registry snapshot shipped with opencode 1.18.30.
- `deepseek-chat` and `deepseek-reasoner` no longer exist. They were retired on
  24 July 2026. Configs carrying those names fail.

List what your installation actually offers, which is the only list that
matters:

```bash
docker compose exec opencode opencode models deepseek
```

Current rates are on the [DeepSeek pricing
page](https://api-docs.deepseek.com/quick_start/pricing). DeepSeek charges less
off-peak, and reasoning tokens bill at the output rate.

## Working on another project

`workspace/` is just the default. To open your own repository, change the bind
mount in `compose.yaml`:

```yaml
    volumes:
      - /path/to/your/project:/workspace
```

Locally, set `WORKSPACE` instead:

```bash
WORKSPACE=/path/to/your/project ./run-local.sh
```

The agent can edit anything under that path, so mount the project you mean.

## Workspace permissions

The agent runs as an unprivileged user inside the container, uid 1000 by
default. A bind-mounted directory keeps the ownership it has on the host, so if
that uid cannot write to the directory you mounted, the agent can read your
project but every edit fails.

On macOS, Docker Desktop maps ownership for you and this never comes up. On
Linux it matters when your account is not uid 1000, or when the directory is
owned by root. Check with `id -u`, and if it is not 1000, set both in `.env`
and rebuild:

```bash
UID=1002
GID=1002
```

```bash
docker compose up -d --build
```

The build renumbers the container user to match, which covers the workspace and
the session store together. A quick way to confirm it worked:

```bash
docker compose exec opencode touch /workspace/.probe && echo writable
```

Do not set `UID=0`. It would run the agent as root, and the rename step fails
against the existing root account anyway.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `DEEPSEEK_API_KEY` | — | Required. Compose refuses to start without it. |
| `PORT` | `4096` | Host port for the web UI. |
| `OPENCODE_VERSION` | `1.18.30` | opencode release built into the image. |
| `UID` / `GID` | `1000` | The uid/gid the agent runs as. Must own the workspace; see above. |
| `WORKSPACE` | `./workspace` | `run-local.sh` only: the directory to open. |
| `BIND` | `127.0.0.1` | `run-local.sh` only: the interface to listen on. |

`opencode.json` reads the key through opencode's `{env:DEEPSEEK_API_KEY}`
substitution, so the key stays in `.env` and never enters the repository.
`.env` is gitignored; `.env.example` is the template.

## Upgrading opencode

Set `OPENCODE_VERSION` in `.env`, then rebuild:

```bash
docker compose up -d --build
```

The image sets `OPENCODE_DISABLE_AUTOUPDATE=1` so the binary cannot silently
replace itself and drift from the version the image was built with.

## Troubleshooting

**The page does not load.** Check the container is healthy and answering:

```bash
docker compose ps
docker compose exec opencode curl -fsS localhost:4096/global/health
```

That endpoint returns `{"healthy":true,...}` only when the server is really
accepting requests.

**Chat fails but the page loads.** The page is served by opencode itself, so a
working page rules out networking and points at the provider. Check the key and
the model name:

```bash
docker compose exec opencode opencode models deepseek
docker compose logs opencode
```

A model identifier that is not in that list is the usual cause.

**The agent reads files but every edit fails.** A permission denied on write is
the uid mismatch described in [Workspace
permissions](#workspace-permissions), not an opencode problem.

**`Provider not found: deepseek`.** opencode resolves provider metadata from
`models.opencode.ai`. If the container cannot reach it, the provider list falls
back to a bundled subset. Confirm outbound HTTPS works from the container.

## Layout

```
.devcontainer/   Codespaces: installs the pinned opencode and starts it
compose.yaml     service, port publishing, volumes
Dockerfile       pinned opencode on node:22-bookworm-slim, non-root, healthcheck
opencode.json    provider and model selection
run-local.sh     same server without Docker
workspace/       the project opencode opens
.env.example     template for .env
```

## License

MIT. See [LICENSE](LICENSE).
