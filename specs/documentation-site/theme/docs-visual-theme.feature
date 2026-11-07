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

  @id:documentation-site.theme.002 @rule:docs.theme.shared-accent-palette @inferred @source:docs/stylesheets/extra.css#:root
  Scenario: The docs and the splash page share one orange-red accent palette
    Given the theme's accent pair is orange #fb923c and red #ef4444
    When a reader views the documentation home and the splash page
    Then the header chrome and links in the light scheme are red #ef4444
    And primary buttons and the hero title show an orange-to-red gradient
    And the splash page title and install label use the same orange and red

  @id:documentation-site.theme.003 @rule:docs.theme.scheme-legible-links @inferred @source:docs/stylesheets/extra.css#[data-md-color-scheme="slate"]
  Scenario Outline: Links switch accent colour so they stay readable in light and dark schemes
    Given the reader has chosen the <scheme> colour scheme
    When the reader views a page containing links
    Then links are shown in <link_colour>
    And the page background is <background>

    Examples:
      | scheme | link_colour    | background         |
      | light  | red #ef4444    | the default white  |
      | dark   | orange #fb923c | near-black #0b0f1a |

  @id:documentation-site.theme.004 @rule:docs.theme.button-hover-glow @inferred @source:docs/stylesheets/extra.css#.md-typeset .md-button:hover @questionable
  Scenario: Hovering a button lifts it with an indigo glow regardless of the palette
    Given the theme's accent pair is orange-red
    When the reader hovers over a documentation button
    Then the button rises slightly and grows by 2%
    And the glow under the button is indigo, not orange-red

  @id:documentation-site.theme.005 @rule:docs.theme.no-borrowed-logo @inferred @source:docs/stylesheets/extra.css#.md-header__button.md-logo
  Scenario: The docs show no logo rather than a generic stand-in
    Given the documentation has no project logo configured
    When the reader views the header and the navigation title
    Then no logo icon appears in the header
    And no logo icon appears beside the navigation title

  @id:documentation-site.theme.006 @rule:docs.theme.tables-as-cards @inferred @source:docs/stylesheets/extra.css#.md-typeset table:not([class]) @questionable
  Scenario: Plain tables render as rounded cards with compact uppercase headers
    Given a documentation page contains a plain markdown table
    When the reader views that page
    Then the table has a rounded, hairline-bordered frame
    And header cells are uppercase and smaller than body cells
    And anything that overflows the table's own rounded frame is clipped
