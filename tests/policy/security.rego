# OPA/Conftest policy: Security best practices for containers

package main

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("Deployment '%s': container '%s' must not run as privileged", [input.metadata.name, container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.runAsRoot == true
  msg := sprintf("Deployment '%s': container '%s' must not run as root", [input.metadata.name, container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.runAsNonRoot
  msg := sprintf("Deployment '%s': container '%s' must set runAsNonRoot: true", [input.metadata.name, container.name])
}

warn[msg] {
  input.kind == "Deployment"
  image := input.spec.template.spec.containers[_].image
  endswith(image, ":latest")
  msg := sprintf("Deployment '%s': should not use ':latest' tag for image '%s'", [input.metadata.name, image])
}
