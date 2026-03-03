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

{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.services.rustfs;

  # Helper to handle volumes as list or string
  volumesStr =
    if builtins.isList cfg.volumes
    then lib.concatStringsSep "," cfg.volumes
    else cfg.volumes;

  volumesList =
    if builtins.isList cfg.volumes
    then cfg.volumes
    else [ cfg.volumes ];
in
{
  imports = [
    (lib.mkRenamedOptionModule
      [ "services" "rustfs" "accessKey" ]
      [ "services" "rustfs" "accessKeyFile" ]
    )
    (lib.mkRenamedOptionModule
      [ "services" "rustfs" "secretKey" ]
      [ "services" "rustfs" "secretKeyFile" ]
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
      description = ''
        Path to a file containing the access key for client authentication.
        Use a runtime path (e.g. /run/secrets/…) to prevent the secret from being copied into the Nix store.
        The file must be readable by root/systemd (not by the rustfs service user directly); systemd reads it
        via LoadCredential and exposes a copy in the service's credential directory ($CREDENTIALS_DIRECTORY).
        For security best practices, use secret management tools like sops-nix, agenix, or NixOps keys.
      '';
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/secrets/rustfs-secret-key";
      description = ''
        Path to a file containing the secret key for client authentication.
        Use a runtime path (e.g. /run/secrets/…) to prevent the secret from being copied into the Nix store.
        The file must be readable by root/systemd (not by the rustfs service user directly); systemd reads it
        via LoadCredential and exposes a copy in the service's credential directory ($CREDENTIALS_DIRECTORY).
        For security best practices, use secret management tools like sops-nix, agenix, or NixOps keys.
      '';
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
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Directory where RustFS service logs are written to files.
        If null (default), logs are written to systemd journal only.
        Set to a path (e.g., "/var/log/rustfs") to enable file logging.
      '';
    };

    tlsDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/etc/rustfs/tls";
      description = "Directory containing TLS certificates.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups = lib.mkIf (cfg.group == "rustfs") {
      rustfs = { };
    };

    users.users = lib.mkIf (cfg.user == "rustfs") {
      rustfs = {
        group = cfg.group;
        isSystemUser = true;
        description = "RustFS service user";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.tlsDirectory} 0750 ${cfg.user} ${cfg.group} -"
    ] ++ (map (vol: "d ${vol} 0750 ${cfg.user} ${cfg.group} -") volumesList)
    ++ (lib.optional (cfg.logDirectory != null) "d ${cfg.logDirectory} 0750 ${cfg.user} ${cfg.group} -");

    systemd.services.rustfs = {
      description = "RustFS Object Storage Server";
      documentation = [ "https://rustfs.com/docs/" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # Environment variables
      environment = {
        RUSTFS_VOLUMES = volumesStr;
        RUSTFS_ADDRESS = cfg.address;
        RUSTFS_CONSOLE_ENABLE = lib.boolToString cfg.consoleEnable;
        RUSTFS_CONSOLE_ADDRESS = cfg.consoleAddress;
        RUST_LOG = cfg.logLevel;
        # Use %d to reference the credentials directory set by LoadCredential
        RUSTFS_ACCESS_KEY = "file:%d/access-key";
        RUSTFS_SECRET_KEY = "file:%d/secret-key";
      } // lib.optionalAttrs (cfg.logDirectory != null) {
        RUSTFS_OBS_LOG_DIRECTORY = cfg.logDirectory;
      } // cfg.extraEnvironmentVariables;

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Type = "simple";

        # Main service executable
        ExecStart = "${cfg.package}/bin/rustfs";

        # Security: Use LoadCredential to securely pass secrets to the service.
        # This avoids permission issues with the service user reading secret files directly,
        # and keeps secrets out of environment variables (which can leak).
        # The credentials are available in the directory referenced by %d placeholder.
        LoadCredential = [
          "access-key:${cfg.accessKeyFile}"
          "secret-key:${cfg.secretKeyFile}"
        ];

        # Resource Limits and Performance
        LimitNOFILE = 1048576;
        LimitNPROC = 32768;

        # Restart settings for better reliability
        Restart = "always";
        RestartSec = "10s";
        TimeoutStartSec = "60s";
        TimeoutStopSec = "30s";

        # Security Hardening
        # Minimize capabilities - RustFS doesn't need any special capabilities
        CapabilityBoundingSet = "";
        # Restrict device access
        DevicePolicy = "closed";
        # Prevent privilege escalation
        NoNewPrivileges = true;
        # Use private /dev
        PrivateDevices = true;
        # Use private /tmp
        PrivateTmp = true;
        # Use private user namespace for better isolation
        PrivateUsers = true;
        # Protect system clock
        ProtectClock = true;
        # Protect cgroup filesystem
        ProtectControlGroups = true;
        # Don't allow access to home directories
        ProtectHome = true;
        # Protect hostname from changes
        ProtectHostname = true;
        # Protect kernel logs
        ProtectKernelLogs = true;
        # Protect kernel modules
        ProtectKernelModules = true;
        # Protect kernel tunables
        ProtectKernelTunables = true;
        # Make /proc minimal
        ProtectProc = "invisible";
        # Make system directories read-only except for paths we explicitly allow
        ProtectSystem = "strict";
        # Restrict /proc access
        ProcSubset = "pid";
        # Restrict network address families to what's needed
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        # Restrict namespaces
        RestrictNamespaces = true;
        # Prevent realtime scheduling
        RestrictRealtime = true;
        # Prevent setuid/setgid
        RestrictSUIDSGID = true;
        # Restrict to native system calls only
        SystemCallArchitectures = "native";
        # Allow only safe system calls
        SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
        # Prevent memory mapping executable
        MemoryDenyWriteExecute = true;
        # Prevent personality changes
        LockPersonality = true;
        # Set restrictive umask
        UMask = "0077";

        # Grant write access to necessary directories
        ReadWritePaths = [ cfg.tlsDirectory ] ++ volumesList
          ++ lib.optional (cfg.logDirectory != null) cfg.logDirectory;

        # Logging: Default to systemd journal, optionally write to files
        StandardOutput =
          if cfg.logDirectory != null
          then "append:${cfg.logDirectory}/rustfs.log"
          else "journal";
        StandardError =
          if cfg.logDirectory != null
          then "append:${cfg.logDirectory}/rustfs-err.log"
          else "journal";
      };
    };
  };
}
