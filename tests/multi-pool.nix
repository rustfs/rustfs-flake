{ pkgs, self }:

let
  disks = [
    "vdb"
    "vdc"
    "vdd"
    "vde"
    "vdf"
    "vdg"
    "vdh"
    "vdi"
  ];
  volumes = pkgs.lib.imap0 (i: _: "/mnt/rustfs${toString i}") disks;
  firstPool = pkgs.lib.take 4 volumes;
  secondPool = pkgs.lib.drop 4 volumes;
in
pkgs.testers.runNixOSTest {
  name = "rustfs-multi-pool";

  nodes.machine =
    { lib, ... }:
    {
      imports = [ self.nixosModules.rustfs ];

      virtualisation.emptyDiskImages = map (_: 1024) disks;
      virtualisation.memorySize = 2048;
      boot.supportedFilesystems = [ "xfs" ];

      virtualisation.fileSystems = lib.listToAttrs (
        lib.imap0 (
          i: disk:
          lib.nameValuePair (builtins.elemAt volumes i) {
            device = "/dev/${disk}";
            fsType = "xfs";
            autoFormat = true;
          }
        ) disks
      );

      services.rustfs = {
        enable = true;
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        # A second pool is how a cluster grows: the first keeps what it stores and
        # the new one takes the writes, rather than everything rebalancing at once.
        pools = [
          { volumes = firstPool; }
          { volumes = secondPool; }
        ];
        address = "127.0.0.1:9000";
        consoleEnable = false;
        accessKeyFile = "/etc/rustfs-access-key";
        secretKeyFile = "/etc/rustfs-secret-key";
      };

      environment.etc."rustfs-access-key".text = "rustfsadmin";
      environment.etc."rustfs-secret-key".text = "rustfsadmin";
      environment.systemPackages = [
        pkgs.awscli2
        self.packages.${pkgs.stdenv.hostPlatform.system}.cli
      ];
    };

  testScript = ''
    machine.wait_for_unit("rustfs.service")
    machine.wait_for_open_port(9000)

    # Each pool collapses to its own ellipsis expression. Listing the drives plainly
    # would make rustfs read all eight as a single pool.
    machine.succeed(
        "systemctl show -p Environment rustfs.service | "
        "grep -q 'RUSTFS_VOLUMES=/mnt/rustfs{0...3} /mnt/rustfs{4...7}'"
    )

    aws = (
        "AWS_ACCESS_KEY_ID=rustfsadmin AWS_SECRET_ACCESS_KEY=rustfsadmin "
        "AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url http://127.0.0.1:9000"
    )
    machine.wait_until_succeeds(aws + " s3 ls", timeout=120)

    # What rustfs itself believes, rather than what we asked for.
    machine.succeed(
        "rc alias set t http://127.0.0.1:9000 rustfsadmin rustfsadmin"
    )
    pools = machine.succeed("rc admin pool list t --json")
    import json
    listed = json.loads(pools)["pools"]
    assert len(listed) == 2, f"expected two pools, got {listed}"
    assert all(p["status"] == "active" for p in listed), f"pool not active: {listed}"

    machine.succeed(aws + " s3 mb s3://testbucket")
    machine.succeed("echo hello > /tmp/obj.txt")
    machine.succeed(aws + " s3 cp /tmp/obj.txt s3://testbucket/obj.txt")
    machine.succeed(aws + " s3 cp s3://testbucket/obj.txt /tmp/roundtrip.txt")
    machine.succeed("grep -q hello /tmp/roundtrip.txt")

    machine.succeed("systemctl is-active rustfs.service")
  '';
}
