# DeepSeek Harness in der Factory

Die Factory startet in jedem Job-Container den **DeepSeek Harness (DSH)** im Headless-Modus. Dieses Dokument beschreibt, wie der Container eingerichtet ist, welche Rechte der Agent hat und wie du die Version aktualisierst.

## Aufbau im Container

| Pfad / Variable | Zweck |
|---|---|
| `DSH_HOME=/home/pwuser/.dsh` | Konfigurations- und Session-Verzeichnis |
| `$DSH_HOME/AGENTS.md` | Playbook aus `playbooks/factory.md` (bzw. `improve.md` beim Verbesserungs-Lauf) |
| `$DSH_HOME/skills/<name>/SKILL.md` | Workflow-Skills aus `workflows/<workflow>/skills/` |
| `/work/dsh-model.yml` | Modell-Patch für den Lauf (`agent-default-model`) |
| `/work/prompt.md` | Auftrag, vom Runner geschrieben |
| `/work/agent.jsonl` | NDJSON-Ausgabe von DSH (`--json`) |
| `/work/agent.err` | Diagnoseausgabe von DSH |
| `/work/repo` | Ziel-Repo, Arbeitsordner des Agenten |

Der Aufruf im Entrypoint:

```bash
dsh --profile headless --patch /work/dsh-model.yml \
  --permission-mode workspace-write --approval-policy never \
  --add-dir /work --add-dir /factory [--add-dir /scenarios] \
  --json - < /work/prompt.md > /work/agent.jsonl 2> /work/agent.err
```

## Modell und Zugang

- Provider: `deepseek-official` (DeepSeek Messages API, Standard-Endpunkt `https://api.deepseek.com/anthropic`).
- Zugang: `DEEPSEEK_API_KEY` aus `/etc/software-factory/secrets.env`. Der Runner reicht den Key nur an den Job-Container weiter.
- Modell: `model` in `/etc/software-factory/config.json`, Standard `deepseek-flash`, optional `deepseek-v4-pro`. Der Entrypoint schreibt daraus den Patch für den Lauf.

## Rechte des Agenten

- `--permission-mode workspace-write`: Schreibzugriffe nur unter dem Arbeitsordner und den mit `--add-dir` freigegebenen Verzeichnissen (`/work`, `/factory`, bei Bedarf `/scenarios`).
- `--approval-policy never`: Es gibt niemanden, der Rückfragen beantworten könnte; Anfragen, die eine Freigabe bräuchten, werden abgelehnt. Der Agent muss im Workspace bleiben.
- Netzwerk ist nicht Teil der Datei-Sandbox: GitHub, Paketinstallationen und die DeepSeek-API funktionieren normal.
- Caches (`npm_config_cache`, `UV_CACHE_DIR`, `XDG_CACHE_HOME`) zeigen nach `/work`, damit Werkzeuge nicht außerhalb des Workspace schreiben müssen.

## Ergebnis und Exit-Code

- DSH endet mit `0`, wenn der Lauf abgeschlossen ist, sonst mit `1`.
- Der Runner glaubt dem Exit-Code nicht allein: Er verlangt zusätzlich ein gültiges `/work/status.json` (geschrieben von `factory-report`). Beim Bau müssen `factory-verify` grün und der gepushte Commit passen.
- Das letzte `final`-Event aus `agent.jsonl` liefert den Antworttext für Fehlerkommentare. `turns` und `costUsd` stehen in den Metriken derzeit auf `null`, weil DSH sie nicht mitliefert.

## Version aktualisieren

Die Version ist im `image/Dockerfile` gepinnt:

```dockerfile
ARG DSH_VERSION=0.2.2-rc.1
```

Ablauf:

1. `DSH_VERSION` auf die gewünschte Version ändern.
2. `docker build -t software-factory-job:latest -f image/Dockerfile .` (oder `factory-rollout` auf dem Server, wenn du die Änderung gepusht hast).
3. Smoke-Test mit einem echten DeepSeek-Key:

   ```bash
   docker run --rm -e DEEPSEEK_API_KEY --entrypoint dsh software-factory-job:latest \
     --profile headless --json "Antworte nur mit OK"
   ```

4. `systemctl restart software-factory` auf dem Server.

## Rollback

- `git revert` des Migrations-Commits bzw. alten Commit auschecken.
- In `secrets.env` wieder den alten Zugang hinterlegen (falls vorhanden) und das vorherige Job-Image bauen.
- `systemctl restart software-factory`.

GitHub bleibt das Gedächtnis der Factory; ein Rollback verliert keine Issues, PRs oder Metriken.

## Bekannte Grenzen

- DSH `0.2.2-rc.1` ist ein Release Candidate; deshalb ist die Version gepinnt.
- Keine Kosten pro Lauf in den Metriken (`costUsd` ist leer).
- Kein Session-Resume zwischen den Phasen: Jede Phase ist ein frischer, wegwerfbarer Container.
- Das Playbook wird als `AGENTS.md` (dauerhafte Nutzer-Instruktion) geladen, nicht als System-Prompt. Reicht die Autorität im Einzelfall nicht, kann `system-prompt.personaSuffix` per Patch ergänzt werden.
