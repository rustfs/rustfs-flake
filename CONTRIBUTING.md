<!---
Copyright 2024 RustFS Team

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# Contributing to RustFS Flake

First off, thank you for considering contributing to RustFS! It's people like you that make RustFS such a great tool.

## Development Workflow

This repository manages the Nix Flake for prebuilt RustFS binaries.

### Prerequisites

- [Nix](https://nixos.org/download.html) with Flakes enabled.
- [nixpkgs-fmt](https://github.com/nix-community/nixpkgs-fmt) for code formatting.

### Local Testing

Before submitting a PR, please ensure your changes are valid:

```bash
# Format check
nix shell nixpkgs#nixpkgs-fmt -c nixpkgs-fmt --check .

# Syntax and basic flake check
nix flake check

# Build the default package for your system
nix build .#default

# Test the example configuration
cd examples && nix eval .#nixosConfigurations.example-host.config.services.rustfs
```

### Updating Binaries

The `sources.json` file tracks the upstream versions and hashes. When a new version of RustFS is released:

1. Update the `version` field in `sources.json`.
2. Update the `sha256` hashes for all supported platforms.
3. Verify the build: `nix build .`.

## Coding Standards

- **Nix Style**: Follow the [Nixpkgs architecture](https://nixos.org/manual/nixpkgs/stable/) guidelines.
- **Modularity**: Keep the NixOS module (`nixos/rustfs.nix`) decoupled from the package definition.
- **Documentation**: Any new option in the NixOS module must include a clear `description`.

## Pull Request Process

1. Create a new branch: `git checkout -b feat/your-feature-name`.
2. Commit your changes using [Conventional Commits](https://www.conventionalcommits.org/) (e.g., `feat: add tlsDirectory option`).
3. Ensure the `examples/` are updated if you change the module interface.
4. Submit the PR and wait for the maintainers' review.

## Security

If you discover a security vulnerability, please do **not** open an issue. Instead, contact the maintainers directly using the contact options provided in this repository's hosting platform.

---

*By contributing, you agree that your contributions will be licensed under the project's LICENSE.*
