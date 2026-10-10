#!/bin/sh
# Run once from the operator's machine after the first deploy with Umami. Through an SSH tunnel to its
# dashboard, it replaces Umami's default admin password with a random one, kept in
# ~/.config/starbridge/secrets/umami-admin-password, and adds the website whose id the public
# pages send (WEBSITE_ID in web/src/lib/analytics.ts), the launch funnel (#559) and a share link
# for it, served on stats.starbridge.run (deploy/Caddyfile). Safe to run again.
set -eu
host=${STARBRIDGE_HOST:-deploy@starbridge.run}
key=$HOME/.ssh/starbridge_ed25519
port=${UMAMI_PORT:-3001}
pwfile=$HOME/.config/starbridge/secrets/umami-admin-password
cd "$(git rev-parse --show-toplevel)"
id=$(sed -n 's/^export const WEBSITE_ID = "\(.*\)";$/\1/p' web/src/lib/analytics.ts)
[ -n "$id" ] || { echo "no WEBSITE_ID in web/src/lib/analytics.ts" >&2; exit 1; }

if [ -z "${UMAMI_URL:-}" ]; then
  sock=$(mktemp -u)
  ssh -i "$key" -M -S "$sock" -fN -o ExitOnForwardFailure=yes -L "$port:127.0.0.1:3001" "$host"
  trap 'ssh -S "$sock" -O exit "$host" 2>/dev/null' EXIT
fi
url=${UMAMI_URL:-http://127.0.0.1:$port}

login() {
  curl -fsS "$url/api/auth/login" -H 'content-type: application/json' \
    -d "$(jq -n --arg p "$1" '{username: "admin", password: $p}')" | jq -r .token
}
if [ ! -s "$pwfile" ]; then
  token=$(login umami)
  umask 077
  openssl rand -base64 24 > "$pwfile.tmp"
  curl -fsS "$url/api/me/password" -H "authorization: Bearer $token" \
    -H 'content-type: application/json' \
    -d "$(jq -n --arg p "$(cat "$pwfile.tmp")" '{currentPassword: "umami", newPassword: $p}')" \
    >/dev/null
  mv "$pwfile.tmp" "$pwfile"
  echo "admin password changed; it is in $pwfile"
fi
# Changing the password ends the session it was changed in.
token=$(login "$(cat "$pwfile")")

# Umami answers an unknown website with null.
if [ "$(curl -fsS "$url/api/websites/$id" -H "authorization: Bearer $token" | jq -r .id)" = "$id" ]; then
  echo "website $id already there"
else
  curl -fsS "$url/api/websites" -H "authorization: Bearer $token" \
    -H 'content-type: application/json' \
    -d "$(jq -n --arg id "$id" '{id: $id, name: "starbridge.run", domain: "starbridge.run"}')" \
    >/dev/null
  echo "website $id added"
fi

auth() {
  path=$1
  shift
  curl -fsS "$url/api/websites/$id/$path" -H "authorization: Bearer $token" "$@"
}
# The funnels, made or brought up to date. Landing: what the landing page sends
# (web/src/components/Landing.tsx). Launch: a new account's steps, which the server sends as one
# visit per account and day (server/src/funnel.ts); second-device comes in any order, so it is
# counted beside them. The window is a day: Umami's daily salt splits a visit at midnight UTC.
funnel() {
  local name=$1 description=$2 steps=$3 body fid
  body=$(jq -n --arg name "$name" --arg d "$description" --argjson steps "$steps" \
    '{name: $name, description: $d, parameters: {window: 1440, steps: $steps}}')
  fid=$(auth funnels | jq -r --arg name "$name" '[.data[] | select(.name == $name)][0].id // empty')
  auth "funnels${fid:+/$fid}" -H 'content-type: application/json' -d "$body" >/dev/null
  if [ -n "$fid" ]; then echo "funnel $name updated"; else echo "funnel $name added"; fi
}
funnel Landing "Landing view, sign-in click" \
  '[{"type": "path", "value": "/"}, {"type": "event", "value": "sign-in"}]'
funnel Launch "First sign-in, recovery key, first machine, first answer" \
  '[{"type": "event", "value": "first-sign-in"}, {"type": "event", "value": "first-keys"},
    {"type": "event", "value": "first-machine"}, {"type": "event", "value": "first-answer"}]'

# Read-only views for the owner's phone; the link holds the only secret.
views='{overview: true, events: true, funnels: true, journeys: true}'
shares=$(auth shares)
share=$(echo "$shares" | jq -c '[.data[] | select(.name == "Owner")][0] // empty')
if [ -z "$share" ]; then
  share=$(auth shares -H 'content-type: application/json' \
    -d "$(jq -n "{name: \"Owner\", parameters: $views}")")
else
  share=$(curl -fsS "$url/api/share/id/$(echo "$share" | jq -r .id)" \
    -H "authorization: Bearer $token" -H 'content-type: application/json' \
    -d "$(echo "$share" | jq "{name, slug, parameters: $views}")")
fi
slug=$(echo "$share" | jq -r '.slug // empty')
[ -n "$slug" ] || { echo "Umami made no share link: $share" >&2; exit 1; }
echo "share link: https://stats.starbridge.run/share/$slug"
