# RustFS Flake

RustFS NixOS module.

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
      accessKey = "rustfsadmin";
      secretKey = "rustfsadmin";
      volumes = "/tmp/rustfs";
      address = ":9000";
      consoleEnable = true;
    };
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

### services.rustfs.accessKey

The access key for the rustfs server.

### services.rustfs.secretKey

The secret key for the rustfs server.

### services.rustfs.volumes

The volumes to mount.

### services.rustfs.address

The address to listen on.

### services.rustfs.consoleEnable

Whether to enable the console.

### services.rustfs.logLevel

The log level.

### services.rustfs.logDirectory

The log directory.

### services.rustfs.tlsDirectory

The TLS directory.

### services.rustfs.extraEnvironmentVariables

Additional environment variables to set for the RustFS service.
These will be appended to the environment file at /etc/default/rustfs.
Used for advanced configuration not covered by other options. (e.g. `RUST_BACKTRACE`)