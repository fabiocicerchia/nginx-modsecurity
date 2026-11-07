@domain:artifact-delivery @area:publishing @from:nginx-modsecurity/makefile
Feature: Publishing tagged module artifacts
  Operators pull the module by a tag that names exactly which ModSecurity, nginx and libc it was built for, so they can pick the one their nginx will load.

  Background:
    Given the artifact image is ghcr.io/fabiocicerchia/nginx-modsecurity-module unless the operator names another

  @id:artifact-delivery.publishing.001 @rule:artifacts.tags.encode-versions-and-flavour @inferred @source:Makefile#VERSION
  Scenario Outline: The artifact tag names the ModSecurity version, the nginx version and the libc flavour
    Given ModSecurity version <modsec> is selected
    And nginx version <nginx> is selected
    And the <flavour> flavour is selected
    When the operator asks for the artifact tag
    Then the tag is "<tag>"

    Examples:
      | modsec | nginx  | flavour | tag                       |
      | 3.0.16 | 1.28.0 | debian  | 3.0.16-nginx1.28.0        |
      | 3.0.16 | 1.28.0 | alpine  | 3.0.16-nginx1.28.0-alpine |
      | 3.0.16 | 1.27.5 | debian  | 3.0.16-nginx1.27.5        |

  @id:artifact-delivery.publishing.002 @rule:artifacts.tags.latest-follows-default-version-only @inferred @source:Makefile#release @questionable
  Scenario: A release moves the latest tag whatever version and flavour it was cut for
    Given nginx version 1.31.4 is selected, which is not the default version
    And the alpine flavour is selected
    When the operator releases the artifact
    Then the artifact is pushed as 3.0.16-nginx1.31.4-alpine
    And the latest tag now points at that musl build for nginx 1.31.4

  @id:artifact-delivery.publishing.003 @rule:artifacts.release.amd64-and-arm64 @inferred @source:Makefile#release
  Scenario: A release publishes the module for amd64 and arm64 under one tag
    Given no platform list is given
    When the operator releases the artifact
    Then the published tag carries a linux/amd64 build
    And the published tag carries a linux/arm64 build
