{ config, lib, pkgs, ... }:

let
  cfg = config.services.rustfs;

  envFile = pkgs.writeText "rustfs.env" ''
    RUSTFS_ACCESS_KEY=${cfg.accessKey}
    RUSTFS_SECRET_KEY=${cfg.secretKey}
    RUSTFS_VOLUMES="${cfg.volumes}"
    RUSTFS_ADDRESS="${cfg.address}"
    RUSTFS_CONSOLE_ENABLE=${lib.boolToString cfg.consoleEnable}
    RUST_LOG=${cfg.logLevel}
    RUSTFS_OBS_LOG_DIRECTORY="${cfg.logDirectory}"
  '';
  startScript = pkgs.writeShellScriptBin "rustfs" ''
    . /etc/default/rustfs
    exec ${cfg.package}/bin/rustfs $RUSTFS_VOLUMES
  '';
in
{
  options.services.rustfs = {
    enable = lib.mkEnableOption "RustFS object storage server";

    package = lib.mkOption {
      type = lib.types.package;
      description = "RustFS package providing the rustfs binary";
    };

    accessKey = lib.mkOption {
      type = lib.types.str;
      default = "rustfsadmin";
    };

    secretKey = lib.mkOption {
      type = lib.types.str;
      default = "rustfsadmin";
    };

    volumes = lib.mkOption {
      type = lib.types.str;
      default = "/data/rustfs0";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = ":9000";
    };

    consoleEnable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "error";
    };

    logDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/var/log/rustfs";
    };

    tlsDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/opt/tls";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.rustfs.package must be set";
      }
    ];

    environment.etc."default/rustfs".source = envFile;

    systemd.tmpfiles.rules =
      [
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
