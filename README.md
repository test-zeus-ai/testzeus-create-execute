# TestZeus Run Action

A composite GitHub Action that runs automated tests using TestZeus and generates comprehensive test reports with Slack notifications.

## Features

- 🚀 Automated test execution using TestZeus CLI
- 📊 CTRF (Common Test Report Format) report generation
- 🔄 Support for multiple test cases and data files
- 📎 Asset file upload support
- 🌍 Environment configuration support for different test environments

## Prerequisites

### Repository Structure

Your repository must follow this structure:

```
your-repo/
├── tests/
│   ├── test-login/
│   │   ├── login.feature            # Gherkin feature file
│   │   ├── environment/             # Optional per-test environment
│   │   │   ├── data.txt             # Environment configuration
│   │   │   ├── extra.json           # Optional extra fields (e.g., connected_env)
│   │   │   └── assets/              # Optional environment assets
│   │   │       └── config.json
│   │   ├── hypermind/               # Optional Hypermind code blocks
│   │   │   ├── helper.py            # Code block file 1
│   │   │   └── utils.js             # Code block file 2
│   │   └── test-data/               # Optional test data configurations
│   │       ├── valid-user/          # Test case 1
│   │       │   ├── data.txt         # Test data file
│   │       │   └── assets/          # Optional asset files
│   │       │       └── profile.png
│   │       ├── admin-user/          # Test case 2
│   │       │   ├── data.txt
│   │       │   └── assets/
│   │       └── guest-user/          # Test case 3
│   │           └── data.txt
│   ├── test-checkout/
│   │   ├── checkout.feature
│   │   ├── environment/
│   │   │   ├── data.txt
│   │   │   └── extra.json           # {"connected_env": "env-id-123"}
│   │   └── test-data/
│   │       ├── single-item/         # Multiple cases assigned to one test
│   │       │   └── data.txt
│   │       └── multiple-items/
│   │           └── data.txt
│   └── test-search/
│       ├── search.feature           # Test without test-data (feature file only)
│       └── hypermind/               # Optional Hypermind code blocks
│           └── search-helper.py
└── templates/
    └── ctrf-report.hbs              # Custom CTRF report template (optional)
```

### Required Files

1. **Feature Files**: Each test directory must contain a `.feature` file with Gherkin scenarios
2. **Test Data Files**: Each test case must have a `data.txt` file in the `test-data/case_name/` directory
   - Multiple test-data cases can exist per test (zero, one, or multiple)
   - All test-data cases are assigned to a single test record
3. **Template File**: Create `templates/ctrf-report.hbs` for custom report formatting

### Optional Files

4. **Per-Test Environment**: Each test can have its own `environment/` directory
   - Contains `data.txt` for environment configuration specific to that test
   - Supports `extra.json` for additional fields like connected environments
   - Supports assets in `environment/assets/` directory
   
5. **Hypermind Code Blocks**: Each test can have a `hypermind/` directory
   - Contains code files that will be uploaded as Hypermind code blocks
   - Each file in the directory becomes a separate code block
   - Automatically linked to the test via `--hypermind-code-blocks` parameter

## Test Creation Logic

The action follows this logic for creating tests:

### 1. **Per-Test Environment** (Optional)
- Each test can have its own `environment/` directory with specific configuration
- Environment supports:
  - `data.txt`: Environment configuration data
  - `extra.json`: Additional fields (e.g., `{"connected_env": "env-id-123"}`)
  - `assets/`: Environment-specific files
- The `connected_env` field in `extra.json` is used to link to other environments via the `--connected-environments` parameter

### 2. **Hypermind Code Blocks** (Optional)
- Each test can have a `hypermind/` directory containing code files
- All files in this directory are uploaded as separate Hypermind code blocks
- Code blocks are automatically linked to the test via the `--hypermind-code-blocks` parameter

### 3. **Test Creation Per Directory**
For each `tests/test-*` directory:

- **Feature File Only**: If no `test-data/` directory exists, creates a test with just the feature file
- **With Test Data**: If `test-data/` directory exists:
  1. Creates individual test-data records for each case directory
  2. Collects all test-data IDs from that test
  3. Creates a single test record with ALL test-data IDs assigned
  4. Associates the per-test environment (if exists)
  5. Links Hypermind code blocks (if exist)

