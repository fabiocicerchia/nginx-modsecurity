@domain:supply-chain @area:source-verification @from:nginx-modsecurity/dockerfile
Feature: Building the module from verified, pinned sources
  Protects operators running a WAF from a module compiled out of substituted downloads or a moved base image, and ties the module to the exact nginx release it will load into.

  Background:
    Given the build pins a SHA-256 digest for each of the ModSecurity, ModSecurity-nginx connector and nginx source releases

  @id:supply-chain.source-verification.001 @rule:supply-chain.sources.checksum-before-unpack @inferred @source:Dockerfile#build
  Scenario Outline: A source download whose bytes do not match the pinned digest fails the build
    Given the downloaded <source> tarball does not match its pinned digest
    When the operator builds the artifact
    Then the build fails at the checksum check for <source>
    And no artifact is produced, so nothing from that download is compiled into the module

    Examples:
      | source                            |
      | ModSecurity 3.0.16                |
      | ModSecurity-nginx connector 1.0.4 |
      | nginx 1.27.5                      |

  @id:supply-chain.source-verification.002 @rule:supply-chain.base.pinned-by-digest @inferred @source:Dockerfile#BASE
  Scenario: The default build base is pinned to an exact image digest
    Given the operator has not chosen a build base
    When the operator builds the artifact
    Then the module is compiled on nginx:1.27.5 at digest sha256:6784fb0834aa7dbbe12e3d7471e69c290df3e6ba810dc38b34ae33d3c1c05f7d
    And a re-tagged nginx:1.27.5 upstream does not change what the module is compiled on
