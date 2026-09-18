{ pkgs, self }:

let
  lib = pkgs.lib;
  system = pkgs.stdenv.hostPlatform.system;

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
    lib.nixosSystem {
      inherit system;
      modules = [ self.nixosModules.rustfs baseModule module ];
    };

  legacyLocal = evaluate {
    services.rustfs.volumes = "/mnt/rustfs0,/mnt/rustfs1";
  };

  legacyDistributed = evaluate {
    services.rustfs = {
      distributed = {
        enable = true;
        nodes = [ "node1" "node2" ];
        volumes = [ "/mnt/rustfs0" "/mnt/rustfs1" ];
        port = 9002;
        localEndpointHost = "node1";
      };
      address = "0.0.0.0:9002";
    };
  };

  invalidMultiPool = evaluate {
    services.rustfs.pools = [
      { volumes = [ "/mnt/rustfs0" ]; }
      { volumes = [ "/mnt/rustfs1" "/mnt/rustfs2" ]; }
    ];
  };

  hasFailedAssertion = configuration: lib.any (entry: !entry.assertion) configuration.assertions;
  localEnvironment = legacyLocal.config.systemd.services.rustfs.environment;
  distributedEnvironment = legacyDistributed.config.systemd.services.rustfs.environment;
  ok =
    localEnvironment.RUSTFS_VOLUMES == "/mnt/rustfs0 /mnt/rustfs1"
    && distributedEnvironment.RUSTFS_VOLUMES
      == "http://node1:9002/mnt/rustfs0 http://node2:9002/mnt/rustfs0 http://node1:9002/mnt/rustfs1 http://node2:9002/mnt/rustfs1"
    && !(distributedEnvironment ? RUSTFS_LOCAL_ENDPOINT_HOST)
    && hasFailedAssertion invalidMultiPool.config;
in
assert ok;
pkgs.runCommand "rustfs-module-options-test" { } ''
  touch $out
''
