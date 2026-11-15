# Software Factory

Eine Software Factory mit dem DeepSeek Harness, die rund um die Uhr auf deinem eigenen Server läuft.

> 🖥️ **Server:** Die Factory läuft auf einem Linux-VPS. Getestet ist sie auf dem **Hostinger KVM 2** (2 CPU-Kerne, 8 GB RAM) mit der Vorlage „Ubuntu 24.04“.
> Server holen: **[hostinger.com/alexclaude](https://hostinger.com/alexclaude)**. Mit dem Code **`ALEXCLAUDE`** sparst du zusätzlich 10 %.
> Einrichtung Schritt für Schritt: **[docs/hostinger-vps-setup.md](docs/hostinger-vps-setup.md)**
>
> _Affiliate-Link: Wenn du darüber kaufst, bekomme ich eine Provision. Für dich ändert sich am Preis nichts, mit dem Code wird es günstiger._

**Du entscheidest, was gebaut wird. Die Factory baut es.**

1. Du schreibst lokal mit DSH die Spec (Skill `write-spec`), prüfst sie und pushst sie.
2. Du übergibst sie mit dem Skill `to-factory` an die Factory. Das legt ein GitHub Issue mit Label `factory` an, das auf die Spec zeigt.
3. Ein Agent auf deinem Server prüft die Spec und schreibt Testszenarien. Ein zweiter Agent entwickelt: Architektur, Umsetzung, Tests, Pull Request mit Belegen (Checks, Screenshots, getroffene Annahmen). Ein dritter, unabhängiger Agent nimmt das Ergebnis mit den Testszenarien ab, die der Entwickler nie gesehen hat. Ist etwas unklar, fragt die Factory im Issue nach und macht weiter, sobald du antwortest.
4. Du prüfst den Pull Request und mergst. **Gemergt wird immer von dir.**

Bugs gehen auch ohne Spec: Issue mit Label `factory` anlegen und beschreiben, was falsch ist und was du erwartest.

**Status auf dem Board:** Neu → In Prüfung → Rückfrage / Abgelehnt → Freigegeben → In Arbeit (Architektur · Umsetzung · Tests) → Abnahme → Review → Fertig, bei technischen Fehlern Fehlgeschlagen. Prüfung, Entwicklung und Abnahme sind getrennte Läufe in eigenen Containern: Neue Issues werden sofort geprüft, entwickelt wird, sobald ein Platz frei ist.

> 🚧 Erste Version, in aktiver Entwicklung.

## So funktioniert es

```
GitHub Issue (Label "factory")
        │
        ▼
Runner auf deinem Server ── prüft jede Minute die Issues
        │
        ▼
Eigener Docker-Container pro Issue
  └─ DeepSeek Harness + Playbook + Workflow-Skills
       Triage → Analyse → Umsetzung → Prüfung → Pull Request
        │
        ├─ unklar?  → Frage als Kommentar im Issue, wartet auf dich
        └─ fertig?  → Pull Request mit Checks + Screenshots
                          │
                          ▼
                    Du reviewst und mergst
```

- **Runner** (`runner/`): kleiner Dienst auf dem Server. Holt Issues, startet Container, setzt Labels und Board-Status. Schreibt selbst keinen Code.
- **Job-Image** (`image/`): DeepSeek Harness, GitHub CLI, git, Node und Chromium (für Tests und Screenshots). Details zum Ablauf und zu den Rechten: [docs/deepseek-harness.md](docs/deepseek-harness.md).
- **Playbook** (`playbooks/factory.md`): die festen Regeln für jeden Lauf. Stages melden, bei Unklarheit fragen statt raten, Pflicht-Checks, nie selbst mergen.
- **Workflow** (`workflows/starter-kit/`): wie entwickelt wird. Standard ist der Workflow aus dem [AI Coding Starter Kit](https://github.com/AlexPEClub/ai-coding-starter-kit): `architecture → build → qa` auf Basis deiner Spec, mit getrennten Dateien pro Feature (`spec.md`, `design.md`, `qa-report.md`). Austauschbar, siehe [workflow.md](workflows/starter-kit/workflow.md).
- **Stack-Packs** (`workflows/starter-kit/stacks/`): Regeln für einen bestimmten Stack (z. B. `nextjs`, `supabase`). Welche gelten, steht in `docs/stack.md` des Projekts. Die Factory ist stack-unabhängig.
- **Lokale Skills** (`local-skills/`): `init` (Projekt aufsetzen inkl. Stack), `write-spec` (Spec im Interview erarbeiten), `to-factory` (an die Factory übergeben). Einmal pro Rechner installieren: `./scripts/install-local-skills.sh`.
- **Projekt-Vorlage**: [factory-template](https://github.com/AlexPEClub/factory-template), stack-unabhängig. Neues Projekt: `./scripts/new-project.sh mein-projekt`.

## Voraussetzungen

- Ein Linux-Server mit Ubuntu 24.04, mindestens 2 vCPU und 8 GB RAM
- Ein DeepSeek-API-Key von [platform.deepseek.com](https://platform.deepseek.com/api_keys)
- Ein GitHub-Account

Kein Claude-Abo und kein Anthropic-Key nötig.

## Schnellstart

```bash
git clone https://github.com/husakki/software-factory-deepseek.git /opt/software-factory
cd /opt/software-factory
./setup.sh
```

Danach:
1. **DeepSeek-Key:** Key von [platform.deepseek.com](https://platform.deepseek.com/api_keys) als `DEEPSEEK_API_KEY=...` in `/etc/software-factory/secrets.env` eintragen (Datei bleibt `chmod 600`)
2. **GitHub-Login** auf dem Server: `gh auth login -s project`
3. **Factory starten:** `systemctl restart software-factory`
4. **Auf deinem Rechner:** `./scripts/install-local-skills.sh`, dann `FACTORY_SERVER=root@DEINE-IP ./scripts/new-project.sh mein-projekt`. Legt das Repo aus der Vorlage an und bindet es samt Labels und Kanban-Board an die Factory an. Ein bestehendes Repo bindest du stattdessen auf dem Server mit `./scripts/add-repo.sh dein-name/dein-repo` an.
5. Im Projekt: Briefing in `docs/briefing.md` → Skill `init` → pro Feature Skill `write-spec` → Skill `to-factory`

Die ausführliche Schritt-für-Schritt-Anleitung (inkl. Server bei Hostinger): [docs/hostinger-vps-setup.md](docs/hostinger-vps-setup.md).

## Messen und verbessern

Jeder Lauf wird mit Dauer, Schritten und Ergebnis in `/var/lib/software-factory/metrics.jsonl` festgehalten. Auswertung auf dem Server:

```bash
factory-stats            # alles
factory-stats --tage 7   # letzte Woche
```

Weil jede Aufgabe denselben Ablauf durchläuft, siehst du so, ob eine Änderung am Playbook, an den Skills oder am Modell etwas bringt: Laufzeit pro Aufgabe, Anteil Rückfragen, wie oft die Abnahme beim ersten Mal besteht.

Kosten pro Lauf stehen derzeit nicht in den Metriken, weil DSH sie nicht mitliefert; `factory-stats` zeigt in der Kostenzeile `0`.

## Das Ziel-Repo

Die Factory liest `.factory/setup.json` im Ziel-Repo:

```json
{
  "install": "npm ci",
  "dev": "npm run dev -- -p $PORT",
  "checks": {
    "lint": "npm run lint",
    "typecheck": "npx tsc --noEmit",
    "test": "npm test",
    "build": "npm run build"
  }
}
```

Der Skill `init` legt sie passend zum Stack an. Braucht dein Stack eine andere Laufzeit als Node oder Python, ergänzt `init` eine `.factory/Dockerfile`, die auf dem Factory-Image aufbaut.

## DeepSeek-API-Key: was du wissen solltest

Die Factory startet den **DeepSeek Harness (DSH)** im Headless-Modus auf deinem eigenen Server. Das Modell kommt von der DeepSeek-API (`deepseek-official`, Standard `deepseek-flash`). Der Key liegt nur in `/etc/software-factory/secrets.env` und wird an den Job-Container weitergereicht; das Repo speichert oder teilt keine fremden Keys.

- Abgerechnet wird nach Verbrauch (Pay-as-you-go). Starte mit `maxParallel: 1–2`.
- Das Modell ist über `model` wählbar: `deepseek-flash` (Standard) oder `deepseek-v4-pro`.
- DSH läuft mit der Datei-Sandbox `workspace-write`: Der Agent schreibt nur im Job-Ordner und im Repo. Netzwerk bleibt frei (GitHub, Paketinstallationen).
- Stand: November 2026. DeepSeek kann Preise und Limits ändern, prüf die [Doku](https://api-docs.deepseek.com).

## Sicherheit und Grenzen (Version 0.1)

- Jeder Lauf hat einen eigenen Container mit Speicher- und Prozesslimit. Standard: zwei Agent-Läufe gleichzeitig (`maxParallel: 2`), passend zu 8 GB RAM. Im Container läuft DSH mit dem Modell von der DeepSeek-API.
- Der Agent arbeitet im DSH-Headless-Modus mit der Datei-Sandbox `workspace-write`: Schreibzugriffe nur im Job-Ordner und im Repo, keine Rückfragen (unbeaufsichtigt).
- Antworten und Änderungswünsche nimmt die Factory nur von dir an (plus `allowedUsers`). Fremde Kommentare sieht der Agent nicht.
- Ein Bau zählt nur, wenn `factory-verify` auf genau dem gepushten Commit grün ist und die Spec unverändert bleibt. Besteht die Abnahme nach zwei Runden nicht, landet der PR mit „Abnahme nicht bestanden“ bei dir, nie als bestanden.
- Vorschauen laufen ohne Zugangsdaten, mit Passwort und mit Domain über HTTPS.
- Die Agents arbeiten mit deinem GitHub-Login. Für mehr Trennung: eigener GitHub-Account für die Factory oder ein Fine-grained Token, der nur deine Factory-Repos erreicht.
- Getestet: Ubuntu 24.04 auf Hostinger KVM 2, Next.js-Projekte. Weitere Stacks sind vorgesehen, aber noch nicht erprobt.

Tests für den Runner: `node --test runner/main.test.ts` (Node 22.6+, ohne GitHub und Docker).

## Lizenz

MIT
