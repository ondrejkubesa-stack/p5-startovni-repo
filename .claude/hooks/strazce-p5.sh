#!/usr/bin/env bash
# strazce-p5.sh - PreToolUse hook pro Claude Code (kurz darkondrej.ai, modul P5). Doplnuje strazce.sh z P2, nenahrazuje ho.
#
# Proc: pravidlo Bash(gh pr merge *) v permissions.deny zastavi jen ten jeden zapis prikazu. Dokumentace Claude Code
# sama pise, ze Bash pravidlo "isn't a security boundary around the program". Merge PR jde i pres
# gh api -X PUT repos/<ja>/<repo>/pulls/1/merge a GitHub agenta od cloveka nerozezna (pouziva tvuj token gh).
# Na GitHub Free u soukromeho repa nejsou chranene vetve ani rulesets (dostupne od GitHub Pro / Team).
#
# Hlida Bash i Monitor (Monitor spousti shellovy prikaz na pozadi; permissions.deny pro Bash na nej plati, hook jen
# s matcherem "Bash|Monitor", ktery doplnek P5 nastavuje). Jak cte prikaz: nejdriv ho NORMALIZUJE (odstrani uvozovky
# a zpetna lomitka, spoji pokracovani radku, ${IFS} na mezeru, vse malymi pismeny, protoze macOS APFS nerozlisuje velikost: GH = gh, Scripts/ = scripts/). Glob (scripts/kontrola-p?.sh,
# scr*/k*) porovna se jmeny chranenych souboru. U chranenych souboru plati DENY-BY-DEFAULT: kdyz je prikaz zmini,
# projde bez dotazu jen prikaz ze seznamu "jen cte" (cat, less, head, tail, grep, wc, ls, diff, git diff/log/show/status,
# sed -n Np, bash -n...), bez presmerovani do souboru a bez $(...). Cokoli jineho (sed -i, cp, mv, rm, ln, dd, perl,
# python, node, install, tee, >, git checkout/restore...) se zepta nebo je zakazane. Neni to vycet zapisovacich prikazu.
# Totez plati, kdyz je PRACOVNI SLOZKA (pole cwd ve vstupu hooku) uvnitr scripts/, .githooks/ nebo .claude/: tam projde
# jen cteni, cokoli jineho je deny (ls | xargs -n1 bash po "cd scripts" chranene jmeno nezmini). Cesta se porovnava
# doslovne i skutecna (pwd -P: symlink na slozku, /var -> /private/var) a malymi pismeny.
#
# Co zakaze (deny):   merge PR: gh ... pr merge v jakemkoli zapisu; gh api na .../merge(s), GraphQL mergePullRequest,
#                       enablePullRequestAutoMerge, mergeBranch; curl/wget na api.github.com s /merge;
#                       gh alias set/import (alias by obesel vsechna pravidla: gh m 1 = gh pr merge 1);
#                     skripty, ktere ctou .env (kontrola-p5.sh, test-anonymniho-cteni.sh, over-zneplatneni.sh) jakkoli
#                       zminene mimo cteni (bash, ./, source, cp do /tmp a spustit, glob): spousti je clovek.
#                       over-balicek.sh a over-strazce-p5.sh .env nectou, ty agent smi (bash scripts/<skript>).
# Na co se zepta (ask): prikaz sestaveny za behu (eval, base64 -d, xxd -r, $'\x..', | sh, promenna v ceste ke skriptu);
#                     gh spolu se slovem merge v jinem tvaru; gh extension install; prime volani api.github.com;
#                     spusteni nebo instalace balicku (npx, bunx, uvx, npm exec/init/create/install/pkg, pnpm/yarn dlx
#                       a create, bun x, pip install, uv add, pipx);
#                     Supabase CLI v jakemkoli zapisu krome status/help/--version (deny-by-default);
#                     jakakoli neciteci prace s chranenymi soubory: scripts/, .githooks/, .gitleaks.toml,
#                       playwright.config.ts, package.json, package-lock.json, strazce-p5.sh, settings-doplnek-P5.json.
#
# Co NECHYTA (regex nad textem prikazu neni sandbox):
#   - program, ktery merge nebo zapis udela sam: node, python, ruby skript (soubor si napise agent nastrojem Write
#     a spusti ho: v textu prikazu pak zadne chranene jmeno neni), npm skript s jinym nazvem, Makefile;
#   - cesta sestavena v jinem procesu (skript precte nazev ze souboru), symlink nebo hardlink vytvoreny driv pod jinym jmenem;
#   - merge nastrojem MCP serveru (proti tomu deny "mcp__*merge_pull_request*" v doplnku P5) a token gh ve skriptu;
#   - git diff s externim diff driverem z .git/config (ten si agent muze nastavit jinym prikazem);
#   - pracovni slozku, do ktere vede symlink vytvoreny uvnitr prikazu (ln -s scripts s; cd s; ...) v jednom volani:
#     hook vidi jen cwd pred spustenim, ne cd uprostred prikazu (proto ask/deny uz pri zmince scripts v textu);
#   - monitory deklarovane pluginem (spousti je Claude Code sam pri startu pluginu, ne nastrojem Monitor).
#   Skutecna ochrana: sandbox (P2.1, /sandbox) s "allowUnsandboxedCommands": false a filesystem.denyWrite na scripts/,
#   .githooks/, package.json (.claude/ a .mcp.json sandbox chrani sam), filesystem.denyRead na .env; managed settings
#   s "allowManagedHooksOnly": true (hooky z repa pak nebezi vubec, firma nasadi vlastni); OS prava (chflags uchg na
#   macOS, vlastnik root); na GitHubu chranena vetev nebo ruleset (od GitHub Pro / Team) a token jen s pravy, ktere
#   agent potrebuje (fine-grained PAT bez "Pull requests: write"). Kontejner s jinym tokenem je nejcistsi.
#
# Pri chybe hooku (pad, timeout, neplatny JSON) Claude Code akci propusti, pokud ho settings.json neregistruje
# s "onFailure": "block" (doplnek P5 to dela; Claude Code 2.1.295+, starsi verze pole ignoruji). Chybejici jq
# nebo vstup, ktery nejde precist, blokuje hook sam (exit 2).
#
# Testy obchvatu: scripts/over-strazce-p5.sh (spoustis ty i agent; necte .env).
# v1.4 · Overeno k 2026-10-12 proti https://code.claude.com/docs/en/hooks, .../permissions, .../permission-modes,
# .../sandboxing a .../tools-reference (Monitor: vstup command nebo ws, stejna permission pravidla jako Bash).
# VOLATILNI. Bash 3.2 kompatibilni.

