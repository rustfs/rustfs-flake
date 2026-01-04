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
              type = types.strMatching "^[^:]+:[0-9]+$";
              default = "127.0.0.1:9000";
              description = "Address and port for RustFS to listen on.";
            };

            consoleAddress = mkOption {
              type = types.strMatching "^[^:]+:[0-9]+$";
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
            # Ensure data directory exists with correct permissions (only if not using StateDirectory)
            systemd.tmpfiles.rules = lib.optionals (! lib.hasPrefix "/var/lib/" cfg.dataDir) [
              "d ${escapeShellArg cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
            ];

            systemd.services.rustfs = {
              description = "RustFS Object Storage Service";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                ExecStart = lib.concatStringsSep " " ([
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
              } // (lib.optionalAttrs (cfg.configFile != null) {
                ReadOnlyPaths = [ (builtins.dirOf cfg.configFile) ];
              }) // (lib.optionalAttrs (lib.hasPrefix "/var/lib/" cfg.dataDir) {
                StateDirectory = lib.removePrefix "/var/lib/" cfg.dataDir;
              });
            };

            users.users = mkIf (cfg.user == "rustfs") {
              rustfs = {
                description = "RustFS service user";
                group = cfg.group;
                isSystemUser = true;
                home = cfg.dataDir;
                createHome = false; # Created by StateDirectory or tmpfiles
              };
            };

            users.groups = mkIf (cfg.group == "rustfs" || (cfg.user == "rustfs" && cfg.group != "rustfs")) (
              { ${cfg.group} = { }; }
            );
          };
        };

      # Overlay for adding RustFS to nixpkgs
      overlays.default = final: prev: {
        rustfs = self.packages.${final.system}.rustfs;
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
              echo "Type 'rustfs --help' to see available commands"
            '';
          };
        }
      );
    };
}
