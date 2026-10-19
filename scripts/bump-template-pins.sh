#!/usr/bin/env bash
# Bumps the tool pins in template/mise.toml.jinja to their latest releases.
# The Jinja source is not TOML mise can read, so this renders the default
# project (every optional tool enabled), runs `mise upgrade --bump` there, and
# copies each new version back onto the matching template line. The Dockerfile
# uv image and the uv_build range then follow the template's uv pin, so
# `docker build` and `uv build` run the same uv that created uv.lock.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template_mise="${repo_root}/template/mise.toml.jinja"
template_dockerfile="${repo_root}/template/Dockerfile.jinja"
template_pyproject="${repo_root}/template/pyproject.toml.jinja"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
project_dir="${tmp_dir}/project"

mise exec -- copier copy --quiet --defaults --vcs-ref=HEAD --skip-tasks "$repo_root" "$project_dir"
# Install the current pins first: npm tools resolve their node dependency from
# the installed toolset, so a fresh runner fails when node bumps too.
(cd "$project_dir" && mise trust --quiet && mise install && mise upgrade --bump --local)

while IFS= read -r pin; do
  tool="${pin%% = *}"
  sed -i "s|^${tool} = \".*\"\$|${pin}|" "$template_mise"
done < <(sed -n '/^\[tools\]/,/^\[/{/^[^#[].* = "/p}' "${project_dir}/mise.toml")

uv_version="$(sed -n 's/^"aqua:astral-sh\/uv" = "\(.*\)"$/\1/p' "$template_mise")"
sed -i "s|^FROM ghcr.io/astral-sh/uv:.*-trixie-slim\$|FROM ghcr.io/astral-sh/uv:${uv_version}-trixie-slim|" \
  "$template_dockerfile"
# uv_build versions track uv; the same range `uv init` would write.
IFS=. read -r uv_major uv_minor _ <<<"$uv_version"
sed -i "s|\"uv_build>=[^\"]*\"|\"uv_build>=${uv_version},<${uv_major}.$((uv_minor + 1)).0\"|" \
  "$template_pyproject"
