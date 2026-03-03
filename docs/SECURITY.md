# Security Policy

## Security Best Practices

This document outlines security best practices for deploying RustFS with the NixOS module.

### 1. Secret Management

**❌ NEVER do this:**

```nix
services.rustfs = {
  accessKey = "rustfsadmin";  # INSECURE! Will be in Nix store!
  secretKey = "rustfsadmin";
};
```

**✅ Always use file-based secrets:**

```nix
services.rustfs = {
  accessKeyFile = "/run/secrets/rustfs-access-key";
  secretKeyFile = "/run/secrets/rustfs-secret-key";
};
```

### 2. Secret Management Tools

We recommend using one of the following tools for managing secrets:

#### Option 1: sops-nix (Recommended)

[sops-nix](https://github.com/Mic92/sops-nix) provides encrypted secrets management:

```nix
inputs.sops-nix.url = "github:Mic92/sops-nix";

imports = [ inputs.sops-nix.nixosModules.sops ];

sops.secrets.rustfs-access-key = {
  sopsFile = ./secrets.yaml;
  owner = config.services.rustfs.user;
  group = config.services.rustfs.group;
  mode = "0400";
};

sops.secrets.rustfs-secret-key = {
  sopsFile = ./secrets.yaml;
  owner = config.services.rustfs.user;
  group = config.services.rustfs.group;
  mode = "0400";
};

services.rustfs = {
  enable = true;
  accessKeyFile = config.sops.secrets.rustfs-access-key.path;
  secretKeyFile = config.sops.secrets.rustfs-secret-key.path;
};
```

#### Option 2: agenix

[agenix](https://github.com/ryantm/agenix) provides age-encrypted secrets:

```nix
inputs.agenix.url = "github:ryantm/agenix";

imports = [ inputs.agenix.nixosModules.default ];

age.secrets.rustfs-access-key = {
  file = ./secrets/rustfs-access-key.age;
  owner = config.services.rustfs.user;
  group = config.services.rustfs.group;
  mode = "0400";
};

age.secrets.rustfs-secret-key = {
  file = ./secrets/rustfs-secret-key.age;
  owner = config.services.rustfs.user;
  group = config.services.rustfs.group;
  mode = "0400";
};

services.rustfs = {
  enable = true;
  accessKeyFile = config.age.secrets.rustfs-access-key.path;
  secretKeyFile = config.age.secrets.rustfs-secret-key.path;
};
```

#### Option 3: Manual Secret Files

For simpler deployments, you can manually create secret files:

```bash
# Create secret files with proper permissions
sudo mkdir -p /run/secrets
echo "your-access-key" | sudo tee /run/secrets/rustfs-access-key
echo "your-secret-key" | sudo tee /run/secrets/rustfs-secret-key
sudo chown rustfs:rustfs /run/secrets/rustfs-*
sudo chmod 400 /run/secrets/rustfs-*
```

### 3. Systemd Security Hardening

The RustFS NixOS module implements extensive systemd security hardening. The service runs with:

- **Non-root user**: Service runs as dedicated `rustfs` user
- **No capabilities**: `CapabilityBoundingSet = ""`
- **Private /tmp**: `PrivateTmp = true`
- **Private /dev**: `PrivateDevices = true`
- **Read-only system**: `ProtectSystem = "strict"` with explicit write paths
- **No privilege escalation**: `NoNewPrivileges = true`
- **Restricted system calls**: `SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ]`
- **Memory protections**: `MemoryDenyWriteExecute = true`
- **Network restrictions**: Only AF_INET, AF_INET6, and AF_UNIX allowed

See the full list in [nixos/rustfs.nix](../nixos/rustfs.nix).

### 4. File Permissions

The module automatically configures secure file permissions:

```nix
# Directories are created with restrictive permissions
systemd.tmpfiles.rules =
  (lib.optional (cfg.logDirectory != null)
    "d ${cfg.logDirectory} 0750 ${cfg.user} ${cfg.group} -")
  ++ [
    "d ${cfg.tlsDirectory} 0750 ${cfg.user} ${cfg.group} -"
    "d ${volume} 0750 ${cfg.user} ${cfg.group} -"  # For each volume
  ];
```

### 5. Network Security

#### TLS/HTTPS Configuration

For production deployments, always use TLS:

```nix
services.rustfs = {
  enable = true;
  # ... other options ...
  tlsDirectory = "/etc/rustfs/tls";
};

# Place your certificates in /etc/rustfs/tls/
# - server.crt
# - server.key
# - ca.crt (optional)
```

#### Firewall Configuration

Restrict network access using NixOS firewall:

```nix
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 9000 9001 ];  # API port and console port

  # Or use interfaces for more granular control
  interfaces.eth0.allowedTCPPorts = [ 9000 9001 ];
};
```

For console access, consider binding to localhost only:

```nix
services.rustfs = {
  consoleAddress = "127.0.0.1:9001";  # Localhost only
};
```

Then use SSH port forwarding to access the console:

```bash
ssh -L 9001:localhost:9001 your-server
```

### 6. Volume Security

Use appropriate volume locations:

```nix
services.rustfs = {
  # ❌ Bad - temporary storage
  volumes = "/tmp/rustfs";

  # ✅ Good - persistent storage with proper permissions
  volumes = "/var/lib/rustfs";

  # ✅ Also good - multiple volumes
  volumes = [ "/mnt/storage1" "/mnt/storage2" ];
};
```

Ensure volumes have appropriate filesystem permissions and are on encrypted filesystems for sensitive data.

### 7. Monitoring and Logging

#### Log Security

By default, logs are written to systemd journal with restricted access:

```nix
services.rustfs = {
  # Default: logs go to systemd journal (journalctl -u rustfs)
  logLevel = "info";  # Don't use "debug" or "trace" in production
};

# View logs with journalctl
# journalctl -u rustfs -f  # Follow logs in real-time
# journalctl -u rustfs --since today  # Today's logs
```

#### Optional: File-Based Logging

For file-based logging with rotation:

```nix
services.rustfs = {
  logDirectory = "/var/log/rustfs";  # Enable file logging
  logLevel = "info";
};

services.logrotate = {
  enable = true;
  settings.rustfs = {
    files = "/var/log/rustfs/*.log";
    frequency = "daily";
    rotate = 7;
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    create = "0640 rustfs rustfs";
  };
};
```

### 8. Updates and Vulnerability Management

Keep RustFS updated:

```nix
services.rustfs.package = inputs.rustfs.packages.${pkgs.stdenv.hostPlatform.system}.default;
```

Regularly update your flake inputs:

```bash
nix flake update
nixos-rebuild switch
```

## Reporting Security Issues

If you discover a security vulnerability in the RustFS NixOS module, please report it to the RustFS security team. Do
not open a public GitHub issue.

## Security Checklist

Before deploying to production, ensure:

- [ ] Secrets are stored in files, not in Nix configuration
- [ ] Secret files have permissions 0400 and correct ownership
- [ ] Using a secret management tool (sops-nix, agenix, etc.)
- [ ] TLS/HTTPS is configured for API and console
- [ ] Firewall rules are properly configured
- [ ] Console is not exposed to public internet
- [ ] Log level is not set to "debug" or "trace"
- [ ] Volumes are on persistent, secure storage
- [ ] Log rotation is configured
- [ ] System is kept up-to-date

## Migration from Insecure Configuration

If you're migrating from an old configuration using `accessKey` and `secretKey` options:

1. Create secret files:

```bash
echo "your-access-key" | sudo tee /run/secrets/rustfs-access-key
echo "your-secret-key" | sudo tee /run/secrets/rustfs-secret-key
sudo chown rustfs:rustfs /run/secrets/rustfs-*
sudo chmod 400 /run/secrets/rustfs-*
```

2. Update configuration:

```nix
services.rustfs = {
  # Remove these:
  # accessKey = "...";
  # secretKey = "...";

  # Add these:
  accessKeyFile = "/run/secrets/rustfs-access-key";
  secretKeyFile = "/run/secrets/rustfs-secret-key";
};
```

3. Rebuild and verify:

```bash
sudo nixos-rebuild switch
sudo systemctl status rustfs
```

## References

- [NixOS Manual - Secret Management](https://nixos.org/manual/nixos/stable/#sec-secrets)
- [sops-nix Documentation](https://github.com/Mic92/sops-nix)
- [agenix Documentation](https://github.com/ryantm/agenix)
- [systemd Security Features](https://www.freedesktop.org/software/systemd/man/systemd.exec.html)

