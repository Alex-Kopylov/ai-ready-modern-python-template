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
(cd "$project_dir" && mise trust --quiet && mise upgrade --bump --local)

while IFS= read -r pin; do
  tool="${pin%% = *}"
  sed -i "s|^${tool} = \".*\"\$|${pin}|" "$template_mise"
done < <(sed -n '/^\[tools\]/,/^\[/{/^[^#[].* = "/p}' "${project_dir}/mise.toml")