### 4. **Example Test Creation**
```
test-login/
├── login.feature
├── environment/
│   ├── data.txt                    # Environment config
│   ├── extra.json                  # {"connected_env": "other-env-id"}
│   └── assets/
│       └── cert.pem
├── hypermind/
│   ├── helper.py                   → Creates Hypermind block: hyper_001
│   └── utils.js                    →   (both files in single block)
└── test-data/
    ├── valid-user/data.txt         → Creates test-data ID: data_001
    ├── admin-user/data.txt         → Creates test-data ID: data_002  
    └── guest-user/data.txt         → Creates test-data ID: data_003

Result: One test record with:
  - data: "data_001,data_002,data_003"
  - environment: env_001 (with connected environment linked)
  - hypermind-code-blocks: "hyper_001" (contains both files)
```

## Setup

### 1. Required Secrets

Configure these secrets in your GitHub repository (`Settings > Secrets and variables > Actions`):

| Secret | Description | Required |
|--------|-------------|----------|
| `TESTZEUS_EMAIL` | Your TestZeus account email | ✅ Yes |
| `TESTZEUS_PASSWORD` | Your TestZeus account password | ✅ Yes |

## Inputs

The action accepts the following input parameters:

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `email` | TestZeus login email | ✅ Yes | - |
| `password` | TestZeus login password | ✅ Yes | - |
| `name` | Name for the test run group | ❌ No | `Smoke action suite` |
| `execution_mode` | Execution mode for the test run (`lenient` or `strict`) | ❌ No | `lenient` |
| `filename` | Filename for the CTRF report output | ❌ No | `ctrf-report.json` |

### Execution Modes

- **`lenient`**: Tests continue running even if some fail, providing a complete overview of all test results
- **`strict`**: Test execution stops at the first failure, useful for fail-fast scenarios

### 2. Create CTRF Report Template (optional)

![Test Results Summary](assets/test-results-summary.png)

