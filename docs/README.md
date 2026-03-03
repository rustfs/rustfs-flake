# RustFS Flake Documentation

This directory contains detailed documentation for the RustFS NixOS Flake.

## Documentation Files

### [SECURITY.md](./SECURITY.md)

Comprehensive security guide covering:

- Secret management with sops-nix and agenix
- TLS/HTTPS configuration
- Firewall setup and network security
- Systemd hardening features
- Monitoring and logging
- Security checklist for production deployments

### [MIGRATION.md](./MIGRATION.md)

Step-by-step migration guide for:

- Upgrading from insecure plain-text secrets to file-based secrets
- Transitioning to sops-nix or agenix
- Volume path updates
- Configuration changes and breaking changes

### [IMPROVEMENTS.md](./IMPROVEMENTS.md)

Technical implementation details of all security and performance improvements:

- Secret management implementation
- Systemd hardening specifications
- Resource limits and performance tuning
- Nix best practices implementation
- Recent improvements based on community feedback

## Quick Links

- [Main README](../README.md) - Getting started and basic usage
- [CHANGELOG](../CHANGELOG.md) - Version history and changes
- [CONTRIBUTING](../CONTRIBUTING.md) - How to contribute
- [Examples](../examples/) - Example configurations

## Getting Help

- **Security Issues**: See [SECURITY.md](./SECURITY.md) for security best practices
- **Migration Issues**: Follow [MIGRATION.md](./MIGRATION.md) for upgrade guidance
- **Technical Details**: Refer to [IMPROVEMENTS.md](./IMPROVEMENTS.md) for implementation specifics

## Issue #9 Response

All documentation in this directory was created or updated in response to security concerns raised
in [Issue #9](https://github.com/rustfs/rustfs-flake/issues/9), implementing comprehensive security hardening and
following Nix community best practices.

