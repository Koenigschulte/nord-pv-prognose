# Status-Check

`check-status.sh` beantwortet die Frage **„sind alle Anwendungen down?"** auf zwei Ebenen:

1. **Infrastruktur** — Power-Status aller Server in der Hetzner Cloud (über die Hetzner Cloud API).
2. **Anwendung** — HTTP-Erreichbarkeit deiner App-URLs (Status-Code).

## Voraussetzungen

- `bash` (4+), `curl`
- `jq` (optional, für hübsche Server-Liste; ohne jq gibt es eine vereinfachte Ausgabe)
- Hetzner Cloud **Read**-API-Token: `console.hetzner.cloud` → *Security → API Tokens*

## Benutzung

```bash
export HCLOUD_TOKEN="dein-readonly-api-token"

# Nur Server-Status:
./scripts/check-status.sh

# Server + App-URLs prüfen:
./scripts/check-status.sh https://pv.example.de https://api.example.de/health

# URLs alternativ per Env-Variable:
APP_URLS="https://pv.example.de https://api.example.de/health" ./scripts/check-status.sh
```

**Exit-Code:** `0` = alles erreichbar · `1` = mindestens etwas ist down.

Damit lässt sich das Skript auch in Cron/CI verwenden, z. B. stündlicher Check mit Alarm bei Exit-Code `1`.

## Hinweis zur Web-Session

Aus der Claude-Code-Web-Session heraus lässt sich dieser Check **nicht** ausführen:
Die Netzwerk-Policy erlaubt nur `github.com`; `api.hetzner.cloud` und beliebige
Server-Hosts werden mit `403 host_not_allowed` geblockt. Führe das Skript daher
lokal oder auf einem Server aus.
