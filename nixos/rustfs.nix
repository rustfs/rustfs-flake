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

  # A literal, so it carries 'nodes' itself: the submodule's defaults never reach it.
  pools =
    if cfg.pools != [ ] then
      cfg.pools
    else
      [
        {
          nodes = [ ];
          volumes = [ "/var/lib/rustfs" ];
        }
      ];

  inherit (import ./pool-naming.nix { inherit lib; })
    rangeable
    consistentlyPadded
    ellipsisOf
    ;

  # Both only matter past a single pool, where each has to be one expression.
  nameLists = lib.concatMap (
    pool: [ pool.volumes ] ++ lib.optional (pool.nodes != [ ]) pool.nodes
  ) pools;

  unrangeable = builtins.filter (items: !rangeable items) nameLists;
  mixedPadding = builtins.filter (items: rangeable items && !consistentlyPadded items) nameLists;

  # An IPv6 literal needs brackets or its colons run into the port separator.
  bracketIfIpv6 = host: if lib.hasInfix ":" host then "[${host}]" else host;
  urlFor = host: volume: "http://${bracketIfIpv6 host}:${toString cfg.port}${volume}";

  # Drive-major, so an erasure set spans nodes instead of sitting on one.
  endpointsOf =
    pool:
    if pool.nodes == [ ] then
      pool.volumes
    else
      lib.concatMap (volume: map (node: urlFor node volume) pool.nodes) pool.volumes;

  ellipsisPool =
    pool:
    if pool.nodes == [ ] then
      ellipsisOf pool.volumes
    else
      urlFor (ellipsisOf pool.nodes) (ellipsisOf pool.volumes);

  localVolumes = lib.unique (lib.concatMap (pool: pool.volumes) pools);
  driveCount = pool: builtins.length pool.volumes * (lib.max 1 (builtins.length pool.nodes));

  # One pool can be listed drive by drive, which puts no shape on the names. Several
  # cannot: rustfs reads plain arguments as a single pool and refuses the mixture.
  volumesStr = lib.concatStringsSep " " (
    if builtins.length pools <= 1 then lib.concatMap endpointsOf pools else map ellipsisPool pools
  );
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

    # volumes predates the pool model
    (lib.mkChangedOptionModule [ "services" "rustfs" "volumes" ] [ "services" "rustfs" "pools" ]
      (config: [ { volumes = config.services.rustfs.volumes; } ])
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

    pools = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
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
                Hostnames making up this pool, resolvable from every node of it.
                Left empty the drives are local paths, which is the single-node case.
              '';
            };
            volumes = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              example = [
                "/mnt/disk0"
                "/mnt/disk1"
                "/mnt/disk2"
                "/mnt/disk3"
              ];
              description = ''
                Drive paths, each on its own filesystem. Every node of the pool uses
                the same layout.
              '';
            };
          };
        }
      );
      default = [ ];
      defaultText = lib.literalExpression ''[ { volumes = [ "/var/lib/rustfs" ]; } ]'';
      example = [
        {
          volumes = [
            "/mnt/disk0"
            "/mnt/disk1"
            "/mnt/disk2"
            "/mnt/disk3"
          ];
        }
        {
          nodes = [
            "node1"
            "node2"
            "node3"
            "node4"
          ];
          volumes = [
            "/mnt/disk0"
            "/mnt/disk1"
            "/mnt/disk2"
            "/mnt/disk3"
          ];
        }
      ];
      description = ''
        Server pools, in order. Every RustFS deployment is one of these -- a single
        drive, one node of four, four nodes of four -- so this is the only place
        drives are declared.

        Appending a pool is how a cluster grows without rebalancing what it already
        stores, and the only route from a single-node deployment to a distributed
        one; draining the old pool afterwards is `rc admin decommission`.

        A lone pool is listed drive by drive, so its names take any shape. Several
        cannot be: RustFS reads plain arguments as one pool and rejects mixing the
        two forms, so each pool has to collapse into a single ellipsis expression
        such as `node{2...5}`. That needs a common prefix and a contiguous numeric
        range, which a single-node pool does not need for its hostname.

        Keep the list identical and in the same order on every node: RustFS derives
        pool identity from it, so a divergent list is a different cluster.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Port peers reach each other on, matching `address`.";
    };

    erasureSetDriveCount = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 4;
      description = ''
        Drives per erasure set. Left null RustFS picks a divisor of the pool's drive
        count itself; set it when the split matters, such as one set spanning all
        four nodes of a pool rather than sitting inside one.
      '';
    };

    storageClassStandardParity = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 2;
      description = ''
        Parity drives per erasure set for the STANDARD storage class. Two of four
        tolerates one node of a four-node set going away while writes continue.
      '';
    };

    storageClassRrsParity = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 1;
      description = "Parity drives per erasure set for the REDUCED_REDUNDANCY class.";
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
    assertions = [
      {
        assertion = pools != [ ];
        message = "services.rustfs.pools cannot be empty -- RustFS needs at least one drive.";
      }
      {
        assertion = builtins.length pools <= 1 || unrangeable == [ ];
        message = "services.rustfs.pools: ${builtins.toJSON unrangeable} cannot each be named as one rustfs pool. Past a single pool every name list has to collapse to an ellipsis expression, so it needs a common prefix and a contiguous numeric range such as node{2...5}.";
      }
      {
        assertion = builtins.length pools <= 1 || mixedPadding == [ ];
        message = "services.rustfs.pools: ${builtins.toJSON mixedPadding} mixes zero-padded and bare numbers. An ellipsis carries the low bound's width across the range, so these would expand to drive names you never declared -- pad all of them or none.";
      }
      {
        assertion = lib.all (pool: pool.volumes != [ ]) pools;
        message = "every services.rustfs.pools entry needs at least one drive.";
      }
      # A pool's drives are dealt into erasure sets, so the count has to divide.
      {
        assertion =
          cfg.erasureSetDriveCount != null
          -> lib.all (pool: lib.mod (driveCount pool) cfg.erasureSetDriveCount == 0) pools;
        message = "every services.rustfs.pools entry needs a drive count divisible by erasureSetDriveCount (${toString cfg.erasureSetDriveCount}); got ${
          lib.concatMapStringsSep ", " (pool: toString (driveCount pool)) pools
        }.";
      }
      # Parity is taken out of the set, so it cannot claim the whole of it.
      {
        assertion =
          lib.all
            (parity: parity != null && cfg.erasureSetDriveCount != null -> parity < cfg.erasureSetDriveCount)
            [
              cfg.storageClassStandardParity
              cfg.storageClassRrsParity
            ];
        message = "services.rustfs storage class parity must be below erasureSetDriveCount (${toString cfg.erasureSetDriveCount}).";
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
    ++ (lib.optional (
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
      // lib.optionalAttrs (cfg.erasureSetDriveCount != null) {
        RUSTFS_ERASURE_SET_DRIVE_COUNT = toString cfg.erasureSetDriveCount;
      }
      // lib.optionalAttrs (cfg.storageClassStandardParity != null) {
        RUSTFS_STORAGE_CLASS_STANDARD = "EC:${toString cfg.storageClassStandardParity}";
      }
      // lib.optionalAttrs (cfg.storageClassRrsParity != null) {
        RUSTFS_STORAGE_CLASS_RRS = "EC:${toString cfg.storageClassRrsParity}";
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
