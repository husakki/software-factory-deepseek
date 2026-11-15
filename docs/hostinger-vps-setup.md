# Software Factory auf einem Hostinger VPS einrichten

Schritt für Schritt vom leeren Server bis zum ersten Pull Request, den die Factory für dich entwickelt.

> 🚧 **Erste Version, nicht production-ready.** Die Factory ist ein funktionierender Startpunkt zum Ausprobieren und Weiterentwickeln. Lass sie zuerst auf Test-Projekten laufen, bevor du ihr echte Kundenprojekte gibst.

**Dauer:** etwa 30–45 Minuten, davon viel Warten auf Installationen.

**Du brauchst:**

- einen Hostinger VPS (empfohlen: **KVM 2** mit 2 CPU-Kernen und 8 GB RAM)
- einen DeepSeek-API-Key von [platform.deepseek.com](https://platform.deepseek.com/api_keys) (kein Claude-Abo, kein Anthropic-Key nötig)
- einen GitHub-Account
- auf deinem Rechner: den DeepSeek Harness (`dsh`), `git` und die [GitHub CLI](https://cli.github.com) (`gh`)

---

## 1. Den Server bestellen

1. Geh auf **[hostinger.com/alexclaude](https://hostinger.com/alexclaude)** und wähl den **KVM 2**.
2. Wähl die Laufzeit. Ich empfehle mindestens 12 Monate; mit 24 Monaten sparst du am meisten. Bei Jahresplänen bekommst du außerdem eine Domain gratis dazu.
3. Gib im Warenkorb den Code **`ALEXCLAUDE`** ein. Damit sparst du noch einmal 10 % auf den aktuellen Preis.
4. Bei der Einrichtung im hPanel wählst du als Betriebssystem die Vorlage **Ubuntu 24.04**. Lege dabei ein sicheres **Root-Passwort** fest (oder hinterlege direkt deinen SSH-Key).

Hostinger hat eine 30-Tage-Geld-zurück-Garantie. Falls ein eigener Server doch nichts für dich ist, kannst du ihn innerhalb dieser Zeit zurückgeben.

> Du kannst auch einen anderen Ubuntu-24.04-Server nehmen. Die Anleitung ist auf Hostinger getestet; Claude Code oder andere Zusatzsoftware muss nicht vorinstalliert sein.

## 2. Mit dem Server verbinden

Die IP-Adresse deines Servers findest du im hPanel in der Übersicht deines VPS. Öffne auf deinem Rechner ein Terminal:

```bash
ssh root@DEINE-SERVER-IP
```

- Beim ersten Mal fragt das Terminal, ob du dem Server vertraust. Bestätige mit `yes`.
- Dann gibst du das Root-Passwort ein. Beim Tippen siehst du nichts, das ist normal. Hast du einen SSH-Key hinterlegt, fragt dein Rechner stattdessen nach dessen Passphrase (oder gar nicht, wenn er sie gespeichert hat).

Kein Terminal zur Hand? Im hPanel gibt es auch ein **Browser-Terminal**, damit geht alles Folgende direkt im Browser.

Alle Befehle in den Schritten 3 bis 6 führst du **auf dem Server** aus.

## 3. Die Factory installieren

```bash
git clone https://github.com/husakki/software-factory-deepseek.git /opt/software-factory
cd /opt/software-factory
./setup.sh
```

Das Skript installiert Docker, die GitHub CLI und Bun, legt die Konfiguration unter `/etc/software-factory/` an, baut das Image für die Agent-Container und richtet den Runner als Systemdienst ein. Beim ersten Mal dauert das ein paar Minuten.

> **Tipp:** Willst du später die Verbesserungs-Vorschläge der Factory nutzen (Schritt 11), forke das Repo vorher auf GitHub und klone deinen Fork statt `AlexPEClub/software-factory`. Die Factory erkennt das automatisch.

Am Ende listet es auf, was noch fehlt. Das sind die nächsten drei Schritte. Du kannst `./setup.sh` jederzeit erneut ausführen; schon Installiertes wird übersprungen.

## 4. DeepSeek-Key hinterlegen

Die Factory startet den **DeepSeek Harness (DSH)** im Headless-Modus; das Modell kommt von der DeepSeek-API. Du brauchst nur einen API-Key von [platform.deepseek.com](https://platform.deepseek.com/api_keys) — kein Claude-Abo, kein Anthropic-Konto.

Speichere den Key **auf dem Server**, ohne dass er im Shell-Verlauf landet. Füge ihn ein, drück **Enter** und dann **Strg+D**:

```bash
stty -echo; printf "DeepSeek-API-Key einfügen, dann Enter und Strg+D: "; K=$(cat | tr -d '[:space:]'); stty echo; echo; printf 'DEEPSEEK_API_KEY=%s\n' "$K" > /etc/software-factory/secrets.env && chmod 600 /etc/software-factory/secrets.env && unset K && awk -F= '{print length($2) " Zeichen"}' /etc/software-factory/secrets.env
```

Der Befehl zeigt am Ende die Länge des Keys. DeepSeek-Keys beginnen mit `sk-`; das Terminal bricht lange Keys oft auf zwei Zeilen um, deshalb liest der Befehl bis Strg+D und entfernt Zeilenumbrüche.

**Abrechnung:** nach Verbrauch (Pay-as-you-go). Starte mit `maxParallel: 1–2`; mehr parallele Läufe kosten entsprechend mehr. Modell: `deepseek-flash` (Standard), optional `deepseek-v4-pro`.

**Wenn der Key fehlt oder ungültig ist:** Der Runner startet nicht (`config:error … DEEPSEEK_API_KEY ist nicht gesetzt`) bzw. die Läufe enden mit einem Auth-Fehler im Issue. Neuen Key hinterlegen, dann `systemctl restart software-factory`.

## 5. GitHub anmelden

```bash
gh auth login -s project
```

Wähle **GitHub.com**, **HTTPS** und die Anmeldung über den Browser. Du bekommst einen Code angezeigt, den du auf deinem Rechner unter github.com/login/device eingibst.

`-s project` gibt der Factory zusätzlich das Recht, dein Kanban-Board (GitHub Projects) zu bearbeiten. Ohne diese Berechtigung kann sie die Karten nicht verschieben.

## 6. Die Factory starten

```bash
systemctl restart software-factory
journalctl -u software-factory -f
```

In den Logs solltest du `runner:started` sehen. Mit `Strg+C` beendest du die Anzeige, die Factory läuft weiter. Nur die neuesten Einträge zeigt `journalctl -u software-factory -f --since "5 min ago"`.

Noch hat die Factory kein Projekt. Bis du in Schritt 8 eins anbindest, meldet sie jede Minute einen `repo:error` für das Platzhalter-Repo `DEIN-GITHUB-NAME/dein-repo`. Das ist normal.

## 6b. Vorschau mit HTTPS (empfohlen)

Für jeden fertigen Pull Request startet die Factory eine Vorschau der App, mit Passwort geschützt. Damit das Passwort verschlüsselt übertragen wird und der Link auch auf dem Handy ohne Warnung aufgeht, braucht die Vorschau eine Domain. Bei Jahresplänen von Hostinger ist eine Domain gratis dabei; eine Subdomain einer vorhandenen Domain reicht aber auch.

1. Leg bei deinem Domain-Anbieter einen **A-Eintrag** an: z. B. `vorschau.deine-domain.de` → IP deines Servers. Bei Hostinger geht das im hPanel unter **Domains → DNS**.
2. Trag die Subdomain auf dem Server ein und starte die Factory neu:

   ```bash
   jq '.preview.domain = "vorschau.deine-domain.de"' /etc/software-factory/config.json > /tmp/c && mv /tmp/c /etc/software-factory/config.json && chmod 600 /etc/software-factory/config.json
   systemctl restart software-factory
   ```

3. Kurz testen (das kann beim ersten Mal eine Minute dauern, bis das Zertifikat da ist):

   ```bash
   curl -sI https://vorschau.deine-domain.de | head -1
   ```

Die Zertifikate holt sich der Webserver Caddy automatisch von Let's Encrypt. Dafür müssen die Ports 80 und 443 erreichbar sein (siehe Firewall in Schritt 13).

Ohne Domain funktioniert die Vorschau auch, dann aber nur über einfaches HTTP mit der IP-Adresse.

## 7. Deinen Rechner vorbereiten

Ab hier arbeitest du **auf deinem Rechner**. Die Specs schreibst du lokal mit DSH; die Factory bekommt nur das fertige Ergebnis.

Klone das Factory-Repo auch lokal und installiere die drei lokalen Skills:

```bash
git clone https://github.com/husakki/software-factory-deepseek.git
cd software-factory-deepseek
./scripts/install-local-skills.sh
```

Danach hast du in jeder DSH-Sitzung diese Skills (im Chat aufrufen, z. B. „nutze den Skill write-spec“):

- `init`: richtet ein Projekt ein (Produktbeschreibung, Stack, Design, Feature-Liste)
- `write-spec`: erarbeitet mit dir im Interview die Spezifikation für ein Feature
- `to-factory`: übergibt eine fertige Spec als GitHub Issue an die Factory

Die Skills sind Verknüpfungen auf diesen Ordner. Updates holst du dir mit `git pull` darin. **Verschieb oder lösch den Ordner danach nicht**, sonst findet DSH die Skills nicht mehr. Hast du ihn doch verschoben, führ `./scripts/install-local-skills.sh` am neuen Ort einfach noch einmal aus.

## 8. Ein Projekt anbinden

Die Factory arbeitet nur in Repos, die du ihr ausdrücklich gibst. Dabei legt sie die Status-Labels im Repo an, trägt es in ihre Konfiguration ein und erstellt beim ersten Mal das Kanban-Board „Software Factory“ in deinem GitHub-Account.

### Neues Projekt (empfohlen)

Der schnellste Weg ist die Projekt-Vorlage. Wechsle auf deinem Rechner in den Ordner, in dem das Projekt liegen soll (z. B. `~/Projects`), und sag dem Skript, wo dein Server ist. Einen Projektordner musst du nicht vorher anlegen, das Skript erstellt ihn selbst:

```bash
export FACTORY_SERVER=root@DEINE-SERVER-IP
~/software-factory/scripts/new-project.sh mein-projekt
```

(Den Pfad zum Skript passt du an den Ort an, an den du die Factory in Schritt 7 geklont hast.)

Das Skript erledigt drei Dinge auf einmal:

1. Es legt auf GitHub ein privates Repo aus der Vorlage an. Mit `--public` am Ende wird es öffentlich.
2. Es klont das Repo in den aktuellen Ordner.
3. Es bindet das Repo per SSH an deine Factory an, inklusive Labels und Board. Den Link zum Board zeigt es am Ende an.

Dann im neuen Projektordner:

1. Leg eine kurze Projektbeschreibung als `docs/briefing.md` ab: Was soll entstehen, für wen, was ist wichtig?
2. Starte DSH (`dsh web`) und führe den Skill `init` aus. Der Agent stellt dir Fragen und legt daraus Produktbeschreibung, Stack, Design-Vorgaben und die Feature-Liste an, inklusive `.factory/setup.json` mit den Befehlen für Installation, Start und Prüfungen.
3. Prüf das Ergebnis und push es.

### Bestehendes Repo

Ein Repo, das es schon gibt, bindest du **auf dem Server** an:

```bash
cd /opt/software-factory
./scripts/add-repo.sh dein-github-name/dein-repo
```

Führ danach im Projekt auf deinem Rechner ebenfalls den Skill `init` aus, damit die Factory Stack und Prüfbefehle kennt.

Für jedes weitere Projekt wiederholst du einfach einen der beiden Wege. Alle Repos landen auf demselben Board; einen Neustart der Factory brauchst du nicht.

## 9. Die erste Aufgabe übergeben

1. In DSH: Skill `write-spec`. Der Agent arbeitet die Spec im Interview mit dir aus und legt sie unter `features/PROJ-1-name/spec.md` ab.
2. Lies die Spec durch. **Die Spec ist der Vertrag:** Die Factory entwickelt genau das, was drinsteht, und ändert sie nie.
3. Commit und push.
4. Skill `to-factory`. Das legt ein GitHub Issue mit dem Label `factory` an, das auf die Spec zeigt.

Innerhalb einer Minute übernimmt die Factory. Den Fortschritt siehst du auf dem Board:

| Status | Was passiert | Was du tust |
|---|---|---|
| **Neu** | Issue wurde angelegt | – |
| **In Prüfung** | Ein Agent prüft, ob die Spec testbar und widerspruchsfrei ist, und schreibt Testszenarien | – |
| **Rückfrage** | Etwas ist unklar | Im Issue antworten |
| **Abgelehnt** | So nicht umsetzbar | Spec überarbeiten, pushen, im Issue kommentieren |
| **Freigegeben** | Wartet auf einen freien Platz | – |
| **In Arbeit** | Ein zweiter Agent entwickelt: Architektur, Umsetzung, Tests | – |
| **Abnahme** | Ein dritter, unabhängiger Agent testet die Szenarien im Browser. Der Entwickler-Agent hat sie nie gesehen. Findet er Fehler, geht es zurück in die Arbeit (höchstens zweimal). Ist es danach immer noch nicht bestanden, landet der PR mit dem deutlichen Hinweis „Abnahme nicht bestanden“ bei dir | – |
| **Review** | Pull Request mit Belegen und Vorschau ist fertig | Prüfen und mergen |
| **Fertig** | Gemergt | – |
| **Fehlgeschlagen** | Technisch hängen geblieben | Im Issue kommentieren, dann versucht die Factory es erneut |

Bei jeder Rückfrage, Ablehnung oder Fehlermeldung genügt ein Kommentar im Issue. Die Factory sieht ihn beim nächsten Durchlauf und macht weiter.

**Bugs** brauchen keine Spec: Leg ein Issue mit dem Label `factory` an und beschreib, was falsch ist und was du stattdessen erwartest.

## 10. Ergebnis prüfen und mergen

Im Pull Request findest du, was umgesetzt wurde, jedes Akzeptanzkriterium mit Ergebnis, die Annahmen der Factory, die Ergebnisse der Prüfungen, Screenshots und den Bericht der Abnahme. Ganz unten steht eine Einschätzung: „Sicher“ oder „Bitte genau prüfen“.

**Vorschau:** Für jeden Pull Request startet die Factory die App auf deinem Server. Den Link postet sie als Kommentar, z. B. `https://vorschau.deine-domain.de:4001` (mit Domain, siehe Schritt 6b) oder `http://DEINE-SERVER-IP:4001` (ohne). Login: Nutzer `factory`, das Passwort steht auf dem Server:

```bash
jq -r .preview.password /etc/software-factory/config.json
```

Standardmäßig läuft eine Vorschau gleichzeitig (`preview.max`). Nach Merge oder Schließen des Pull Requests wird sie entfernt. Die Vorschau bekommt keine Zugangsdaten: Der Code der App kann weder auf GitHub noch auf DeepSeek zugreifen.

> Ohne Domain läuft die Vorschau über einfaches HTTP. Das Passwort hält Zufallsbesucher fern, wird aber unverschlüsselt übertragen. Richte deshalb am besten HTTPS ein (Schritt 6b) und zeig über die Vorschau keine echten Kundendaten.

Gefällt dir etwas nicht, schreib es ins Issue. Die Factory arbeitet dann am selben Pull Request weiter. Passt alles, mergst du. **Gemergt wird immer von dir, nie von der Factory.**

## 11. Messen und verbessern

Jeder Lauf wird mit Dauer, Schritten und Ergebnis gespeichert. Auswertung auf dem Server:

```bash
factory-stats                          # alles
factory-stats --tage 7                 # letzte Woche
factory-stats --seit 2026-11-20        # ab einem Datum, z. B. seit einer Änderung
```

Du siehst unter anderem die Laufzeit pro Aufgabe, wie oft die Prüfung zurückfragt und wie oft die Abnahme beim ersten Mal besteht.

**Verbesserungs-Lauf:** Die Factory kann ihre eigenen Läufe auswerten und konkrete Änderungen an Playbook und Skills vorschlagen:

```bash
factory-improve
```

Ein Agent schaut sich Metriken, Rückfragen, Abnahme-Befunde und deine Änderungswünsche an. Findet er ein Muster mit mindestens zwei Belegen, öffnet er einen Pull Request in **deiner Kopie** des Factory-Repos (`factoryRepo` in der Konfiguration). Sonst legt er ein Issue mit der Auswertung an. Sinnvoll wird das ab etwa 20 Läufen.

Hast du einen Verbesserungs-PR gemergt, holst du die neue Version auf den Server:

```bash
factory-rollout
```

> Damit Verbesserungs-PRs bei dir landen, brauchst du eine eigene Kopie: Hast du auf dem Server deinen Fork geklont (Tipp in Schritt 3), trägt `add-repo.sh` ihn automatisch als `factoryRepo` ein. Sonst kannst du ihn später in `/etc/software-factory/config.json` eintragen.

## 12. Einstellungen

Die Konfiguration liegt in `/etc/software-factory/config.json`. Die wichtigsten Werte:

| Feld | Standard | Bedeutung |
|---|---|---|
| `maxParallel` | `2` | Wie viele Agent-Läufe gleichzeitig laufen (Prüfung, Entwicklung, Abnahme, Verbesserung), über alle Repos zusammen |
| `model` | `deepseek-flash` | Modell für alle Agents (`deepseek-v4-pro` für mehr Leistung) |
| `jobTimeoutMinutes` | `90` | Danach wird ein Lauf abgebrochen |
| `containerMemory` | `3g` | Arbeitsspeicher pro Agent-Container |
| `preview.max` | `1` | Gleichzeitige Vorschauen |
| `preview.domain` | leer | Subdomain für HTTPS-Vorschauen (Schritt 6b) |
| `allowedUsers` | `[]` | Weitere GitHub-Nutzer, deren Antworten und Änderungswünsche die Factory annimmt. Dein eigener Login zählt immer |
| `improve.everyDays` | `0` (aus) | Automatischer Verbesserungs-Lauf alle X Tage. Sonst nur mit `factory-improve` |

Nach Änderungen: `systemctl restart software-factory`.

Der Standard `maxParallel: 2` passt zum KVM 2: zwei Läufe mit je bis zu 3 GB plus eine Vorschau. Mehr Parallelität braucht mehr Arbeitsspeicher und kostet entsprechend mehr DeepSeek-Tokens. Mit `deepseek-v4-pro` ist `1` die sicherere Wahl.

## 13. Absichern

- **Firewall:** Erlaube nur SSH und die Vorschau-Ports:

  ```bash
  ufw allow OpenSSH
  ufw allow 80,443/tcp      # nur nötig mit HTTPS-Vorschau (Zertifikat)
  ufw allow 4001:4003/tcp
  ufw enable
  ```

  Alternativ geht das auch über die Firewall im hPanel.
- **SSH-Key statt Passwort:** Hinterlege im hPanel deinen SSH-Key und schalte danach die Passwort-Anmeldung ab.
- **Zugangsdaten:** Token und Vorschau-Passwort liegen nur in `/etc/software-factory/` (nur für root lesbar). Teil diese Dateien nie und häng sie nie an ein Issue.
- **Wer darf mitreden:** Die Factory nimmt Antworten und Änderungswünsche nur von dir an (und von Personen unter `allowedUsers`). Kommentare anderer ignoriert sie und zeigt sie dem Agent nicht. Aufgaben einstellen kann jeder, der im Repo Labels setzen darf. Bind trotzdem zuerst private Repos an.

## 14. Wenn etwas hakt

| Problem | Lösung |
|---|---|
| Nichts passiert nach `to-factory` | `journalctl -u software-factory -f` ansehen. Hat das Issue das Label `factory`? Ist das Repo mit `add-repo.sh` angebunden? |
| `config:error … DEEPSEEK_API_KEY ist nicht gesetzt` | Schritt 4 wiederholen, dann `systemctl restart software-factory` |
| Beim Key-Einfügen landet ein Teil als Befehl in der Shell | Der Key wurde umgebrochen. `history -c` ausführen (löscht den Rest aus dem Verlauf), dann Schritt 4 mit Strg+D wiederholen |
| `board:error` in den Logs | `gh auth refresh -s project`, dann `systemctl restart software-factory` |
| Status **Fehlgeschlagen** | Der Fehler steht als Kommentar im Issue. Ursache beheben, dann im Issue kommentieren |
| Vorschau lädt nicht | Nach jedem neuen Stand braucht sie 1–2 Minuten. Ist schon eine Vorschau aktiv (`preview.max`), bekommt der PR keine weitere. Mit Domain: Zeigt die Subdomain auf den Server und sind Port 80 und 443 offen? |
| DeepSeek-Rate-Limit oder Guthaben leer | Die Läufe schlagen fehl, bis das Limit zurückgesetzt oder Guthaben aufgeladen ist. `maxParallel` senken |
| `sandbox: file access denied` im Lauf | Der Agent wollte außerhalb von `/work` schreiben. Pfad im Job korrigieren; nicht pauschal auf `danger-full-access` umstellen |
| Neue Version der Factory holen | `factory-rollout` |

## Was die Factory nie tut

- Sie ändert nie deine Spec.
- Sie mergt nie selbst.
- Sie rät nicht bei Unklarheiten, sondern fragt im Issue nach.
- Sie meldet nie „bestanden“, wenn die Checks nicht grün sind oder ein Testszenario durchfällt.
- Sie arbeitet nur in Repos, die du mit `add-repo.sh` angebunden hast.
