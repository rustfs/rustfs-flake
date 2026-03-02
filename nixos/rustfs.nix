# Copyright 2024 RustFS Team
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.rustfs;

  # Helper to handle volumes as list or string
  volumesStr = if builtins.isList cfg.volumes
               then lib.concatStringsSep "," cfg.volumes
               else cfg.volumes;

  volumesList = if builtins.isList cfg.volumes
                then cfg.volumes
                else [ cfg.volumes ];
in
{
  imports = [
    (lib.mkRenamedOptionModule
      [ "services" "rustfs" "accessKey" ]
      [ "services" "rustfs" "accessKeyFile" ]
      "World readable secrets is insecure and should be replaced with references to files"
    )
    (lib.mkRenamedOptionModule
      [ "services" "rustfs" "secretKey" ]
      [ "services" "rustfs" "secretKeyFile" ]
      "World readable secrets is insecure and should be replaced with references to files"
    )
  ];

  options.services.rustfs = {
    enable = lib.mkEnableOption "RustFS object storage server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.rustfs;
      description = "RustFS package providing the rustfs binary";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "rustfs";
      description = "User account under which RustFS runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "rustfs";
      description = "Group under which RustFS runs.";
    };

    extraEnvironmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for the RustFS service.";
    };

    accessKeyFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/secrets/rustfs-access-key";
      description = "Path to a file containing the access key for client authentication. Use a runtime path (e.g. /run/secrets/…) to prevent the secret from being copied into the Nix store.";
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/secrets/rustfs-secret-key";
      description = "Path to a file containing the secret key for client authentication. Use a runtime path (e.g. /run/secrets/…) to prevent the secret from being copied into the Nix store.";
    };

    volumes = lib.mkOption {
      type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
      default = [ "/var/lib/rustfs" ];
      description = "List of paths or comma-separated string where RustFS stores data.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = ":9000";
      description = "Network address for the API server (e.g., :9000).";
    };

    consoleEnable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the RustFS management console.";
    };

    consoleAddress = lib.mkOption {
      type = lib.types.str;
      default = ":9001";
      description = "Network address for the management console (e.g., :9001).";
    };

    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "info";
      description = "Log level (error, warn, info, debug, trace).";
    };

    logDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/var/log/rustfs";
      description = "Directory where RustFS service logs are written.";
    };

    tlsDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/etc/rustfs/tls";
      description = "Directory containing TLS certificates.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups = lib.mkIf (cfg.group == "rustfs") {
      rustfs = {};
    };

    users.users = lib.mkIf (cfg.user == "rustfs") {
      rustfs = {
        group = cfg.group;
        isSystemUser = true;
        description = "RustFS service user";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.logDirectory} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.tlsDirectory} 0750 ${cfg.user} ${cfg.group} -"
    ] ++ (map (vol: "d ${vol} 0750 ${cfg.user} ${cfg.group} -") volumesList);

    systemd.services.rustfs = {
      description = "RustFS Object Storage Server";
      documentation = [ "https://rustfs.com/docs/" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Type = "simple";

        # Environment variables
        Environment = [
          "RUSTFS_VOLUMES=${volumesStr}"
          "RUSTFS_ADDRESS=${cfg.address}"
          "RUSTFS_CONSOLE_ENABLE=${lib.boolToString cfg.consoleEnable}"
          "RUSTFS_CONSOLE_ADDRESS=${cfg.consoleAddress}"
          "RUST_LOG=${cfg.logLevel}"
          "RUSTFS_OBS_LOG_DIRECTORY=${cfg.logDirectory}"
        ] ++ (lib.mapAttrsToList (n: v: "${n}=${v}") cfg.extraEnvironmentVariables);

        # Security: Use LoadCredential to securely pass secrets to the service.
        # This avoids permission issues with the service user reading secret files directly,
        # and keeps secrets out of environment variables (which can leak).
        LoadCredential = [
          "access-key:${cfg.accessKeyFile}"
          "secret-key:${cfg.secretKeyFile}"
        ];

        ExecStart = pkgs.writeShellScript "rustfs-start" ''
          # Read secrets from systemd credentials directory
          export RUSTFS_ACCESS_KEY="$(< "$CREDENTIALS_DIRECTORY/access-key")"
          export RUSTFS_SECRET_KEY="$(< "$CREDENTIALS_DIRECTORY/secret-key")"

          exec ${cfg.package}/bin/rustfs
        '';

        LimitNOFILE = 1048576;
        LimitNPROC = 32768;
        Restart = "always";
        RestartSec = "10s";

        # Security Hardening
        CapabilityBoundingSet = "";
        DevicePolicy = "closed";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        ProcSubset = "pid";
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" "~@privileged" ];
        UMask = "0077";

        # Logging
        StandardOutput = "append:${cfg.logDirectory}/rustfs.log";
        StandardError = "append:${cfg.logDirectory}/rustfs-err.log";
      };
    };
  };
}
