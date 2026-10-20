#!/bin/zsh
# Count the build number up by one before each App Store Connect upload.
#   tools/bump_build.sh          -> 1 becomes 2
#   tools/bump_build.sh 1.1      -> also sets the version (MARKETING_VERSION) to 1.1
set -euo pipefail
cd "$(dirname "$0")/.."
# The map needs the Datafordeler key. Without it no boundaries are drawn, so stop here.
# Never print the key.
SECRETS=App/Config/Secrets.xcconfig
if [[ ! -f "$SECRETS" ]]; then
  echo "Missing $SECRETS. Without the Datafordeler key the build draws no boundaries. See App/Config/." >&2
  exit 1
fi
# The value after "=", trimmed. Never echoed.
key=$(sed -nE 's/^[[:space:]]*DATAFORDELER_API_KEY[[:space:]]*=[[:space:]]*//p' "$SECRETS" | tail -n 1 | sed -E 's/[[:space:]]+$//')
if [[ -z "$key" ]]; then
  echo "DATAFORDELER_API_KEY is empty in $SECRETS. Without the key the build draws no boundaries." >&2
  exit 1
fi
if [[ "$key" == "din-nøgle" ]]; then
  echo "DATAFORDELER_API_KEY in $SECRETS is still the placeholder from Secrets.example.xcconfig. Put the real key there." >&2
  exit 1
fi
unset key
PBX=App/JagtFokus.xcodeproj/project.pbxproj
current=$(grep -m1 -o 'CURRENT_PROJECT_VERSION = [0-9]*' "$PBX" | grep -o '[0-9]*$')
next=$((current + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION = $current;/CURRENT_PROJECT_VERSION = $next;/g" "$PBX"
if [[ $# -ge 1 ]]; then
  sed -i '' -E "s/MARKETING_VERSION = [0-9.]+;/MARKETING_VERSION = $1;/g" "$PBX"
fi
version=$(grep -m1 -o 'MARKETING_VERSION = [0-9.]*' "$PBX" | grep -o '[0-9.]*$')
echo "Version $version ($next)"