set -uo pipefail
set -f   # zadne rozvijeni globu v hooku samotnem: globy z prikazu se porovnavaji jako vzory
command -v jq >/dev/null 2>&1 || { echo "strazce-p5.sh: chybi jq, akce zablokovana" >&2; exit 2; }

input="$(cat)"
nastroj="$(jq -r '.tool_name // ""' <<<"$input" 2>/dev/null)" || { echo "strazce-p5.sh: vstup hooku neni JSON, akce zablokovana" >&2; exit 2; }
case "$nastroj" in Bash|Monitor) ;; *) exit 0 ;; esac   # Monitor spousti shellovy prikaz stejne jako Bash
cmd="$(jq -r '.tool_input.command // ""' <<<"$input" 2>/dev/null)" || { echo "strazce-p5.sh: prikaz nejde precist, akce zablokovana" >&2; exit 2; }
[ -n "$cmd" ] || exit 0   # Monitor s WebSocketem (ws) prikaz nema
projekt="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cwd="$(jq -r '.cwd // ""' <<<"$input" 2>/dev/null)"; [ -n "$cwd" ] || cwd="$(pwd)"
log="$projekt/.claude/hooks/blokace.log"

rozhodni() { # rozhodni deny|ask "duvod"
  mkdir -p "$(dirname "$log")" 2>/dev/null
  printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$nastroj" "$2" >>"$log" 2>/dev/null
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  exit 0
}

