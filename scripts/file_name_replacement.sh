#!/bin/bash
set -e

# Script to replace asset file references in test feature text with actual supporting_data_files
# Usage: ./file_replacement.sh <comma-separated-test-ids>
# Example: ./file_replacement.sh "test1,test2,test3"

echo "🔄 Starting feature asset replacement process..."

# Check if test IDs are provided
if [[ -z "$1" ]]; then
  echo "❌ Error: No test IDs provided"
  echo "Usage: $0 <comma-separated-test-ids>"
  exit 1
fi

ALL_TEST_IDS="$1"

# Convert comma-separated string to array
IFS=',' read -ra TEST_IDS_ARRAY <<< "$ALL_TEST_IDS"

# Function to extract file references from feature text (files inside square brackets)
# Handles: ["filename.ext"], ['filename.ext'], [filename.ext], ["filename.ext] (missing closing quote)
extract_file_references() {
  local feature_text="$1"
  # Match patterns:
  # - ["filename.ext"] or ['filename.ext'] (quoted)
  # - [filename.ext] (unquoted)
  # - ["filename.ext] or ['filename.ext] (missing closing quote)
  echo "$feature_text" | grep -oE '\[["'"'"']?[^]"'"'"']+["'"'"']?\]' | sed -E 's/\[["'"'"']?([^]"'"'"']+)["'"'"']?\]/\1/g' || true
}

# Function to replace file reference in feature text
replace_file_reference() {
  local feature_text="$1"
  local old_file="$2"
  local new_file="$3"
  
  # Replace all possible patterns:
  # ["old_file"] -> ["new_file"]
  # ['old_file'] -> ["new_file"]
  # [old_file] -> ["new_file"]
  # ["old_file] -> ["new_file"] (missing closing quote)
  # ['old_file] -> ["new_file"] (missing closing quote)
  
  local updated_text="$feature_text"
  
  # Handle quoted patterns (both single and double quotes)
  updated_text=$(echo "$updated_text" | sed "s/\[\"$old_file\"\]/[\"$new_file\"]/g")
  updated_text=$(echo "$updated_text" | sed "s/\['$old_file'\]/[\"$new_file\"]/g")
  
  # Handle unquoted patterns
  updated_text=$(echo "$updated_text" | sed "s/\[$old_file\]/[\"$new_file\"]/g")
  
  # Handle missing closing quote patterns
  updated_text=$(echo "$updated_text" | sed "s/\[\"$old_file\]/[\"$new_file\"]/g")
  updated_text=$(echo "$updated_text" | sed "s/\['$old_file\]/[\"$new_file\"]/g")
  
  echo "$updated_text"
}

# Function to get supporting files from test-data
get_test_data_files() {
  local test_data_id="$1"
  echo "  📦 Fetching supporting files for test-data: $test_data_id" >&2
  
  local test_data_json=$(testzeus --format json test-data get "$test_data_id" 2>/dev/null)
  
  if [[ -z "$test_data_json" ]]; then
    echo "  ⚠️  Warning: Could not fetch test-data $test_data_id" >&2
    echo ""
    return
  fi
  
  local files=$(echo "$test_data_json" | jq -r '.supporting_data_files[]?' 2>/dev/null || echo "")
  echo "$files"
}

# Function to get supporting files from environment
get_environment_files() {
  local env_id="$1"
  echo "  🌍 Fetching supporting files for environment: $env_id" >&2
  
  local env_json=$(testzeus --format json environment get "$env_id" 2>/dev/null)
  
  if [[ -z "$env_json" ]]; then
    echo "  ⚠️  Warning: Could not fetch environment $env_id" >&2
    echo ""
    return
  fi
  
  local files=$(echo "$env_json" | jq -r '.supporting_data_files[]?' 2>/dev/null || echo "")
  echo "$files"
}

