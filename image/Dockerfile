# Job-Image: Jeder Factory-Job läuft in einem eigenen Container aus diesem Image.
# Enthält den DeepSeek Harness (DSH), GitHub CLI, git, Node und einen Chromium für Screenshots/E2E-Tests.
FROM mcr.microsoft.com/playwright:v1.65.0-noble

# DSH-Version bewusst pinnen: Upgrades nur zusammen mit einem Rebuild (factory-rollout).
ARG DSH_VERSION=0.2.2-rc.1

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends git jq curl ca-certificates gnupg \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update -qq && apt-get install -y -qq gh \
 && rm -rf /var/lib/apt/lists/*

# Playwright als globales Paket (Browser sind im Basis-Image schon vorhanden)
RUN npm install -g playwright@1.65.0 && npm cache clean --force
ENV NODE_PATH=/usr/lib/node_modules

# DeepSeek Harness: der Agent im Job-Container. Das Modell kommt aus der DeepSeek-API.
RUN npm install -g @deepseek-ai/dsh@${DSH_VERSION} && npm cache clean --force

# Factory-Werkzeuge, Playbook und Workflow
COPY image/bin/ /usr/local/bin/
COPY image/entrypoint.sh /factory/entrypoint.sh
COPY image/preview.sh /factory/preview.sh
COPY image/improve.sh /factory/improve.sh
COPY playbooks/factory.md /factory/playbook.md
COPY playbooks/improve.md /factory/improve.md
COPY workflows/ /factory/workflows/
RUN chmod +x /usr/local/bin/factory-* /factory/entrypoint.sh /factory/preview.sh /factory/improve.sh

USER pwuser
ENV HOME=/home/pwuser
ENV DSH_HOME=/home/pwuser/.dsh
# Headless-Profil einmalig anlegen (nur Manifest und Patch-Vorlage, kein Modellaufruf).
# Der spätere Job kopiert Playbook und Skills nach DSH_HOME.
RUN dsh --profile headless --help >/dev/null
# Python-Projekte: uv (verwaltet Python-Versionen und Pakete selbst)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH=/home/pwuser/.local/bin:$PATH

# Cache-Schreibzugriffe im Workspace halten: die DSH-Datei-Sandbox erlaubt nur /work.
ENV npm_config_cache=/work/.npm
ENV UV_CACHE_DIR=/work/.uv
ENV XDG_CACHE_HOME=/work/.cache

WORKDIR /work
ENTRYPOINT ["/factory/entrypoint.sh"]
