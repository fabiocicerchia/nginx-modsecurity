@domain:supply-chain @area:source-verification @from:nginx-modsecurity/makefile
Feature: Verifying the nginx source for the selected version
  Operators can trust that the nginx source compiled into the module is the one recorded for that version, because a mismatched tarball fails the build.

  @id:supply-chain.source-verification.004 @rule:build.sources.nginx-checksum-matches-selected-version @inferred @source:Makefile#NGINX_SHA256
  Scenario Outline: Only an nginx version with a recorded checksum can be built
    Given nginx version <nginx> is selected
    And <listing>
    When the operator builds the module
    Then <outcome>

    Examples:
      | nginx  | listing                                                 | outcome                                                                |
      | 1.31.4 | the supported versions list records its source checksum | the nginx source is verified against e6f20b64… and the build continues |
      | 1.29.9 | the supported versions list does not include it         | the build fails at the nginx source checksum                           |
