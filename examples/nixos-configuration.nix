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

{ config, pkgs, ... }:

{
  services.rustfs = {
    enable = true;
    
    # Storage path
    volumes = "/var/lib/rustfs/data";
    
    # API server address (Port 9000)
    address = "127.0.0.1:9000";

    # Management console configuration (Port 9001)
    consoleEnable = true;
    consoleAddress = "127.0.0.1:9001";

    # Logging configuration
    logLevel = "info";
    logDirectory = "/var/log/rustfs";

    # Security: In production, do not hard-code secrets. Integrate a secret
    # management tool such as sops-nix or agenix to provide these values.
    #
    # Example with sops-nix (assuming you have defined the secrets
    # `rustfs-access-key` and `rustfs-secret-key` in your sops file):
    #   services.rustfs.accessKey =
    #     builtins.readFile config.sops.secrets."rustfs-access-key".path;
    #   services.rustfs.secretKey =
    #     builtins.readFile config.sops.secrets."rustfs-secret-key".path;
    #
    # For this example configuration, we use obvious placeholders instead of
    # real secrets. Replace them with values injected by your secret manager.
    accessKey = "<rustfs-access-key-from-secret-manager>";
    secretKey = "<rustfs-secret-key-from-secret-manager>";
  };

  # Open firewall ports for both API and Console
  networking.firewall.allowedTCPPorts = [
    9000 # RustFS API
    9001 # RustFS Console
  ];
}
