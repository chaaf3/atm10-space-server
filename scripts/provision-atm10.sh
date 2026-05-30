#!/usr/bin/env bash
set -euo pipefail

ATM_USER="${ATM_USER:-minecraft}"
ATM_DIR="${ATM_DIR:-/opt/atm10}"
ATM10_VERSION="${ATM10_VERSION:-7.0}"
ATM10_SERVER_ZIP_URL="${ATM10_SERVER_ZIP_URL:-https://edge.forgecdn.net/files/8094/893/ServerFiles-7.0.zip}"
GAME_VERSION="${GAME_VERSION:-1.21.1}"
LOADER="${LOADER:-neoforge}"
JAVA_PACKAGE="${JAVA_PACKAGE:-openjdk-21-jre-headless}"
MEMORY_MIN="${MEMORY_MIN:-8G}"
MEMORY_MAX="${MEMORY_MAX:-12G}"
MOTD="${MOTD:-ATM10 + Stellaris Space Server}"
MINECRAFT_WHITELIST="${MINECRAFT_WHITELIST:-}"
SWAP_SIZE_GB="${SWAP_SIZE_GB:-8}"
ENABLE_COST_SHUTDOWN="${ENABLE_COST_SHUTDOWN:-false}"
COST_SHUTDOWN_THRESHOLD="${COST_SHUTDOWN_THRESHOLD:-60}"
OCI_BUDGET_ID="${OCI_BUDGET_ID:-}"
OCI_REGION="${OCI_REGION:-}"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl unzip python3 iptables-persistent "$JAVA_PACKAGE"

if ! id -u "$ATM_USER" >/dev/null 2>&1; then
  useradd --system --home-dir "$ATM_DIR" --shell /usr/sbin/nologin "$ATM_USER"
fi

mkdir -p "$ATM_DIR" "$ATM_DIR/downloads" "$ATM_DIR/backups" "$ATM_DIR/space-mods"
chown -R "$ATM_USER:$ATM_USER" "$ATM_DIR"

install_server_pack() {
  local marker="$ATM_DIR/.atm10-server-version"
  local zip_path="$ATM_DIR/downloads/ServerFiles-${ATM10_VERSION}.zip"

  if [[ -f "$marker" ]] && [[ "$(cat "$marker")" == "$ATM10_VERSION" ]]; then
    echo "ATM10 server files ${ATM10_VERSION} already installed."
    return 0
  fi

  systemctl stop atm10 >/dev/null 2>&1 || true

  echo "Downloading ATM10 server files ${ATM10_VERSION}..."
  curl -fL --retry 5 --retry-delay 5 -o "$zip_path" "$ATM10_SERVER_ZIP_URL"

  echo "Unpacking ATM10 server files..."
  unzip -q -o "$zip_path" -d "$ATM_DIR"
  chown -R "$ATM_USER:$ATM_USER" "$ATM_DIR"
  echo "$ATM10_VERSION" > "$marker"
}

fetch_modrinth_file() {
  local project="$1"

  python3 - "$project" "$GAME_VERSION" "$LOADER" <<'PY'
import json
import sys
import urllib.parse
import urllib.request

project, game_version, loader = sys.argv[1:]

def load_versions(version):
    params = urllib.parse.urlencode({
        "game_versions": json.dumps([version]),
        "loaders": json.dumps([loader]),
    })
    url = f"https://api.modrinth.com/v2/project/{urllib.parse.quote(project)}/version?{params}"
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "atm10-space-server-setup/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)

versions = load_versions(game_version)
if not versions and game_version == "1.21.1":
    versions = load_versions("1.21")

if not versions:
    raise SystemExit(f"No Modrinth versions found for {project} on {game_version}/{loader}")

preferred = [version for version in versions if version.get("version_type") == "release"] or versions
version = preferred[0]
files = version.get("files") or []
primary = next((file for file in files if file.get("primary")), files[0] if files else None)

if not primary:
    raise SystemExit(f"No downloadable files found for {project}")

print(primary["url"])
print(primary["filename"])
print(version["name"])
print(version.get("version_number", ""))
PY
}

