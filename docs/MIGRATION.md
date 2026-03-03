# Migration Guide: From Insecure to Secure Configuration

This guide helps you migrate from the deprecated `accessKey` and `secretKey` options to the secure `accessKeyFile` and
`secretKeyFile` options.

## Why Migrate?

The old `accessKey` and `secretKey` options store secrets directly in your NixOS configuration, which means:

1. **Secrets are copied to the Nix store** - readable by all users on the system
2. **Secrets may end up in Git repositories** - potentially exposing them publicly
3. **No encryption** - secrets stored in plain text
4. **Difficult to rotate** - changing secrets requires rebuilding the system

The new file-based approach:

- ✅ Keeps secrets out of the Nix store
- ✅ Uses proper Unix permissions (readable only by service user)
- ✅ Supports encryption via sops-nix, agenix, etc.
- ✅ Easier secret rotation
- ✅ Better audit trail

## Breaking Changes

- **`services.rustfs.accessKey`** option has been **REMOVED**
- **`services.rustfs.secretKey`** option has been **REMOVED**
- **`services.rustfs.accessKeyFile`** is now **REQUIRED**
- **`services.rustfs.secretKeyFile`** is now **REQUIRED**

## Migration Steps

### Step 1: Choose Your Secret Management Method

Pick one of these options:

#### Option A: sops-nix (Recommended for production)

- Encrypted secrets
- Git-friendly
- Multi-environment support
- See [SECURITY.md](./SECURITY.md) for full setup

#### Option B: agenix

- Age-encrypted secrets
- Simple setup
- Good for smaller deployments

#### Option C: Manual files

- Simple but requires manual management
- Good for testing or simple setups
- Not recommended for production

### Step 2: Prepare Your Secrets

#### If using sops-nix:

1. Install sops and age:
   ```bash
   nix-shell -p sops age
   ```

2. Generate age key:
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

3. Create `.sops.yaml`:
   ```yaml
   keys:
     - &admin age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
   creation_rules:
     - path_regex: secrets/.*\.yaml$
       key_groups:
       - age:
         - *admin
   ```

4. Create encrypted secrets file:
   ```bash
   mkdir -p secrets
   sops secrets/rustfs.yaml
   ```

   Add:
   ```yaml
   rustfs_access_key: your-access-key-here
   rustfs_secret_key: your-secret-key-here
   ```

#### If using agenix:

1. Generate age key pair on your server:
   ```bash
   ssh your-server "age-keygen -o /var/lib/age/key.txt"
   ```

2. Encrypt secrets:
   ```bash
   age -r age1... -e -o secrets/rustfs-access-key.age <<< "your-access-key"
   age -r age1... -e -o secrets/rustfs-secret-key.age <<< "your-secret-key"
   ```

#### If using manual files:

On your server:

```bash
sudo mkdir -p /run/secrets
echo "your-access-key" | sudo tee /run/secrets/rustfs-access-key
echo "your-secret-key" | sudo tee /run/secrets/rustfs-secret-key
sudo chown rustfs:rustfs /run/secrets/rustfs-*
sudo chmod 400 /run/secrets/rustfs-*
```

### Step 3: Update Your Configuration

#### Old Configuration (INSECURE):

```nix
services.rustfs = {
  enable = true;
  accessKey = "rustfsadmin";  # ❌ INSECURE!
  secretKey = "rustfsadmin";  # ❌ INSECURE!
  volumes = "/tmp/rustfs";
  address = ":9000";
};
```

#### New Configuration with sops-nix:

```nix
{ config, pkgs, ... }:

{
  # Add sops-nix import to your flake.nix first!
  
  sops = {
    defaultSopsFile = ./secrets/rustfs.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    
    secrets = {
      rustfs-access-key = {
        owner = config.services.rustfs.user;
        group = config.services.rustfs.group;
        mode = "0400";
      };
      
      rustfs-secret-key = {
        owner = config.services.rustfs.user;
        group = config.services.rustfs.group;
        mode = "0400";
      };
    };
  };

  services.rustfs = {
    enable = true;
    accessKeyFile = config.sops.secrets.rustfs-access-key.path;  # ✅ SECURE
    secretKeyFile = config.sops.secrets.rustfs-secret-key.path;  # ✅ SECURE
    volumes = "/var/lib/rustfs";  # Use persistent storage
    address = ":9000";
    consoleAddress = "127.0.0.1:9001";  # Localhost only
  };
}
```

#### New Configuration with agenix:

