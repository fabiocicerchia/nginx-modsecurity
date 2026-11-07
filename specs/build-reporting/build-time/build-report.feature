@domain:build-reporting @area:build-time @from:nginx-modsecurity/report
Feature: Reporting clean build time and artifact size
  Gives operators and prospective consumers a measured, per-run figure for how long a clean build takes and how big the shipped artifact image is, instead of a committed number that goes stale.

  Background:
    Given the artifact image for the current nginx version and flavour can be built

  @id:build-reporting.build-time.001 @rule:build-reporting.build-time.measured-from-uncached-build @inferred @source:report.sh#report.sh
  Scenario: The reported build time comes from a build that reuses nothing from cache
    Given earlier builds of the same version have left cached layers on the machine
    When the operator runs the build report
    Then the artifact image is rebuilt from scratch without using any cached layer
    And the image is tagged with the selected image name and version
    And the console shows the build time in seconds, marked "(clean, --no-cache)"

  @id:build-reporting.build-time.002 @rule:build-reporting.artifact-size.size-layers-and-architecture @inferred @source:report.sh#report.sh
  Scenario Outline: The report states the artifact image's size, layer count and architecture
    Given the clean build of the artifact image has finished
    When the operator runs the build report
    Then the console shows the image reference and its architecture
    And the console shows "size <bytes> bytes (<mib> MiB)" followed by the layer count
    And the MiB figure has one decimal place, truncated rather than rounded

    Examples:
      | bytes    | mib  |
      | 10485760 | 10.0 |
      | 2086666  | 1.9  |
      | 5242880  | 5.0  |

  @id:build-reporting.build-time.003 @rule:build-reporting.ci-summary.attached-to-producing-run @inferred @source:report.sh#report.sh
  Scenario: In CI the measurements are attached to the run that produced them
    Given the report runs inside a CI job that provides a run summary
    When the operator runs the build report
    Then the run summary gains a "Build report" heading naming the nginx version and flavour
    And the summary table lists image, base, ModSecurity version, architecture, size, clean build time and runner
    And the runner shows as "unknown / unknown" when the CI does not name it
    And the summary notes that build time is an order of magnitude on a shared runner and the size is the module and library on scratch, not a runnable nginx

  @id:build-reporting.build-time.004 @rule:build-reporting.ci-summary.local-run-console-only @inferred @source:report.sh#report.sh
  Scenario: Outside CI the report only prints to the console
    Given the report runs on a workstation with no CI run summary available
    When the operator runs the build report
    Then the measurements are printed to the console
    And no summary file is written anywhere

  @id:build-reporting.build-time.005 @rule:build-reporting.build-time.refuses-missing-inputs @inferred @source:report.sh#report.sh @questionable
  Scenario: The report refuses to run without the version, flavour and base it should measure
    Given the operator omits one of image, version, Dockerfile, nginx version, flavour, ModSecurity version or base
    When the operator runs the report script
    Then no build starts
    And the script exits with an error
    And when the image is missing the message reads "usage: report.sh IMAGE VERSION DOCKERFILE NGINX MODSEC BASE [SHA]"
