#!/bin/bash
# Shared helpers for TestZeus create-execute scripts.
# shellcheck shell=bash

# Bump deliberately when validating a new CLI; override via TESTZEUS_CLI_VERSION.
: "${TESTZEUS_CLI_VERSION:=0.0.30}"

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "❌ Required binary not found on PATH: $name"
    exit 1
  fi
}

set_run_defaults() {
  export TEST_RUN_NAME="${TEST_RUN_NAME:-Smoke action suite}"
  export EXECUTION_MODE="${EXECUTION_MODE:-lenient}"
  export REPORT_FILENAME="${REPORT_FILENAME:-ctrf-report.json}"
  export NOTIFICATION_CHANNELS="${NOTIFICATION_CHANNELS:-}"
}

# Prefer TESTZEUS_TOKEN. Fall back to email/password.
# Auth reads secrets from the environment only (see authenticate_ci.py) so they
# never appear on process argv / `ps` listings.
authenticate_testzeus() {
  local script_dir real_testzeus profile
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ -n "${TESTZEUS_TOKEN:-}" ]]; then
    profile="${TESTZEUS_PROFILE:-ci}"
    export TESTZEUS_PROFILE="$profile"
    echo "🔐 Authenticating with TESTZEUS_TOKEN (profile: ${profile})..."
    if ! python3 "${script_dir}/authenticate_ci.py"; then
      echo "❌ Token authentication failed: aborting."
      exit 1
    fi

    real_testzeus="$(command -v testzeus)"
    local shim_dir
    shim_dir="$(mktemp -d "${TMPDIR:-/tmp}/testzeus-shim.XXXXXX")"
    cat >"${shim_dir}/testzeus" <<EOF
#!/bin/bash
exec "${real_testzeus}" --profile "${profile}" "\$@"
EOF
    chmod +x "${shim_dir}/testzeus"
    export PATH="${shim_dir}:${PATH}"
    echo "✅ Authenticated via token (shim profile: ${profile})."
    return 0
  fi

  if [[ -n "${TESTZEUS_EMAIL:-}" && -n "${TESTZEUS_PASSWORD:-}" ]]; then
    export TESTZEUS_PROFILE="${TESTZEUS_PROFILE:-default}"
    echo "🔐 Logging into TestZeus with email/password..."
    if ! python3 "${script_dir}/authenticate_ci.py"; then
      echo "❌ Login failed: aborting."
      exit 1
    fi
    echo "✅ Successfully logged into TestZeus."
    return 0
  fi

  echo "❌ Authentication required. Set TESTZEUS_TOKEN (preferred) or TESTZEUS_EMAIL + TESTZEUS_PASSWORD."
  exit 1
}
