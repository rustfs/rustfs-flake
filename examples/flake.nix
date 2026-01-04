# Example flake.nix for a NixOS system using RustFS
#
# This shows how to integrate the rustfs-flake into your system configuration.

{
  description = "NixOS system with RustFS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rustfs-flake.url = "github:rustfs/rustfs-flake";
  };

  outputs = { self, nixpkgs, rustfs-flake }: {
    # Example NixOS configuration
    nixosConfigurations.example-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the RustFS NixOS module
        rustfs-flake.nixosModules.default
        
        # Your system configuration
        ({ config, pkgs, ... }: {
          # Enable RustFS service
          services.rustfs = {
            enable = true;
            dataDir = "/var/lib/rustfs";
            address = "0.0.0.0:9000";
            consoleAddress = "0.0.0.0:9001";
          };

          # Open firewall ports
          networking.firewall.allowedTCPPorts = [ 9000 9001 ];

          # Rest of your system configuration...
          system.stateVersion = "24.11";
        })
      ];
    };
    
    # If you want to use the overlay instead
    nixosConfigurations.example-host-with-overlay = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ config, pkgs, ... }: {
          nixpkgs.overlays = [ rustfs-flake.overlays.default ];
          
          # Now you can use pkgs.rustfs
          environment.systemPackages = [ pkgs.rustfs ];
          
          system.stateVersion = "24.11";
        })
      ];
    };
  };
}
