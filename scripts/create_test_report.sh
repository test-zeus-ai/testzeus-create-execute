#!/bin/bash
set -euo pipefail
shopt -s nullglob

echo "Creating tests from ./tests directory..."
SEED_ID=$(date +%s)
ALL_TEST_IDS=""

create_test_record() {
  local test_name="$1"
  local feature_file="$2"
  local test_env_id="$3"
  local hypermind_ids="$4"
  local test_data_ids="${5:-}"
  local -a create_cmd
  create_cmd=(
    testzeus --format json tests create
    --name "${test_name}-${SEED_ID}"
    --feature-file "$feature_file"
    --status "ready"
  )
  if [[ -n "$test_data_ids" ]]; then
    create_cmd+=(--data "$test_data_ids")
  fi
  if [[ -n "$test_env_id" ]]; then
    create_cmd+=(--environment "$test_env_id")
  fi
  if [[ -n "$hypermind_ids" ]]; then
    create_cmd+=(--hypermind-code-blocks "$hypermind_ids")
  fi
  "${create_cmd[@]}" | jq -r '.id'
}

test_dirs=(./tests/test-*)
if (( ${#test_dirs[@]} == 0 )); then
  echo "❌ No ./tests/test-* directories found; aborting."
  exit 1
fi

for test_dir in "${test_dirs[@]}"; do
  TEST_NAME=$(basename "$test_dir")

  mapfile -t feature_files < <(find "$test_dir" -maxdepth 1 -type f -name '*.feature' | sort)
  if (( ${#feature_files[@]} == 0 )); then
    echo "❌ Skipping $TEST_NAME — no .feature file found."
    continue
  fi
  if (( ${#feature_files[@]} > 1 )); then
    echo "❌ Aborting $TEST_NAME — expected exactly one .feature file, found ${#feature_files[@]}:"
    printf '  - %s\n' "${feature_files[@]}"
    exit 1
  fi
  FEATURE_FILE="${feature_files[0]}"

  # Process per-test environment if it exists
  TEST_ENV_ID=""
  TEST_ENV_DIR="$test_dir/environment"

  if [[ -d "$TEST_ENV_DIR" ]]; then
    ENV_DATA_FILE="$TEST_ENV_DIR/data.txt"

    if [[ -f "$ENV_DATA_FILE" ]]; then
      echo "🌍 Creating environment for $TEST_NAME..."

      TEST_ENV_ID=$(testzeus --format json environments create --name "${TEST_NAME}-env-${SEED_ID}" --data-file "$ENV_DATA_FILE" | jq -r '.id')
      echo "✅ Created environment ID: $TEST_ENV_ID"

      EXTRA_JSON_FILE="$TEST_ENV_DIR/extra.json"
      if [[ -f "$EXTRA_JSON_FILE" ]]; then
        echo "📋 Processing extra.json for connected environments..."
        CONNECTED_ENV_ID=$(jq -r '.connected_env // empty' "$EXTRA_JSON_FILE")

        if [[ -n "$CONNECTED_ENV_ID" ]]; then
          echo "🔗 Linking connected environment: $CONNECTED_ENV_ID"
          testzeus --format json environments update "$TEST_ENV_ID" --connected-environments "$CONNECTED_ENV_ID" > /dev/null
          echo "✅ Connected environment linked successfully"
        fi
      fi

      ENV_ASSETS_DIR="$TEST_ENV_DIR/assets"
      if [[ -d "$ENV_ASSETS_DIR" ]]; then
        echo "📂 Uploading environment assets..."
        for file in "$ENV_ASSETS_DIR"/*; do
          if [[ -f "$file" ]]; then
            echo "📎 Uploading environment asset: $file"
            testzeus --format json environments upload-file "$TEST_ENV_ID" "$file" | jq -r '.supporting_data_files[0]'
          fi
        done
      fi
    else
      echo "⚠️ Warning: environment directory exists for $TEST_NAME but no data.txt found"
    fi
  fi

  HYPERMIND_IDS=""
  HYPERMIND_DIR="$test_dir/hypermind"

  if [[ -d "$HYPERMIND_DIR" ]]; then
    hypermind_files=("$HYPERMIND_DIR"/*)
    has_hypermind_file=false
    for hypermind_file in "${hypermind_files[@]}"; do
      if [[ -f "$hypermind_file" ]]; then
        has_hypermind_file=true
        break
      fi
    done

    if [[ "$has_hypermind_file" == true ]]; then
      echo "🧠 Processing Hypermind code blocks for $TEST_NAME..."

      HYPERMIND_NAME="${TEST_NAME}-${SEED_ID}"
      echo "📝 Creating Hypermind code block: $HYPERMIND_NAME"

      hypermind_cmd=(
        testzeus --format json hypermind-code-blocks create
        --name "$HYPERMIND_NAME"
        --status "ready"
      )
      for hypermind_file in "${hypermind_files[@]}"; do
        if [[ -f "$hypermind_file" ]]; then
          hypermind_cmd+=(--file "$hypermind_file")
        fi
      done

      HYPERMIND_IDS=$("${hypermind_cmd[@]}" | jq -r '.id')
      echo "✅ Created Hypermind code block ID: $HYPERMIND_IDS"
    fi
  fi

  DATA_PARENT_DIR="$test_dir/test-data"

  # If no test-data directory, create a test with the feature file only
  if [[ ! -d "$DATA_PARENT_DIR" ]]; then
    echo "ℹ️ No test-data directory found for $TEST_NAME — creating test with feature file only."

    echo "🧪 Creating test for $TEST_NAME (feature file only)..."
    TEST_ID="$(create_test_record "$TEST_NAME" "$FEATURE_FILE" "$TEST_ENV_ID" "$HYPERMIND_IDS")"

    if [[ -z "$ALL_TEST_IDS" ]]; then
      ALL_TEST_IDS="$TEST_ID"
    else
      ALL_TEST_IDS="$ALL_TEST_IDS,$TEST_ID"
    fi

    echo "✅ Test created: ${TEST_NAME} (ID: $TEST_ID)"
    echo "--------------------------------------------"
    continue
  fi

  TEST_DATA_IDS=""

  for case_dir in "$DATA_PARENT_DIR"/*; do
    if [[ ! -d "$case_dir" ]]; then
      continue
    fi

    CASE_NAME=$(basename "$case_dir")
    DATA_FILE="$case_dir/data.txt"

    if [[ ! -f "$DATA_FILE" ]]; then
      echo "❌ Skipping $CASE_NAME — no data.txt found."
      continue
    fi

    echo "📄 Creating test-data for $TEST_NAME/$CASE_NAME..."
    TEST_DATA_ID=$(testzeus --format json test-data create --name "${TEST_NAME}-${CASE_NAME}-${SEED_ID}" --data-file "$DATA_FILE" | jq -r '.id')

    echo "✅ Created test-data ID: $TEST_DATA_ID"

    if [[ -z "$TEST_DATA_IDS" ]]; then
      TEST_DATA_IDS="$TEST_DATA_ID"
    else
      TEST_DATA_IDS="$TEST_DATA_IDS,$TEST_DATA_ID"
    fi

    ASSETS_DIR="$case_dir/assets"

    if [[ -d "$ASSETS_DIR" ]]; then
      echo "📂 Uploading test-data assets..."
      for file in "$ASSETS_DIR"/*; do
        if [[ -f "$file" ]]; then
          echo "📎 Uploading test-data asset: $file"
          testzeus --format json test-data upload-file "$TEST_DATA_ID" "$file" | jq -r '.supporting_data_files[0]'
        fi
      done
    fi
  done

  if [[ -n "$TEST_DATA_IDS" ]]; then
    echo "🧪 Creating test for $TEST_NAME with test-data: $TEST_DATA_IDS..."
    TEST_ID="$(create_test_record "$TEST_NAME" "$FEATURE_FILE" "$TEST_ENV_ID" "$HYPERMIND_IDS" "$TEST_DATA_IDS")"

    if [[ -z "$ALL_TEST_IDS" ]]; then
      ALL_TEST_IDS="$TEST_ID"
    else
      ALL_TEST_IDS="$ALL_TEST_IDS,$TEST_ID"
    fi

    echo "✅ Test created: ${TEST_NAME} (ID: $TEST_ID)"
    echo "--------------------------------------------"
  else
    echo "⚠️ No valid test-data found for $TEST_NAME — skipping test creation"
    echo "--------------------------------------------"
  fi
done

if [[ -z "$ALL_TEST_IDS" ]]; then
  echo "❌ No tests created from ./tests/test-*; aborting."
  exit 1
fi

echo ""
echo "🎉 All tests created successfully!"
echo "Test IDs: $ALL_TEST_IDS"

echo ""
echo "🔄 Updating feature asset references..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/file_name_replacement.sh" "$ALL_TEST_IDS"

mkdir -p downloads
REPORT_PATH="downloads/${REPORT_FILENAME}"

echo ""
echo "Running test-run-group and generating CTRF report..."
# execute-and-monitor requires a tenant-unique name; consumers often pass a fixed
# display name (e.g. platform-test-rig "Smoke action Suite"), so stamp a suffix.
UNIQUE_RUN_NAME="${TEST_RUN_NAME}-$(date +%Y%m%d-%H%M%S)"
# Avoid passing an empty --notification-channels flag (some CLI versions mishandle it).
execute_cmd=(
  testzeus test-run-group execute-and-monitor
  --name "$UNIQUE_RUN_NAME"
  --test-ids "$ALL_TEST_IDS"
  --interval 60
  --filename "$REPORT_FILENAME"
  --output-dir downloads
  --execution-mode "${EXECUTION_MODE:-lenient}"
)
if [[ -n "${NOTIFICATION_CHANNELS}" ]]; then
  execute_cmd+=(--notification-channels "$NOTIFICATION_CHANNELS")
fi

set +e
"${execute_cmd[@]}"
execute_rc=$?
set -e

# CLI downloads as test_report_<id>.json then renames; if rename/exit fails after a
# successful run, normalize to the contracted REPORT_FILENAME path.
if [[ ! -f "$REPORT_PATH" ]]; then
  shopt -s nullglob
  # Prefer the CLI's test_report_*.json rename source; sort for stable pick.
  mapfile -t candidates < <(printf '%s\n' downloads/test_report_*.json downloads/*.json 2>/dev/null | sort -u)
  shopt -u nullglob
  if (( ${#candidates[@]} > 0 )) && [[ -n "${candidates[0]}" ]]; then
    mv -f "${candidates[0]}" "$REPORT_PATH"
    echo "Normalized CTRF report to ${REPORT_PATH}"
  fi
fi

if [[ -f "$REPORT_PATH" ]]; then
  # Keep downloads/ as the canonical artifact path, and mirror to workspace root
  # so existing GitHub consumers (e.g. platform-test-rig) that read REPORT_FILENAME
  # from the checkout root keep working.
  cp -f "$REPORT_PATH" "./${REPORT_FILENAME}"
  if [[ "${execute_rc:-0}" -eq 0 ]]; then
    echo "✅ CTRF report available at ${REPORT_PATH} (and ./${REPORT_FILENAME})"
    exit 0
  fi
  # Do not greenwash strict-mode / CLI failures just because a report was written.
  echo "⚠️ CTRF report available at ${REPORT_PATH}, but execute-and-monitor exited ${execute_rc}"
  exit "${execute_rc}"
fi

echo "❌ execute-and-monitor failed and no CTRF report was produced at ${REPORT_PATH}"
exit "${execute_rc:-1}"
