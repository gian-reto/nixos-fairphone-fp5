# NixOS on Fairphone 5

This repository aims to port NixOS to the Fairphone 5, a modular and sustainable smartphone. The goal is to provide a fully functional NixOS system that can run on the Fairphone 5, and to support as many of its hardware features as possible.

The Fairphone 5 uses a Qualcomm QCM6490 SoC, which is based on the ARM architecture and is very similar to the Qualcomm SC7280 SoC found in various other devices. This repository builds on existing work by the amazing PostmarketOS community, mainly their work on porting the Linux kernel and other essential components to the Fairphone 5. For more information regarding the status of the port, see the [Fairphone 5 page](<https://wiki.postmarketos.org/wiki/Fairphone_5_(fairphone-fp5)>) in the PostmarketOS Wiki.

## Current Status

- Kernel: 6.17.0

## Getting Started

TBD.

## Development & Contribution

Simply enter the provided Nix devshell by running `nix develop` in this repository. The devshell provides all necessary tools and dependencies for building and flashing NixOS on the Fairphone 5, as well as building individual packages contained in this repository (e.g., the custom kernel package).

### AI

The development in this repository is partially assisted by AI tools. Contributions made with the help of AI are welcome, provided that they are reviewed and tested by human contributors to ensure quality and correctness.

Coding agents must adhere to the instructions and guidelines outlined in [AGENTS.md](AGENTS.md) when working in this repository.
