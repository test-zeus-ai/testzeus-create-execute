#!/bin/bash
set -e

echo "Creating tests from ./tests directory..."
SEED_ID=$(date +%s)
ALL_TEST_IDS=""

for test_dir in ./tests/test-*; do
  TEST_NAME=$(basename "$test_dir")
  FEATURE_FILE=$(find "$test_dir" -maxdepth 1 -name '*.feature')

  if [[ ! -f "$FEATURE_FILE" ]]; then
    echo "❌ Skipping $TEST_NAME — no .feature file found."
    continue
  fi

  DATA_PARENT_DIR="$test_dir/test-data"
  ENV_PARENT_DIR="$test_dir/test-environments"

  if [[ ! -d "$DATA_PARENT_DIR" ]]; then
    echo "❌ Skipping $TEST_NAME — test-data dir not found."
    continue
  fi

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

    ASSETS_DIR="$case_dir/assets"

    if [[ -d "$ASSETS_DIR" ]]; then
      echo "📂 Uploading test-data assets..."
      for file in "$ASSETS_DIR"/*; do
        echo "📎 Uploading test-data asset: $file"
        testzeus --format json test-data upload-file "$TEST_DATA_ID" "$file" | jq -r '.supporting_data_files[0]'
      done
    fi

    # Process test-environments directory with same case structure
    TEST_ENV_ID=""
    ENV_CASE_DIR="$ENV_PARENT_DIR/$CASE_NAME"
    
    if [[ -d "$ENV_CASE_DIR" ]]; then
      ENV_DATA_FILE="$ENV_CASE_DIR/data.txt"
      
      if [[ -f "$ENV_DATA_FILE" ]]; then
        echo "🌍 Creating test-environment for $TEST_NAME/$CASE_NAME..."
        TEST_ENV_ID=$(testzeus --format json test-environment create --name "${TEST_NAME}-${CASE_NAME}-env-${SEED_ID}" --data-file "$ENV_DATA_FILE" --status "ready" | jq -r '.id')
        
        echo "✅ Created test-environment ID: $TEST_ENV_ID"
        
        ENV_ASSETS_DIR="$ENV_CASE_DIR/assets"
        
        if [[ -d "$ENV_ASSETS_DIR" ]]; then
          echo "📂 Uploading test-environment assets..."
          for file in "$ENV_ASSETS_DIR"/*; do
            echo "📎 Uploading test-environment asset: $file"
            testzeus --format json test-environment upload-file "$TEST_ENV_ID" "$file" | jq -r '.supporting_data_files[0]'
          done
        fi
      else
        echo "⚠️ Warning: test-environments/$CASE_NAME directory exists but no data.txt found"
      fi
    else
      echo "ℹ️ No test-environment found for $TEST_NAME/$CASE_NAME (optional)"
    fi

    echo "🧪 Creating test for $TEST_NAME / $CASE_NAME..."
    if [[ -n "$TEST_ENV_ID" ]]; then
      TEST_ID=$(testzeus --format json tests create --name "${TEST_NAME}-${SEED_ID}" --feature-file "$FEATURE_FILE" --data "$TEST_DATA_ID" --environment "$TEST_ENV_ID" --status "ready" | jq -r '.id')
    else
      TEST_ID=$(testzeus --format json tests create --name "${TEST_NAME}-${SEED_ID}" --feature-file "$FEATURE_FILE" --data "$TEST_DATA_ID" --status "ready" | jq -r '.id')
    fi

    # Add test ID to comma-separated string
    if [[ -z "$ALL_TEST_IDS" ]]; then
      ALL_TEST_IDS="$TEST_ID"
    else
      ALL_TEST_IDS="$ALL_TEST_IDS,$TEST_ID"
    fi

    echo "✅ Test created: ${TEST_NAME} (ID: $TEST_ID)"
    echo "--------------------------------------------"
  done
done

echo ""
echo "🎉 All tests created successfully!"
echo "Test IDs: $ALL_TEST_IDS"

# Run multiple tests and generate CTRF report
echo ""
echo "Running multiple tests and generating CTRF report..."
testzeus --format json test-runs run-multiple-tests-and-generate-ctrf "$ALL_TEST_IDS" --mode lenient --interval 30 --filename "ctrf-report.json" 