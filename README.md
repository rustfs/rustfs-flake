# RustFS Flake

RustFS NixOS module with secure secret management and systemd hardening.

> **⚠️ SECURITY NOTICE**: Never use plain-text secrets in your NixOS configuration! Always use `accessKeyFile` and
`secretKeyFile` with a secret management tool like sops-nix or agenix. See [docs/SECURITY.md](./docs/SECURITY.md) for
> details.

## Documentation

- **[docs/SECURITY.md](./docs/SECURITY.md)** - Security best practices and secret management
- **[docs/MIGRATION.md](./docs/MIGRATION.md)** - Migrating from old insecure configuration
- **[docs/IMPROVEMENTS.md](./docs/IMPROVEMENTS.md)** - Technical implementation details
- **[examples/nixos-configuration.nix](./examples/nixos-configuration.nix)** - Example secure configuration
- **[examples/single-node-multi-disk.nix](./examples/single-node-multi-disk.nix)** - One node, four drives (erasure coding)
- **[examples/distributed-cluster.nix](./examples/distributed-cluster.nix)** - Four-node cluster, four drives per node

## Features

- 🔒 **Secure by default**: File-based secrets with systemd LoadCredential
- 🛡️ **Systemd hardening**: Comprehensive security restrictions
- 🔐 **Secret management**: Integration with sops-nix, agenix, etc.
- 📝 **Non-root**: Runs as dedicated unprivileged user
- 🔥 **Firewall-ready**: Minimal port exposure
- 📊 **Production-ready**: Log rotation, monitoring, TLS support

## Usage

First, add the flake to your flakes:

```nix
{
  inputs = {
    rustfs.url = "github:rustfs/rustfs-flake";
    rustfs.inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

And then import the flake:

```nix
  imports = [
    inputs.rustfs.nixosModules.rustfs
  ];
```

Then, add the flake to your `configuration.nix`:

```nix
  services = {
    rustfs = {
      enable = true;
      package = inputs.rustfs.packages.${pkgs.stdenv.hostPlatform.system}.default;
      # SECURITY NOTE: Never use plain text secrets in configuration.nix!
      # Use accessKeyFile and secretKeyFile instead:
      accessKeyFile = "/run/secrets/rustfs-access-key";  # or use sops-nix, agenix, etc.
      secretKeyFile = "/run/secrets/rustfs-secret-key";
      volumes = "/var/lib/rustfs";  # Use a persistent location
      address = ":9000";
      consoleEnable = true;
      consoleAddress = ":9001";
    };
  };
```

**For example with sops-nix:**

```nix
  # In your flake inputs
  inputs.sops-nix.url = "github:Mic92/sops-nix";

  # In your configuration
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

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
    package = inputs.rustfs.packages.${pkgs.stdenv.hostPlatform.system}.default;
    accessKeyFile = config.sops.secrets.rustfs-access-key.path;
    secretKeyFile = config.sops.secrets.rustfs-secret-key.path;
    volumes = "/var/lib/rustfs";
    address = ":9000";
    consoleEnable = true;
  };
