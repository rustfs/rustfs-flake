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
          services.rustfs = {
            enable = true;
            package = rustfs-flake.packages.${pkgs.stdenv.hostPlatform.system}.default;

            volumes = "/var/lib/rustfs/data";
            address = "0.0.0.0:9000";
            consoleEnable = true;
            consoleAddress = "0.0.0.0:9001";

            accessKey = "admin-access-key";
            secretKey = "secure-secret-key";

            logLevel = "info";
          };

          networking.firewall.allowedTCPPorts = [ 9000 9001 ];
          system.stateVersion = "24.11";
        })
      ];
    };
  };
}
