FROM node:22-bookworm-slim

# Pinned so a rebuild produces the same opencode. Bump it deliberately;
# see "Upgrading opencode" in README.md.
ARG OPENCODE_VERSION=1.18.30

# ca-certificates  TLS to the DeepSeek API and to the model registry.
# curl             used by the HEALTHCHECK below.
# git              opencode reads repository state for the project it opens.
# ripgrep          backs opencode's file-search tool.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      ripgrep \
 && rm -rf /var/lib/apt/lists/*

RUN npm install -g "opencode-ai@${OPENCODE_VERSION}" \
 && npm cache clean --force

ENV HOME=/home/node

# Where compose mounts opencode.json. Reading it from an explicit path rather
# than the home directory keeps the config independent of the user layout.
ENV OPENCODE_CONFIG=/etc/opencode/opencode.json

# The image pins OPENCODE_VERSION, so let the pin stand rather than letting the
# binary replace itself at runtime and drift from the built image.
ENV OPENCODE_DISABLE_AUTOUPDATE=1

# /etc/opencode            mount point for the read-only config.
# .local/share/opencode    sessions and message history; compose mounts a named
#                          volume so they survive `docker compose down`.
# /workspace               the project opencode reads and edits.
RUN mkdir -p /etc/opencode \
             /home/node/.local/share/opencode \
             /workspace \
 && chown -R node:node /home/node /workspace

# opencode runs shell commands on behalf of the model, so it must not be root.
# The node image already ships this unprivileged uid 1000 account.
USER node
WORKDIR /workspace

EXPOSE 4096

# /global/health answers {"healthy":true,...} only once the server is really
# accepting requests, which makes this a readiness check rather than a guess.
HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --retries=6 \
  CMD curl -fsS http://127.0.0.1:4096/global/health || exit 1

# `serve` exposes the same web UI as `opencode web` but does not try to open a
# local browser, which in a container only fails with an xdg-open ENOENT.
# 0.0.0.0 is the container's own interface; compose publishes it to loopback.
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
