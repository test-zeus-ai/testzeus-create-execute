#!/bin/bash
# Unit checks for sanitize_entity_name (UIX validateEntityName / VARIABLE_KEY_REGEX).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

REGEX='^[a-z][a-z0-9]*(_[a-z0-9]+)*$'
fail=0

assert_name() {
  local input="$1"
  local expected="$2"
  local actual
  actual="$(sanitize_entity_name "$input")"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL input='$input' expected='$expected' actual='$actual'"
    fail=1
    return
  fi
  if [[ ! "$actual" =~ $REGEX ]]; then
    echo "FAIL input='$input' actual='$actual' does not match $REGEX"
    fail=1
    return
  fi
  echo "OK   '$input' → '$actual'"
}

assert_name "test-file_upload-sf-data-1786354399" "test_file_upload_sf_data_1786354399"
assert_name "test_file_upload_sf_data_1" "test_file_upload_sf_data_1"
assert_name "test-API-api-data-1" "test_api_api_data_1"
assert_name "Test_File_Upload" "test_file_upload"
assert_name "123bad" "n_123bad"
assert_name "---" "entity"
assert_name "ok_name_1" "ok_name_1"
assert_name "test_CPQ_flow_add_product_env_99" "test_cpq_flow_add_product_env_99"

if (( fail != 0 )); then
  echo "sanitize_entity_name checks failed"
  exit 1
fi

echo "All sanitize_entity_name checks passed"
