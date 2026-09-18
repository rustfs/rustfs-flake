{ pkgs, self }:

{
  singleNodeMultiDisk = import ./single-node-multi-disk.nix { inherit pkgs self; };
  multiNodeMultiDisk = import ./multi-node-multi-disk.nix { inherit pkgs self; };
  multiPool = import ./multi-pool.nix { inherit pkgs self; };
  poolNaming = import ./pool-naming.nix { inherit pkgs self; };
}
