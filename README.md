# rustfs-flake

A Nix flake for [RustFS](https://github.com/rustfs/rustfs), a high-performance S3-compatible object storage system written in Rust.

## Features

- 🚀 **High Performance**: 2.3x faster than MinIO for 4KB object payloads
- 🔒 **S3 Compatible**: Drop-in replacement for Amazon S3, MinIO, and other S3-compatible storage
- 📦 **Easy Installation**: Simple Nix flake integration for NixOS
- 🔧 **NixOS Module**: Pre-configured systemd service for running RustFS
- 🎯 **Multi-platform**: Supports x86_64 and aarch64 on Linux and macOS

## Quick Start

### Running RustFS with nix run

```bash
nix run github:rustfs/rustfs-flake
```

### Installing RustFS

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rustfs-flake.url = "github:rustfs/rustfs-flake";
  };

  outputs = { self, nixpkgs, rustfs-flake }: {
    # Your configuration here
  };
}
```

### Using the NixOS Module

Add the following to your NixOS configuration:

```nix
{
  imports = [ rustfs-flake.nixosModules.default ];

  services.rustfs = {
    enable = true;
    dataDir = "/var/lib/rustfs";
    address = "0.0.0.0:9000";
    consoleAddress = "0.0.0.0:9001";
  };

  # Open firewall ports if needed
  networking.firewall.allowedTCPPorts = [ 9000 9001 ];
}
```

### Using the Overlay

Add to your nixpkgs overlays:

```nix
{
  nixpkgs.overlays = [ rustfs-flake.overlays.default ];
}
```

Then install RustFS like any other package:

```nix
environment.systemPackages = [ pkgs.rustfs ];
```

## Configuration Options

The NixOS module supports the following options:

- `services.rustfs.enable`: Enable the RustFS service (default: `false`)
- `services.rustfs.package`: RustFS package to use (default: from this flake)
- `services.rustfs.dataDir`: Data directory (default: `/var/lib/rustfs`)
- `services.rustfs.configFile`: Optional configuration file path
- `services.rustfs.user`: Service user (default: `rustfs`)
- `services.rustfs.group`: Service group (default: `rustfs`)
- `services.rustfs.address`: API server address (default: `127.0.0.1:9000`)
- `services.rustfs.consoleAddress`: Console address (default: `127.0.0.1:9001`)
- `services.rustfs.extraArgs`: Additional command-line arguments

## Development

Enter the development shell:

```bash
nix develop github:rustfs/rustfs-flake
```

## Building from Source

Build the package:

```bash
nix build github:rustfs/rustfs-flake
```

## License

This flake is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

RustFS itself is also licensed under the Apache License 2.0.

## Links

- [RustFS Repository](https://github.com/rustfs/rustfs)
- [RustFS Documentation](https://docs.rustfs.com)
- [RustFS Website](https://rustfs.com)
