#!/usr/bin/env bash
# Entry point for the cross-distribution Linux AI development setup.
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MODULES=(
  00-bootstrap.sh
  05-packages.sh
  10-system-packages.sh
  15-vscode.sh
  20-miniforge.sh
  25-ai-environments.sh
  30-web-codex.sh
  35-containers.sh
  40-desktop-finish.sh
)
for name in "${MODULES[@]}"; do
  module="$SCRIPT_DIR/lib/$name"
  [[ -r "$module" ]] || { echo "Missing installer module: $module" >&2; exit 1; }
  # shellcheck source=/dev/null
  source "$module"
done
