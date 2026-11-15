# Migration: DeepSeek Harness statt Claude Code

Stand: November 2026 · Branch `deepseek`

## Ziel

Die Factory startet in jedem Job-Container keinen Claude Code mehr, sondern den **DeepSeek Harness (DSH)** im Headless-Modus. Playbook, Workflow, Skills, Statuslogik, Board, Vorschau und PR-Flow bleiben inhaltlich unverändert. Zugangsdaten: nur noch ein DeepSeek-API-Key, kein Claude-Abo, kein Anthropic-Key.

Erfolg heißt:

- Ein Lauf startet mit **nur** `DEEPSEEK_API_KEY` in `/etc/software-factory/secrets.env`.
- Prüfung → Bau → Abnahme → PR läuft durch; `factory-report`, `factory-verify`, `factory-screenshot`, Board und Vorschau funktionieren.
- `node --test runner/main.test.ts` ist grün, das Job-Image baut, ein DSH-Smoke-Test liefert ein `final`-Event mit Exit 0.
- Ein Test-Issue mit Label `factory` endet im Status **Review** mit PR und grünen Checks.

## So bildet DSH die Factory-Anforderungen ab

| Factory braucht | DSH-Mechanismus |
|---|---|
| Auftrag | `dsh --profile headless … --json - < /work/prompt.md` |
| Arbeitsordner | cwd `/work/repo`; Workspace-Root ist cwd (`sandbox-policy`) |
| Schreiben außerhalb des Repos | `--add-dir /work`, `--add-dir /factory`, `--add-dir /scenarios` (nur wenn gemountet) |
| Playbook | `$DSH_HOME/AGENTS.md` (user-global chain, wird in den ersten Request injiziert) |
| Workflow-Skills | `$DSH_HOME/skills/<name>/SKILL.md` (Top-Level-Ordner, Frontmatter `name`+`description` passt) |
| Modell | `--patch /work/dsh-model.yml` → `agent-default-model: {provider: deepseek-official, model: <MODEL>}` |
| Auth | `DEEPSEEK_API_KEY` (Default-`apiKeyEnv` von `deepseek-official`) |
| Rechte | `--permission-mode workspace-write --approval-policy never` (Datei-Sandbox; Netzwerk bleibt frei) |
| Ergebnis | Exit-Code + `/work/status.json` (unverändert); `agent.jsonl` nur für Fehlertexte |
| Repo-Kontext | zusätzlich lädt DSH `AGENTS.md`/`CLAUDE.md` des Ziel-Repos als Projekt-Chain |

DSH wird exakt gepinnt (`DSH_VERSION=0.2.2-rc.1`). DSH verlangt Node ≥ 24.9; das Playwright-Basis-Image `v1.65.0-noble` bringt Node 26 mit, ein Node-Umbau ist nicht nötig.

## Änderungen nach Subsystem

### Job-Image (`image/`)

**`Dockerfile`**

- Claude-Code-Install entfernen.
- `ARG DSH_VERSION=0.2.2-rc.1` und `npm install -g @deepseek-ai/dsh@${DSH_VERSION}` als root.
- Nach `USER pwuser`: `DSH_HOME=/home/pwuser/.dsh`; `dsh --profile headless --help` initialisiert das Profil (nur Manifest und Patch-Vorlage, kein Netz). Falls das im Build nicht zuverlässig läuft: `profiles/` im Entrypoint anlegen, Init beim ersten Lauf.
- Cache-Umleitung, damit Schreibzugriffe im Workspace bleiben: `npm_config_cache=/work/.npm`, `UV_CACHE_DIR=/work/.uv`, `XDG_CACHE_HOME=/work/.cache`.

**`entrypoint.sh`**

- Skills nach `$DSH_HOME/skills` kopieren.
- Playbook nach `$DSH_HOME/AGENTS.md` kopieren.
- `MODEL` validieren und `/work/dsh-model.yml` schreiben (Provider `deepseek-official`).
- Aufruf:

  ```bash
  cd /work/repo
  dsh --profile headless --patch /work/dsh-model.yml \
    --permission-mode workspace-write --approval-policy never \
    --add-dir /work --add-dir /factory \
    ${SCEN:+--add-dir /scenarios} \
    --json - < /work/prompt.md \
    > /work/agent.jsonl 2> /work/agent.err
  ```

- `gh auth setup-git`, Commit-Identität, `.factory/setup.json`-Install und Repo-Clone bleiben unverändert.

**`improve.sh`**

- Improve-Playbook nach `$DSH_HOME/AGENTS.md`, Prompt nach `/work/prompt.md`, gleicher DSH-Aufruf in `/work` mit `--add-dir /work`.

**`preview.sh`**

- Kommentar: Die Vorschau erreicht „weder GitHub noch DeepSeek“.

### Runner (`runner/`)

- Start bricht mit klarer Meldung ab, wenn `DEEPSEEK_API_KEY` fehlt; die Claude-Varianten entfallen.
- `launch()` und `maybeImprove()` geben `DEEPSEEK_API_KEY` und `MODEL` in den Container (Key über die Docker-Umgebung, nie über die Kommandozeile).
- Default-Modell in `loadConfig`: `deepseek-flash`.
- Der Runner liest `agent.jsonl`/`agent.err` statt `claude.*`. Aus der letzten Zeile wird bei `type === "final"` ein Ergebnis (`result`, `is_error`) gebildet; `turns`/`costUsd` bleiben leer, das Metrik-Format ändert sich nicht.
- `redact()` entfernt zusätzlich `DEEPSEEK_API_KEY=…` und generische `sk-…`-Keys.
- `buildPrompt()` verweist auf das Playbook als `AGENTS.md`.
- Startlog nennt Harness, Provider und Modell (`harness: "dsh"`, `provider: "deepseek-official"`).

