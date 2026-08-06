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

# RustFS single-node, multi-disk NixOS Configuration Example
#
# One machine with four drives, so erasure coding has something to spread parity
# across. Erasure coding needs at least four drives; with fewer, RustFS falls back
# to a single-drive layout with no redundancy.
#
# Each volume must sit on its own filesystem — pointing several `volumes` entries
# at directories of the same disk gives you no redundancy at all, and RustFS
# rejects the layout.
#
# For complete security documentation, see ../docs/SECURITY.md

{ config, pkgs, ... }:

{
  # The drives themselves. Replace the /dev/disk/by-id/… devices with the ones on
  # your machine; by-id names are stable across reboots, unlike /dev/sdX.
  fileSystems = {
    "/mnt/rustfs0" = {
      device = "/dev/disk/by-id/REPLACE-ME-disk0";
      fsType = "xfs";
    };
    "/mnt/rustfs1" = {
      device = "/dev/disk/by-id/REPLACE-ME-disk1";
      fsType = "xfs";
    };
    "/mnt/rustfs2" = {
      device = "/dev/disk/by-id/REPLACE-ME-disk2";
      fsType = "xfs";
    };
    "/mnt/rustfs3" = {
      device = "/dev/disk/by-id/REPLACE-ME-disk3";
      fsType = "xfs";
    };
  };

  services.rustfs = {
    enable = true;

    # One entry per drive. A comma-separated string works too, but the list form
    # is easier to read and to generate.
    volumes = [
      "/mnt/rustfs0"
      "/mnt/rustfs1"
      "/mnt/rustfs2"
      "/mnt/rustfs3"
    ];

    address = ":9000";

    # SECURITY: Bind console to localhost only, access via SSH tunnel
    consoleEnable = true;
    consoleAddress = "127.0.0.1:9001";

    logLevel = "info";

    # SECURITY: Use file-based secrets, never plain text!
    # See nixos-configuration.nix for the sops-nix / agenix variants.
    accessKeyFile = "/run/secrets/rustfs-access-key";
    secretKeyFile = "/run/secrets/rustfs-secret-key";
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 9000 ];
  };
}
