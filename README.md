# TestZeus Run Action

A composite GitHub Action that runs automated tests using TestZeus and generates comprehensive test reports with Slack notifications.

## Features

- 🚀 Automated test execution using TestZeus CLI
- 📊 CTRF (Common Test Report Format) report generation
- 📱 Slack notifications for test results
- 🔄 Support for multiple test cases and data files
- 📎 Asset file upload support
- 🌍 Environment configuration support for different test environments

## Prerequisites

### Repository Structure

Your repository must follow this structure:

```
your-repo/
├── tests/
│   ├── test-example1/
│   │   ├── example.feature          # Gherkin feature file
│   │   ├── test-data/
│   │   │   ├── case1/
│   │   │   │   ├── data.txt         # Test data file
│   │   │   │   └── assets/          # Optional asset files
│   │   │   │       └── screenshot.png
│   │   │   └── case2/
│   │   │       ├── data.txt
│   │   │       └── assets/
│   │   └── test-environments/       # Optional environment configurations
│   │       ├── case1/
│   │       │   ├── data.txt         # Environment configuration file
│   │       │   └── assets/          # Optional environment assets
│   │       │       └── config.json
│   │       └── case2/
│   │           ├── data.txt
│   │           └── assets/
│   └── test-example2/
│       ├── another.feature
│       ├── test-data/
│       │   └── case1/
│       │       └── data.txt
│       └── test-environments/       # Optional - matches test-data structure
│           └── case1/
│               └── data.txt
└── templates/
    └── ctrf-report.hbs              # Custom CTRF report template (optional)
```

### Required Files

1. **Feature Files**: Each test directory must contain a `.feature` file with Gherkin scenarios
2. **Test Data Files**: Each test case must have a `data.txt` file in the `test-data/case_name/` directory
3. **Template File**: Create `templates/ctrf-report.hbs` for custom report formatting

### Optional Files

4. **Environment Files**: Each test case can optionally have a corresponding `data.txt` file in the `test-environments/case_name/` directory
   - Environment files contain configuration data for test execution environments
   - Must follow the same directory structure as `test-data`
   - If present, will be automatically associated with the corresponding test case
   - Supports assets in the same way as test-data directories

## Setup

### 1. Required Secrets

Configure these secrets in your GitHub repository (`Settings > Secrets and variables > Actions`):

| Secret | Description | Required |
|--------|-------------|----------|
| `TESTZEUS_EMAIL` | Your TestZeus account email | ✅ Yes |
| `TESTZEUS_PASSWORD` | Your TestZeus account password | ✅ Yes |
| `SLACK_WEBHOOK_URL` | Slack webhook URL for notifications | ❌ Optional |

### 2. Create CTRF Report Template (optional)

![Test Results Summary](assets/test-results-summary.png)

Create `templates/ctrf-report.hbs` in your repository:

```handlebars
<!DOCTYPE html>
<html>
<head>
    <title>Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .pass { color: green; }
        .fail { color: red; }
        .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Test Execution Report</h1>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total Tests:</strong> {{results.summary.tests}}</p>
        <p><strong>Passed:</strong> <span class="pass">{{results.summary.passed}}</span></p>
        <p><strong>Failed:</strong> <span class="fail">{{results.summary.failed}}</span></p>
        <p><strong>Duration:</strong> {{results.summary.stop}} ms</p>
    </div>
    
    <h2>Test Results</h2>
    {{#each results.tests}}
    <div style="border: 1px solid #ddd; margin: 10px 0; padding: 10px;">
        <h3>{{name}}</h3>
        <p><strong>Status:</strong> <span class="{{status}}">{{status}}</span></p>
        <p><strong>Duration:</strong> {{duration}} ms</p>
        {{#if message}}
        <p><strong>Message:</strong> {{message}}</p>
        {{/if}}
    </div>
    {{/each}}
</body>
</html>
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
    - name: Run TestZeus Tests
      uses: test-zeus-ai/testzeus-create-execute@v1
      env:
        TESTZEUS_EMAIL: ${{ secrets.TESTZEUS_EMAIL }}
        TESTZEUS_PASSWORD: ${{ secrets.TESTZEUS_PASSWORD }}
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
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
    - name: Run Smoke Tests
      uses: your-username/testzeus-run-action@v1
      env:
        TESTZEUS_EMAIL: ${{ secrets.TESTZEUS_EMAIL }}
        TESTZEUS_PASSWORD: ${{ secrets.TESTZEUS_PASSWORD }}
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Test Environments

The action supports optional test environment configurations that allow you to specify different execution environments for your tests.

### How Test Environments Work

1. **Structure**: Test environments follow the same directory structure as test-data
2. **Matching**: Each test case in `test-data/case_name/` can have a corresponding `test-environments/case_name/`
3. **Automatic Association**: When both exist, they are automatically linked during test creation
4. **Optional**: Test environments are completely optional - tests work without them

### Example Use Cases

- **Different API endpoints** for staging vs production
- **Database configurations** for different environments
- **Authentication credentials** for various test environments
- **Feature flags** or configuration settings
- **Environment-specific assets** like certificates or config files

### Sample Environment Structure

```
test-environments/
├── staging/
│   ├── data.txt              # Staging environment config
│   └── assets/
│       ├── staging-cert.pem
│       └── staging-config.json
└── production/
    ├── data.txt              # Production environment config
    └── assets/
        ├── prod-cert.pem
        └── prod-config.json
```

The environment `data.txt` files can contain:
- API base URLs
- Database connection strings
- Environment-specific variables
- Configuration parameters

## Outputs

The action generates the following outputs:

- **CTRF Report**: `ctrf-report.json` - Machine-readable test results
- **HTML Report**: Generated from the custom template
- **Console Logs**: Detailed execution logs in GitHub Actions
- **Slack Notifications**: Success/failure notifications (if configured)

## Slack Notifications

If you configure the `SLACK_WEBHOOK_URL` secret, you'll receive:

- ✅ **Success notifications** with a link to the test run
- ❌ **Failure notifications** with error details and run link

### Setting up Slack Webhook

1. Go to your Slack workspace
2. Create a new Slack app or use an existing one
3. Enable Incoming Webhooks
4. Create a webhook URL for your channel
5. Add the webhook URL as `SLACK_WEBHOOK_URL` secret in GitHub

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
   - Test environments are optional - missing directories won't cause failures
   - Ensure `test-environments` structure matches `test-data` structure
   - Each environment case directory must have its own `data.txt` file

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
