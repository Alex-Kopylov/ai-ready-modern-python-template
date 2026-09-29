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
(cd "$project_dir" && mise trust --quiet && mise install && mise upgrade --bump --local)

while IFS= read -r pin; do
  tool="${pin%% = *}"
  sed -i "s|^${tool} = \".*\"\$|${pin}|" "$template_mise"
done < <(sed -n '/^\[tools\]/,/^\[/{/^[^#[].* = "/p}' "${project_dir}/mise.toml")

# copier.yml's Python patch table follows the new uv pin.
"${repo_root}/scripts/sync-python-pins.sh" >/dev/null
