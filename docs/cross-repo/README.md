# Cross-Repository Indexes

This directory stores long-term cross-repository knowledge rather than temporary request details.

Maintain at least these three indexes:

- [business-chain-index.md](docs/cross-repo/business-chain-index.md): business workflow index
- [dependency-map.md](docs/cross-repo/dependency-map.md): repository dependencies and master-data ownership
- [contract-index.md](docs/cross-repo/contract-index.md): cross-repository contracts and verification entry points

Usage principles:

- Record only stable, long-term cross-repository knowledge here.
- Keep temporary judgments for individual requests in `changes/<change-id>/`.
- Keep facts internal to a business repository in that repository; do not copy them into the control repository.
