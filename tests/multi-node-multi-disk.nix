{ pkgs, self }:

let
  lib = pkgs.lib;

  hosts = [ "node1" "node2" "node3" "node4" ];
  disks = [ "vdb" "vdc" "vdd" "vde" ];

  accessKey = "clusteradmin";
  secretKey = "a-strong-random-test-secret";

  localVolumes = lib.imap0 (i: _: "/mnt/rustfs${toString i}") disks;

  endpoints = lib.concatMap (volume: map (host: "http://${host}:9000${volume}") hosts) localVolumes;

  nodeConfig = name: { lib, ... }: {
    imports = [ self.nixosModules.rustfs ];

    virtualisation.emptyDiskImages = map (_: 1024) disks;
    virtualisation.memorySize = 2048;
    boot.supportedFilesystems = [ "xfs" ];

    networking.hostName = name;
    networking.firewall.allowedTCPPorts = [ 9000 ];


    virtualisation.fileSystems = lib.listToAttrs (
      lib.imap0
        (i: disk: lib.nameValuePair (builtins.elemAt localVolumes i) {
          device = "/dev/${disk}";
          fsType = "xfs";
          autoFormat = true;
        })
        disks
    );

    services.rustfs = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      pools = [
        {
          nodes = hosts;
          volumes = localVolumes;
        }
      ];
      port = 9000;
      address = "0.0.0.0:9000";
      consoleEnable = false;
      accessKeyFile = "/etc/rustfs-access-key";
      secretKeyFile = "/etc/rustfs-secret-key";
    };

    # Non-default credentials: RustFS derives the inter-node RPC secret from them
    # and refuses to derive one from rustfsadmin/rustfsadmin.
    environment.etc."rustfs-access-key".text = accessKey;
    environment.etc."rustfs-secret-key".text = secretKey;

    environment.systemPackages = [ pkgs.awscli2 ];
  };
in
pkgs.testers.runNixOSTest {
  name = "rustfs-multi-node-multi-disk";

  nodes = lib.listToAttrs (map (host: lib.nameValuePair host (nodeConfig host)) hosts);

  testScript = ''
    start_all()

    nodes = [${lib.concatStringsSep ", " hosts}]

    for node in nodes:
        node.wait_for_unit("rustfs.service")
        node.wait_for_open_port(9000)

    node1.succeed(
        "systemctl show -p Environment rustfs.service | "
        "grep -q 'RUSTFS_VOLUMES=${lib.concatStringsSep " " endpoints}'"
    )

    # Each node must claim its own drives; 0 local endpoints means every disk
    # access becomes an RPC to itself, which then fails signature verification.
    for node in nodes:
        node.wait_until_succeeds(
            "journalctl -u rustfs.service | grep -q "
            "'\"total_endpoints\":${toString (builtins.length endpoints)},\"local_endpoints\":${toString (builtins.length localVolumes)}'",
            timeout=60,
        )

    node1.fail("systemctl show -p ReadWritePaths rustfs.service | grep -q 'http://'")
    node1.succeed("test ! -e '/http:'")
    for volume in [${lib.concatStringsSep ", " (map (v: "\"${v}\"") localVolumes)}]:
        node1.succeed(f"test -d {volume}")

    aws = (
        "AWS_ACCESS_KEY_ID=${accessKey} AWS_SECRET_ACCESS_KEY=${secretKey} "
        "AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url http://127.0.0.1:9000"
    )

    node1.wait_until_succeeds(aws + " s3 ls", timeout=300)

    node1.succeed(aws + " s3 mb s3://testbucket")
    node1.succeed("echo distributed > /tmp/obj.txt")
    node1.succeed(aws + " s3 cp /tmp/obj.txt s3://testbucket/obj.txt")

    for node in nodes[1:]:
        node.wait_until_succeeds(aws + " s3 ls s3://testbucket/", timeout=120)
        node.succeed(aws + " s3 cp s3://testbucket/obj.txt /tmp/roundtrip.txt")
        node.succeed("grep -q distributed /tmp/roundtrip.txt")

    for node in nodes:
        node.succeed("systemctl is-active rustfs.service")
  '';
}
