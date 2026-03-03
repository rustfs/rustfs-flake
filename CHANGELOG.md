# Changelog

All notable changes to the RustFS NixOS module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Recent Improvements (March 2026)

Following community feedback on Issue #9, additional improvements aligned with Nix best practices:

#### Removed Manual Binary Stripping

- Removed redundant manual `strip` command and `binutils` dependency
- Nix automatically strips binaries by default
- Allows packages to use `dontStrip` for debugging when needed

#### Clarified sourceProvenance

- Added clear documentation explaining pre-compiled binaries from GitHub releases
- Makes it obvious why `sourceProvenance = [ sourceTypes.binaryNativeCode ]` is declared

#### Migrated to Environment Attribute Set

- Changed from `serviceConfig.Environment` list to `environment` attribute set
- More idiomatic Nix style following nixpkgs conventions
- Better integration with override system
- Follows patterns from minio and other modules

#### Replaced Shell Script with %d Placeholder

- Eliminated `pkgs.writeShellScript` wrapper for credential loading
- Uses systemd's `%d` placeholder for credentials directory
- Cleaner implementation: `RUSTFS_ACCESS_KEY = "file:%d/access-key"`
- Direct binary execution without wrapper script

#### Default to Systemd Journal Logging

- Changed `logDirectory` default from `"/var/log/rustfs"` to `null`
- Logs written to systemd journal by default
- View logs with: `journalctl -u rustfs -f`
- File logging still available when explicitly configured
- Automatic log rotation and unified log management

### Added

- Comprehensive security documentation in `docs/SECURITY.md`
- Migration guide for users upgrading from insecure configuration in `docs/MIGRATION.md`
- Example configurations with sops-nix integration
- Support for both file-based and sops-nix/agenix secret management
- Systemd LoadCredential for secure secret passing
- Extensive systemd security hardening:
    - `CapabilityBoundingSet = ""`
    - `PrivateDevices = true`
    - `PrivateTmp = true`
    - `PrivateUsers = true`
    - `ProtectSystem = "strict"`
    - `ProtectHome = true`
    - `ProtectKernelTunables = true`
    - `ProtectKernelModules = true`
    - `ProtectKernelLogs = true`
    - `ProtectClock = true`
    - `ProtectControlGroups = true`
    - `ProtectHostname = true`
    - `ProtectProc = "invisible"`
    - `ProcSubset = "pid"`
    - `RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ]`
    - `RestrictNamespaces = true`
    - `RestrictRealtime = true`
    - `RestrictSUIDSGID = true`
    - `SystemCallArchitectures = "native"`
    - `SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ]`
    - `MemoryDenyWriteExecute = true`
    - `LockPersonality = true`
    - `NoNewPrivileges = true`
    - `UMask = "0077"`
- `ReadWritePaths` configuration for explicit write access
- Resource limits: `LimitNOFILE = 1048576`, `LimitNPROC = 32768`
- Improved restart configuration with `RestartSec = "10s"`
- Timeout configurations: `TimeoutStartSec = "60s"`, `TimeoutStopSec = "30s"`
- Automatic directory creation with secure permissions via `systemd.tmpfiles.rules`
- Detailed option descriptions with examples
- Security checklist in documentation
- Log rotation example configuration

### Changed

- **Deprecated**: `services.rustfs.accessKey` is renamed to `services.rustfs.accessKeyFile` via `mkRenamedOptionModule`. The old name now maps to the *file path* option — plain-text secret strings are no longer accepted. A valid file path is required whenever `services.rustfs.enable = true`.
- **Deprecated**: `services.rustfs.secretKey` is renamed to `services.rustfs.secretKeyFile` via `mkRenamedOptionModule`. The old name now maps to the *file path* option — plain-text secret strings are no longer accepted. A valid file path is required whenever `services.rustfs.enable = true`.
- Default `volumes` changed from `"/tmp/rustfs"` to `"/var/lib/rustfs"` (persistent storage)
- Console now defaults to localhost-only binding (`127.0.0.1:9001`)
- Improved logging output to separate stdout and stderr streams
- Enhanced documentation with security focus
- Updated examples to demonstrate secure configurations
- Service now explicitly grants write access only to required directories

### Deprecated

- `accessKey` option (removed, use `accessKeyFile`)
- `secretKey` option (removed, use `secretKeyFile`)

### Removed

- Direct secret configuration options (must use file-based secrets)

### Fixed

- Secrets no longer stored in Nix store (world-readable)
- Secrets no longer passed via environment variables
- Service can no longer access user home directories
- Service can no longer modify system files outside designated paths
- Service cannot spawn arbitrary processes or modify system configuration
- Console no longer exposed to public network by default

### Security

- Secrets are now passed via systemd LoadCredential (never in Nix store)
- Service runs as unprivileged `rustfs` user (not root)
- Comprehensive systemd sandboxing enabled
- System calls restricted to safe subset
- All capabilities dropped
- Prevents privilege escalation
- Memory execution protection
- Network address family restrictions
- Filesystem isolation with explicit write paths

## Migration Notes

Users upgrading from previous versions must:

1. Move secrets from `accessKey`/`secretKey` to file-based configuration
2. Update to use `accessKeyFile` and `secretKeyFile` options
3. Consider using sops-nix or agenix for secret management
4. Review firewall rules (console now localhost-only by default)
5. Update volume paths from `/tmp` to persistent storage

See [docs/MIGRATION.md](./docs/MIGRATION.md) for detailed migration instructions.

## Version Compatibility

- **NixOS**: 23.11 or later recommended
- **Systemd**: 252 or later (for all security features)
- **RustFS**: Compatible with current RustFS binary

## References

- [Issue #9](https://github.com/rustfs/rustfs-flake/issues/9) - Original security concerns
- [docs/SECURITY.md](./docs/SECURITY.md) - Complete security documentation
- [docs/MIGRATION.md](./docs/MIGRATION.md) - Migration guide
- [docs/IMPROVEMENTS.md](./docs/IMPROVEMENTS.md) - Technical implementation details

