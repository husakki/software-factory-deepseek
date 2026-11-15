#!/usr/bin/env bash
# Installiert die lokalen Factory-Skills (init, write-spec, to-factory) einmalig auf deinem Rechner.
# Sie gelten dann in allen DSH-Sitzungen. Updates: im Factory-Repo "git pull", fertig (es sind Verknüpfungen).
#   ./scripts/install-local-skills.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)/local-skills"
DEST="${DSH_HOME:-$HOME/.dsh}/skills"
mkdir -p "$DEST"
for skill in "$SRC"/*/; do
  name=$(basename "$skill")
  if [ -e "$DEST/$name" ] && [ ! -L "$DEST/$name" ]; then
    mv "$DEST/$name" "$DEST/$name.backup-$(date +%Y%m%d%H%M%S)"
    echo "  vorhandenen Skill '$name' gesichert"
  fi
  ln -sfn "${skill%/}" "$DEST/$name"
  echo "  ✓ $name"
done
echo "Fertig. Die Skills stehen in jeder DSH-Sitzung zur Verfügung (im Chat aufrufen, z. B. „nutze den Skill write-spec“)."
