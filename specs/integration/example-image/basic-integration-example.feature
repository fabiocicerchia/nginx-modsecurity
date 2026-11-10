@domain:integration @area:example-image @from:examples/basic
Feature: Running the reference nginx integration
  Gives operators a working stock-nginx image with the ModSecurity module loaded, so they can see it block a request and copy the integration into their own image.

  Background:
    Given the operator has built the basic example image from a module artifact and an nginx base of the same version, 1.31.4

  @id:integration.example-image.001 @rule:integration.example.unprotected-path-bypasses-waf @inferred @source:examples/basic/nginx.conf#location /unprotected/ @questionable
  Scenario: A path with the WAF switched off answers even a flagged request
    Given the example container is running and listening on port 8080
    When a client requests "/unprotected/?testparam=blocked"
    Then the response status is 200
    And the response body is "ok, no waf"
    And the response content type is text/plain

  @id:integration.example-image.002 @rule:integration.example.module-loads-at-start @inferred @source:examples/basic/Dockerfile#COPY --from=modsec
  Scenario: The example starts with the module and its library loadable
    Given the example image is built
    When the operator starts the example container
    Then nginx starts without a dlopen or "not binary compatible" error
    And nginx accepts requests on port 8080 with ModSecurity enforcing

  @id:integration.example-image.003 @rule:integration.example.runs-unprivileged @inferred @source:examples/basic/Dockerfile#USER nginx
  Scenario: The example nginx runs as an unprivileged user on a high port
    Given the example image is built
    When the operator starts the example container
    Then the nginx processes run as the nginx user, not root
    And the server listens on port 8080
    And nginx writes its pid and temp files only under /tmp

  @id:integration.example-image.004 @rule:integration.demo-rule.health-check-reflects-serving @inferred @source:examples/basic/Dockerfile#HEALTHCHECK
  Scenario: The container reports healthy only while nginx serves its front page
    Given the example container is running
    When the container runtime runs the health check
    Then the container is healthy when "/" on port 8080 answers with a success status
    And the container is unhealthy when "/" fails or answers with an error status
