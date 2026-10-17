#!/usr/bin/env bash
# connect-publish-async.sh -- publish an app to Posit Connect from its COMMITTED
# manifest.json, using plain curl calls. No rsconnect on the runner.
#
# Adapted from timothyfraser/fastapi-connect-demo (MIT).
set -euo pipefail

: "${CONNECT_SERVER:?CONNECT_SERVER is required (add it as a repo secret)}"
: "${CONNECT_API_KEY:?CONNECT_API_KEY is required (add it as a repo secret)}"
: "${BUNDLE_DIR:?BUNDLE_DIR is required}"
: "${CONTENT_NAME:?CONTENT_NAME is required}"
CONTENT_TITLE="${CONTENT_TITLE:-$CONTENT_NAME}"
CONTENT_GUID="${CONTENT_GUID:-}"
POLL_BUDGET_SECONDS="${POLL_BUDGET_SECONDS:-120}"

SERVER="${CONNECT_SERVER%/}"
AUTH=(-H "Authorization: Key ${CONNECT_API_KEY}")
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

fail() { echo "::error::$*" >&2; exit 1; }
emit() { if [ -n "${GITHUB_OUTPUT:-}" ]; then printf '%s\n' "$1" >> "$GITHUB_OUTPUT"; fi; }

command -v jq >/dev/null || fail "jq is required"
[ -f "${BUNDLE_DIR}/manifest.json" ] \
  || fail "no manifest.json in '${BUNDLE_DIR}'. Write it on YOUR machine and commit it."

# Connect content names allow only letters, digits, '-' and '_' (max 64).
CONTENT_NAME=$(printf '%s' "$CONTENT_NAME" | tr -c 'A-Za-z0-9_-' '-' | cut -c1-64)

# ------------------------------------------------- 0. find or create content --
if [ -z "$CONTENT_GUID" ]; then
  Q_BODY="${WORKDIR}/find.json"
  Q_CODE=$(curl -sS -o "$Q_BODY" -w '%{http_code}' "${AUTH[@]}" \
    "${SERVER}/__api__/v1/content?name=${CONTENT_NAME}") \
    || fail "could not reach CONNECT_SERVER. Is the secret a full https:// URL?"
  case "$Q_CODE" in
    200) ;;
    401|403) fail "Connect said HTTP ${Q_CODE}: the CONNECT_API_KEY secret is wrong or expired." ;;
    *) fail "looking up content '${CONTENT_NAME}' returned HTTP ${Q_CODE}: $(head -c 300 "$Q_BODY")" ;;
  esac
  CONTENT_GUID=$(jq -r '.[0].guid // empty' "$Q_BODY" | tr -d '\r')
  if [ -z "$CONTENT_GUID" ]; then
    echo "No content named '${CONTENT_NAME}' yet -- creating it (first deploy)."
    C_BODY="${WORKDIR}/create.json"
    C_CODE=$(curl -sS -o "$C_BODY" -w '%{http_code}' "${AUTH[@]}" \
      -X POST "${SERVER}/__api__/v1/content" -H "Content-Type: application/json" \
      -d "$(jq -n --arg n "$CONTENT_NAME" --arg t "$CONTENT_TITLE" '{name: $n, title: $t, access_type: "all"}')")
    [ "$C_CODE" = "200" ] || [ "$C_CODE" = "201" ] \
      || fail "creating content failed (HTTP ${C_CODE}): $(head -c 300 "$C_BODY"). A 409 means another user already owns that name: change CONTENT_NAME."
    CONTENT_GUID=$(jq -r '.guid' "$C_BODY" | tr -d '\r')
  fi
fi
[ -n "$CONTENT_GUID" ] && [ "$CONTENT_GUID" != "null" ] || fail "no content guid"

# Ensure public access (all)
curl -sS -o /dev/null "${AUTH[@]}" -X PATCH "${SERVER}/__api__/v1/content/${CONTENT_GUID}" \
  -H "Content-Type: application/json" -d '{"access_type": "all"}' || true

T_INFO="${WORKDIR}/content.json"
I_CODE=$(curl -sS -o "$T_INFO" -w '%{http_code}' "${AUTH[@]}" \
  "${SERVER}/__api__/v1/content/${CONTENT_GUID}")
[ "$I_CODE" = "200" ] || fail "content ${CONTENT_GUID} returned HTTP ${I_CODE} (does this key own it?)"
CONTENT_URL=$(jq -r '.content_url' "$T_INFO" | tr -d '\r')
echo "target: '$(jq -r '.title // .name' "$T_INFO" | tr -d '\r')'  guid=${CONTENT_GUID}"
emit "content_guid=${CONTENT_GUID}"
emit "content_url=${CONTENT_URL}"

