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

# RustFS NixOS Configuration Example
#
# This example demonstrates a secure production deployment of RustFS.
# For complete security documentation, see ../docs/SECURITY.md

{ config, pkgs, ... }:

{
  services.rustfs = {
    enable = true;

    # Storage path - use persistent storage, not /tmp
    volumes = "/var/lib/rustfs/data";

    # API server address (Port 9000)
    # Use "0.0.0.0:9000" or ":9000" to listen on all interfaces
    address = ":9000";

    # Management console configuration (Port 9001)
    # SECURITY: Bind console to localhost only, access via SSH tunnel
    consoleEnable = true;
    consoleAddress = "127.0.0.1:9001";

    # Logging configuration
    # Use "info" in production, not "debug" or "trace"
    logLevel = "info";

    # Optional: Log to files instead of systemd journal
    # By default (null), logs go to systemd journal (journalctl -u rustfs)
    # Uncomment to enable file logging:
    # logDirectory = "/var/log/rustfs";

    # TLS directory for certificates
    tlsDirectory = "/etc/rustfs/tls";

    # SECURITY: Use file-based secrets, never plain text!
    # The accessKey and secretKey options have been removed for security.
    # Always use accessKeyFile and secretKeyFile instead.
    #
    # Option 1: Using sops-nix (Recommended)
    accessKeyFile = config.sops.secrets.rustfs-access-key.path;
    secretKeyFile = config.sops.secrets.rustfs-secret-key.path;

    # Option 2: Using agenix
    # accessKeyFile = config.age.secrets.rustfs-access-key.path;
    # secretKeyFile = config.age.secrets.rustfs-secret-key.path;

    # Option 3: Manual secret files
    # accessKeyFile = "/run/secrets/rustfs-access-key";
    # secretKeyFile = "/run/secrets/rustfs-secret-key";
  };

  # Example: sops-nix configuration
  # Uncomment if using sops-nix for secret management
  # sops = {
  #   defaultSopsFile = ./secrets/rustfs.yaml;
  #   age.keyFile = "/var/lib/sops-nix/key.txt";
  #
  #   secrets = {
  #     rustfs-access-key = {
  #       owner = config.services.rustfs.user;
  #       group = config.services.rustfs.group;
  #       mode = "0400";
  #     };
  #
  #     rustfs-secret-key = {
  #       owner = config.services.rustfs.user;
  #       group = config.services.rustfs.group;
  #       mode = "0400";
  #     };
  #   };
  # };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    # Only allow API port
    # Console is on localhost only and accessed via SSH tunnel
    allowedTCPPorts = [ 9000 ];
  };

  # Optional: Log rotation (only needed when logDirectory is set)
  # services.logrotate = {
  #   enable = true;
  #   settings.rustfs = {
  #     files = "/var/log/rustfs/*.log";
  #     frequency = "daily";
  #     rotate = 7;
  #     compress = true;
  #     delaycompress = true;
  #     missingok = true;
  #     notifempty = true;
  #     create = "0640 rustfs rustfs";
  #   };
  # };
}