Create `templates/ctrf-report.hbs` in your repository and copy this template in to ctrf-report.hbs file. This will render similar to above image:
To create you own custom template then refer the following repos:
- [build custom CTRF template using ctrf-io repo](https://github.com/ctrf-io/github-test-reporter/tree/v1/)
- [Learn how to write handlebar for github actions](https://handlebarsjs.com/guide/)

```handlebars
# 🧪 Test Results Summary

| **Tests** | **Passed** | **Failed** | **Skipped** | **Other** | **Flaky** | **Duration** |
|----------|------------|------------|-------------|-----------|-----------|--------------|
| {{ctrf.summary.tests}} | {{ctrf.summary.passed}} | {{ctrf.summary.failed}} | {{add ctrf.summary.skipped ctrf.summary.pending}} | {{ctrf.summary.other}} | {{countFlaky ctrf.tests}} | {{formatDuration ctrf.summary.start ctrf.summary.stop}} |

---

## 📊 Overview
- ✅ Passed: {{ctrf.summary.passed}} / {{ctrf.summary.tests}}
- ❌ Failed: {{ctrf.summary.failed}}

---

## ⚙️ Execution Details
{{#if ctrf.tool.name}}![tool](https://ctrf.io/assets/github/tools.svg) **Tool**: {{ctrf.tool.name}}{{/if}}  
🔍 **Branch**: `{{github.branchName}}`  
👤 **Triggered by**: `{{github.actor}}`

---

{{#if ctrf.summary.failed}}
## ❌ Failed Tests

{{#each ctrf.tests}}
  {{#if (eq this.status "fail")}}
  ### 🔴 {{this.extra.feature_name}} - {{this.extra.scenario_name}}
  - ⏱️ Duration: {{formatDurationMs this.duration}}
  - 🔗 TestZeus Run: [View](https://prod.testzeus.app/test-runs/{{this.extra.test_run_id}})
  {{#if this.extra.test_data_id}}
  - 🧾 Test Data: [View](https://prod.testzeus.app/test-data/{{this.extra.test_data_id.[0]}})
  {{/if}}

  {{#if (getCollapseLargeReports)}}
  <details>
    <summary><strong>View Steps</strong></summary>

    {{#each this.steps}}
    - {{#if (eq this.status "fail")}}❌{{else if (eq this.status "pass")}}✅{{/if}} {{this.name}}
    {{/each}}

  </details>
  {{else}}
  - **Steps**:
    {{#each this.steps}}
    - {{#if (eq this.status "fail")}}❌{{else if (eq this.status "pass")}}✅{{/if}} {{this.name}}
  {{/each}}
  {{/if}}

  {{/if}}
{{/each}}

{{/if}}
```

## Usage

### Basic Usage

```yaml
name: Run TestZeus Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - name: Run Smoke Suite
      uses: test-zeus-ai/testzeus-create-execute@v1
      with:
        email: ${{ secrets.TESTZEUS_EMAIL }}
        password: ${{ secrets.TESTZEUS_PASSWORD }}
        name: 'CI Smoke Tests'
        execution_mode: 'lenient'
        filename: 'test-results.json'
        
    - name: Publish Test Report
      uses: ctrf-io/github-test-reporter@v1
      with:
        report-path: 'downloads/test-results.json'
        template-path: 'templates/testzeus-report.hbs'
        custom-report: true
      if: always()
```

### Advanced Usage with Custom Triggers

```yaml
name: Smoke Tests

on:
  schedule:
    - cron: '0 */6 * * *'  # Run every 6 hours
  workflow_dispatch:        # Manual trigger
  push:
    branches: [ main, staging ]

jobs:
  smoke-tests:
    runs-on: ubuntu-latest
    
    steps:
    - name: Run Smoke Suite
      uses: test-zeus-ai/testzeus-create-execute@v1
      with:
        email: ${{ secrets.TESTZEUS_EMAIL }}
        password: ${{ secrets.TESTZEUS_PASSWORD }}
        name: 'Scheduled Smoke Tests'
        execution_mode: 'strict'
        
    - name: Publish Test Report
      uses: ctrf-io/github-test-reporter@v1
      with:
        report-path: 'downloads/ctrf-report.json'
        template-path: 'templates/testzeus-report.hbs'
        custom-report: true
      if: always()
```

### Usage with Different Execution Modes

```yaml
name: Multi-Environment Tests

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'staging'
        type: choice
        options:
        - staging
        - production

jobs:
  test-staging:
    if: github.event.inputs.environment == 'staging'
    runs-on: ubuntu-latest
    steps:
    - name: Run Staging Tests
      uses: test-zeus-ai/testzeus-create-execute@v1
      with:
        email: ${{ secrets.TESTZEUS_EMAIL }}
        password: ${{ secrets.TESTZEUS_PASSWORD }}
        name: 'Staging Environment Tests'
        execution_mode: 'lenient'
        
  test-production:
    if: github.event.inputs.environment == 'production'
    runs-on: ubuntu-latest
    steps:
    - name: Run Production Tests
      uses: test-zeus-ai/testzeus-create-execute@v1
      with:
        email: ${{ secrets.TESTZEUS_EMAIL }}
        password: ${{ secrets.TESTZEUS_PASSWORD }}
        name: 'Production Environment Tests'
        execution_mode: 'strict'
```

## Per-Test Environment Configuration

The action supports optional per-test environment configuration, allowing each test to have its own isolated environment settings.

### How Per-Test Environments Work

1. **Test-Specific**: Each test directory can contain its own `environment/` directory
2. **Isolated Configuration**: Each environment is independent and specific to one test
3. **Automatic Association**: The environment is automatically linked to its corresponding test
4. **Optional**: Per-test environments are completely optional - tests work without them

### Environment Structure

```
tests/test-login/
├── login.feature
└── environment/
    ├── data.txt              # Environment configuration
    ├── extra.json            # Optional extra fields
    └── assets/               # Optional environment assets
        ├── api-cert.pem
        └── config.json
```

### extra.json Format

The `extra.json` file allows you to specify additional environment properties:

```json
{
  "connected_env": "environment-id-or-name-123"
}
```

**Fields:**
- `connected_env`: ID or name of another environment to link via the `--connected-environments` parameter
- Additional custom fields can be added as needed

### Example Use Cases

- **Test-Specific URLs**: Different API endpoints for different test suites
- **Authentication Credentials**: Separate credentials per test type
- **Environment Links**: Connect staging/production environments using `connected_env`
- **Feature Flags**: Test-specific feature configurations
- **Database Configs**: Per-test database connection strings
- **Certificates**: Test-specific SSL/TLS certificates

### Connected Environments

Use the `connected_env` field in `extra.json` to link environments together:

```json
{
  "connected_env": "prod-env-id"
}
```

This automatically calls:
```bash
testzeus environments update <env-id> --connected-environments "prod-env-id"
```

### Sample Structure with Multiple Tests

```
tests/
├── test-login/
│   ├── login.feature
│   ├── environment/
│   │   ├── data.txt          # Login-specific environment
│   │   ├── extra.json        # {"connected_env": "base-env-id"}
│   │   └── assets/
│   │       └── auth-cert.pem
│   └── test-data/
│       └── valid-user/
│           └── data.txt
├── test-checkout/
│   ├── checkout.feature
│   ├── environment/
│   │   ├── data.txt          # Checkout-specific environment
│   │   └── assets/
│   │       └── payment-config.json
│   └── test-data/
│       ├── guest-checkout/
│       │   └── data.txt
│       └── member-checkout/
│           └── data.txt
└── test-admin/
    ├── admin.feature
    └── environment/
        ├── data.txt          # Admin-specific environment
        └── extra.json        # {"connected_env": "admin-base-env"}
```

Each test's `environment/data.txt` file can contain:
- Test-specific API endpoints
- Authentication tokens or credentials
- Environment-specific variables
- Configuration parameters unique to that test
- Database connection strings

## Hypermind Code Blocks

The action supports Hypermind code blocks, allowing you to attach reusable code snippets, helper functions, or utilities to your tests.

### How Hypermind Code Blocks Work

1. **Per-Test Directory**: Each test can have a `hypermind/` directory containing code files
2. **Single Code Block**: All files in the directory are uploaded together as one code block
3. **Automatic Linking**: The code block is automatically associated with the test via `--hypermind-code-blocks`
4. **Optional**: Hypermind directories are completely optional - tests work without them

### Hypermind Structure

```
tests/test-login/
├── login.feature
└── hypermind/
    ├── helper.py             # Python helper functions
    ├── utils.js              # JavaScript utilities
    └── config.yaml           # Configuration code
```

### Example Use Cases

- **Helper Functions**: Reusable code for data manipulation or validation
- **API Clients**: Custom API interaction code
- **Data Generators**: Functions to generate test data
- **Utilities**: Common utilities shared across test steps
- **Configuration Code**: Programmatic configuration setup
- **Parsers**: Custom parsers for test data or responses

### How It Works

When the action runs:
1. Scans the `hypermind/` directory for all files
2. Creates a single Hypermind code block with all files using:
   ```bash
   testzeus hypermind-code-blocks create --name "test-name-timestamp" --status "ready" --file "path/to/file1" --file "path/to/file2" ...
   ```
3. Associates it with the test via:
   ```bash
   testzeus tests create ... --hypermind-code-blocks "id"
   ```

### Sample Structure with Hypermind

```
tests/
├── test-login/
│   ├── login.feature
│   ├── hypermind/
│   │   ├── auth-helper.py        # Authentication utilities
│   │   └── token-validator.js    # Token validation logic
│   └── test-data/
│       └── valid-user/
│           └── data.txt
├── test-checkout/
│   ├── checkout.feature
│   ├── hypermind/
│   │   ├── payment-processor.py  # Payment processing code
│   │   ├── cart-utils.js         # Shopping cart utilities
│   │   └── discount-calc.py      # Discount calculation logic
│   └── test-data/
│       └── single-item/
│           └── data.txt
└── test-search/
    ├── search.feature
    └── hypermind/
        └── search-algorithm.py    # Custom search logic
```

### Supported File Types

Hypermind code blocks support any text-based file format:
- Python (`.py`)
- JavaScript (`.js`)
- TypeScript (`.ts`)
- YAML/JSON configuration files
- Shell scripts (`.sh`)
- Any other text-based code files

## Complete Example: All Features Combined

Here's a comprehensive example showing how to use environments, Hypermind code blocks, and test data together:

```
your-repo/
├── tests/
│   ├── test-api-authentication/
│   │   ├── authentication.feature              # Feature file
│   │   ├── environment/
│   │   │   ├── data.txt                        # API base URLs, auth endpoints
│   │   │   ├── extra.json                      # {"connected_env": "base-api-env"}
│   │   │   └── assets/
│   │   │       ├── api-certificate.pem         # SSL certificate
│   │   │       └── oauth-config.json           # OAuth configuration
│   │   ├── hypermind/
│   │   │   ├── jwt-helper.py                   # JWT token utilities
│   │   │   ├── auth-validator.js               # Authentication validation
│   │   │   └── token-refresh.py                # Token refresh logic
│   │   └── test-data/
│   │       ├── admin-login/
│   │       │   ├── data.txt                    # Admin credentials
│   │       │   └── assets/
│   │       │       └── admin-profile.json
│   │       ├── user-login/
│   │       │   └── data.txt                    # Regular user credentials
│   │       └── guest-access/
│   │           └── data.txt                    # Guest access token
│   │
│   ├── test-payment-processing/
│   │   ├── payment.feature
│   │   ├── environment/
│   │   │   ├── data.txt                        # Payment gateway URLs
│   │   │   ├── extra.json                      # {"connected_env": "prod-payment-env"}
│   │   │   └── assets/
│   │   │       └── payment-gateway-cert.pem
│   │   ├── hypermind/
│   │   │   ├── payment-calculator.py           # Payment calculations
│   │   │   ├── tax-engine.js                   # Tax calculation logic
│   │   │   └── currency-converter.py           # Currency conversion
│   │   └── test-data/
│   │       ├── credit-card-payment/
│   │       │   ├── data.txt
│   │       │   └── assets/
│   │       │       └── card-details.json
│   │       ├── paypal-payment/
│   │       │   └── data.txt
│   │       └── crypto-payment/
│   │           └── data.txt
│   │
│   └── test-simple-search/
│       ├── search.feature                      # Simple test with no test-data
│       ├── environment/
│       │   └── data.txt                        # Search API configuration
│       └── hypermind/
│           └── search-ranker.py                # Search ranking algorithm
│
└── templates/
    └── ctrf-report.hbs
```

### What Happens During Execution

For `test-api-authentication`:

1. **Environment Creation**:
   ```bash
   testzeus environments create --name "test-api-authentication-env-1234567890" \
     --data-file "./tests/test-api-authentication/environment/data.txt" \
     --status "ready"
   # Returns: env_001
   ```

2. **Connected Environment Linking**:
   ```bash
   testzeus environments update env_001 \
     --connected-environments "base-api-env"
   ```

3. **Environment Assets Upload**:
   ```bash
   testzeus environments upload-file env_001 \
     "./tests/test-api-authentication/environment/assets/api-certificate.pem"
   testzeus environments upload-file env_001 \
     "./tests/test-api-authentication/environment/assets/oauth-config.json"
   ```

4. **Hypermind Code Blocks Creation**:
   ```bash
   testzeus hypermind-code-blocks create \
     --name "test-api-authentication-1234567890" \
     --status "ready" \
     --file "./tests/test-api-authentication/hypermind/jwt-helper.py" \
     --file "./tests/test-api-authentication/hypermind/auth-validator.js" \
     --file "./tests/test-api-authentication/hypermind/token-refresh.py"
   # Returns: hyper_001
   ```

5. **Test Data Creation**:
   ```bash
   testzeus test-data create \
     --name "test-api-authentication-admin-login-1234567890" \
     --data-file "./tests/test-api-authentication/test-data/admin-login/data.txt" \
     --status "ready"
   # Returns: data_001
   
   testzeus test-data upload-file data_001 \
     "./tests/test-api-authentication/test-data/admin-login/assets/admin-profile.json"
   
   # Similar for user-login (data_002) and guest-access (data_003)
   ```

6. **Test Creation with All Components**:
   ```bash
   testzeus tests create \
     --name "test-api-authentication-1234567890" \
     --feature-file "./tests/test-api-authentication/authentication.feature" \
     --data "data_001,data_002,data_003" \
     --environment "env_001" \
     --hypermind-code-blocks "hyper_001" \
     --status "ready"
   # Returns: test_001
   ```

### Key Benefits of This Structure

1. **Isolation**: Each test has its own environment configuration
2. **Reusability**: Hypermind code blocks provide shared logic
3. **Flexibility**: Connect related environments via `connected_env`
4. **Organization**: Clear separation of concerns (environment, code, data)
5. **Scalability**: Easy to add new tests without affecting existing ones

## Outputs

The action generates the following outputs:

- **CTRF Report**: Stored in `downloads/` directory with configurable filename (default: `downloads/ctrf-report.json`) - Machine-readable test results
- **HTML Report**: Generated from the custom template
- **Console Logs**: Detailed execution logs in GitHub Actions
- **Slack Notifications**: Success/failure notifications (if configured)

### Report Location

After the action completes, the CTRF report will be available at:
- **Default path**: `downloads/ctrf-report.json`
- **Custom path**: `downloads/{your-custom-filename}` (when using the `filename` input parameter)

### CTRF Schema

The generated CTRF report follows the **Common Test Report Format (CTRF) v1.0.0** specification. The schema includes:

- **Report metadata**: Format version, specification version, and tool information
- **Test summary**: Aggregate counts (total, passed, failed, pending, skipped, other) and execution timing
- **Individual test results**: Each test includes:
  - Test identification (name, status, duration, timing)
  - Thread/execution context information
  - File attachments (screenshots, logs, artifacts)
  - Step-by-step execution details with individual step status
  - Extended metadata (tenant IDs, test run identifiers, feature/scenario names)

This standardized format ensures compatibility with CTRF-compliant tools and enables consistent test reporting across different testing frameworks.

#### Schema Example

```json
{
  "reportFormat": "CTRF",
  "specVersion": "1.0.0",
  "results": {
    "tool": {
      "name": "testzeus",
      "version": "1.0.0"
    },
    "summary": {
      "tests": 5,
      "passed": 4,
      "failed": 1,
      "start": 1640995200,
      "stop": 1640995800
    },
    "tests": [
      {
        "name": "Login Test",
        "status": "pass",
        "duration": 2500,
        "steps": [
          {
            "name": "Enter credentials",
            "status": "pass"
          }
        ],
        "attachments": [
          {
            "name": "image.png",
            "contentType": "png",
            "path": "<path/to/image>.png"
          }
        ],
        "extra": {
          "tenantid": "abcd",
          "test_run_id": "abcd",
          "test_run_dash_id": "abcd",
          "agent_config_id": "abcd",
          "feature_name": "Authentication",
          "scenario_name": "Login to google"
        }
      }
    ]
  }
}
```

## Troubleshooting

### Common Issues

1. **"No .feature file found"**
   - Ensure each test directory has a `.feature` file
   - Check file naming and extensions

2. **"test-data dir not found"**
   - This is optional - tests can run with just a feature file
   - Verify the `test-data` directory structure if you want to use test data

3. **"Login failed"**
   - Check your TestZeus credentials in secrets
   - Ensure your TestZeus account is active

4. **Template errors**
   - Ensure `templates/ctrf-report.hbs` exists
   - Check Handlebars syntax in your template

5. **Per-test environment issues**
   - Per-test environments are optional - missing directory won't cause failures
   - Ensure `environment/data.txt` exists if you create the `environment/` directory
   - Validate `extra.json` syntax if using connected environments
   - Environment assets are stored in `environment/assets/`
   - Each test can have its own independent environment configuration

6. **Hypermind code block issues**
   - Hypermind directories are optional - missing directory won't cause failures
   - All files in the `hypermind/` directory will be uploaded as separate code blocks
   - Check that code files are readable and not binary
   - Verify file permissions if upload fails

### Debug Mode

Add this step before the action to enable debug logging:

```yaml
- name: Enable Debug
  run: echo "ACTIONS_STEP_DEBUG=true" >> $GITHUB_ENV
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with a sample repository
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues related to:
- **TestZeus CLI**: Contact TestZeus support
- **This Action**: Open an issue in this repository
- **GitHub Actions**: Check GitHub's documentation