# ---------------------------------------------------------------- 1. bundle --
mapfile -t FILES < <(jq -r '.files | keys[]' "${BUNDLE_DIR}/manifest.json" | tr -d '\r')
[ "${#FILES[@]}" -gt 0 ] || fail "manifest.json lists no files"
MISSING=0
for f in "${FILES[@]}"; do
  if [ ! -f "${BUNDLE_DIR}/${f}" ]; then
    echo "::error::manifest.json lists '${f}' but it is not in ${BUNDLE_DIR}" >&2
    MISSING=1
  fi
done
[ "$MISSING" -eq 0 ] || fail "stale manifest. Re-write it on your machine and commit it."

TARBALL="${WORKDIR}/bundle.tar.gz"
tar -czf "$TARBALL" -C "$BUNDLE_DIR" manifest.json "${FILES[@]}"
echo "bundle: ${#FILES[@]} files + manifest.json ($(wc -c < "$TARBALL") bytes)"

# ---------------------------------------------------------------- 2. upload --
UP_BODY="${WORKDIR}/upload.json"
UP_CODE=$(curl -sS -o "$UP_BODY" -w '%{http_code}' "${AUTH[@]}" \
  -X POST "${SERVER}/__api__/v1/content/${CONTENT_GUID}/bundles" \
  -H "Content-Type: application/gzip" --data-binary @"$TARBALL")
[ "$UP_CODE" = "200" ] || [ "$UP_CODE" = "201" ] \
  || fail "bundle upload failed (HTTP ${UP_CODE}): $(head -c 300 "$UP_BODY")"
BUNDLE_ID=$(jq -r '.id' "$UP_BODY" | tr -d '\r')
[ -n "$BUNDLE_ID" ] && [ "$BUNDLE_ID" != "null" ] || fail "no bundle id in upload response"
echo "uploaded bundle id=${BUNDLE_ID}"

# ---------------------------------------------------------------- 3. deploy --
DEP_BODY="${WORKDIR}/deploy.json"
DEP_CODE=$(curl -sS -o "$DEP_BODY" -w '%{http_code}' "${AUTH[@]}" \
  -X POST "${SERVER}/__api__/v1/content/${CONTENT_GUID}/deploy" \
  -H "Content-Type: application/json" -d "{\"bundle_id\": \"${BUNDLE_ID}\"}")
[ "$DEP_CODE" = "200" ] || [ "$DEP_CODE" = "202" ] \
  || fail "deploy request failed (HTTP ${DEP_CODE}): $(head -c 300 "$DEP_BODY")"
TASK_ID=$(jq -r '.task_id' "$DEP_BODY" | tr -d '\r')
[ -n "$TASK_ID" ] && [ "$TASK_ID" != "null" ] || fail "no task_id in deploy response"
echo "deploy task started: ${TASK_ID}"
emit "task_id=${TASK_ID}"

# ----------------------------------------------- 4. bounded watch, then detach
DEADLINE=$(( $(date +%s) + POLL_BUDGET_SECONDS ))
FIRST=0
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  T_BODY="${WORKDIR}/task.json"
  T_CODE=$(curl -sS -o "$T_BODY" -w '%{http_code}' "${AUTH[@]}" \
    "${SERVER}/__api__/v1/tasks/${TASK_ID}?wait=5&first=${FIRST}") || T_CODE=000
  if [ "$T_CODE" != "200" ]; then
    echo "task poll HTTP ${T_CODE} (transient?) -- retrying" >&2
    sleep 5
    continue
  fi
  jq -r '.output[]?' "$T_BODY" | sed 's/^/   connect> /'
  FIRST=$(jq -r '.last // 0' "$T_BODY" | tr -d '\r')
  if [ "$(jq -r '.finished' "$T_BODY" | tr -d '\r')" = "true" ]; then
    CODE=$(jq -r '.code' "$T_BODY" | tr -d '\r')
    if [ "$CODE" = "0" ]; then
      echo "deploy finished successfully."
      emit "deploy_status=succeeded"
      exit 0
    fi
    fail "Connect's deploy FAILED (code=${CODE}): $(jq -r '.error // "read the connect> lines above"' "$T_BODY")"
  fi
done

echo "Still building on Connect after ${POLL_BUDGET_SECONDS}s -- detaching (not a failure)."
echo "The next step checks whether the app actually answers."
emit "deploy_status=detached"
exit 0

