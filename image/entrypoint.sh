#!/usr/bin/env bash
# Startet einen Factory-Job: Repo holen, Branch auschecken, DeepSeek Harness (DSH) mit Playbook laufen lassen.
# Erwartet: REPO, ISSUE, BRANCH, MODEL, WORKFLOW, GH_TOKEN, DEEPSEEK_API_KEY
# und /work/prompt.md (vom Runner geschrieben).
set -euo pipefail

log() { echo "[factory] $*"; }

: "${REPO:?}" "${ISSUE:?}" "${BRANCH:?}"
MODEL="${MODEL:-deepseek-flash}"
export PHASE="${PHASE:-build}"   # check = prüfen, build = entwickeln, accept = unabhängige Abnahme
WORKFLOW="${WORKFLOW:-starter-kit}"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
export DSH_HOME

# Workflow-Skills als DSH-Skills bereitstellen (landen nicht im Ziel-Repo)
mkdir -p "$DSH_HOME/skills"
if [ -d "/factory/workflows/$WORKFLOW/skills" ]; then
  cp -r "/factory/workflows/$WORKFLOW/skills/." "$DSH_HOME/skills/"
fi
# Playbook als dauerhafte Workspace-Instruktion (DSH lädt es in den ersten Request)
cp /factory/playbook.md "$DSH_HOME/AGENTS.md"

# Modell für diesen Lauf: kleine Patch-Datei überschreibt den Profil-Default.
case "$MODEL" in
  ""|*[!a-zA-Z0-9._-]*) echo "Ungültiges Modell: '$MODEL'" >&2; exit 2 ;;
esac
printf -- '- id: agent-default-model\n  config:\n    provider: deepseek-official\n    model: %s\n' "$MODEL" > /work/dsh-model.yml

# Caches im Workspace halten: die DSH-Datei-Sandbox erlaubt Schreibzugriffe nur dort.
export npm_config_cache="${npm_config_cache:-/work/.npm}"
export UV_CACHE_DIR="${UV_CACHE_DIR:-/work/.uv}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/work/.cache}"
mkdir -p "$npm_config_cache" "$UV_CACHE_DIR" "$XDG_CACHE_HOME"

gh auth setup-git >/dev/null
GH_LOGIN=$(gh api user --jq .login)
GH_ID=$(gh api user --jq .id)
git config --global user.name "$GH_LOGIN (Software Factory)"
git config --global user.email "${GH_ID}+${GH_LOGIN}@users.noreply.github.com"
git config --global init.defaultBranch main

cd /work
if [ ! -d repo/.git ]; then
  log "Klone $REPO"
  gh repo clone "$REPO" repo -- --quiet
fi
cd repo
git fetch --quiet origin
DEFAULT_BRANCH=$(gh repo view "$REPO" --json defaultBranchRef --jq .defaultBranchRef.name)
if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  git checkout --quiet -B "$BRANCH" "origin/$BRANCH"
  # Die Abnahme startet immer mit genau dem gepushten Stand, ohne Reste früherer Läufe
  if [ "$PHASE" = "accept" ]; then git reset --quiet --hard "origin/$BRANCH" && git clean -ffdxq; fi
else
  git checkout --quiet -B "$BRANCH" "origin/$DEFAULT_BRANCH"
fi

# Abhängigkeiten installieren (zum Entwickeln und für die Abnahme nötig)
if [ "$PHASE" != "check" ] && [ -f .factory/setup.json ]; then
  INSTALL=$(jq -r '.install // empty' .factory/setup.json)
  if [ -n "$INSTALL" ]; then
    log "Setup: $INSTALL"
    bash -lc "$INSTALL" > /work/setup.log 2>&1 || log "Setup fehlgeschlagen (siehe /work/setup.log), der Agent kümmert sich"
  fi
fi

export FACTORY_DEFAULT_BRANCH="$DEFAULT_BRANCH"

ARGS=(--profile headless --patch /work/dsh-model.yml
  --permission-mode workspace-write --approval-policy never
  --add-dir /work --add-dir /factory)
if [ -d /scenarios ]; then ARGS+=(--add-dir /scenarios); fi

log "Starte DeepSeek Harness ($MODEL, Phase: $PHASE, Workflow: $WORKFLOW) für $REPO#$ISSUE auf $BRANCH"
set +e
dsh "${ARGS[@]}" --json - < /work/prompt.md > /work/agent.jsonl 2> /work/agent.err
CODE=$?
set -e
log "DeepSeek Harness beendet mit Exit-Code $CODE"
tail -n 1 /work/agent.jsonl | jq -r 'select(.type == "final") | "Ergebnis: " + ((.text // "-") | tostring | .[0:500])' 2>/dev/null || true
exit $CODE
