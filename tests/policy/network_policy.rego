# OPA/Conftest policy: All Deployments must have a NetworkPolicy

package main

# Collect all NetworkPolicy names
network_policies[name] {
  input.kind == "NetworkPolicy"
  name := input.metadata.name
}

# Check that Deployments in namespaces without a NetworkPolicy get a warning
warn[msg] {
  input.kind == "Deployment"
  ns := input.metadata.namespace
  not network_policies[_]
  msg := sprintf("Deployment '%s' in namespace '%s': no NetworkPolicy found in the same manifest", [input.metadata.name, ns])
}
