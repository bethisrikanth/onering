Feature: Core API
  Scenario: Test Endpoints
    Given I am at /api
    Then I should see 'status' => 'ok' in the JSON response