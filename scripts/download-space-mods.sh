#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-./client-mods}"
GAME_VERSION="${GAME_VERSION:-1.21.1}"
LOADER="${LOADER:-neoforge}"

mkdir -p "${TARGET_DIR}"

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
  local existing=()

  shopt -s nullglob
  existing=("${TARGET_DIR}"/${match_glob})
  shopt -u nullglob

  if ((${#existing[@]} > 0)); then
    printf 'Already present: %s\n' "${existing[0]}"
    return 0
  fi

  local metadata_file
  metadata_file="$(mktemp)"
  fetch_modrinth_file "$project" > "$metadata_file"
  local url
  local filename
  local version_name
  local version_number
  url="$(sed -n '1p' "$metadata_file")"
  filename="$(sed -n '2p' "$metadata_file")"
  version_name="$(sed -n '3p' "$metadata_file")"
  version_number="$(sed -n '4p' "$metadata_file")"
  rm -f "$metadata_file"
  local output="${TARGET_DIR}/${filename}"

  printf 'Downloading %s %s (%s)\n' "$project" "$version_number" "$version_name"
  curl -fL --retry 5 --retry-delay 2 -o "$output" "$url"
  printf '%s\t%s\t%s\t%s\n' "$project" "$version_number" "$filename" "$url" >> "${TARGET_DIR}/space-mods.lock"
}

: > "${TARGET_DIR}/space-mods.lock"
download_project "stellaris" "stellaris*.jar"
download_project "architectury-api" "architectury*.jar"
download_project "potentials" "potentials*.jar"

printf 'Downloaded space mods into %s\n' "$TARGET_DIR"
