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
            # NOTE: Binding to 0.0.0.0 exposes the RustFS service on all network interfaces.
            # Ensure that strong authentication and appropriate network restrictions (firewall,
            # reverse proxy, VPN, etc.) are in place before using this in production. For
            # local-only setups, consider binding to 127.0.0.1 instead.
            address = "0.0.0.0:9000";
            # The console UI is also exposed on all interfaces when bound to 0.0.0.0.
            # Protect this endpoint with authentication and/or restrict access to trusted
            # networks only.
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
