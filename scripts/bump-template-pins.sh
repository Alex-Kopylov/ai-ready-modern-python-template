#!/usr/bin/env bash
# Bumps the tool pins in template/mise.toml.jinja to their latest releases.
# The Jinja source is not TOML mise can read, so this renders the default
# project (every optional tool enabled), runs `mise upgrade --bump` there, and
# copies each new version back onto the matching template line.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template_mise="${repo_root}/template/mise.toml.jinja"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
project_dir="${tmp_dir}/project"

mise exec -- copier copy --quiet --defaults --vcs-ref=HEAD "$repo_root" "$project_dir"
# Install the current pins first: npm tools resolve their node dependency from
# the installed toolset, so a fresh runner fails when node bumps too.
(cd "$project_dir" && mise trust --quiet && mise install && mise upgrade --bump --local &&
  mise run sync-docker-uv)

while IFS= read -r pin; do
  tool="${pin%% = *}"
  sed -i "s|^${tool} = \".*\"\$|${pin}|" "$template_mise"
done < <(sed -n '/^\[tools\]/,/^\[/{/^[^#[].* = "/p}' "${project_dir}/mise.toml")

# The Dockerfile's uv image and copier.yml's Python patch table follow the
# new uv pin.
from_line="$(grep '^FROM ghcr.io/astral-sh/uv:' "${project_dir}/Dockerfile")"
sed -i "s|^FROM ghcr.io/astral-sh/uv:.*|${from_line}|" "${repo_root}/template/Dockerfile.jinja"
"${repo_root}/scripts/sync-python-pins.sh" >/dev/null
