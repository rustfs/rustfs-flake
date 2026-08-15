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

  dist = cfg.distributed;

  configuredVolumes =
    if builtins.isList cfg.volumes then
      cfg.volumes
    else
      lib.filter (v: v != "") (lib.splitString "," cfg.volumes);

  localVolumes = if dist.enable then dist.volumes else configuredVolumes;

  # Every node must be given the identical endpoint list, ordered drive-major so an
  # erasure set spans nodes instead of sitting on one.
  endpoints = lib.concatMap
    (
      volume: map (node: "http://${node}:${toString dist.port}${volume}") dist.nodes
    )
    dist.volumes;

  volumesStr = lib.concatStringsSep " " (if dist.enable then endpoints else configuredVolumes);
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

    distributed = {
      enable = lib.mkEnableOption "a distributed RustFS cluster spanning several nodes";

      nodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "node1"
          "node2"
          "node3"
          "node4"
        ];
        description = ''
          Hostnames of every node in the cluster, resolvable from each of them.
          Used to render the shared endpoint list; set identically on all nodes.
        '';
      };

      volumes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "/mnt/disk0"
          "/mnt/disk1"
          "/mnt/disk2"
          "/mnt/disk3"
        ];
        description = ''
          Drive paths present on each node, each on its own filesystem. Every node
          uses the same layout, so this replaces `volumes` when distributed mode is
          enabled and is what gets created and made writable locally.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 9000;
        description = "Port peers reach each other on, matching `address`.";
      };

      localEndpointHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Which entry of `nodes` identifies this machine, so it claims its own
          drives instead of reaching them over RPC. Normally unnecessary: RustFS
          resolves each endpoint host and recognises the addresses that are its
          own, wildcard bind included. Set it only when that inference fails.

          RustFS 1.0.0-rc.1 accepts this in orchestrated mode alone, which it
          infers from running under Kubernetes, so on a plain host it refuses to
          start. Pass it through `extraEnvironmentVariables` if you do run this
          module inside a pod.
        '';
      };
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
    # Erasure coding needs 4 drives; a distributed cluster needs 4 nodes of 4.
    assertions = [
      {
        assertion = dist.enable -> builtins.length dist.nodes >= 4;
        message = "services.rustfs.distributed.nodes needs at least 4 nodes, got ${toString (builtins.length dist.nodes)}.";
      }
      {
        assertion = dist.enable -> builtins.length dist.volumes >= 4;
        message = "services.rustfs.distributed.volumes needs at least 4 drives per node, got ${toString (builtins.length dist.volumes)}.";
      }
      {
        assertion =
          dist.localEndpointHost != null -> builtins.elem dist.localEndpointHost dist.nodes;
        message = "services.rustfs.distributed.localEndpointHost is ${toString dist.localEndpointHost}, which is not one of nodes (${lib.concatStringsSep ", " dist.nodes}).";
      }
    ];

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
    ]
    ++ (map (vol: "d ${vol} 0750 ${cfg.user} ${cfg.group} -") localVolumes)
    ++ (lib.optional
      (
        cfg.logDirectory != null
      ) "d ${cfg.logDirectory} 0750 ${cfg.user} ${cfg.group} -");

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
        RUSTFS_ACCESS_KEY_FILE = "%d/access-key";
        RUSTFS_SECRET_KEY_FILE = "%d/secret-key";
      }
      // lib.optionalAttrs (cfg.logDirectory != null) {
        RUSTFS_OBS_LOG_DIRECTORY = cfg.logDirectory;
      }
      // lib.optionalAttrs (dist.localEndpointHost != null) {
        RUSTFS_LOCAL_ENDPOINT_HOST = dist.localEndpointHost;
      }
      // cfg.extraEnvironmentVariables;

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
        # Restrict /proc access; multi-drive setups need /proc/mounts for rustfs'
        # cross-device mount validation, which "pid" hides.
        ProcSubset = if builtins.length localVolumes > 1 then "all" else "pid";
        # Restrict network address families to what's needed
        # AF_NETLINK: getifaddrs needs it to enumerate local interfaces, which is how
        # RustFS decides which endpoints are its own drives rather than a peer's.
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
        # Restrict namespaces
        RestrictNamespaces = true;
        # Prevent realtime scheduling
        RestrictRealtime = true;
        # Prevent setuid/setgid
        RestrictSUIDSGID = true;
        # Restrict to native system calls only
        SystemCallArchitectures = "native";
        # Allow only safe system calls
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        # Prevent memory mapping executable
        MemoryDenyWriteExecute = true;
        # Prevent personality changes
        LockPersonality = true;
        # Set restrictive umask
        UMask = "0077";

        # Grant write access to necessary directories
        ReadWritePaths = [
          cfg.tlsDirectory
        ]
        ++ localVolumes
        ++ lib.optional (cfg.logDirectory != null) cfg.logDirectory;

        # Logging: Default to systemd journal, optionally write to files
        StandardOutput =
          if cfg.logDirectory != null then "append:${cfg.logDirectory}/rustfs.log" else "journal";
        StandardError =
          if cfg.logDirectory != null then "append:${cfg.logDirectory}/rustfs-err.log" else "journal";
      };
    };
  };
}
