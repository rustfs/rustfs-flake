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
  description = "RustFS: High-performance object storage server (Prebuilt Binary Flake)";

  inputs = {
    # Security Note: Using unstable branch. For production environments,
    # consider pinning to a specific release (e.g., nixos-24.05) to ensure stability and security updates.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      sources = builtins.fromJSON (builtins.readFile ./sources.json);
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      # Standard NixOS Module
      nixosModules.rustfs = import ./nixos/rustfs.nix;
      nixosModules.default = self.nixosModules.rustfs;

      # Overlays for extending nixpkgs
      overlays.default = final: prev: {
        rustfs = self.packages.${prev.system}.default;
      };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          srcInfo = sources.files.${system} or (throw "Unsupported system: ${system}");
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "rustfs";
            version = sources.version;

            src = pkgs.fetchurl {
              url = "${sources.downloadBase}/${sources.version}/${srcInfo.name}";
              sha256 = srcInfo.sha256;
            };

            # Build Tools:
            # - unzip: Required for extracting the source archive.
            nativeBuildInputs = [ pkgs.unzip ];

            # The archive contains the binary at the root, so we set sourceRoot to current dir
            sourceRoot = ".";

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin
              install -m755 rustfs $out/bin/rustfs


              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "High-performance object storage server written in Rust";
              homepage = "https://rustfs.com";
              license = licenses.asl20;
              platforms = supportedSystems;
              mainProgram = "rustfs";
              # This package uses pre-compiled binaries downloaded from GitHub releases.
              # The binaries are fetched from ${sources.downloadBase}/${sources.version}/
              # and are not built from source in this flake.
              sourceProvenance = [ sourceTypes.binaryNativeCode ];
            };
          };
        }
      );

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            # Security: Include shellcheck to assist in writing secure shell scripts during development.
            buildInputs = with pkgs; [ nixpkgs-fmt shellcheck ];
          };
        }
      );
    };
}
