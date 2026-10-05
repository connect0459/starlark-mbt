#!/usr/bin/env bash
# Verifies that the mooncakes credentials are accepted by the registry without
# publishing anything.
#
# `moon publish --dry-run` still contacts the registry, so this script runs a
# real `moon publish` in a throwaway copy whose version is set to one that is
# already published. The registry authenticates the token first and then
# rejects the duplicate version:
#   401 -> the token is invalid
#   409 -> the token is valid and nothing was published
set -euo pipefail

: "${MOONCAKES_CREDENTIALS:?MOONCAKES_CREDENTIALS is not set}"

moon_home="${MOON_HOME:-$HOME/.moon}"
credentials="$moon_home/credentials.json"
mkdir -p "$moon_home"
trap 'rm -f "$credentials"' EXIT
(umask 077 && printf '%s' "$MOONCAKES_CREDENTIALS" >"$credentials")

if ! jq -e '(.token | type == "string" and length > 0) and (.username | type == "string" and length > 0)' "$credentials" >/dev/null 2>&1; then
  echo "::error::MOONCAKES_CREDENTIALS must be JSON with non-empty \"token\" and \"username\""
  exit 1
fi

module="$(awk -F'"' '/^name[[:space:]]*=/{ print $2; exit }' moon.mod)"
owner="${module%%/*}"
username="$(jq -r '.username' "$credentials")"
if [ "$owner" != "$username" ]; then
  echo "::error::Credentials belong to '$username' but the module is owned by '$owner'"
  exit 1
fi

published="$(moon view "$module" --versions --json | jq -r '[.result[] | select(.yanked == false)][0].version // empty')"
if [ -z "$published" ]; then
  echo "::error::$module has no published version, so the credentials cannot be verified without publishing"
  exit 1
fi
echo "Probing with already published version $module@$published"

probe="$(mktemp -d)"
git archive HEAD | tar -x -C "$probe"
sed -E -i.bak "s/^version[[:space:]]*=.*/version = \"$published\"/" "$probe/moon.mod"
rm -f "$probe/moon.mod.bak"

set +e
output="$(cd "$probe" && moon publish 2>&1)"
status=$?
set -e
echo "$output" | tail -n 5
rm -rf "$probe"

if [ "$status" -eq 0 ]; then
  echo "::error::moon publish unexpectedly succeeded; check the registry for $module@$published"
  exit 1
fi
if echo "$output" | grep -q "Server status: 401"; then
  echo "::error::The registry rejected the credentials (401 Unauthorized)"
  exit 1
fi
if echo "$output" | grep -q "Server status: 409"; then
  echo "Credentials accepted by the registry (409: version already exists, nothing published)"
  exit 0
fi
echo "::error::Unexpected response from the registry"
exit 1
