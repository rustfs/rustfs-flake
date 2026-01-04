# Contributing to rustfs-flake

Thank you for your interest in contributing to rustfs-flake! This document provides guidelines for contributing to this Nix flake.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/rustfs-flake.git`
3. Create a feature branch: `git checkout -b feature/my-new-feature`

## Making Changes

### Testing Your Changes

Since this is a Nix flake, you should test your changes locally:

```bash
# Check flake syntax
nix flake check

# Build the package
nix build

# Test the NixOS module (requires NixOS)
nixos-rebuild test --flake .#

# Enter the dev shell
nix develop
```

### Code Style

- Follow the existing Nix code style in the repository
- Use 2 spaces for indentation
- Keep lines under 100 characters when possible
- Add comments for complex logic

### Commit Messages

- Use clear, descriptive commit messages
- Start with a verb in present tense (e.g., "Add", "Fix", "Update")
- Reference issues when applicable

## Submitting Changes

1. Push your changes to your fork
2. Create a Pull Request against the main branch
3. Describe your changes in the PR description
4. Wait for review and address any feedback

## Reporting Issues

- Use the GitHub issue tracker
- Include your Nix/NixOS version
- Provide steps to reproduce the issue
- Include relevant error messages

## Questions?

Feel free to open an issue for questions or discussions!
