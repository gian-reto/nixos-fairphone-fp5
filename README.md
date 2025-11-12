# NixOS on Fairphone 5

This repository aims to port NixOS to the Fairphone 5, a modular and sustainable smartphone. The goal is to provide a fully functional NixOS system that can run on the Fairphone 5, and to support as many of its hardware features as possible.

The Fairphone 5 uses a Qualcomm QCM6490 SoC, which is based on the ARM architecture and is very similar to the Qualcomm SC7280 SoC found in various other devices. This repository builds on existing work by the amazing PostmarketOS community, mainly their work on porting the Linux kernel and other essential components to the Fairphone 5. For more information regarding the status of the port, see the [Fairphone 5 page](<https://wiki.postmarketos.org/wiki/Fairphone_5_(fairphone-fp5)>) in the PostmarketOS Wiki.

## Current Status

- Kernel: 6.17.0

So far, I only tested whether the device can boot successfully all the way to the NixOS login prompt. While the display correctly displays the login prompt (albeit very small due to missing display scaling), I have not yet used the phone itself, because there's no software keyboard yet. However, it's possible to log in via USB serial console and the system seems to work fine in general after logging in.

Additional details will be added here as development progresses.

## Getting Started

> [!TIP]
> Note: This project has cross-compilation support, so if you build the boot and rootfs image on an x86_64 host using the provided devshell, the resulting outputs will correctly be built for the aarch64 architecture of the Fairphone 5.

> [!IMPORTANT]
> When booting NixOS, the display will show various artifacts, and the screen will be black for a brief moment. This is expected behavior and doesn't mean something is wrong. Just wait a bit until the device has fully booted and the login prompt appears.

**Prerequisites:**

- A Fairphone 5 device, obviously :)
- The device must have an unlocked bootloader. Follow the instructions on the [Fairphone 5 page](<https://wiki.postmarketos.org/wiki/Fairphone_5_(fairphone-fp5)>) in the PostmarketOS Wiki if you haven't done this yet.
- A NixOS host to build the images. Other distributions that have Nix installed may also work, but have not been tested.

To build the necessary images and flash them to your Fairphone 5, you can either use the provided `build-and-flash.sh` script, or build and flash manually. In both cases, make sure to do the following preparatory steps first:

1. Put your device into `fastboot` mode by turning it off first, and then holding the volume down and power button simultaneously until the device powers on and displays the `fastboot` screen.
2. Connect the Fairphone 5 to your host machine via USB-C.
3. Clone this repository.
4. `cd` into the repository directory.

### Build and Flash using the Script

All you need to do is run the provided `build-and-flash.sh` script using the following command:

```sh
./scripts/build-and-flash.sh
```

After the flashing process is complete, you are asked to choose whether you want to reboot the device immediately to boot into NixOS.

### Build and Flash Manually

<details>

<summary>Extend to see instructions</summary>

1. Enter the Nix devshell (execute all following steps marked with the ❄️ symbol inside the devshell):

   ```sh
   nix develop
   ```

2. ❄️ Build the boot image:

   ```sh
   nix build .#boot-image-minimal
   ```

3. ❄️ Flash the boot image to the phone's boot partition:

   ```sh
   fastboot flash boot result
   ```

4. ❄️ Build the rootfs image:

   ```sh
   nix build .#rootfs-image-minimal
   ```

5. ❄️ Flash the rootfs image to the phone's userdata partition:

   ```sh
   fastboot flash userdata result
   ```

6. ❄️ Reboot the device:

   ```sh
   fastboot reboot
   ```

7. The device should now boot into NixOS! The default user and password are both `admin`, so make sure to change the password after your first login.

</details>

## Development & Contribution

Simply enter the provided Nix devshell by running `nix develop` in this repository. The devshell provides all necessary tools and dependencies for building and flashing NixOS on the Fairphone 5, as well as building individual packages contained in this repository (e.g., the custom kernel package).

### AI

The development in this repository is partially assisted by AI tools. Contributions made with the help of AI are welcome, provided that they are reviewed and tested by human contributors to ensure quality and correctness.

Coding agents must adhere to the instructions and guidelines outlined in [AGENTS.md](AGENTS.md) when working in this repository.

## Thanks

- Huge thanks to the PostmarketOS community for their incredible work on porting Linux to the Fairphone 5 (especially to Luca Weiss, the main maintainer of the Fairphone ports) and other devices. Their efforts have laid the groundwork for this NixOS port, and their documentation and resources have been invaluable throughout the development process.
- This port was also inspired by [MatthewCroughan/nixos-qcm6490](https://github.com/MatthewCroughan/nixos-qcm6490), which is an attempt to port NixOS to the SHIFTphone 8 (otter), which uses the same SoC as the Fairphone 5. Not sure if the port was successful, but the code was still an invaluable reference. Thanks, Matthew!
