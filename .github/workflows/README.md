# Health Auto-Heal (GitHub Action)

Die Action [`health-autoheal.yml`](./health-autoheal.yml) prüft alle 5 Minuten den
Health-Endpoint und **rebootet bei Ausfall automatisch** den Hetzner-Cloud-Server
über die Hetzner Cloud API. Läuft komplett auf GitHub — **kein Laptop nötig**.

## Einrichtung (geht komplett am Handy im GitHub-Mobile-Web)

### 1. Hetzner API-Token erstellen
- `console.hetzner.cloud` → richtiges Projekt → **Security → API Tokens** → **Generate API token**
- Berechtigung: **Read & Write** (Write ist für den Reboot nötig)
- Token kopieren (wird nur einmal angezeigt).

### 2. GitHub-Secrets anlegen
Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Wert |
|--------|------|
| `HCLOUD_TOKEN` | der eben erstellte Hetzner-Token |
| `HCLOUD_SERVER_NAME` | Name des Servers in der Hetzner Cloud, z. B. `koeschu` |

> Alternativ statt des Namens `HCLOUD_SERVER_ID` mit der numerischen Server-ID setzen.

### 3. (Optional) Einstellungen anpassen
Repo → **Settings → Secrets and variables → Actions → Variables**:

| Variable | Default | Bedeutung |
|----------|---------|-----------|
| `HEALTH_URL` | `https://koeschu.com/api/health` | zu prüfender Endpoint |
| `HEALTH_TIMEOUT` | `15` | Timeout pro Versuch (Sekunden) |
| `HEALTH_RETRIES` | `3` | Fehlversuche, bevor als „down" gewertet wird |

## So läuft es ab
1. Alle 5 Min: Health-Endpoint wird bis zu `HEALTH_RETRIES`-mal geprüft.
2. Ist er erreichbar → fertig, nichts passiert.
3. Ist er down → der Server wird per Hetzner API neugestartet
   (`reboot`, wenn er läuft; `poweron`, wenn er aus ist).
4. Danach wird bis zu ~2 Min auf Recovery gewartet.
5. Es wird ein **GitHub-Issue** (Label `incident`) erstellt — mit Ergebnis
   (behoben / noch offen).

## Sofort testen
Repo → **Actions → „Health Auto-Heal" → Run workflow** (manueller Start).

## Sicherheitshinweis
Der `HCLOUD_TOKEN` hat Schreibrechte auf dein Hetzner-Projekt. Er liegt als
verschlüsseltes GitHub-Secret und wird nicht im Log ausgegeben. Bei Verdacht auf
Kompromittierung: Token in der Hetzner Console **revoken** und neu anlegen.
