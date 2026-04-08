# OPA/Conftest policy: All containers must have resource limits
# https://www.conftest.dev/
#
# Test with: conftest test kubernetes/ --policy tests/policy/

package main

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits
  msg := sprintf("Deployment '%s': container '%s' must have resource limits", [input.metadata.name, container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.requests
  msg := sprintf("Deployment '%s': container '%s' must have resource requests", [input.metadata.name, container.name])
}
