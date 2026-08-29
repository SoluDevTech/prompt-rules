#!/usr/bin/env bash
# Usage: ./switch-config.sh [spark|cloud]
# Sans argument: affiche la config active et les profils disponibles
set -eu
cd ~/.config/opencode

profiles=(spark cloud)
target="${1:-}"

if [[ -z "$target" ]]; then
  echo "Config active:"
  if [[ -L opencode.json ]]; then
    echo "  opencode.json -> $(readlink opencode.json)"
  else
    echo "  opencode.json (fichier direct)"
  fi
  if [[ -L agents ]]; then
    echo "  agents -> $(readlink agents)"
  else
    echo "  agents (dossier direct)"
  fi
  echo
  echo "Profils disponibles: ${profiles[*]}"
  echo "Usage: $0 <${profiles[*]}>"
  exit 0
fi

case "$target" in
  spark|cloud) ;;
  *) echo "Profil inconnu: $target" >&2; echo "Usage: $0 <${profiles[*]}>" >&2; exit 1 ;;
esac

for f in "opencode-${target}.json" "agents-${target}"; do
  [[ -e "$f" ]] || { echo "Manquant: $f" >&2; exit 1; }
done

rm -f opencode.json
ln -s "opencode-${target}.json" opencode.json
rm -f agents
ln -s "agents-${target}" agents

echo "Config active: ${target}"
echo "  opencode.json -> $(readlink opencode.json)"
echo "  agents -> $(readlink agents)"