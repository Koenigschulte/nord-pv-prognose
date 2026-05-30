#!/usr/bin/env bash
#
# check-status.sh — Prüft, ob deine Anwendungen down sind.
#
# Zwei Ebenen:
#   1) Infrastruktur:  Power-Status aller Server in der Hetzner Cloud (über die Hetzner Cloud API).
#   2) Anwendung:      HTTP-Erreichbarkeit deiner App-URLs (Status-Code).
#
# Benutzung:
#   export HCLOUD_TOKEN="dein-readonly-api-token"     # Hetzner Cloud > Security > API Tokens (Read)
#   ./scripts/check-status.sh
#
# App-URLs prüfen (eine oder mehrere):
#   ./scripts/check-status.sh https://pv.example.de https://api.example.de/health
#   # oder per Env-Variable (Leerzeichen-getrennt):
#   APP_URLS="https://pv.example.de https://api.example.de/health" ./scripts/check-status.sh
#
# Exit-Code: 0 = alles erreichbar, 1 = mindestens etwas ist down/nicht erreichbar.
#
set -uo pipefail

# ---- Farben (nur wenn Terminal) -------------------------------------------
if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
fi

ok()   { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$RED"   "$RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
head() { printf '\n%s== %s ==%s\n' "$BOLD" "$*" "$RESET"; }

FAIL=0
TIMEOUT="${TIMEOUT:-15}"

# ---- 1) Hetzner Cloud: Server-Status --------------------------------------
head "Hetzner Cloud — Server"

if [ -z "${HCLOUD_TOKEN:-}" ]; then
  warn "HCLOUD_TOKEN nicht gesetzt — überspringe Server-Check."
  warn "Token anlegen: console.hetzner.cloud > Security > API Tokens (Read). Dann: export HCLOUD_TOKEN=..."
else
  resp="$(curl -s -m "$TIMEOUT" -H "Authorization: Bearer $HCLOUD_TOKEN" \
            "https://api.hetzner.cloud/v1/servers?per_page=50")"
  if [ -z "$resp" ]; then
    bad "Keine Antwort von api.hetzner.cloud (Netzwerk/Timeout?)."; FAIL=1
  elif printf '%s' "$resp" | grep -q '"error"'; then
    bad "API-Fehler:"; printf '%s\n' "$resp" | sed 's/^/    /'; FAIL=1
  elif command -v jq >/dev/null 2>&1; then
    count="$(printf '%s' "$resp" | jq '.servers | length')"
    if [ "${count:-0}" -eq 0 ]; then
      warn "Keine Server gefunden (Token korrekt? richtiges Projekt?)."
    fi
    while IFS=$'\t' read -r name status ip; do
      if [ "$status" = "running" ]; then
        ok "$name ($ip) — running"
      else
        bad "$name ($ip) — $status"; FAIL=1
      fi
    done < <(printf '%s' "$resp" | jq -r '.servers[] | [.name, .status, (.public_net.ipv4.ip // "-")] | @tsv')
  else
    warn "jq nicht installiert — zeige rohe Statuswerte:"
    printf '%s' "$resp" | grep -oE '"status":"[a-z]+"' | sort | uniq -c | sed 's/^/    /'
    printf '%s' "$resp" | grep -q '"status":"running"' || { bad "Kein laufender Server erkennbar."; FAIL=1; }
  fi
fi

# ---- 2) App-URLs: HTTP-Erreichbarkeit -------------------------------------
head "Anwendungen — HTTP"

# URLs aus Argumenten oder Env-Variable APP_URLS
urls=("$@")
if [ "${#urls[@]}" -eq 0 ] && [ -n "${APP_URLS:-}" ]; then
  # shellcheck disable=SC2206
  urls=($APP_URLS)
fi

if [ "${#urls[@]}" -eq 0 ]; then
  warn "Keine App-URLs angegeben — überspringe HTTP-Check."
  warn "Beispiel: $0 https://pv.example.de https://api.example.de/health"
else
  for url in "${urls[@]}"; do
    code="$(curl -s -o /dev/null -w '%{http_code}' -m "$TIMEOUT" -L "$url" 2>/dev/null)"
    if [ "$code" = "000" ]; then
      bad "$url — nicht erreichbar (Timeout/DNS/Connection refused)"; FAIL=1
    elif [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
      ok "$url — HTTP $code"
    else
      bad "$url — HTTP $code"; FAIL=1
    fi
  done
fi

# ---- Zusammenfassung -------------------------------------------------------
head "Ergebnis"
if [ "$FAIL" -eq 0 ]; then
  ok "Alles erreichbar — nichts ist down."
else
  bad "Mindestens eine Komponente ist down oder nicht erreichbar (siehe oben)."
fi
exit "$FAIL"
