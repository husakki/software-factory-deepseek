#!/usr/bin/env bash
# Verbesserungs-Lauf: wertet die bisherigen Läufe aus und schlägt Änderungen am Playbook vor.
# Erwartet: REPO (Factory-Repo), GH_TOKEN, DEEPSEEK_API_KEY, MODEL
# Daten unter /data (nur lesend), Arbeitsordner /work.
set -euo pipefail
: "${REPO:?}"
MODEL="${MODEL:-deepseek-flash}"
export PHASE=improve
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
export DSH_HOME

# Modell für diesen Lauf: kleine Patch-Datei überschreibt den Profil-Default.
case "$MODEL" in
  ""|*[!a-zA-Z0-9._-]*) echo "Ungültiges Modell: '$MODEL'" >&2; exit 2 ;;
esac
printf -- '- id: agent-default-model\n  config:\n    provider: deepseek-official\n    model: %s\n' "$MODEL" > /work/dsh-model.yml

# Caches im Workspace halten: die DSH-Datei-Sandbox erlaubt Schreibzugriffe nur dort.
export npm_config_cache="${npm_config_cache:-/work/.npm}"
export UV_CACHE_DIR="${UV_CACHE_DIR:-/work/.uv}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/work/.cache}"
mkdir -p "$npm_config_cache" "$UV_CACHE_DIR" "$XDG_CACHE_HOME" "$DSH_HOME"

gh auth setup-git >/dev/null
GH_LOGIN=$(gh api user --jq .login); GH_ID=$(gh api user --jq .id)
git config --global user.name "$GH_LOGIN (Software Factory)"
git config --global user.email "${GH_ID}+${GH_LOGIN}@users.noreply.github.com"

rm -rf /work/repo
gh repo clone "$REPO" /work/repo -- --quiet
cd /work/repo
DEFAULT_BRANCH=$(gh repo view "$REPO" --json defaultBranchRef --jq .defaultBranchRef.name)
BRANCH="improve/$(date +%Y-%m-%d-%H%M)"
git checkout --quiet -b "$BRANCH"
export FACTORY_DEFAULT_BRANCH="$DEFAULT_BRANCH" FACTORY_METRICS=/data/metrics.jsonl

# Improve-Playbook als dauerhafte Workspace-Instruktion (Repo-Version hat Vorrang)
PLAYBOOK=/work/repo/playbooks/improve.md
[ -f "$PLAYBOOK" ] || PLAYBOOK=/factory/improve.md
cp "$PLAYBOOK" "$DSH_HOME/AGENTS.md"

RUNS=$(ls /data/runs 2>/dev/null | wc -l)
LINES=$(wc -l < /data/metrics.jsonl 2>/dev/null || echo 0)
echo "[improve] $LINES Läufe in den Metriken, $RUNS Zusammenfassungen, Branch $BRANCH"

cat > /work/prompt.md <<EOF
Werte die bisherigen Läufe der Software Factory aus und schlage Verbesserungen vor, wie im Verbesserungs-Playbook beschrieben. Factory-Repo: $REPO (geklont unter /work/repo, Branch $BRANCH, Standard-Branch $DEFAULT_BRANCH). Daten: /data/metrics.jsonl ($LINES Läufe) und /data/runs ($RUNS Zusammenfassungen).
EOF

set +e
dsh --profile headless --patch /work/dsh-model.yml \
  --permission-mode workspace-write --approval-policy never \
  --add-dir /work --json - < /work/prompt.md \
  > /work/agent.jsonl 2> /work/agent.err
CODE=$?
set -e
tail -n 1 /work/agent.jsonl | jq -r 'select(.type == "final") | "Ergebnis: " + ((.text // "-") | tostring | .[0:800])' 2>/dev/null || true
exit $CODE