download_project() {
  local project="$1"
  local match_glob="$2"
  local mods_dir="$ATM_DIR/mods"
  local existing=()

  mkdir -p "$mods_dir" "$ATM_DIR/space-mods"

  shopt -s nullglob
  existing=("$mods_dir"/${match_glob})
  shopt -u nullglob

  if ((${#existing[@]} > 0)); then
    printf 'Already present in ATM10 pack, not duplicating: %s\n' "${existing[0]}"
    return 0
  fi

  mapfile -t metadata < <(fetch_modrinth_file "$project")
  local url="${metadata[0]}"
  local filename="${metadata[1]}"
  local version_name="${metadata[2]}"
  local version_number="${metadata[3]}"
  local output="$ATM_DIR/space-mods/$filename"

  printf 'Downloading %s %s (%s)\n' "$project" "$version_number" "$version_name"
  curl -fL --retry 5 --retry-delay 2 -o "$output" "$url"
  cp "$output" "$mods_dir/$filename"
  printf '%s\t%s\t%s\t%s\n' "$project" "$version_number" "$filename" "$url" >> "$ATM_DIR/space-mods.lock.tmp"
}

install_space_mods() {
  : > "$ATM_DIR/space-mods.lock.tmp"
  download_project "stellaris" "stellaris*.jar"
  download_project "architectury-api" "architectury*.jar"
  download_project "potentials" "potentials*.jar"
  mv "$ATM_DIR/space-mods.lock.tmp" "$ATM_DIR/space-mods.lock"
  chown -R "$ATM_USER:$ATM_USER" "$ATM_DIR/mods" "$ATM_DIR/space-mods" "$ATM_DIR/space-mods.lock"
}

write_server_properties() {
  local properties="$ATM_DIR/server.properties"

  touch "$properties"
  python3 - "$properties" "$MOTD" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
motd = sys.argv[2]
desired = {
    "motd": motd,
    "online-mode": "true",
    "white-list": "true",
    "enforce-whitelist": "true",
    "difficulty": "normal",
    "max-players": "10",
    "view-distance": "8",
    "simulation-distance": "6",
    "sync-chunk-writes": "false",
    "max-tick-time": "-1",
    "enable-command-block": "false",
}

lines = path.read_text().splitlines()
seen = set()
output = []

for line in lines:
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "=" not in line:
        output.append(line)
        continue
    key = line.split("=", 1)[0]
    if key in desired:
        output.append(f"{key}={desired[key]}")
        seen.add(key)
    else:
        output.append(line)

for key, value in desired.items():
    if key not in seen:
        output.append(f"{key}={value}")

path.write_text("\n".join(output) + "\n")
PY

  echo "eula=true" > "$ATM_DIR/eula.txt"
  chown "$ATM_USER:$ATM_USER" "$properties" "$ATM_DIR/eula.txt"
}

write_whitelist() {
  python3 - "$ATM_DIR/whitelist.json" "$MINECRAFT_WHITELIST" <<'PY'
from pathlib import Path
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

path = Path(sys.argv[1])
raw_names = sys.argv[2]
names = []
seen = set()

for item in raw_names.replace("\n", ",").split(","):
    name = item.strip()
    if not name:
        continue
    lowered = name.lower()
    if lowered in seen:
        continue
    if not re.fullmatch(r"[A-Za-z0-9_]{3,16}", name):
        raise SystemExit(f"Invalid Minecraft username for whitelist: {name!r}")
    seen.add(lowered)
    names.append(name)

entries = []

for name in names:
    url = "https://api.mojang.com/users/profiles/minecraft/" + urllib.parse.quote(name)
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "atm10-space-server-setup/1.0"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            if response.status == 204:
                raise SystemExit(f"Minecraft username not found for whitelist: {name}")
            profile = json.load(response)
    except urllib.error.HTTPError as exc:
        if exc.code == 204:
            raise SystemExit(f"Minecraft username not found for whitelist: {name}") from exc
        raise

    raw_uuid = profile["id"]
    uuid = f"{raw_uuid[0:8]}-{raw_uuid[8:12]}-{raw_uuid[12:16]}-{raw_uuid[16:20]}-{raw_uuid[20:32]}"
    entries.append({"uuid": uuid, "name": profile["name"]})

path.write_text(json.dumps(entries, indent=2) + "\n")
print(f"Wrote {len(entries)} whitelist entries to {path}")
PY

  chown "$ATM_USER:$ATM_USER" "$ATM_DIR/whitelist.json"
}

write_runtime_files() {
  cat > "$ATM_DIR/user_jvm_args.txt" <<EOF
-Xms${MEMORY_MIN}
-Xmx${MEMORY_MAX}
-XX:+UseG1GC
-XX:+ParallelRefProcEnabled
-XX:MaxGCPauseMillis=200
-XX:+UnlockExperimentalVMOptions
-XX:+DisableExplicitGC
-XX:+AlwaysPreTouch
-Dlog4j2.formatMsgNoLookups=true
EOF

  cat > "$ATM_DIR/run-atm10.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ -x ./startserver.sh ]]; then
  exec ./startserver.sh
fi

if [[ -f ./startserver.sh ]]; then
  exec bash ./startserver.sh
fi

if [[ -x ./run.sh ]]; then
  exec ./run.sh nogui
fi

if [[ -f ./run.sh ]]; then
  exec bash ./run.sh nogui
fi

server_jar="$(find . -maxdepth 2 -type f \( -name 'serverstarter*.jar' -o -name 'neoforge*-server*.jar' -o -name 'forge*-server*.jar' \) | head -n 1)"

if [[ -n "$server_jar" ]]; then
  exec java @user_jvm_args.txt -jar "$server_jar" nogui
fi

echo "No known ATM10 start script or server jar found in $(pwd)" >&2
find . -maxdepth 2 -type f | sort >&2
exit 1
EOF

  chmod +x "$ATM_DIR/run-atm10.sh"
  chown "$ATM_USER:$ATM_USER" "$ATM_DIR/user_jvm_args.txt" "$ATM_DIR/run-atm10.sh"
}

write_systemd_service() {
  cat > /etc/systemd/system/atm10.service <<EOF
[Unit]
Description=All the Mods 10 Space Server
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=${ATM_USER}
Group=${ATM_USER}
WorkingDirectory=${ATM_DIR}
ExecStart=${ATM_DIR}/run-atm10.sh
Restart=on-failure
RestartSec=30
SuccessExitStatus=0 143
TimeoutStartSec=0
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable atm10
}

configure_swap() {
  if [[ "$SWAP_SIZE_GB" == "0" ]]; then
    return 0
  fi

  if [[ ! -f /swapfile ]]; then
    fallocate -l "${SWAP_SIZE_GB}G" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
  fi

  swapon --show=NAME --noheadings | grep -qx /swapfile || swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
}

configure_firewall() {
  iptables -C INPUT -p tcp -m state --state NEW -m tcp --dport 25565 -j ACCEPT 2>/dev/null \
    || iptables -I INPUT 5 -p tcp -m state --state NEW -m tcp --dport 25565 -j ACCEPT

  mkdir -p /etc/iptables
  iptables-save > /etc/iptables/rules.v4
  netfilter-persistent save >/dev/null 2>&1 || true
}

install_cost_shutdown() {
  if [[ "$ENABLE_COST_SHUTDOWN" != "true" ]]; then
    return 0
  fi

  if [[ -z "$OCI_BUDGET_ID" ]]; then
    echo "ENABLE_COST_SHUTDOWN=true but OCI_BUDGET_ID is empty." >&2
    return 1
  fi

  apt-get install -y python3-venv

  if [[ ! -x /opt/oci-cli/bin/oci ]]; then
    python3 -m venv /opt/oci-cli
    /opt/oci-cli/bin/pip install --upgrade pip wheel
    /opt/oci-cli/bin/pip install oci-cli
  fi

  cat > /usr/local/sbin/oci-budget-shutdown.sh <<'EOF'
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
EOF
  chmod 0755 /usr/local/sbin/oci-budget-shutdown.sh

  cat > /etc/atm10-cost-shutdown.env <<EOF
OCI_BUDGET_ID=${OCI_BUDGET_ID}
COST_SHUTDOWN_THRESHOLD=${COST_SHUTDOWN_THRESHOLD}
OCI_REGION=${OCI_REGION}
EOF
  chmod 0600 /etc/atm10-cost-shutdown.env

  cat > /etc/systemd/system/atm10-cost-shutdown.service <<'EOF'
[Unit]
Description=Stop ATM10 server when OCI budget threshold is reached
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/atm10-cost-shutdown.env
ExecStart=/usr/local/sbin/oci-budget-shutdown.sh
EOF

  cat > /etc/systemd/system/atm10-cost-shutdown.timer <<'EOF'
[Unit]
Description=Check OCI budget for ATM10 shutdown threshold

[Timer]
OnBootSec=15min
OnUnitActiveSec=30min
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now atm10-cost-shutdown.timer
}

install_server_pack
install_space_mods
write_server_properties
write_whitelist
write_runtime_files
write_systemd_service
configure_swap
configure_firewall
install_cost_shutdown

systemctl restart atm10
systemctl --no-pager --full status atm10 || true
