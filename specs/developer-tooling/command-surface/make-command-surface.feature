@domain:developer-tooling @area:command-surface @from:nginx-modsecurity/makefile
Feature: Discovering and using the make verbs
  Operators and contributors can see every verb the repo offers, and verbs that do not apply say why instead of silently succeeding.

  @id:developer-tooling.command-surface.001 @rule:tooling.commands.bare-make-shows-help @inferred @source:Makefile#help
  Scenario: Running make with no verb lists every verb and what it does
    When the operator runs make with no verb
    Then every documented verb is listed with its one-line description
    And nothing is built

  @id:developer-tooling.command-surface.002 @rule:tooling.commands.run-is-declared-not-applicable @inferred @source:Makefile#run
  Scenario: Asking to run the artifact explains that it is a module, not a program
    When the operator asks to run the artifact
    Then they are told there is nothing to run because the image holds only a .so with no entrypoint
    And they are pointed at make test and make extract

  @id:developer-tooling.command-surface.003 @rule:tooling.commands.analyze-requires-trivy @inferred @source:Makefile#analyze
  Scenario: Scanning is refused with an install pointer when the scanner is missing
    Given trivy is not installed
    When the operator asks to scan the tree
    Then they see "analyze needs trivy" with the installation URL
    And the command exits with status 69
