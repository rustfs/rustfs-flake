{ config, lib, pkgs, ... }:

let
  cfg = config.services.rustfs;

  envFile = pkgs.writeText "rustfs.env" (
    ''
      RUSTFS_ACCESS_KEY=${cfg.accessKey}
      RUSTFS_SECRET_KEY=${cfg.secretKey}
      RUSTFS_VOLUMES="${cfg.volumes}"
      RUSTFS_ADDRESS="${cfg.address}"
      RUSTFS_CONSOLE_ENABLE=${lib.boolToString cfg.consoleEnable}
      RUSTFS_CONSOLE_ADDRESS="${cfg.consoleAddress}"
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
      default = pkgs.rustfs;
      description = "RustFS package providing the rustfs binary";
    };

    extraEnvironmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for the RustFS service.";
    };

    accessKey = lib.mkOption {
      type = lib.types.str;
      default = "rustfsadmin";
      description = "Access key for client authentication.";
    };

    secretKey = lib.mkOption {
      type = lib.types.str;
      default = "rustfsadmin";
      description = "Secret key for signing and authorization.";
    };

    volumes = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/rustfs";
      description = "Comma-separated list of paths where RustFS stores data.";
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
    systemd.tmpfiles.rules = [
      "d ${cfg.logDirectory} 0750 root root -"
      "d ${cfg.tlsDirectory} 0750 root root -"
      "d ${cfg.volumes} 0750 root root -"
    ];

    systemd.services.rustfs = {
      description = "RustFS Object Storage Server";
      documentation = [ "https://rustfs.com/docs/" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/rustfs";
        EnvironmentFile = envFile;

        LimitNOFILE = 1048576;
        LimitNPROC = 32768;
        Restart = "always";
        RestartSec = "10s";

        NoNewPrivileges = true;
        ProtectHome = true;
        PrivateTmp = true;
        ProtectSystem = "full";

        StandardOutput = "append:${cfg.logDirectory}/rustfs.log";
        StandardError = "append:${cfg.logDirectory}/rustfs-err.log";
      };
    };
  };
}