# ---------- Normalizace ----------
NL=$'\n'
n="${cmd//\\$NL/ }"                      # pokracovani radku \<Enter>
n="${n//$NL/ ; }"                        # dalsi radek = dalsi prikaz
n="${n//\$\{IFS\}/ }"; n="${n//\$IFS/ }" # gh${IFS}pr${IFS}merge
n="$(printf '%s' "$n" | tr -d "\"'\\\\" | tr '\t' ' ' | tr '[:upper:]' '[:lower:]')"

W='(^|[;&|(`[:space:]/])'   # zacatek slova: zacatek, oddelovac, mezera nebo lomitko (/usr/bin/gh)

# Chranene soubory (malymi pismeny). ENV = skripty, ktere ctou .env (spousti jen clovek).
ENV_RE='(kontrola-p5|test-anonymniho-cteni|over-zneplatneni)'
ENV_JMENA="kontrola-p5.sh test-anonymniho-cteni.sh over-zneplatneni.sh"
CHR_RE='(^|[[:space:]/=;&|(<>])(scripts(/|[[:space:];&|)]|$)|\.githooks|\.gitleaks\.toml|playwright\.config|package(-lock)?\.json|kontrola-p5|test-anonymniho-cteni|over-zneplatneni|over-balicek|sluc-nastaveni-p5|over-strazce-p5|strazce-p5|settings-doplnek-p5)'
CHR_JMENA="scripts .githooks .gitleaks.toml playwright.config.ts package.json package-lock.json over-balicek.sh sluc-nastaveni-p5.sh over-strazce-p5.sh strazce-p5.sh settings-doplnek-p5.json"

# Trefuje nektery token s globem (* ? [) nektere z danych jmen? Porovnava kazdou cast cesty zvlast.
glob_trefa() { # glob_trefa "jmena oddelena mezerou"
  local tok cast jm
  for tok in $(printf '%s' "$n" | tr ';&|()<>`=' '          '); do
    case "$tok" in *[\*\?\[]*) ;; *) continue ;; esac
    for cast in $(printf '%s' "$tok" | tr '/' ' '); do
      for jm in $1; do
        # shellcheck disable=SC2053  # zamerne vzor, ne retezec
        [[ $jm == $cast ]] && return 0
      done
    done
  done
  return 1
}

# 0 = vsechny casti prikazu jen ctou (deny-by-default: co tu neni, neni cteni)
jen_cteni() {
  local s bez
  case "$n" in *'$('*|*'`'*|*'<('*|*'>('*) return 1 ;; esac
  bez="$(printf '%s' "$n" | sed -E 's/[0-9]*>&[0-9-]//g; s/[0-9]*>[[:space:]]*\/dev\/null//g')"
  case "$bez" in *'>'*) return 1 ;; esac
  case "$n" in *--output*|*--pre\ *|*--pre=*|*--ext-diff*|*-exec*|*-delete*) return 1 ;; esac
  bez="${n//&&/;}"; bez="${bez//||/;}"; bez="${bez//|/;}"; bez="${bez//&/;}"
  while IFS= read -r s; do
    s="$(printf '%s' "$s" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -n "$s" ] || continue
    case "$s" in
      cat|cat\ *|less\ *|more\ *|head\ *|tail\ *|grep\ *|egrep\ *|rg\ *|wc\ *|ls|ls\ *|file\ *|stat\ *|diff\ *|cmp\ *) ;;
      shasum\ *|sha256sum\ *|md5\ *|md5sum\ *|cd|cd\ *|pwd|echo\ *|printf\ *|true|jq\ *|shellcheck\ *|bash\ -n\ *|sh\ -n\ *) ;;
      git\ diff|git\ diff\ *|git\ log|git\ log\ *|git\ show|git\ show\ *|git\ status|git\ status\ *) ;;
      git\ blame\ *|git\ ls-files|git\ ls-files\ *|git\ hash-object\ *|git\ rev-parse\ *) ;;   # ne difftool, ne git grep -O
      sed\ -n\ *) grep -Eq '^sed -n [0-9,$]+p( |$)' <<<"$s" || return 1 ;;
      *) return 1 ;;   # vcetne VAR=hodnota prikaz (GIT_EXTERNAL_DIFF, LESSOPEN...)
    esac
  done <<EOF
