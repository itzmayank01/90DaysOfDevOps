# Day 54 – Kubernetes ConfigMaps and Secrets

## What are ConfigMaps and Secrets?

ConfigMaps are used to store non-sensitive configuration data such as environment variables, ports, and feature flags.

Secrets are used to store sensitive data such as passwords, API keys, and credentials.

---

## When to Use Each

* Use ConfigMaps for general configuration
* Use Secrets for confidential data

---

## Environment Variables vs Volume Mounts

Environment Variables:

* Inject key-value pairs directly into containers
* Easy to use
* Do not update after pod starts

Volume Mounts:

* Mount config as files inside container
* Suitable for large configs like nginx
* Automatically update when ConfigMap/Secret changes

---

## Base64 Encoding vs Encryption

Secrets in Kubernetes are base64 encoded.

Base64 is NOT encryption because:

* It can be easily decoded
* It provides no security by itself

Real security comes from:

* RBAC
* Encryption at rest
* Access control

---

## ConfigMap Update Behavior

* Volume-mounted ConfigMaps update automatically inside running pods
* Environment variables do NOT update after pod creation

---

## Conclusion

ConfigMaps and Secrets help decouple configuration from application code, making deployments flexible and secure.
