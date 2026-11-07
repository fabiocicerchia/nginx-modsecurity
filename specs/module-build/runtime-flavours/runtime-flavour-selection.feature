@domain:module-build @area:runtime-flavours @from:nginx-modsecurity/makefile
Feature: Choosing the libc flavour of the module
  Operators pick a glibc or musl build so the module loads into the nginx runtime they actually run.

  @id:module-build.runtime-flavours.001 @rule:build.flavour.selects-matching-nginx-base @inferred @source:Makefile#BASE_TAG
  Scenario Outline: The chosen flavour decides which official nginx image the module is compiled against
    Given nginx version 1.28.0 is selected
    And the <flavour> flavour is selected
    When the operator asks which base the build targets
    Then the answer is "<base_tag>"

    Examples:
      | flavour | base_tag            |
      | debian  | nginx:1.28.0        |
      | alpine  | nginx:1.28.0-alpine |
