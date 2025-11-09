# Agent Information

This document outlines key information needed by coding agents to work in this repository. It outlines the rules to follow during work, and provides helpful commands and tips to facilitate development.

## General Rules

- ALWAYS ask the user first before you try to do testing or validation of any kind at the end of a step. NEVER proceed to the testing phase directly on your own without user confirmation.
- NEVER delete any files from the repo unless the user explicitly asks you to do so, or you ask for confirmation first.

## Nix

Information about working with Nix / NixOS. In general:

- You are working in a Nix flake-based project.
- The machine you're working on is also running NixOS.

### Do's:

- If you have access to MCP servers or tools that help you retrieve information about Nix, NixOS options or Nix packages (e.g., `nixos_search`, `context7`, or similar), you MUST use them to verify whether options or packages exist before you use them, and to get more information about them.
- If you need to run a command that starts with `nix`, NEVER run it yourself and ALWAYS give the command to the user to run it for you. For example, if you need to build something with `nix build`, ALWAYS ask the user to run the command for you.
- The ONLY Nix command you are allowed to run is `nix run` to run a binary that is not already available in your environment (more infor further down below).

### Don'ts:

- NEVER run `nix`, `nix-build`, `nix build` or any other Nix commands or subcommands.
- NEVER attempt to enter a Nix shell or devshell (e.g. `nix develop`). Ask the user to enter for you. If you're not sure if you're in a Nix shell, ask the user to confirm whether you are or not.

### Helpful Nix Commands

#### Running a Binary Temporarily

If a command you are trying to run doesn't exist on the system, you can use `nix run` or `nix shell` to run it temporarily without installing it permanently. For example, if you want to run `e2image --help` (provided by the `e2fsprogs` package on NixOS), but it's not installed, use this instead:

```
nix shell nixpkgs#e2fsprogs -c e2image --help
```

If you only need to run the main binary from a package, `nix run` is more suitable. E.g., if `curl` was not installed, you could run:

```
nix run nixpkgs#curl -- --help
```

#### Finding Package Hashes

If you use fetching functions like `fetchFromGitHub`, `fetchurl`, or similar in your code, you will often need to provide a hash for the fetched content. To compute the correct hash, you can use `nurl [OPTIONS] [URL] [REV]`. If it's not already installed on the system, you can use `nix run` to run it temporarily without installing it. For example, to get the hash for the repository `https://github.com/nix-community/patsh` and tag `v0.2.0`, you can run:

```
nix run nixpkgs#nurl -- https://github.com/nix-community/patsh v0.2.0 2>/dev/null
```

This will return the necessary info:

```
fetchFromGitHub {
  owner = "nix-community";
  repo = "patsh";
  rev = "v0.2.0";
  hash = "sha256-<computed-hash>";
}
```

## Repo Structure

You can look at the file tree yourself, but there are some notable files and folders to point out:

- `README.md`: The main README file with general information about the project.
- `flake.nix`: The main Nix flake, which defines the devshell for the user, as well as the flake outputs and build commands (e.g. for building the kernel, the boot image, root image, etc.).
