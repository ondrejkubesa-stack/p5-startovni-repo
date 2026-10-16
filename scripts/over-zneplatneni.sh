#!/usr/bin/env bash
# over-zneplatneni.sh - dukaz rotace pro cviceni "unikl klic" (kurz darkondrej.ai, modul P5.2). v1.1
# Spoustis TY ve svem terminalu, v koreni repa, kde je .env s klicem (skript cte .env, proto ne pres Claude Code).
#
# Pouziti:  bash scripts/over-zneplatneni.sh anthropic              # varianta A (Dilna): ANTHROPIC_API_KEY z P1.2
#           bash scripts/over-zneplatneni.sh openrouter             # varianta A: OPENROUTER_API_KEY z P1.2
#           bash scripts/over-zneplatneni.sh supabase [tabulka]     # varianta B (po ukolu P5.2): SUPABASE_SECRET_KEY, vychozi tabulka poptavky
#
# Jak to funguje (jeden beh skriptu pres celou rotaci, starý klic nikam neopisujes):
#   PRED  skript precte STARY klic z .env a overi, ze funguje (jinak cviceni nic nedokaze: preklep, spatny soubor).
#         Klic drzi jen v pameti tohoto behu, nikam ho neuklada a nevypisuje.
#   ...   ty vytvoris novy klic, vlozis ho do .env, restartujes appku a stary klic smazes u poskytovatele. Pak Enter.
#   PO    skript precte NOVY klic z .env: novy musi fungovat a stary musi vratit HTTP 401.
# Klice jdou do curl pres stdin (-H @-), takze nejsou videt ve vypisu procesu. Data se nestahuji
# (Supabase: select=id&limit=0, Anthropic: seznam modelu, OpenRouter: informace o klici).
# Overeno k 2026-10-07. VOLATILNI: odpovedi poskytovatelu na smazany klic, adresy API. Kompatibilni s bash 3.2.

set -u
command -v curl >/dev/null 2>&1 || { echo "Chybi curl."; exit 2; }
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$ROOT" || exit 2
REZIM="${1:-}"; T="${2:-poptavky}"
case "$REZIM" in
  supabase)   PROM=SUPABASE_SECRET_KEY ;;
  anthropic)  PROM=ANTHROPIC_API_KEY ;;
  openrouter) PROM=OPENROUTER_API_KEY ;;
  *) echo "Pouziti: bash scripts/over-zneplatneni.sh anthropic|openrouter|supabase [tabulka]"; exit 2 ;;
esac

# Hodnota z .env.local, jinak z .env (stejne poradi jako Next.js). Soubor se NESPOUSTI, jen cte.
env_hodnota() {
  for f in .env.local .env; do
    [ -f "$f" ] || continue
    v="$(grep -E "^[[:space:]]*(export[[:space:]]+)?$1=" "$f" | tail -n 1 | sed -E "s/^[[:space:]]*(export[[:space:]]+)?$1=//; s/^[\"']//; s/[\"'][[:space:]]*$//; s/[[:space:]]+$//")"
    [ -n "$v" ] && { printf '%s' "$v"; return; }
  done
}

URL=""
if [ "$REZIM" = "supabase" ]; then
  URL="$(env_hodnota SUPABASE_URL)"; URL="${URL%/}"
  [ -n "$URL" ] || { echo "V .env chybi SUPABASE_URL."; exit 2; }
  # Klic smi jen na endpoint projektu Supabase nebo na lokalni Supabase CLI. Jina adresa = klic by unikl.
  printf '%s' "$URL" | grep -Eq '^(https://[a-z0-9-]+\.supabase\.co|http://(127\.0\.0\.1|localhost):[0-9]+)$' \
    || { echo "STOP: na tuto adresu klic neodeslu. SUPABASE_URL musi byt https://<projekt>.supabase.co, nebo http://127.0.0.1:<port> pro lokalni Supabase CLI."; exit 2; }
fi

