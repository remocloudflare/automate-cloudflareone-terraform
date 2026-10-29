#!/bin/sh
# Idempotently apply a Worker's one-time Durable Object migration out of band.
#
# Why: the Workers API rejects re-sending a bootstrap migration once the script is at
# that tag (10079) and rejects a Durable Object class without it on a fresh script.
# Keeping migrations out of cloudflare_workers_script makes that resource's config
# constant, so plan is empty after every apply (fresh create, update, destroy/recreate).
#
# Behavior: live tag == MIGRATION_TAG -> no-op. No tag -> upload a minimal placeholder
# that exports the class with the migration; Terraform then uploads the real code
# (without migrations) immediately after. Any other tag -> fail loudly.
#
# Required env: ACCOUNT_ID SCRIPT_NAME CLASS_NAME MIGRATION_TAG COMPATIBILITY_DATE
# Token: CF_TOKEN, else CLOUDFLARE_API_TOKEN. Never printed.
set -eu

TOKEN="${CF_TOKEN:-${CLOUDFLARE_API_TOKEN:-}}"
[ -n "$TOKEN" ] || { echo "bootstrap-do-migration: no API token (cloudflare_api_token or CLOUDFLARE_API_TOKEN)" >&2; exit 1; }
for v in ACCOUNT_ID SCRIPT_NAME CLASS_NAME MIGRATION_TAG COMPATIBILITY_DATE; do
  eval "val=\${$v:-}"
  [ -n "$val" ] || { echo "bootstrap-do-migration: $v is required" >&2; exit 1; }
done

API="https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -sS "$API" -H "Authorization: Bearer $TOKEN" -o "$TMP/list.json"
TAG=$(python3 - "$TMP/list.json" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1]))
if not d.get("success"):
    sys.exit("bootstrap-do-migration: list scripts failed: %s" % d.get("errors"))
name = os.environ["SCRIPT_NAME"]
print(next(((s.get("migration_tag") or "") for s in d.get("result") or [] if s.get("id") == name), ""))
PY
)

if [ "$TAG" = "$MIGRATION_TAG" ]; then
  echo "bootstrap-do-migration: $SCRIPT_NAME already at migration tag $MIGRATION_TAG; nothing to do"
  exit 0
fi
if [ -n "$TAG" ]; then
  echo "bootstrap-do-migration: $SCRIPT_NAME is at unexpected migration tag '$TAG' (want '$MIGRATION_TAG'); refusing to change it" >&2
  exit 1
fi

cat > "$TMP/bootstrap.js" <<EOF
import { DurableObject } from 'cloudflare:workers';
export class $CLASS_NAME extends DurableObject {}
export default { fetch() { return new Response('Deploying, try again shortly.', { status: 503 }); } };
EOF
cat > "$TMP/metadata.json" <<EOF
{"main_module":"bootstrap.js","compatibility_date":"$COMPATIBILITY_DATE","bindings":[{"type":"durable_object_namespace","name":"BOOTSTRAP","class_name":"$CLASS_NAME"}],"migrations":{"new_tag":"$MIGRATION_TAG","new_sqlite_classes":["$CLASS_NAME"]}}
EOF

curl -sS -X PUT "$API/$SCRIPT_NAME" -H "Authorization: Bearer $TOKEN" \
  -F "metadata=@$TMP/metadata.json;type=application/json" \
  -F "bootstrap.js=@$TMP/bootstrap.js;type=application/javascript+module" -o "$TMP/put.json"
python3 - "$TMP/put.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if not d.get("success"):
    sys.exit("bootstrap-do-migration: migration upload failed: %s" % d.get("errors"))
print("bootstrap-do-migration: applied Durable Object migration")
PY