$(printf '%s' "$bez" | tr ';' '\n')
EOF
  return 0
}

# ---------- 1) Merge PR: deny ----------
if grep -Eq "${W}gh ([^;&|]* )?pr ([^;&|]* )?merge( |$)" <<<"$n"; then
  rozhodni deny "Strazce P5: merge PR dela clovek po precteni diffu."
fi
if grep -Eq "${W}gh ([^;&|]* )?api( |$)" <<<"$n" \
   && grep -Eq '/merges?([[:space:]?&]|$)|mergepullrequest|enablepullrequestautomerge|mergebranch' <<<"$n"; then
  rozhodni deny "Strazce P5: merge pres gh api. Merge dela clovek v GitHubu."
fi
if grep -Eq "${W}gh ([^;&|]* )?alias ([^;&|]* )?(set|import)( |$)" <<<"$n"; then
  rozhodni deny "Strazce P5: alias gh by obesel pravidla (gh m 1 = gh pr merge 1). Alias si nastavi clovek."
fi
if grep -Eq 'api\.github\.com' <<<"$n" && grep -Eq '/merges?([[:space:]?&]|$)|mergepullrequest|enablepullrequestautomerge|mergebranch' <<<"$n"; then
  rozhodni deny "Strazce P5: merge pres API GitHubu. Merge dela clovek v GitHubu."
fi

