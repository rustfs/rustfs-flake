{
  description = "RustFS - High-performance S3-compatible object storage for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rustfs = {
      url = "github:rustfs/rustfs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rustfs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      # Export the RustFS package from upstream
      packages = forAllSystems (system: {
        default = rustfs.packages.${system}.default;
        rustfs = rustfs.packages.${system}.default;
      });

      # NixOS module for running RustFS as a service
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.rustfs;
        in
        {
          options.services.rustfs = {
            enable = mkEnableOption "RustFS object storage service";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.rustfs;
              defaultText = literalExpression "self.packages.\${pkgs.system}.rustfs";
              description = "The RustFS package to use.";
            };

            dataDir = mkOption {
              type = types.path;
              default = "/var/lib/rustfs";
              description = "Directory where RustFS will store data.";
            };

            configFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Path to RustFS configuration file.";
            };

            user = mkOption {
              type = types.str;
              default = "rustfs";
              description = "User account under which RustFS runs.";
            };

            group = mkOption {
              type = types.str;
              default = "rustfs";
              description = "Group under which RustFS runs.";
            };

            address = mkOption {
              type = types.str;
              default = "127.0.0.1:9000";
              description = "Address and port for RustFS to listen on.";
            };

            consoleAddress = mkOption {
              type = types.str;
              default = "127.0.0.1:9001";
              description = "Address and port for RustFS console to listen on.";
            };

            extraArgs = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Extra arguments to pass to RustFS.";
            };
          };

          config = mkIf cfg.enable {
            # Ensure data directory exists with correct permissions
            systemd.tmpfiles.rules = [
              "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} - -"
            ];

            systemd.services.rustfs = {
              description = "RustFS Object Storage Service";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                ExecStart = lib.escapeShellArgs ([
                  "${cfg.package}/bin/rustfs"
                  "server"
                  cfg.dataDir
                  "--address"
                  cfg.address
                  "--console-address"
                  cfg.consoleAddress
                ] ++ lib.optionals (cfg.configFile != null) [
                  "--config"
                  cfg.configFile
                ] ++ cfg.extraArgs);
                Restart = "on-failure";
                RestartSec = "5s";

                # Security hardening
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                ReadWritePaths = [ cfg.dataDir ];
              };
            };

            users.users = mkIf (cfg.user == "rustfs") {
              rustfs = {
                description = "RustFS service user";
                group = cfg.group;
                isSystemUser = true;
                home = cfg.dataDir;
                createHome = false; # Created by tmpfiles instead
              };
            };

            users.groups = mkIf (cfg.group == "rustfs") {
              rustfs = { };
            };
          };
        };

      # Overlay for adding RustFS to nixpkgs
      overlays.default = final: prev: {
        rustfs = self.packages.${prev.system}.rustfs;
      };

      # Development shell
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              self.packages.${system}.rustfs
            ];
            shellHook = ''
              echo "RustFS development environment"
              echo "RustFS version: $(rustfs --version 2>/dev/null || echo 'unknown')"
            '';
          };
        }
      );
    };
}
