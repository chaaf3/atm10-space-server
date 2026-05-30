#!/usr/bin/env bash
set -euo pipefail

OCI_BIN="${OCI_BIN:-/opt/oci-cli/bin/oci}"
OCI_BUDGET_ID="${OCI_BUDGET_ID:?OCI_BUDGET_ID is required}"
COST_SHUTDOWN_THRESHOLD="${COST_SHUTDOWN_THRESHOLD:-60}"
COST_SHUTDOWN_DRY_RUN="${COST_SHUTDOWN_DRY_RUN:-false}"
METADATA_URL="${METADATA_URL:-http://169.254.169.254/opc/v2/instance}"

log() {
  logger -t atm10-cost-shutdown "$*"
  printf '%s\n' "$*"
}

metadata() {
  curl -fsS -H "Authorization: Bearer Oracle" "${METADATA_URL}/$1"
}

OCI_REGION="${OCI_REGION:-$(metadata region)}"
OCI_INSTANCE_ID="${OCI_INSTANCE_ID:-$(metadata id)}"

if [[ ! -x "$OCI_BIN" ]]; then
  log "OCI CLI not found at ${OCI_BIN}; skipping budget shutdown check."
  exit 1
fi

budget_json="$("$OCI_BIN" budgets budget budget get \
  --budget-id "$OCI_BUDGET_ID" \
  --auth instance_principal \
  --region "$OCI_REGION" \
  --output json)"

decision="$(
  BUDGET_JSON="$budget_json" python3 - "$COST_SHUTDOWN_THRESHOLD" <<'PY'
import json
import os
import sys

threshold = float(sys.argv[1])
payload = json.loads(os.environ["BUDGET_JSON"]).get("data", {})
actual = float(payload.get("actual-spend") or 0)
forecast = float(payload.get("forecasted-spend") or 0)
computed = payload.get("time-spend-computed") or "unknown"
trip = actual >= threshold or forecast >= threshold
reason = "actual" if actual >= threshold else "forecast" if forecast >= threshold else "none"
print(json.dumps({
    "actual": actual,
    "forecast": forecast,
    "computed": computed,
    "reason": reason,
    "trip": trip,
    "threshold": threshold,
}))
PY
)"

trip="$(python3 -c 'import json,sys; print(str(json.load(sys.stdin)["trip"]).lower())' <<<"$decision")"
actual="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["actual"])' <<<"$decision")"
forecast="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["forecast"])' <<<"$decision")"
computed="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["computed"])' <<<"$decision")"
reason="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["reason"])' <<<"$decision")"

if [[ "$trip" != "true" ]]; then
  log "Budget check OK: actual=${actual}, forecast=${forecast}, threshold=${COST_SHUTDOWN_THRESHOLD}, computed=${computed}."
  exit 0
fi

log "Budget shutdown threshold reached by ${reason}: actual=${actual}, forecast=${forecast}, threshold=${COST_SHUTDOWN_THRESHOLD}, computed=${computed}. Stopping instance ${OCI_INSTANCE_ID}."

if [[ "$COST_SHUTDOWN_DRY_RUN" == "true" ]]; then
  log "Dry run enabled; not stopping instance."
  exit 0
fi

"$OCI_BIN" compute instance action \
  --instance-id "$OCI_INSTANCE_ID" \
  --action STOP \
  --auth instance_principal \
  --region "$OCI_REGION"