```nix
{ config, pkgs, ... }:

{
  # Add agenix import to your flake.nix first!
  
  age.secrets = {
    rustfs-access-key = {
      file = ./secrets/rustfs-access-key.age;
      owner = config.services.rustfs.user;
      group = config.services.rustfs.group;
      mode = "0400";
    };
    
    rustfs-secret-key = {
      file = ./secrets/rustfs-secret-key.age;
      owner = config.services.rustfs.user;
      group = config.services.rustfs.group;
      mode = "0400";
    };
  };

  services.rustfs = {
    enable = true;
    accessKeyFile = config.age.secrets.rustfs-access-key.path;
    secretKeyFile = config.age.secrets.rustfs-secret-key.path;
    volumes = "/var/lib/rustfs";
    address = ":9000";
  };
}
```

#### New Configuration with manual files:

```nix
services.rustfs = {
  enable = true;
  accessKeyFile = "/run/secrets/rustfs-access-key";
  secretKeyFile = "/run/secrets/rustfs-secret-key";
  volumes = "/var/lib/rustfs";
  address = ":9000";
};
```

### Step 4: Update Your Flake (if using sops-nix or agenix)

Update your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rustfs.url = "github:rustfs/rustfs-flake";
    rustfs.inputs.nixpkgs.follows = "nixpkgs";
    
    # Add sops-nix OR agenix
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    
    # OR
    # agenix.url = "github:ryantm/agenix";
    # agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rustfs, sops-nix, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        rustfs.nixosModules.rustfs
        sops-nix.nixosModules.sops  # or agenix.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### Step 5: Deploy

1. **Test locally first** (if possible):
   ```bash
   nixos-rebuild build --flake .#myhost
   ```

2. **Deploy to server**:
   ```bash
   nixos-rebuild switch --flake .#myhost --target-host root@your-server
   ```

3. **Verify the service is running**:
   ```bash
   ssh your-server
   sudo systemctl status rustfs
   sudo journalctl -u rustfs -n 50
   ```

4. **Test functionality**:
   ```bash
   curl http://your-server:9000/ -u "access-key:secret-key"
   ```

### Step 6: Clean Up Old Secrets

After confirming the service works:

1. **Remove old configuration**:
    - Delete any files with plain-text secrets
    - Remove old commits from Git history (if secrets were committed)

2. **Rotate secrets** (recommended):
   ```bash
   # Generate new keys
   NEW_ACCESS_KEY=$(openssl rand -base64 32)
   NEW_SECRET_KEY=$(openssl rand -base64 32)
   
   # Update in sops
   sops secrets/rustfs.yaml
   # (Update the values manually)
   
   # Redeploy
   nixos-rebuild switch --flake .#myhost --target-host root@your-server
   ```

## Troubleshooting

### Error: "could not read secret file"

The service user can't access the secret file. Check:

```bash
# Check if file exists
ls -la /run/secrets/rustfs-*

# Should show:
# -r-------- 1 rustfs rustfs ... rustfs-access-key
# -r-------- 1 rustfs rustfs ... rustfs-secret-key

# Fix ownership if needed:
sudo chown rustfs:rustfs /run/secrets/rustfs-*
sudo chmod 400 /run/secrets/rustfs-*
```

### Error: "sops could not decrypt"

Age key not found or wrong key. Check:

```bash
# Verify key file exists
ls -la /var/lib/sops-nix/key.txt

# Verify the public key matches .sops.yaml
sudo cat /var/lib/sops-nix/key.txt

# Re-encrypt with correct keys
sops updatekeys secrets/rustfs.yaml
```

### Service won't start after migration

Check logs:

```bash
sudo journalctl -u rustfs -n 100 --no-pager
```

Common issues:

- Secret file doesn't exist
- Wrong permissions
- Service can't read LoadCredential paths

### Need to rollback?

If something goes wrong:

```bash
# Rollback to previous generation
nixos-rebuild switch --rollback

# Or use generation number
nixos-rebuild switch --switch-generation 123
```

## Verification Checklist

After migration, verify:

- [ ] Service starts successfully: `systemctl status rustfs`
- [ ] No errors in logs: `journalctl -u rustfs -n 50`
- [ ] API responds: `curl http://server:9000/`
- [ ] Console accessible (if enabled)
- [ ] Can authenticate with new credentials
- [ ] No secrets in `/nix/store`: `grep -r "your-secret" /nix/store` (should find nothing)
- [ ] Secret files have correct permissions (400)
- [ ] Secret files owned by rustfs user

## Getting Help

If you encounter issues:

1. Check the [SECURITY.md](./SECURITY.md) documentation
2. Review the [example configuration](../examples/nixos-configuration.nix)
3. Check service logs: `journalctl -u rustfs -f`
4. Open an issue on GitHub with:
    - Your sanitized configuration (remove all secrets!)
    - Error messages from logs
    - NixOS version: `nixos-version`

## Additional Resources

- [sops-nix Documentation](https://github.com/Mic92/sops-nix)
- [agenix Documentation](https://github.com/ryantm/agenix)
- [NixOS Manual - Secret Management](https://nixos.org/manual/nixos/stable/#sec-secrets)
- [RustFS Documentation](https://rustfs.com/docs/)

