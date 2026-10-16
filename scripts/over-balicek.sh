#!/usr/bin/env bash
# over-balicek.sh - proverka npm balicku PRED instalaci (kurz darkondrej.ai, modul P5.2, slopsquatting VC-7).
# Pouziti:  bash scripts/over-balicek.sh <nazev> [<nazev> ...]
# Jediny skript ze scripts/, ktery smi spoustet i agent (necte .env).
#           bash scripts/over-balicek.sh @supabase/supabase-js server-only
#
# Co dela: zepta se verejneho registru npm (registry.npmjs.org, api.npmjs.org), nic neinstaluje, nic nespousti.
# Verdikt:  STOP      balicek neexistuje (model si ho mozna vymyslel; nekdo ho muze zalozit a cekat)
#           PROVERIT  existuje, ale je novy, malo stahovany, bez repozitare nebo s instalacnim skriptem
#           OK        zadny varovny signal (porad over, ze je to TEN balicek z oficialni dokumentace)
# Prahy jsou orientacni, ne pravidlo. Rozhoduje clovek.
# Limit: skript kontroluje jen zadany balicek, ne jeho zavislosti. npm install spousti instalacni skripty
# (postinstall) i u zavislosti; kdo chce jistotu, instaluje s --ignore-scripts a overi, ze appka bezi.
# Fail-closed: kdyz registr neodpovi platnym JSON (sit, vypadek, captive portal), verdikt je NEOVERENO a exit 2,
# ne OK. Nazev musi byt platny nazev npm balicku (@scope/nazev, bez verze a mezer), jinak se registr vubec nepta.
# Overeno k 2026-10-12 (repository jako objekt i jako retezec "github:autor/repo"). VOLATILNI: format odpovedi registru. Kompatibilni s bash 3.2 (macOS), Linux a WSL (Windows jen pres WSL).

set -u
command -v curl >/dev/null 2>&1 || { echo "Chybi curl."; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "Chybi jq (macOS 15+: /usr/bin/jq, jinak brew install jq; Linux/WSL: sudo apt install jq)."; exit 2; }
[ $# -ge 1 ] || { echo "Pouziti: bash scripts/over-balicek.sh <nazev> [<nazev> ...]"; exit 2; }

MIN_DNI=90          # mladsi nez ~3 mesice = PROVERIT
MIN_STAZENI=1000    # mene stazeni za tyden = PROVERIT
celkem_stop=0; celkem_neovereno=0

for nazev in "$@"; do
  echo "== $nazev"
  if ! printf '%s' "$nazev" | grep -Eiq '^(@[a-z0-9][a-z0-9._~-]*/)?[a-z0-9][a-z0-9._~-]{0,213}$'; then
    echo "  STOP: '$nazev' neni platny nazev npm balicku (verzi nezadavej, jen nazev). Opis ho z oficialni dokumentace."
    celkem_stop=$((celkem_stop + 1)); echo; continue
  fi
  kod="$(printf '%s' "$nazev" | sed 's|/|%2f|')"
  meta="$(curl -s --max-time 20 -w '\n%{http_code}' "https://registry.npmjs.org/$kod")"
  http="${meta##*$'\n'}"; meta="${meta%$'\n'*}"
  if [ "$http" = "404" ]; then
    echo "  STOP: balicek v registru npm neexistuje. Nehledej podobny nazev, najdi spravny v oficialni dokumentaci."
    celkem_stop=$((celkem_stop + 1)); echo; continue
  fi
  if [ "$http" != "200" ] || ! printf '%s' "$meta" | jq -e 'type == "object" and has("name")' >/dev/null 2>&1; then
    echo "  NEOVERENO: registr neodpovedel platnymi daty (HTTP $http). Sit nebo vypadek; nic neinstaluj a zkus to znovu."
    celkem_neovereno=$((celkem_neovereno + 1)); echo; continue
  fi

  posledni="$(printf '%s' "$meta" | jq -r '."dist-tags".latest // "?"')"
  vytvoreno="$(printf '%s' "$meta" | jq -r '.time.created // ""')"
  stari="$(printf '%s' "$meta" | jq -r '(.time.created // "") | if . == "" then -1 else (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 | (now - .) / 86400 | floor) end' 2>/dev/null)"
  repo="$(printf '%s' "$meta" | jq -r '(.repository | if type == "object" then .url else . end) // ""' 2>/dev/null)"
  udrzbari="$(printf '%s' "$meta" | jq -r '(.maintainers // []) | length')"
  skripty="$(printf '%s' "$meta" | jq -r --arg v "$posledni" '(.versions[$v].scripts // {}) | to_entries | map(select(.key == "preinstall" or .key == "install" or .key == "postinstall")) | map(.key) | join(", ")')"
  stazeni="$(curl -s --max-time 20 "https://api.npmjs.org/downloads/point/last-week/$nazev" | jq -r '.downloads // 0' 2>/dev/null)"
  case "$stazeni" in ''|*[!0-9]*) stazeni=0 ;; esac   # neznamy pocet = 0 = PROVERIT, ne OK
  case "$stari" in ''|*[!0-9-]*) stari=-1 ;; esac

  echo "  posledni verze: $posledni · vytvoren: ${vytvoreno%%T*} (${stari} dni) · stazeni za tyden: $stazeni · udrzbaru: $udrzbari"
  echo "  repozitar: ${repo:-zadny}"
  echo "  instalacni skripty: ${skripty:-zadne}"

  varovani=""
  [ "$stari" -ge 0 ] && [ "$stari" -lt "$MIN_DNI" ] && varovani="$varovani novy(<${MIN_DNI} dni);"
  [ "$stari" -lt 0 ] && varovani="$varovani neznamy vek;"
  [ "$stazeni" -lt "$MIN_STAZENI" ] && varovani="$varovani malo stazeni(<${MIN_STAZENI}/tyden);"
  [ -z "$repo" ] && varovani="$varovani bez repozitare;"
  [ -n "$skripty" ] && varovani="$varovani spousti kod pri instalaci ($skripty);"

  if [ -n "$varovani" ]; then
    echo "  PROVERIT:$varovani"
    echo "  Over rucne: odkaz z oficialni dokumentace knihovny, repozitar existuje a odkazuje zpet na npm, autor, README."
  else
    echo "  OK: zadny varovny signal. Over jeste, ze nazev je presne ten z oficialni dokumentace (preklep = jiny balicek)."
  fi
  echo
done

[ "$celkem_stop" -eq 0 ] || exit 1
[ "$celkem_neovereno" -eq 0 ] || exit 2
exit 0