# Function to find best matching file from supporting files
find_best_match() {
  local reference_file="$1"
  shift
  local supporting_files=("$@")
  
  echo "    🔍 Looking for match for: $reference_file" >&2
  echo "    📁 Available files: ${supporting_files[*]}" >&2
  
  # First try exact match
  for file in "${supporting_files[@]}"; do
    if [[ "$file" == "$reference_file" ]]; then
      echo "    ✅ Exact match found: $file" >&2
      echo "$file"
      return
    fi
  done
  
  # Try case-insensitive match
  local ref_lower=$(echo "$reference_file" | tr '[:upper:]' '[:lower:]')
  for file in "${supporting_files[@]}"; do
    local file_lower=$(echo "$file" | tr '[:upper:]' '[:lower:]')
    if [[ "$file_lower" == "$ref_lower" ]]; then
      echo "    ✅ Case-insensitive match found: $file" >&2
      echo "$file"
      return
    fi
  done
  
  # Try partial match (filename without extension)
  local ref_base=$(basename "$reference_file" | sed 's/\.[^.]*$//')
  local ref_ext="${reference_file##*.}"
  
  for file in "${supporting_files[@]}"; do
    local file_base=$(basename "$file" | sed 's/\.[^.]*$//')
    local file_ext="${file##*.}"
    
    # Match by base name and extension
    if [[ "$file_base" == "$ref_base" && "$file_ext" == "$ref_ext" ]]; then
      echo "    ✅ Base name + extension match found: $file" >&2
      echo "$file"
      return
    fi
  done
  
  # Try matching by extension only
  for file in "${supporting_files[@]}"; do
    local file_ext="${file##*.}"
    if [[ "$file_ext" == "$ref_ext" ]]; then
      echo "    ✅ Extension match found: $file" >&2
      echo "$file"
      return
    fi
  done
  
  # Try matching original filename pattern in the supporting file name
  for file in "${supporting_files[@]}"; do
    if [[ "$file" == *"$ref_base"* ]]; then
      echo "    ✅ Partial name match found: $file" >&2
      echo "$file"
      return
    fi
  done
  
  # If no match found, return empty (don't replace)
  echo "    ❌ No suitable match found for: $reference_file" >&2
  echo ""
}

