Feature: String Patches
  Scenario: Test String Conversion Methods
    Given I want the boolean value of 'true'
    Then I should see a true value

    Given I want the boolean value of 'True'
    Then I should see a true value

    Given I want the boolean value of 'on'
    Then I should see a true value

    Given I want the boolean value of 'yes'
    Then I should see a true value

    Given I want the boolean value of 'y'
    Then I should see a true value

    Given I want the boolean value of '1'
    Then I should see a true value

    Given I want the boolean value of 'false'
    Then I should see a false value

    Given I want the boolean value of 'False'
    Then I should see a false value

    Given I want the boolean value of '0'
    Then I should see a false value

    Given I want the boolean value of 'no'
    Then I should see a false value

    Given I want the boolean value of 'yams'
    Then I should see a false value
	
    Given I want the boolean value of 'potato'
    Then I should see a false value
