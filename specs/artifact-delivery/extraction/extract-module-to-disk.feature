@domain:artifact-delivery @area:extraction @from:nginx-modsecurity/makefile
Feature: Extracting the module to disk
  Operators who do not want a registry get the module and its library as plain files they can copy into their own nginx.

  @id:artifact-delivery.extraction.001 @rule:artifacts.extract.writes-files-to-dist @inferred @source:Makefile#extract
  Scenario: Extraction writes the artifact's files to ./dist and lists them
    Given nginx version 1.28.0 and the debian flavour are selected
    When the operator extracts the module
    Then the artifact's files, including the module and its library, are written under ./dist
    And each written file is listed under "wrote:"