### Setup, Config, lokale Skills

- `setup.sh` prüft `DEEPSEEK_API_KEY` statt Claude-Token/Anthropic-Key.
- `factory.config.example.json`: `"model": "deepseek-flash"`.
- `scripts/install-local-skills.sh` installiert nach `$DSH_HOME`/`skills`.
- `scripts/new-project.sh` verweist auf DSH statt Claude Code.
- `workflows/starter-kit/workflow.md` beschreibt die lokalen Skills über DSH.
- `playbooks/factory.md`: „keine Rückfrage-Tools, kein Plan-Modus“ statt Claude-spezifischer Werkzeugnamen.

### Doku

- `README.md`: Titel, Diagramm, Voraussetzungen, Schnellstart, Sicherheit/Grenzen und der bisherige Claude-Abo-Abschnitt werden auf DSH und den DeepSeek-Key umgestellt.
- `docs/hostinger-vps-setup.md`: Server-Template ohne Claude Code, Schritt 4 = DeepSeek-Key, Einstellungen, Fehlerbehebung.
- Neu `docs/deepseek-harness.md`: Mapping, `DSH_HOME`-Layout, Rechte-Modell, Output/Exit-Codes, Upgrade und Rollback.

## Contract (Endzustand)

```bash
# /etc/software-factory/secrets.env
DEEPSEEK_API_KEY=sk-...
```

Host → Container: `DEEPSEEK_API_KEY`, `MODEL`, `REPO`, `ISSUE`, `BRANCH`, `PHASE`, `WORKFLOW`, `GH_TOKEN`.

Im Container: `DSH_HOME=/home/pwuser/.dsh`, `$DSH_HOME/AGENTS.md`, `$DSH_HOME/skills/*`, `/work/dsh-model.yml`, `/work/prompt.md`, `/work/agent.jsonl`, `/work/agent.err`.

Sandbox: cwd `/work/repo`; zusätzlich schreibbar `/work`, `/factory`, `/scenarios` (nur gemountet).

## Randfälle

- **Profil-Init** braucht ein schreibbares `$DSH_HOME`. Im Image als `pwuser` anlegen, sonst beim ersten Lauf.
- **Sandbox-Denials** bei npm-/uv-/Chromium-Caches: über die Cache-Umleitung lösen, nicht pauschal `danger-full-access` vergeben.
- **`--approval-policy never`** lehnt Eskalationen ab. Das ist gewollt, weil niemand im Container antworten kann; ein Hänger ist ein Pfad- oder Playbook-Problem.
- **Playbook als `AGENTS.md`** ist eine dauerhafte Nutzer-Instruktion, kein System-Prompt. Reicht die Autorität nicht, ist `system-prompt.personaSuffix` per Patch die dokumentierte Alternative.
- **Kosten/Turns** fehlen in `agent.jsonl`; `factory-stats` zeigt `costUsd: 0`. Das ist eine bekannte Grenze, eine Token-/Kosten-Auswertung ist ein möglicher Folgeschritt.
- **RC-Version** ist gepinnt; ein Upgrade erfolgt bewusst über `DSH_VERSION` plus Rebuild (`factory-rollout`).
- **Sessions** liegen unter `$DSH_HOME/sessions` und werden mit dem Container verworfen. Ein Resume zwischen Phasen gibt es nicht.
- **Rollback**: alten Commit auschecken, `secrets.env` auf den Claude-Token umstellen, altes Image-Tag verwenden. GitHub bleibt das Gedächtnis, es gehen keine Daten verloren.

## Validierung

1. Image bauen; im Container `node --version` (≥ 24.9), `dsh --version`, `dsh --profile headless --help` prüfen; mit Key `dsh --profile headless --json "Antworte nur mit OK"` ausführen (erwartet: `final`-Event, Exit 0).
2. `bash -n` auf allen geänderten Shell-Skripten.
3. `node --test runner/main.test.ts`.
4. `docker build -t software-factory-job:test -f image/Dockerfile .`.
5. End-to-End auf dem Server: Key in `secrets.env`, `model: "deepseek-flash"`, Restart, Test-Issue mit Label `factory`; `journalctl -f` beobachten bis **Review** und PR mit `factory-verify`-Belegen; `factory-improve` einmal auslösen.
6. `factory-stats` prüfen (Läufe und Status; die Kostenzeile bleibt als bekanntes Nullfeld).

## Annahmen

- Ziel ist der Harness-Wechsel; Playbook, Workflow, Skills, Labels, Board und Abnahme-Logik bleiben inhaltlich gleich.
- Standardmodell ist `deepseek-flash`; `deepseek-v4-pro` ist über `model` wählbar.
- Lokale Spec-Skills laufen künftig über DSH (Web/TUI), nicht mehr über Claude-Code-Slash-Befehle. Die Skill-Inhalte selbst bleiben unverändert.
- Keine Token-Kostenmetrik, kein Session-Resume, keine Multi-Turn-Nutzung zwischen Factory-Phasen.
