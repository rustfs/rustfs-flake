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

# RustFS distributed cluster NixOS Configuration Example
#
# Four nodes with four drives each. This exact file is imported by every node —
# `services.rustfs.pools` is deliberately identical everywhere, and the
# module derives each node's identity from `networking.hostName`.
#
# Requirements the module asserts at evaluation time:
#   - at least 4 nodes and 4 drives in the pool
#
# Additional requirements the module cannot check for you:
#   - every hostname in `nodes` resolves from every other node (DNS or
#     `networking.hosts`), and `port` is reachable between them
#   - the access/secret key pair is identical on all nodes, and is *not* the
#     default rustfsadmin/rustfsadmin — RustFS derives the inter-node RPC secret
#     from the credentials and refuses to derive one from the defaults
#   - each drive is its own filesystem, on every node
#
# For complete security documentation, see ../docs/SECURITY.md

{ config, lib, pkgs, ... }:

let
  # Same on every node: the shared endpoint list is rendered from these, and it
  # must come out byte-identical cluster-wide.
  nodes = [
    "node1"
    "node2"
    "node3"
    "node4"
  ];

  volumes = [
    "/mnt/rustfs0"
    "/mnt/rustfs1"
    "/mnt/rustfs2"
    "/mnt/rustfs3"
  ];
in
{
  # Drive layout, identical on each node. Replace the by-id device names with the
  # ones on your hardware; if they differ per node, split this attrset out into a
  # per-host file and keep the mount points the same.
  fileSystems = lib.listToAttrs (
    lib.imap0
      (i: volume: lib.nameValuePair volume {
        device = "/dev/disk/by-id/REPLACE-ME-disk${toString i}";
        fsType = "xfs";
      })
      volumes
  );

  services.rustfs = {
    enable = true;

    # One pool spanning the fleet. The module expands it into the shared
    # endpoint list (http://<node>:<port><volume>) every node must agree on.
    # Appending a second pool here is how the cluster grows later; RustFS works
    # out which drives are this machine's by resolving the endpoint hosts.
    pools = [ { inherit nodes volumes; } ];

    port = 9000;

    # Sets of four across sixteen drives, two of them parity. Because the module
    # lays the endpoints out drive-major, a set spans the four nodes rather than
    # sitting on one, so a whole node can go away and writes still have quorum.
    erasureSetDriveCount = 4;
    storageClassStandardParity = 2;
    storageClassRrsParity = 1;

    # Must bind an address peers can reach, on `port`.
    address = "0.0.0.0:9000";

    # SECURITY: Bind console to localhost only, access via SSH tunnel
    consoleEnable = true;
    consoleAddress = "127.0.0.1:9001";

    logLevel = "info";

    # SECURITY: Use file-based secrets, never plain text!
    # Distribute the *same* pair to every node, e.g. with sops-nix or agenix.
    accessKeyFile = "/run/secrets/rustfs-access-key";
    secretKeyFile = "/run/secrets/rustfs-secret-key";
  };

  # Peers talk to each other on the API port, so it has to be open between nodes.
  # Narrow this to the cluster subnet in production rather than opening it wide.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 9000 ];
  };

  # Only needed if the node names are not in DNS.
  # networking.hosts = {
  #   "10.0.0.1" = [ "node1" ];
  #   "10.0.0.2" = [ "node2" ];
  #   "10.0.0.3" = [ "node3" ];
  #   "10.0.0.4" = [ "node4" ];
  # };
}
