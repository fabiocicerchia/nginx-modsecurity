@domain:artifact-delivery @area:artifact-contents @from:nginx-modsecurity/dockerfile
Feature: Packaging the ModSecurity module artifact
  Gives nginx operators a non-runnable artifact holding exactly the files they copy into their own nginx image, so they adopt the WAF module without adopting someone else's image.

  Background:
    Given the operator has built the artifact for nginx 1.27.5 and ModSecurity 3.0.16

  @id:artifact-delivery.artifact-contents.001 @rule:artifact.contents.module-ships-with-runtime-files @inferred @source:Dockerfile#build
  Scenario Outline: The artifact holds the module together with the library and files it needs at runtime
    When the operator lists the files in the artifact
    Then the artifact contains "<path>"
    And the artifact contains no shell, nginx binary or other runnable program

    Examples:
      | path                                    |
      | /modules/ngx_http_modsecurity_module.so |
      | /lib/libmodsecurity.so.3                |
      | /conf/modsecurity.conf                  |
      | /conf/unicode.mapping                   |
      | /NGINX_VERSION                          |
      | /MODSECURITY_VERSION                    |
      | /NOTICE                                 |

  @id:artifact-delivery.artifact-contents.002 @rule:artifact.contents.version-stamps @inferred @source:Dockerfile#build
  Scenario: The artifact records the nginx and ModSecurity versions it was built for
    When the operator reads the artifact's version records
    Then the NGINX_VERSION file reads "1.27.5"
    And the MODSECURITY_VERSION file reads "3.0.16"
    And the image's version label reads "3.0.16-nginx1.27.5"

  @id:artifact-delivery.artifact-contents.003 @rule:artifact.contents.real-unicode-mapping @inferred @source:Dockerfile#build
  Scenario Outline: A build whose unicode mapping is only a placeholder is refused
    Given the upstream ModSecurity release ships a unicode.mapping of <size> bytes
    When the operator builds the artifact
    Then <outcome>

    Examples:
      | size  | outcome                                                                          |
      | 22    | the build fails with "unicode.mapping looks like a stub, not the upstream table" |
      | 10000 | the build fails with "unicode.mapping looks like a stub, not the upstream table" |
      | 74000 | the artifact ships that table as /conf/unicode.mapping                           |
