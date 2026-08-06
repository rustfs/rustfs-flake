{ pkgs, self }:

let
  disks = [ "vdb" "vdc" "vdd" "vde" ];
  volumes = pkgs.lib.imap0 (i: _: "/mnt/rustfs${toString i}") disks;
in
pkgs.testers.runNixOSTest {
  name = "rustfs-single-node-multi-disk";

  nodes.machine = { lib, ... }: {
    imports = [ self.nixosModules.rustfs ];

    virtualisation.emptyDiskImages = map (_: 1024) disks;
    virtualisation.memorySize = 2048;
    boot.supportedFilesystems = [ "xfs" ];

    virtualisation.fileSystems = lib.listToAttrs (
      lib.imap0
        (i: disk: lib.nameValuePair (builtins.elemAt volumes i) {
          device = "/dev/${disk}";
          fsType = "xfs";
          autoFormat = true;
        })
        disks
    );

    services.rustfs = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      inherit volumes;
      address = "127.0.0.1:9000";
      consoleEnable = false;
      accessKeyFile = "/etc/rustfs-access-key";
      secretKeyFile = "/etc/rustfs-secret-key";
    };

    environment.etc."rustfs-access-key".text = "rustfsadmin";
    environment.etc."rustfs-secret-key".text = "rustfsadmin";
    environment.systemPackages = [ pkgs.awscli2 ];
  };

  testScript = ''
    machine.wait_for_unit("rustfs.service")
    machine.wait_for_open_port(9000)

    machine.succeed(
        "systemctl show -p Environment rustfs.service | "
        "grep -q 'RUSTFS_VOLUMES=${builtins.concatStringsSep " " volumes}'"
    )

    aws = (
        "AWS_ACCESS_KEY_ID=rustfsadmin AWS_SECRET_ACCESS_KEY=rustfsadmin "
        "AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url http://127.0.0.1:9000"
    )
    machine.wait_until_succeeds(aws + " s3 ls", timeout=120)

    machine.succeed(aws + " s3 mb s3://testbucket")
    machine.succeed("echo hello > /tmp/obj.txt")
    machine.succeed(aws + " s3 cp /tmp/obj.txt s3://testbucket/obj.txt")
    machine.succeed(aws + " s3 cp s3://testbucket/obj.txt /tmp/roundtrip.txt")
    machine.succeed("grep -q hello /tmp/roundtrip.txt")

    for volume in [${builtins.concatStringsSep ", " (map (v: "\"${v}\"") volumes)}]:
        machine.succeed(f"find {volume} -name 'xl.meta' | grep -q .")

    machine.succeed("systemctl is-active rustfs.service")
  '';
}
