@domain:supply-chain @area:base-pinning @from:nginx-modsecurity/makefile
Feature: Building on a pinned nginx base
  Operators get a module compiled on the exact upstream nginx bytes recorded for that version, so a rebuild cannot silently drift.

  @id:supply-chain.base-pinning.001 @rule:build.base.pinned-by-digest-per-version-and-flavour @inferred @source:Makefile#BASE_DIGEST @questionable
  Scenario Outline: A supported version builds on its recorded base digest, and anything else builds on the moving tag
    Given nginx version <nginx> is selected
    And the <flavour> flavour is selected
    And <pin_state>
    When the operator builds the module
    Then the build starts from "<base>"

    Examples:
      | nginx  | flavour | pin_state                                           | base                                                                                        |
      | 1.28.0 | debian  | the supported versions list records a digest for it | nginx:1.28.0@sha256:552e7481ca93ffccd046aa658dbbed22caefbc09c66fa7cd247cbb90b8a5c609        |
      | 1.28.0 | alpine  | the supported versions list records a digest for it | nginx:1.28.0-alpine@sha256:30f1c0d78e0ad60901648be663a710bdadf19e4c10ac6782c235200619158284 |
      | 1.29.9 | debian  | the supported versions list does not include it     | nginx:1.29.9                                                                                |
      | 1.28.0 | debian  | the operator opts out of the pin                    | nginx:1.28.0                                                                                |