# ---------- 1b) Pracovni slozka uvnitr chraneneho mista: deny-by-default ----------
# Po "cd scripts" v predchozim prikazu uz dalsi prikaz chranene jmeno zminit nemusi (ls | xargs -n1 bash).
# Cesta se porovna doslovne i skutecna (symlink na scripts/, /var -> /private/var), malymi pismeny (APFS).
fyz() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }
mala() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
for r in "$(mala "$projekt")" "$(mala "$(fyz "$projekt")")"; do
  for c in "$(mala "$cwd")" "$(mala "$(fyz "$cwd")")"; do
    case "${c%/}/" in "${r%/}"/scripts/*|"${r%/}"/.githooks/*|"${r%/}"/.claude/*)
      jen_cteni || rozhodni deny "Strazce P5: pracovni slozka je uvnitr scripts/, .githooks/ nebo .claude/ ($cwd). Odtud projde jen cteni. Vrat se do korene repa samostatnym prikazem cd \"$projekt\"." ;;
    esac
  done
done

# ---------- 2) Skripty, ktere ctou .env: deny (krome cteni) ----------
if { grep -Eq "$ENV_RE" <<<"$n" || glob_trefa "$ENV_JMENA"; } && ! jen_cteni; then
  rozhodni deny "Strazce P5: kontrola-p5.sh, test-anonymniho-cteni.sh a over-zneplatneni.sh ctou .env, spousti je clovek ve svem terminalu. Agent smi jen bash scripts/over-balicek.sh <nazev>."
fi

# ---------- 3) Prikaz skladany za behu: ask ----------
if grep -Eq "(^|[;&|( ])eval( |$)|base64 ([^;&|]* )?(-d|-D|--decode)|xxd ([^;&|]* )?-r|openssl ([^;&|]* )?(base64|enc) ([^;&|]* )?-d|/dev/stdin|\|[[:space:]]*(ba|z|da|k)?sh([[:space:]]|$)|(ba|z)?sh[[:space:]]+<\(" <<<"$n" \
   || grep -Eq "\\$'[^']*\\\\([xu0-7])" <<<"$cmd"; then
  rozhodni ask "Strazce P5: prikaz se sklada az za behu (eval, dekodovani, | sh). Hook ho neprecte; over, co opravdu spusti."
fi
if grep -Eq '\$[a-z_{(]|`' <<<"$n" && grep -Eq '(scripts|\.githooks)(/|[[:space:]]|$)|\.sh([[:space:];&|)]|$)' <<<"$n"; then
  rozhodni ask "Strazce P5: cesta ke skriptu se sklada z promennych. Hook nevi, co se spusti; over to."
fi

# ---------- 4) gh v jinem tvaru, rozsireni gh, prime API GitHubu: ask ----------
if grep -Eq "${W}gh( |$)" <<<"$n" && grep -Eq 'merge' <<<"$n"; then
  rozhodni ask "Strazce P5: gh a slovo merge v jednom prikazu. Merge dela clovek; over, co prikaz dela."
fi
if grep -Eq "${W}gh ([^;&|]* )?(extension|ext) ([^;&|]* )?(install|upgrade)( |$)" <<<"$n"; then
  rozhodni ask "Strazce P5: rozsireni gh je cizi kod s tvym tokenem. Prover ho a potvrd rucne."
fi
if grep -Eq 'api\.github\.com' <<<"$n"; then
  rozhodni ask "Strazce P5: prime volani API GitHubu. Over, co prikaz dela."
fi

# ---------- 5) Balicky z registru (stahne a spusti cizi kod): ask ----------
if grep -Eq "${W}(npx|bunx|pnpx|uvx)( |$)|${W}npm ([^;&|]* )?(exec|x|init|create|install|i|in|ins|add|isntall|update|up|upgrade|link|ln|pkg|uninstall|un|remove|rm|r)( |$)|${W}(pnpm|yarn) ([^;&|]* )?(dlx|create|add|up|upgrade|update|remove)( |$)|${W}bun ([^;&|]* )?(x|create|add|update|remove)( |$)|${W}(pip|pip3|uv) ([^;&|]* )?(install|add)( |$)|${W}python[0-9.]* -m pip |${W}pipx (run|install)( |$)" <<<"$n"; then
  rozhodni ask "Strazce P5: prikaz stahne, nainstaluje nebo spusti balicek. Over nazev (bash scripts/over-balicek.sh <nazev>) a potvrd rucne."
fi

# ---------- 6) Supabase CLI: deny-by-default, bez dotazu jen status/help/--version ----------
for druhe in $(grep -Eo "(^|[;&|( /])supabase(( +[^ ;&|)]+)|[ ;&|)]|$)" <<<"$n" | sed -E 's/^.*supabase//; s/^ +//; s/[ ;&|)].*$//'); do
  case "$druhe" in status|help|--help|-h|--version|-v) ;; *)
    rozhodni ask "Strazce P5: Supabase CLI ($druhe) muze sahat na vsechny projekty uctu. Zkontroluj projekt a prikaz." ;;
  esac
done

# ---------- 7) Chranene soubory: deny-by-default, bez dotazu jen cteni ----------
if grep -Eq '^ *(bash|sh) +(\./)?scripts/(over-balicek|over-strazce-p5)\.sh( +[a-z0-9@._/~-]+)* *$' <<<"$n"; then
  exit 0   # jedine skripty ze scripts/, ktere agent smi spustit (nectou .env)
fi
if { grep -Eq "$CHR_RE" <<<"$n" || glob_trefa "$CHR_JMENA"; } && ! jen_cteni; then
  rozhodni ask "Strazce P5: prikaz pracuje s kontrolnim skriptem, hookem nebo konfiguraci testu/balicku a jen necte. Over, proc to agent potrebuje."
fi

exit 0