```

You can also install the rustfs itself (Just binary):

just install following as a package:

```nix
inputs.rustfs.packages.${pkgs.stdenv.hostPlatform.system}.default
```

## Options

### services.rustfs.enable

Enables the rustfs service.

### services.rustfs.package

The rustfs package providing the rustfs binary.

### services.rustfs.accessKeyFile

**Type:** `path`

**Example:** `/run/secrets/rustfs-access-key`

Path to a file containing the access key for client authentication. Use a runtime path (e.g. /run/secrets/…) to prevent
the secret from being copied into the Nix store. The file must be readable by root/systemd — the module uses systemd
`LoadCredential` to read it and expose a copy in the service's credential directory (`$CREDENTIALS_DIRECTORY`); the
`rustfs` service user does not read the source file directly.

For security best practices, use secret management tools like sops-nix, agenix, or NixOps keys.

**Note:** The `accessKey` option has been renamed to `accessKeyFile` via `mkRenamedOptionModule`. The old name now maps
to this file-path option — plain-text secret strings are no longer accepted. A valid file path is required whenever
`services.rustfs.enable = true`.

### services.rustfs.secretKeyFile

**Type:** `path`

**Example:** `/run/secrets/rustfs-secret-key`

Path to a file containing the secret key for client authentication. Use a runtime path (e.g. /run/secrets/…) to prevent
the secret from being copied into the Nix store. The file must be readable by root/systemd — the module uses systemd
`LoadCredential` to read it and expose a copy in the service's credential directory (`$CREDENTIALS_DIRECTORY`); the
`rustfs` service user does not read the source file directly.

For security best practices, use secret management tools like sops-nix, agenix, or NixOps keys.

**Note:** The `secretKey` option has been renamed to `secretKeyFile` via `mkRenamedOptionModule`. The old name now maps
to this file-path option — plain-text secret strings are no longer accepted. A valid file path is required whenever
`services.rustfs.enable = true`.

### services.rustfs.user

**Type:** `string`

**Default:** `"rustfs"`

User account under which RustFS runs. The service runs as a dedicated non-root user for security.

### services.rustfs.group

**Type:** `string`

**Default:** `"rustfs"`

Group under which RustFS runs.

### services.rustfs.volumes

**Type:** `string` or `list of strings`

**Default:** `["/var/lib/rustfs"]`

List of paths or comma-separated string where RustFS stores data. Use persistent locations, not /tmp. Each entry must be
its own filesystem; several entries on one disk give no redundancy. Erasure coding needs at least 4 drives. Ignored when
`distributed.enable` is set — use `distributed.volumes` instead.

### services.rustfs.distributed.enable

**Type:** `bool`

**Default:** `false`

Whether to run as part of a distributed RustFS cluster spanning several nodes. When enabled, the module renders the
shared endpoint list (`http://<node>:<port><volume>` for every node × volume pair) that all nodes must agree on, ordered
drive-major so an erasure set spans nodes instead of sitting on one.

See [examples/distributed-cluster.nix](./examples/distributed-cluster.nix) for a complete four-node configuration.

### services.rustfs.distributed.nodes

**Type:** `list of strings`

**Default:** `[]`

**Example:** `["node1" "node2" "node3" "node4"]`

Hostnames of every node in the cluster, resolvable from each of them. Set identically on all nodes — the endpoint list is
rendered from this and must come out byte-identical cluster-wide. At least 4 nodes are required.

### services.rustfs.distributed.volumes

**Type:** `list of strings`

**Default:** `[]`

**Example:** `["/mnt/disk0" "/mnt/disk1" "/mnt/disk2" "/mnt/disk3"]`

Drive paths present on each node, each on its own filesystem. Every node uses the same layout, so this replaces
`volumes` in distributed mode and is what gets created and made writable locally. At least 4 drives per node are
required.

### services.rustfs.distributed.port

**Type:** `port`

**Default:** `9000`

Port peers reach each other on. Must match the port in `address`, and be open between nodes in the firewall.

### services.rustfs.distributed.localEndpointHost

**Type:** `string`

**Default:** `config.networking.hostName`

Which entry of `nodes` identifies this machine, so it claims its own drives instead of reaching them over RPC. Required
whenever `address` binds a wildcard such as `0.0.0.0`, since RustFS cannot infer its identity from that and would
otherwise treat every drive as remote.

> **Note**: All nodes must share the *same* access/secret key pair, and it must not be the default
> `rustfsadmin`/`rustfsadmin` — RustFS derives the inter-node RPC secret from the credentials and refuses to derive one
> from the defaults.

### services.rustfs.address

**Type:** `string`

**Default:** `":9000"`

The network address for the API server (e.g., :9000).

### services.rustfs.consoleEnable

**Type:** `bool`

**Default:** `true`

Whether to enable the RustFS management console.

### services.rustfs.consoleAddress

**Type:** `string`

**Default:** `":9001"`

The network address for the management console (e.g., :9001).

### services.rustfs.logLevel

**Type:** `string`

**Default:** `"info"`

The log level (error, warn, info, debug, trace).

### services.rustfs.logDirectory

**Type:** `null or path`

**Default:** `null`

Directory where RustFS service logs are written to files. If `null` (default), logs are written to systemd journal only.
Use `journalctl -u rustfs` to view logs. Set to a path (e.g., `"/var/log/rustfs"`) to enable file logging.

### services.rustfs.tlsDirectory

**Type:** `path`

**Default:** `"/etc/rustfs/tls"`

The directory containing TLS certificates.

### services.rustfs.extraEnvironmentVariables

**Type:** `attribute set of strings`

**Default:** `{}`

Additional environment variables to set for the RustFS service. Used for advanced configuration not covered by other
options (e.g. `RUST_BACKTRACE`).
