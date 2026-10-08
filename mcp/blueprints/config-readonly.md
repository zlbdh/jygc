# config-readonly

## Goals

Inspect development or test configuration mappings through read-only access to diagnose cases that work locally but fail during integration.

## Allowed capabilities

- Read environment-variable mappings
- Read Nacos configuration entries
- Inspect interservice addresses, feature switches, and namespaces

## Prohibited capabilities

- Modifying configuration
- Publishing configuration
- Connecting to production configuration services

## Use cases

- Investigating environment differences
- Documenting configuration changes in release records
- Confirming integration prerequisites