# Process each test ID
for TEST_ID in "${TEST_IDS_ARRAY[@]}"; do
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🧪 Processing test ID: $TEST_ID"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Get test details
  TEST_JSON=$(testzeus --format json tests get "$TEST_ID" 2>/dev/null)
  
  if [[ -z "$TEST_JSON" ]]; then
    echo "❌ Error: Could not fetch test $TEST_ID"
    continue
  fi
  
  # Extract test feature text
  FEATURE_TEXT=$(echo "$TEST_JSON" | jq -r '.test_feature')
  
  if [[ -z "$FEATURE_TEXT" || "$FEATURE_TEXT" == "null" ]]; then
    echo "⚠️  Warning: No feature text found for test $TEST_ID"
    continue
  fi
  
  echo "📄 Original feature text length: ${#FEATURE_TEXT} characters"
  
  # Extract file references from feature text
  FILE_REFERENCES=$(extract_file_references "$FEATURE_TEXT")
  
  if [[ -z "$FILE_REFERENCES" ]]; then
    echo "ℹ️  No file references found in feature text (no files in square brackets)"
    continue
  fi
  
  echo "📋 Found file references:"
  echo "$FILE_REFERENCES" | while read -r ref; do
    if [[ -n "$ref" ]]; then
      echo "   - [$ref]"
    fi
  done
  
  # Collect all supporting files from test-data and environment
  ALL_SUPPORTING_FILES=()
  
  # Get test-data IDs
  TEST_DATA_IDS=$(echo "$TEST_JSON" | jq -r '.test_data[]?' 2>/dev/null || echo "")
  
  if [[ -n "$TEST_DATA_IDS" ]]; then
    echo ""
    echo "📦 Processing test-data..."
    for DATA_ID in $TEST_DATA_IDS; do
      DATA_FILES=$(get_test_data_files "$DATA_ID")
      if [[ -n "$DATA_FILES" ]]; then
        while IFS= read -r file; do
          if [[ -n "$file" ]]; then
            ALL_SUPPORTING_FILES+=("$file")
            echo "  ✓ Found: $file"
          fi
        done <<< "$DATA_FILES"
      fi
    done
  else
    echo "ℹ️  No test-data associated with this test"
  fi
  
  # Get environment ID
  ENV_ID=$(echo "$TEST_JSON" | jq -r '.environment' 2>/dev/null || echo "")
  
  if [[ -n "$ENV_ID" && "$ENV_ID" != "null" && "$ENV_ID" != "" ]]; then
    echo ""
    echo "🌍 Processing environment..."
    ENV_FILES=$(get_environment_files "$ENV_ID")
    if [[ -n "$ENV_FILES" ]]; then
      while IFS= read -r file; do
        if [[ -n "$file" ]]; then
          ALL_SUPPORTING_FILES+=("$file")
          echo "  ✓ Found: $file"
        fi
      done <<< "$ENV_FILES"
    fi
  else
    echo "ℹ️  No environment associated with this test"
  fi
  
  # Check if we have any supporting files
  if [[ ${#ALL_SUPPORTING_FILES[@]} -eq 0 ]]; then
    echo "⚠️  Warning: No supporting files found in test-data or environment"
    continue
  fi
  
  echo ""
  echo "🔄 Starting file reference replacements..."
  
  # Replace file references with supporting files
  UPDATED_FEATURE_TEXT="$FEATURE_TEXT"
  REPLACEMENT_COUNT=0
  USED_FILES=()
  
  # Create array from file references for easier processing
  declare -a FILE_REF_ARRAY
  while IFS= read -r ref; do
    if [[ -n "$ref" ]]; then
      FILE_REF_ARRAY+=("$ref")
    fi
  done <<< "$FILE_REFERENCES"
  
  # Replace each file reference with best matching supporting file
  for old_ref in "${FILE_REF_ARRAY[@]}"; do
    echo "  🔍 Processing reference: [$old_ref]"
    
    # Find the best matching file that hasn't been used yet
    AVAILABLE_FILES=()
    for file in "${ALL_SUPPORTING_FILES[@]}"; do
      # Check if file hasn't been used yet
      file_used=false
      for used_file in "${USED_FILES[@]}"; do
        if [[ "$file" == "$used_file" ]]; then
          file_used=true
          break
        fi
      done
      
      if [[ "$file_used" == false ]]; then
        AVAILABLE_FILES+=("$file")
      fi
    done
    
    # If no available files, use all files (allow reuse)
    if [[ ${#AVAILABLE_FILES[@]} -eq 0 ]]; then
      AVAILABLE_FILES=("${ALL_SUPPORTING_FILES[@]}")
    fi
    
    BEST_MATCH=$(find_best_match "$old_ref" "${AVAILABLE_FILES[@]}")
    
    if [[ -n "$BEST_MATCH" ]]; then
      echo "  🔁 Replacing [$old_ref] → [$BEST_MATCH]"
      UPDATED_FEATURE_TEXT=$(replace_file_reference "$UPDATED_FEATURE_TEXT" "$old_ref" "$BEST_MATCH")
      USED_FILES+=("$BEST_MATCH")
      REPLACEMENT_COUNT=$((REPLACEMENT_COUNT + 1))
    else
      echo "  ⚠️  No matching file found for [$old_ref] - keeping original"
    fi
  done
  
  # Check if any replacements were made
  if [[ "$UPDATED_FEATURE_TEXT" == "$FEATURE_TEXT" ]]; then
    echo "⚠️  No changes made to feature text"
    continue
  fi
  
  echo ""
  echo "✅ Made $REPLACEMENT_COUNT replacement(s)"
  echo "📄 Updated feature text length: ${#UPDATED_FEATURE_TEXT} characters"
  
  # Update the test with the new feature text
  echo ""
  echo "💾 Updating test $TEST_ID..."
  
  # Create a temporary file for the feature text
  TEMP_FEATURE_FILE=$(mktemp)
  echo "$UPDATED_FEATURE_TEXT" > "$TEMP_FEATURE_FILE"
  
  # Update the test using the feature file
  UPDATE_RESULT=$(testzeus --format json tests update "$TEST_ID" --feature-file "$TEMP_FEATURE_FILE" 2>&1)
  UPDATE_EXIT_CODE=$?
  
  # Clean up temp file
  rm -f "$TEMP_FEATURE_FILE"
  
  if [[ $UPDATE_EXIT_CODE -eq 0 ]]; then
    echo "✅ Successfully updated test $TEST_ID"
  else
    echo "❌ Error updating test $TEST_ID:"
    echo "$UPDATE_RESULT"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Feature asset replacement process completed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"