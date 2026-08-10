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

  # Process per-test environment if it exists
  TEST_ENV_ID=""
  TEST_ENV_DIR="$test_dir/environment"
  
  if [[ -d "$TEST_ENV_DIR" ]]; then
    ENV_DATA_FILE="$TEST_ENV_DIR/data.txt"
    
    if [[ -f "$ENV_DATA_FILE" ]]; then
      echo "🌍 Creating environment for $TEST_NAME..."
      
      # Create base environment
      TEST_ENV_ID=$(testzeus --format json environments create --name "${TEST_NAME}-env-${SEED_ID}" --data-file "$ENV_DATA_FILE" --status "ready" | jq -r '.id')
      echo "✅ Created environment ID: $TEST_ENV_ID"
      
      # Check for extra.json and handle connected environments
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
      
      # Upload environment assets if they exist
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

  # Process Hypermind code blocks if directory exists
  HYPERMIND_IDS=""
  HYPERMIND_DIR="$test_dir/hypermind"
  
  if [[ -d "$HYPERMIND_DIR" ]]; then
    # Check if there are any files in the directory
    if ls "$HYPERMIND_DIR"/* 1> /dev/null 2>&1; then
      echo "🧠 Processing Hypermind code blocks for $TEST_NAME..."
      
      HYPERMIND_NAME="${TEST_NAME}-${SEED_ID}"
      echo "📝 Creating Hypermind code block: $HYPERMIND_NAME"
      
      # Create single Hypermind code block with all files
      HYPERMIND_CMD="testzeus --format json hypermind-code-blocks create --name \"$HYPERMIND_NAME\" --status \"ready\""
      
      for hypermind_file in "$HYPERMIND_DIR"/*; do
        if [[ -f "$hypermind_file" ]]; then
          HYPERMIND_CMD="$HYPERMIND_CMD --file \"$hypermind_file\""
        fi
      done
      
      HYPERMIND_IDS=$(eval "$HYPERMIND_CMD" | jq -r '.id')
      echo "✅ Created Hypermind code block ID: $HYPERMIND_IDS"
    fi
  fi

  DATA_PARENT_DIR="$test_dir/test-data"

  # If no test-data directory, create a test with the feature file only
  if [[ ! -d "$DATA_PARENT_DIR" ]]; then
    echo "ℹ️ No test-data directory found for $TEST_NAME — creating test with feature file only."
    
    echo "🧪 Creating test for $TEST_NAME (feature file only)..."
    
    # Build test creation command with optional parameters
    CREATE_CMD="testzeus --format json tests create --name \"${TEST_NAME}-${SEED_ID}\" --feature-file \"$FEATURE_FILE\" --status \"ready\""
    
    if [[ -n "$TEST_ENV_ID" ]]; then
      CREATE_CMD="$CREATE_CMD --environment \"$TEST_ENV_ID\""
    fi
    
    if [[ -n "$HYPERMIND_IDS" ]]; then
      CREATE_CMD="$CREATE_CMD --hypermind-code-blocks \"$HYPERMIND_IDS\""
    fi
    
    TEST_ID=$(eval "$CREATE_CMD" | jq -r '.id')

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
    
    # Build test creation command with optional parameters
    CREATE_CMD="testzeus --format json tests create --name \"${TEST_NAME}-${SEED_ID}\" --feature-file \"$FEATURE_FILE\" --data \"$TEST_DATA_IDS\" --status \"ready\""
    
    if [[ -n "$TEST_ENV_ID" ]]; then
      CREATE_CMD="$CREATE_CMD --environment \"$TEST_ENV_ID\""
    fi
    
    if [[ -n "$HYPERMIND_IDS" ]]; then
      CREATE_CMD="$CREATE_CMD --hypermind-code-blocks \"$HYPERMIND_IDS\""
    fi
    
    TEST_ID=$(eval "$CREATE_CMD" | jq -r '.id')

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

# Replace asset file references in feature text with actual supporting files
if [[ -n "$ALL_TEST_IDS" ]]; then
  echo ""
  echo "🔄 Updating feature asset references..."
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  "$SCRIPT_DIR/file_name_replacement.sh" "$ALL_TEST_IDS"
fi

# Run test-run-group and generate CTRF report
echo ""
echo "Running test-run-group and generating CTRF report..."
testzeus test-run-group execute-and-monitor \
  --name "$TEST_RUN_NAME" \
  --test-ids "$ALL_TEST_IDS" \
  --interval 60 \
  --filename "$REPORT_FILENAME" \
  --output-dir '.' \
  --notification-channels "$NOTIFICATION_CHANNELS" \
  --execution-mode "${EXECUTION_MODE:-lenient}"