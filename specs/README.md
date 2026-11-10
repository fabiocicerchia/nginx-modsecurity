# Specifications of nginx-modsecurity

What this code does, one atomic Gherkin scenario per behaviour, read from the code by code-atlas.
Tags: `@verified` a test asserts it · `@inferred` read from the code only · `@gap` an entry point no test covers · `@human` written or amended by a person, never rewritten.

## Artifact Delivery

Handing consumers the module as a non-runnable artifact they copy into their own nginx, rather than an image to adopt.

- **Artifact contents**: [Packaging the ModSecurity module artifact](artifact-delivery/artifact-contents/module-artifact-contents.feature) (3)
- **Extraction to disk**: [Extracting the module to disk](artifact-delivery/extraction/extract-module-to-disk.feature) (1)
- **Publishing and pulling**: [Publishing tagged module artifacts](artifact-delivery/publishing/artifact-tags-and-release.feature) (3)

## Build Reporting

Measuring what adopting the artifact costs, rather than claiming it.

- **Clean build time**: [Reporting clean build time and artifact size](build-reporting/build-time/build-report.feature) (5)

## Developer Tooling

The uniform command surface and quality gates contributors use to work on the repo.

- **Command surface**: [Discovering and using the make verbs](developer-tooling/command-surface/make-command-surface.feature) (3)

## Documentation Site

The project's documentation and landing page presentation.

- **Visual theme**: [Documentation visual theme](documentation-site/theme/docs-visual-theme.feature) (2)

## Integration into nginx

How a consumer loads the module into a stock nginx and gets a working, observable WAF.

- **Example integration**: [Running the reference nginx integration](integration/example-image/basic-integration-example.feature) (4)

## Supply-chain Integrity

Guaranteeing that the bytes compiled into the WAF are the ones that were asked for.

- **Base image pinning**: [Building on a pinned nginx base](supply-chain/base-pinning/base-image-pinning.feature) (1)
- **Source verification**: [Verifying the nginx source for the selected version](supply-chain/source-verification/source-checksum-per-version.feature) (1), [Building the module from verified, pinned sources](supply-chain/source-verification/verified-pinned-sources.feature) (2)
