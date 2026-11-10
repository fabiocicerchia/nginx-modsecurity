@domain:documentation-site @area:theme @from:docs/stylesheets
Feature: Documentation visual theme
  Gives readers of the nginx-modsecurity docs a consistent, privacy-respecting look whose security-cluster accent palette is defined once and shared with the splash page.

  Background:
    Given the documentation site is built with the project's theme

  @id:documentation-site.theme.001 @rule:docs.theme.no-network-assets @inferred @source:docs/stylesheets/extra.css#:root
  Scenario: The docs render without fetching fonts or assets from the network
    Given a reader whose browser blocks all third-party requests
    When the reader opens any documentation page
    Then body text is set in the operating system's sans-serif font
    And code is set in the operating system's monospace font
    And no font, stylesheet or analytics request leaves the documentation site

  @id:documentation-site.theme.006 @rule:docs.theme.tables-as-cards @inferred @source:docs/stylesheets/extra.css#.md-typeset table:not([class]) @questionable
  Scenario: Plain tables render as rounded cards with compact uppercase headers
    Given a documentation page contains a plain markdown table
    When the reader views that page
    Then the table has a rounded, hairline-bordered frame
    And header cells are uppercase and smaller than body cells
    And anything that overflows the table's own rounded frame is clipped
