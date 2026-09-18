{ pkgs, self }:

let
  lib = pkgs.lib;
  system = pkgs.stdenv.hostPlatform.system;
  nixosSystem = import (pkgs.path + "/nixos/lib/eval-config.nix");

  baseModule = {
    system.stateVersion = "24.11";
    services.rustfs = {
      enable = true;
      package = self.packages.${system}.default;
      accessKeyFile = "/etc/rustfs-access-key";
      secretKeyFile = "/etc/rustfs-secret-key";
    };
  };

  evaluate = module:
    (nixosSystem {
      inherit system;
      modules = [ self.nixosModules.rustfs baseModule module ];
    }).config;

  legacyLocal = evaluate {
    services.rustfs.volumes = "/mnt/rustfs0,/mnt/rustfs1";
  };

  invalidMultiPool = evaluate {
    services.rustfs.pools = [
      { volumes = [ "/mnt/rustfs0" ]; }
      { volumes = [ "/mnt/rustfs1" "/mnt/rustfs2" ]; }
    ];
  };

  hasFailedAssertion = configuration: lib.any (entry: !entry.assertion) configuration.assertions;
  localEnvironment = legacyLocal.systemd.services.rustfs.environment;
  ok =
    localEnvironment.RUSTFS_VOLUMES == "/mnt/rustfs0 /mnt/rustfs1"
    && hasFailedAssertion invalidMultiPool;
in
assert ok;
pkgs.runCommand "rustfs-module-options-test" { } ''
  touch $out
''
