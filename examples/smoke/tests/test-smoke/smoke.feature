Feature: Create-execute smoke

  Scenario: Open example.com and confirm the page title
    Given I navigate to "https://example.com"
    Then the page title should contain "Example Domain"
