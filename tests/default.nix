{ pkgs, self }:

{
  singleNodeMultiDisk = import ./single-node-multi-disk.nix { inherit pkgs self; };
  multiNodeMultiDisk = import ./multi-node-multi-disk.nix { inherit pkgs self; };
}
