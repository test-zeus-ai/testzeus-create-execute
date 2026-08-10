#!/bin/bash
# Shared helpers for TestZeus create-execute scripts.
# shellcheck shell=bash

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

# Prefer TESTZEUS_TOKEN (session-exchange). Fall back to email/password login.
# When token auth is used, installs a PATH shim so bare `testzeus` calls use --profile ci.
authenticate_testzeus() {
  local real_testzeus
  real_testzeus="$(command -v testzeus)"

  if [[ -n "${TESTZEUS_TOKEN:-}" ]]; then
    local profile="${TESTZEUS_PROFILE:-ci}"
    echo "🔐 Authenticating with TESTZEUS_TOKEN (profile: ${profile})..."
    if ! testzeus session-exchange --token "$TESTZEUS_TOKEN" --profile "$profile"; then
      echo "❌ Token session-exchange failed: aborting."
      exit 1
    fi

    local shim_dir
    shim_dir="$(mktemp -d "${TMPDIR:-/tmp}/testzeus-shim.XXXXXX")"
    cat >"${shim_dir}/testzeus" <<EOF
#!/bin/bash
exec "${real_testzeus}" --profile "${profile}" "\$@"
EOF
    chmod +x "${shim_dir}/testzeus"
    export PATH="${shim_dir}:${PATH}"
    export TESTZEUS_PROFILE="$profile"
    echo "✅ Authenticated via token (shim profile: ${profile})."
    return 0
  fi

  if [[ -n "${TESTZEUS_EMAIL:-}" && -n "${TESTZEUS_PASSWORD:-}" ]]; then
    echo "🔐 Logging into TestZeus with email/password..."
    local login_output
    login_output="$(testzeus login --email "$TESTZEUS_EMAIL" --password "$TESTZEUS_PASSWORD" 2>&1 || true)"
    if echo "$login_output" | grep -q "Login failed"; then
      echo "❌ Login failed: aborting."
      echo "$login_output"
      exit 1
    fi
    echo "✅ Successfully logged into TestZeus."
    return 0
  fi

  echo "❌ Authentication required. Set TESTZEUS_TOKEN (preferred) or TESTZEUS_EMAIL + TESTZEUS_PASSWORD."
  exit 1
}
