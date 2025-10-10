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
│   ├── test-environment/            # Global test environment (optional)
│   │   ├── data.txt                 # Global environment configuration
│   │   └── assets/                  # Optional global environment assets
│   │       └── config.json
│   ├── test-login/
│   │   ├── login.feature            # Gherkin feature file
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
│   │   └── test-data/
│   │       ├── single-item/         # Multiple cases assigned to one test
│   │       │   └── data.txt
│   │       └── multiple-items/
│   │           └── data.txt
│   └── test-search/
│       └── search.feature           # Test without test-data (feature file only)
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

4. **Global Environment File**: A single `tests/test-environment/data.txt` file for global environment configuration
   - This environment configuration is shared across all tests
   - Contains global settings like API endpoints, authentication tokens, or configuration parameters
   - Supports assets in the `tests/test-environment/assets/` directory
   - If present, will be automatically associated with all created tests

## Test Creation Logic

The action follows this logic for creating tests:

### 1. **Global Environment** (Optional)
- If `tests/test-environment/` exists, creates one global environment record
- This environment is shared across all tests

### 2. **Test Creation Per Directory**
For each `tests/test-*` directory:

- **Feature File Only**: If no `test-data/` directory exists, creates a test with just the feature file
- **With Test Data**: If `test-data/` directory exists:
  1. Creates individual test-data records for each case directory
  2. Collects all test-data IDs from that test
  3. Creates a single test record with ALL test-data IDs assigned
  4. Associates the global environment (if exists)

### 3. **Example Test Creation**
```
test-login/
├── login.feature
└── test-data/
    ├── valid-user/data.txt     → Creates test-data ID: data_001
    ├── admin-user/data.txt     → Creates test-data ID: data_002  
    └── guest-user/data.txt     → Creates test-data ID: data_003

Result: One test record with data: "data_001,data_002,data_003"
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

## Global Test Environment

The action supports an optional global test environment configuration that applies to all tests in your repository.

### How Global Test Environment Works

1. **Single Location**: Place environment configuration in `tests/test-environment/` directory
2. **Global Scope**: The same environment configuration is applied to all tests
3. **Automatic Association**: When present, the global environment is automatically linked to every test
4. **Optional**: The global test environment is completely optional - tests work without it

### Example Use Cases

- **API Base URLs** for different environments (staging, production)
- **Authentication Tokens** or credentials shared across all tests
- **Global Configuration** settings or feature flags
- **Environment-specific Assets** like certificates or config files
- **Database Connection Strings** for test environments

### Sample Global Environment Structure

```
tests/
├── test-environment/
│   ├── data.txt              # Global environment config
│   └── assets/
│       ├── api-cert.pem
│       ├── config.json
│       └── auth-token.txt
├── test-login/
│   ├── login.feature
│   └── test-data/
│       └── valid-user/
│           └── data.txt
└── test-checkout/
    ├── checkout.feature
    └── test-data/
        ├── guest-checkout/
        │   └── data.txt
        └── member-checkout/
            └── data.txt
```

The global environment `data.txt` file can contain:
- API base URLs and endpoints
- Authentication tokens or API keys
- Environment-specific variables
- Global configuration parameters
- Database connection strings

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
   - Verify the `test-data` directory structure
   - Each test must have a `test-data` subdirectory

3. **"Login failed"**
   - Check your TestZeus credentials in secrets
   - Ensure your TestZeus account is active

4. **Template errors**
   - Ensure `templates/ctrf-report.hbs` exists
   - Check Handlebars syntax in your template

5. **Test environment issues**
   - Global test environment is optional - missing directory won't cause failures
   - Ensure `tests/test-environment/data.txt` exists if you create the directory
   - Global environment assets are stored in `tests/test-environment/assets/`
   - The same environment configuration applies to all tests

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
