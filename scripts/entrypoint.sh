#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

set_run_defaults

if [[ "${TESTZEUS_SKIP_INSTALL:-}" != "true" ]]; then
  echo "📦 Installing dependencies..."
  pip install --upgrade testzeus-cli python-dateutil
fi

require_bin jq
require_bin testzeus

authenticate_testzeus

chmod +x "$SCRIPT_DIR/create_test_report.sh" "$SCRIPT_DIR/file_name_replacement.sh"
echo "Creating test..."
"$SCRIPT_DIR/create_test_report.sh"
