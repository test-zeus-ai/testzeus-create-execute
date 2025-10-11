#!/bin/bash
set -e

echo "Creating tests from ./tests directory..."
SEED_ID=$(date +%s)
ALL_TEST_IDS=""
GLOBAL_TEST_ENV_ID=""

# Check for global test-environment directory and create it first
GLOBAL_ENV_DIR="./tests/test-environment"
if [[ -d "$GLOBAL_ENV_DIR" ]]; then
  ENV_DATA_FILE="$GLOBAL_ENV_DIR/data.txt"
  
  if [[ -f "$ENV_DATA_FILE" ]]; then
    echo "🌍 Creating global test-environment..."
    GLOBAL_TEST_ENV_ID=$(testzeus --format json test-environment create --name "global-env-${SEED_ID}" --data-file "$ENV_DATA_FILE" --status "ready" | jq -r '.id')
    
    echo "✅ Created global test-environment ID: $GLOBAL_TEST_ENV_ID"
    
    # Upload global environment assets if they exist
    GLOBAL_ENV_ASSETS_DIR="$GLOBAL_ENV_DIR/assets"
    if [[ -d "$GLOBAL_ENV_ASSETS_DIR" ]]; then
      echo "📂 Uploading global test-environment assets..."
      for file in "$GLOBAL_ENV_ASSETS_DIR"/*; do
        if [[ -f "$file" ]]; then
          echo "📎 Uploading global test-environment asset: $file"
          testzeus --format json test-environment upload-file "$GLOBAL_TEST_ENV_ID" "$file" | jq -r '.supporting_data_files[0]'
        fi
      done
    fi
    echo "--------------------------------------------"
  else
    echo "⚠️ Warning: test-environment directory exists but no data.txt found"
  fi
else
  echo "ℹ️ No global test-environment directory found (optional)"
fi

for test_dir in ./tests/test-*; do
  TEST_NAME=$(basename "$test_dir")
  FEATURE_FILE=$(find "$test_dir" -maxdepth 1 -name '*.feature')

  if [[ ! -f "$FEATURE_FILE" ]]; then
    echo "❌ Skipping $TEST_NAME — no .feature file found."
    continue
  fi

  DATA_PARENT_DIR="$test_dir/test-data"

  # If no test-data directory, create a test with the feature file only
  if [[ ! -d "$DATA_PARENT_DIR" ]]; then
    echo "ℹ️ No test-data directory found for $TEST_NAME — creating test with feature file only."
    
    echo "🧪 Creating test for $TEST_NAME (feature file only)..."
    if [[ -n "$GLOBAL_TEST_ENV_ID" ]]; then
      TEST_ID=$(testzeus --format json tests create --name "${TEST_NAME}-${SEED_ID}" --feature-file "$FEATURE_FILE" --environment "$GLOBAL_TEST_ENV_ID" --status "ready" | jq -r '.id')
    else
      TEST_ID=$(testzeus --format json tests create --name "${TEST_NAME}-${SEED_ID}" --feature-file "$FEATURE_FILE" --status "ready" | jq -r '.id')
    fi

    # Add test ID to comma-separated string
    if [[ -z "$ALL_TEST_IDS" ]]; then
      ALL_TEST_IDS="$TEST_ID"
    else
      ALL_TEST_IDS="$ALL_TEST_IDS,$TEST_ID"
    fi

    echo "✅ Test created: ${TEST_NAME} (ID: $TEST_ID)"
    echo "--------------------------------------------"
    continue
  fi
  
  # If test-data directory exists, create test-data records for each case
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
    TEST_DATA_ID=$(testzeus --format json test-data create --name "${TEST_NAME}-${CASE_NAME}-${SEED_ID}" --data-file "$DATA_FILE" --status "ready" | jq -r '.id')

    echo "✅ Created test-data ID: $TEST_DATA_ID"

    # Collect test-data IDs
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

  # Create single test with all test-data IDs
  if [[ -n "$TEST_DATA_IDS" ]]; then
    echo "🧪 Creating test for $TEST_NAME with test-data: $TEST_DATA_IDS..."
    if [[ -n "$GLOBAL_TEST_ENV_ID" ]]; then
      TEST_ID=$(testzeus --format json tests create --name "${TEST_NAME}-${SEED_ID}" --feature-file "$FEATURE_FILE" --data "$TEST_DATA_IDS" --environment "$GLOBAL_TEST_ENV_ID" --status "ready" | jq -r '.id')
    else
      TEST_ID=$(testzeus --format json tests create --name "${TEST_NAME}-${SEED_ID}" --feature-file "$FEATURE_FILE" --data "$TEST_DATA_IDS" --status "ready" | jq -r '.id')
    fi

    # Add test ID to comma-separated string
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

echo ""
echo "🎉 All tests created successfully!"
echo "Test IDs: $ALL_TEST_IDS"

# Run test-run-group and generate CTRF report
echo ""
echo "Running test-run-group and generating CTRF report..."
testzeus --format json test-run-group execute-and-monitor --name "$TEST_RUN_NAME" --test-ids "$ALL_TEST_IDS" --execution-mode "$EXECUTION_MODE" --interval 30 --filename "$REPORT_FILENAME" 