kod() { # kod KLIC -> HTTP kod (000 = sit nedostupna)
  case "$REZIM" in
    supabase)   printf 'apikey: %s\n' "$1" | curl -s --max-time 20 -o /dev/null -w '%{http_code}' -H @- "$URL/rest/v1/$T?select=id&limit=0" ;;
    anthropic)  printf 'x-api-key: %s\nanthropic-version: 2023-06-01\n' "$1" | curl -s --max-time 20 -o /dev/null -w '%{http_code}' -H @- https://api.anthropic.com/v1/models ;;
    openrouter) printf 'Authorization: Bearer %s\n' "$1" | curl -s --max-time 20 -o /dev/null -w '%{http_code}' -H @- https://openrouter.ai/api/v1/key ;;
  esac
}

STARY="$(env_hodnota "$PROM")"
[ -n "$STARY" ] || { echo "V .env chybi $PROM."; exit 2; }

echo "== PRED rotaci ($REZIM, $PROM) =="
K="$(kod "$STARY")"
case "$K" in
  200|206) echo "[OK]    stary klic funguje (HTTP $K). Skript si ho drzi jen v pameti." ;;
  000) echo "[STOP]  sit nebo adresa nedostupna (HTTP 000). Zkontroluj pripojeni a adresu."; exit 2 ;;
  401) echo "[STOP]  klic v .env nefunguje uz ted (HTTP 401): preklep, cizi soubor nebo uz smazany klic. Bez platneho PRED nic nedokazes."; exit 2 ;;
  404) echo "[STOP]  tabulka $T neexistuje (HTTP 404). Varianta B patri az po migraci a seedu; jinak zadej tabulku: ... supabase <tabulka>"; exit 2 ;;
  *) echo "[STOP]  necekana odpoved HTTP $K. Zkus znovu za minutu."; exit 2 ;;
esac
echo "Cas PRED: $(date +%H:%M)"
echo
echo "Ted: 1) vytvor novy klic,  2) vloz ho do .env misto stareho a restartuj appku,"
echo "     3) stary klic SMAZ u poskytovatele (kontroluj NAZEV, ne poradi v seznamu)."
echo "Az bude hotovo, stiskni Enter. (Ctrl+C = konec, stary klic se nikam neulozil.)"

while :; do
  read -r _
  NOVY="$(env_hodnota "$PROM")"
  if [ -z "$NOVY" ]; then echo "V .env chybi $PROM. Dopln novy klic a stiskni Enter."; continue; fi
  if [ "$NOVY" = "$STARY" ]; then echo "V .env je porad STARY klic. Nahrad ho novym, uloz a stiskni Enter."; continue; fi
  break
done

echo "== PO rotaci =="
K_NOVY="$(kod "$NOVY")"
K_STARY="$(kod "$STARY")"; i=1
while [ "$K_STARY" != "401" ] && [ "$i" -lt 4 ]; do   # smazani se muze par sekund sirit
  echo "   stary klic zatim vraci HTTP $K_STARY, zkousim znovu za 20 s ($i/3)"; sleep 20
  K_STARY="$(kod "$STARY")"; i=$((i+1))
done
unset STARY NOVY

OK=1
case "$K_STARY" in
  401) echo "[OK]    stary klic je neplatny (HTTP 401)" ;;
  000) echo "[CHYBA] sit nedostupna, neplatnost stareho klice NENI overena."; OK=0 ;;
  *)   echo "[CHYBA] stary klic PORAD FUNGUJE nebo vraci necekane HTTP $K_STARY. Smaz ho u poskytovatele (podle nazvu)."; OK=0 ;;
esac
case "$K_NOVY" in
  200|206) echo "[OK]    novy klic funguje (HTTP $K_NOVY)" ;;
  *) echo "[CHYBA] novy klic nefunguje (HTTP $K_NOVY). Zkontroluj .env a restartuj aplikaci."; OK=0 ;;
esac
echo "Cas PO: $(date +%H:%M) - cely vystup vloz do docs/incident-cviceni.md"
[ "$OK" -eq 1 ] && exit 0 || exit 1
