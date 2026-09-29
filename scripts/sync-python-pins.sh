#!/usr/bin/env bash
# Keeps copier.yml's python_version_pin table in step with the uv that
# template/mise.toml.jinja ships. uv embeds the list of Pythons it can
# download, so the table is a pure function of that pin: for each minor
# >= 3.10, the newest stable CPython patch the pinned uv downloads on every
# mainstream platform. Works offline once that uv is installed.
#
#   scripts/sync-python-pins.sh          rewrite the table in copier.yml
#   scripts/sync-python-pins.sh --check  fail when the table has drifted
#
# Both modes print "<minor> <patch>" lines for the expected table.
set -euo pipefail

mode="${1:-write}"
[[ "$mode" == write || "$mode" == --check ]] || {
  printf 'Usage: %s [--check]\n' "$0" >&2
  exit 2
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
uv_pin="$(
  sed -n 's|^"aqua:astral-sh/uv" = "\(.*\)"$|\1|p' \
    "${repo_root}/template/mise.toml.jinja"
)"
[[ -n "$uv_pin" ]] || {
  printf 'no "aqua:astral-sh/uv" pin in template/mise.toml.jinja\n' >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# mise can fall back to a system uv without saying so; the table must come
# from exactly the pinned one.
mise exec "aqua:astral-sh/uv@${uv_pin}" -- uv --version |
  grep -Fq "uv ${uv_pin} " || {
  printf 'mise did not provide uv %s\n' "$uv_pin" >&2
  exit 1
}
mise exec "aqua:astral-sh/uv@${uv_pin}" -- \
  env -u UV_PYTHON_DOWNLOADS_JSON_URL uv python list \
  --all-versions --only-downloads --all-platforms --all-arches \
  --output-format json >"${tmp_dir}/downloads.json"

mise exec -- uv run --no-project python - \
  "$mode" "$uv_pin" "${repo_root}/copier.yml" "${tmp_dir}/downloads.json" <<'PY'
import json
import re
import sys
from pathlib import Path

mode, uv_pin, copier_yml, downloads_json = sys.argv[1:]
platforms = {  # os, arch, libc: where generated projects are developed and run
    ("linux", "x86_64", "gnu"), ("linux", "aarch64", "gnu"),
    ("macos", "x86_64", "none"), ("macos", "aarch64", "none"),
    ("windows", "x86_64", "none"),
}
builds = {}  # stable cpython version -> platforms it downloads on
for d in json.loads(Path(downloads_json).read_text(encoding="utf-8")):
    if (d["implementation"] == "cpython" and d["variant"] == "default"
            and re.fullmatch(r"3\.\d+\.\d+", d["version"])):
        builds.setdefault(d["version"], set()).add((d["os"], d["arch"], d["libc"]))
expected = {}  # ascending walk: the newest patch per minor wins
for version in sorted(builds, key=lambda v: [int(p) for p in v.split(".")]):
    minor = version.rsplit(".", 1)[0]
    if platforms <= builds[version] and int(minor.split(".")[1]) >= 10:
        expected[minor] = version

path = Path(copier_yml)
text = path.read_text(encoding="utf-8")
table = re.search(
    r"^python_version_pin:\n(?:[ \t].*\n)*?    \{\{ \{\n((?:      .*\n)+)    \}\.get\(",
    text, re.M)
if not table:
    sys.exit("copier.yml: python_version_pin table not found")
actual = dict(re.findall(r"'(3\.\d+)': '(3\.\d+\.\d+)'", table.group(1)))

if actual != expected:
    if mode == "--check":
        sys.exit(
            f"copier.yml python_version_pin disagrees with uv {uv_pin} downloads\n"
            f"  copier.yml: {actual}\n  uv {uv_pin}:    {expected}\n"
            "  run scripts/sync-python-pins.sh to rewrite it")
    entries = [f"'{m}': '{v}'," for m, v in expected.items()]
    lines = "".join(
        "      " + " ".join(entries[i:i + 3]) + "\n" for i in range(0, len(entries), 3))
    path.write_text(text[:table.start(1)] + lines + text[table.end(1):], encoding="utf-8")

for minor, version in expected.items():
    print(minor, version)
PY
