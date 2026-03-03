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

{
  description = "Example NixOS system using RustFS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rustfs-flake.url = "path:../.";
  };

  outputs = { self, nixpkgs, rustfs-flake }: {
    nixosConfigurations.example-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        rustfs-flake.nixosModules.default

        ({ config, pkgs, ... }: {
          # Secret files must live outside the Nix store so they are never world-readable.
          # Populate /run/secrets/rustfs-* before the service starts, for example with
          # sops-nix, agenix, or a simple activation script that writes the files from
          # a secrets backend.  The files only need to be readable by root/systemd because
          # the module uses systemd LoadCredential to hand them to the service.
          #
          # Example with a NixOS activation script (for local testing only – never embed
          # real credentials like this in Nix – fetch them from an external runtime source):
          #   system.activationScripts.rustfs-secrets = ''
          #     install -d -m 700 /run/secrets
          #     # Example: populate secrets from environment variables or a secrets backend.
          #     # The actual secret bytes must NOT appear in this Nix file.
          #     # Using environment variables (set outside Nix) for local testing:
          #     #   test -n "$RUSTFS_ACCESS_KEY" && printf '%s' "$RUSTFS_ACCESS_KEY" > /run/secrets/rustfs-access-key
          #     #   test -n "$RUSTFS_SECRET_KEY" && printf '%s' "$RUSTFS_SECRET_KEY" > /run/secrets/rustfs-secret-key
          #     chmod 600 /run/secrets/rustfs-access-key /run/secrets/rustfs-secret-key
          #   '';
          #
          # For production, prefer sops-nix (https://github.com/Mic92/sops-nix) or
          # agenix (https://github.com/ryantm/agenix).

          services.rustfs = {
            enable = true;
            package = rustfs-flake.packages.${pkgs.stdenv.hostPlatform.system}.default;

            volumes = "/var/lib/rustfs/data";
            address = "0.0.0.0:9000";
            consoleEnable = true;
            consoleAddress = "0.0.0.0:9001";

            # Use file-based secrets (required for security)
            # The files must exist at these paths before the service starts (see comment above)
            accessKeyFile = "/run/secrets/rustfs-access-key";
            secretKeyFile = "/run/secrets/rustfs-secret-key";

            logLevel = "info";
            # Logs default to systemd journal (journalctl -u rustfs)
          };

          networking.firewall.allowedTCPPorts = [ 9000 9001 ];
          system.stateVersion = "24.11";
        })
      ];
    };
  };
}
