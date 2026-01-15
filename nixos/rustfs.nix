{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.rustfs;

  envFile = pkgs.writeText "rustfs.env" (
    ''
      RUSTFS_ACCESS_KEY=${cfg.accessKey}
      RUSTFS_SECRET_KEY=${cfg.secretKey}
      RUSTFS_VOLUMES="${cfg.volumes}"
      RUSTFS_ADDRESS="${cfg.address}"
      RUSTFS_CONSOLE_ENABLE=${lib.boolToString cfg.consoleEnable}
      RUST_LOG=${cfg.logLevel}
      RUSTFS_OBS_LOG_DIRECTORY="${cfg.logDirectory}"
    ''
    + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "${name}=${value}") cfg.extraEnvironmentVariables
    )
  );
in
{
  options.services.rustfs = {
    enable = lib.mkEnableOption "RustFS object storage server";

    package = lib.mkOption {
      type = lib.types.package;
      description = "RustFS package providing the rustfs binary";
    };

    extraEnvironmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Additional environment variables to set for the RustFS service.
        These will be appended to the environment file at /etc/default/rustfs.
        Used for advanced configuration not covered by other options. (e.g. `RUST_BACKTRACE`)
      '';
    };

    accessKey = lib.mkOption {
      type = lib.types.str;
      default = "rustfsadmin";
      description = ''
        Access key used by RustFS for client authentication.
        This value is exported as the RUSTFS_ACCESS_KEY environment variable.
        Use a strong, secret value in production deployments.
      '';
    };

    secretKey = lib.mkOption {
      type = lib.types.str;
      default = "rustfsadmin";
      description = ''
        Secret key used by RustFS for signing and authorization.
        This value is exported as the RUSTFS_SECRET_KEY environment variable.
        Treat this as a credential and avoid committing it to version control.
      '';
    };

    volumes = lib.mkOption {
      type = lib.types.str;
      default = "/data/rustfs0";
      description = ''
        Storage volume configuration for RustFS.
        Typically a path or a comma-separated list of paths where RustFS stores data,
        exported as the RUSTFS_VOLUMES environment variable.
      '';
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = ":9000";
      description = ''
        Network address RustFS listens on, for example ":9000" or "127.0.0.1:9000".
        This is exported as the RUSTFS_ADDRESS environment variable.
        Adjust this to control which interfaces and port are exposed.
      '';
    };

    consoleEnable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable the RustFS management console.
        When enabled, the console can be accessed using the configured address.
      '';
    };

    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "error";
      description = ''
        Log level for the RustFS service, passed via the RUST_LOG environment variable.
        Common values include "error", "warn", "info", "debug", and "trace".
      '';
    };

    logDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/var/log/rustfs";
      description = ''
        Directory where RustFS service logs are written.
        Systemd StandardOutput and StandardError are appended to files in this directory.
      '';
    };

    tlsDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/opt/tls";
      description = ''
        Directory containing TLS certificates and keys used by RustFS, if TLS is enabled.
        Configure this to point to the location of your certificate and key files.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."default/rustfs".source = envFile;

    systemd.tmpfiles.rules = [
      "d ${cfg.logDirectory} 0750 root root -"
      "d ${cfg.tlsDirectory} 0750 root root -"
    ];

    systemd.services.rustfs = {
      description = "RustFS Object Storage Server";
      documentation = [ "https://rustfs.com/docs/" ];

      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "notify";
        NotifyAccess = "main";

        User = "root";
        Group = "root";

        ExecStart = "${pkgs.bash}/bin/bash -c '${startScript}/bin/rustfs'";

        LimitNOFILE = 1048576;
        LimitNPROC = 32768;
        TasksMax = "infinity";

        Restart = "always";
        RestartSec = "10s";

        OOMScoreAdjust = -1000;
        SendSIGKILL = false;

        TimeoutStartSec = "30s";
        TimeoutStopSec = "30s";

        NoNewPrivileges = true;

        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;

        StandardOutput = "append:${cfg.logDirectory}/rustfs.log";
        StandardError = "append:${cfg.logDirectory}/rustfs-err.log";
      };
    };
  };
}
