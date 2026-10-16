#!/usr/bin/env bash
# sluc-nastaveni-P5.sh - slouci .claude/settings-doplnek-P5.json do .claude/settings.json z P2, nic neprepise.
# Spoustis TY ve svem terminalu, v koreni repa appky (agentovi upravy .claude/ zakazuje P2):
#     bash scripts/sluc-nastaveni-P5.sh
# Co udela: settings.json zazalohuje (.claude/settings.json.zaloha), seznamy deny a ask z doplnku spoji bez duplicit,
# defaultMode acceptEdits a disableAutoMode doplni, hook strazce-p5.sh prida vedle strazce.sh z P2 s matcherem Bash|Monitor
# (pri opakovani jen jednou; starsi zaznam, napr. s matcherem jen Bash, nahradi).
# Rezim a zaznam hooku bere z TOHOTO skriptu, ne z doplnku: doplnek lezi v repu a mohl ho kdokoli (i agent) zmenit.
# Z doplnku bere jen retezce deny a ask a overi, ze v nich jsou povinna pravidla. Odmitne settings.json
# s "disableAllHooks" a varuje, kdyz .claude/settings.local.json obsahuje hooky, rezim nebo vypnuti hooku
# (local ma prednost pred settings.json a git ho nevidi). Na konci overi vysledek jq empty. Kdyz neco selze, vrati zalohu.
# v1.4 · Overeno k 2026-10-12 proti https://code.claude.com/docs/en/hooks a .../settings. VOLATILNI: format settings.json
# se meni s verzemi Claude Code. Bash 3.2.

set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "Chybi jq (macOS 15+: /usr/bin/jq, jinak brew install jq; Linux/WSL: sudo apt install jq)."; exit 1; }
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

DOPLNEK=.claude/settings-doplnek-P5.json
CIL=.claude/settings.json
[ -f "$DOPLNEK" ] || { echo "Chybi $DOPLNEK (sablona P5, slozka do-repa/.claude/)."; exit 1; }
[ -f "$CIL" ] || { echo "Chybi $CIL z P2. Nejdriv P2: bash ~/kurz/sablony/P2/startovni-repo/scripts/sluc-nastaveni.sh"; exit 1; }
jq empty "$CIL" 2>/dev/null || { echo "$CIL neni platny JSON. Oprav ho nejdriv (jq empty $CIL ukaze radek)."; exit 1; }

# Doplnek: jen retezce v deny a ask, povinna pravidla pritomna
jq -e '(.permissions.deny | type == "array" and all(type == "string"))
       and (.permissions.ask | type == "array" and all(type == "string"))
       and (.permissions.deny | index("Bash(gh pr merge *)") != null)
       and (.permissions.deny | index("mcp__*merge_pull_request*") != null)' "$DOPLNEK" >/dev/null 2>&1 \
  || { echo "$DOPLNEK neni v poradku (deny/ask nejsou seznamy textu nebo chybi deny gh pr merge / mcp__*merge_pull_request*). Vezmi ho znovu ze sablony P5."; exit 1; }
jq -e '.disableAllHooks == true' "$CIL" >/dev/null 2>&1 \
  && { echo "$CIL ma \"disableAllHooks\": true, hooky by nebezely. Odstran ten radek a spust znovu."; exit 1; }
if [ -f .claude/settings.local.json ]; then
  jq -e '(.hooks // {} | length > 0) or (.permissions.defaultMode // "" | length > 0) or (.disableAllHooks // false) or (.permissions.allow // [] | map(select(test("^(Bash|Edit|Write|mcp__[*])$|[(][*][)]$"))) | length > 0)' .claude/settings.local.json >/dev/null 2>&1 \
    && echo "POZOR: .claude/settings.local.json nastavuje hooky, rezim, vypnuti hooku nebo plose allow (Bash, Bash(*)) a ma prednost pred settings.json. Projdi ho: jq . .claude/settings.local.json"
fi

HOOK='{"matcher":"Bash|Monitor","hooks":[{"type":"command","command":"${CLAUDE_PROJECT_DIR}/.claude/hooks/strazce-p5.sh","args":[],"timeout":10,"onFailure":"block"}]}'
cp "$CIL" "$CIL.zaloha"
if jq -s --argjson hook "$HOOK" '
  def spoj(a; b): ((a // []) + (b // [])) | unique;
  .[0] as $m | .[1] as $s
  | $m
  | .permissions.defaultMode     = "acceptEdits"
  | .permissions.disableAutoMode = "disable"
  | .permissions.deny = spoj($m.permissions.deny; $s.permissions.deny)
  | .permissions.ask  = spoj($m.permissions.ask;  $s.permissions.ask)
  | .hooks.PreToolUse = ([ ($m.hooks.PreToolUse // [])[] | select(tostring | test("strazce-p5.sh") | not) ] + [$hook])
' "$CIL.zaloha" "$DOPLNEK" > "$CIL.novy" && jq empty "$CIL.novy" 2>/dev/null; then
  mv "$CIL.novy" "$CIL"
  echo "Hotovo: $CIL doplnen o P5 (zaloha $CIL.zaloha)."
  echo "Kontrola: deny $(jq '.permissions.deny | length' "$CIL"), ask $(jq '.permissions.ask | length' "$CIL"), hooku PreToolUse $(jq '.hooks.PreToolUse | length' "$CIL"), rezim $(jq -r '.permissions.defaultMode' "$CIL")."
  echo "Zalohu .claude/settings.json.zaloha necommituj (je v .gitignore z P2). Doplnek muzes smazat: rm $DOPLNEK"
else
  rm -f "$CIL.novy"; cp "$CIL.zaloha" "$CIL"
  echo "Slouceni selhalo, $CIL vracen ze zalohy. Napis do vlakna Drahy P."; exit 1
fi
