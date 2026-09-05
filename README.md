# NixOS on Fairphone 5

This repository aims to port NixOS to the Fairphone 5, a modular and sustainable smartphone. The goal is to provide a fully functional NixOS system that can run on the Fairphone 5, and to support as many of its hardware features as possible.

The Fairphone 5 uses a Qualcomm QCM6490 SoC, which is based on the ARM architecture and is very similar to the Qualcomm SC7280 SoC found in various other devices. This repository builds on existing work by the amazing PostmarketOS community, mainly their work on porting the Linux kernel and other essential components to the Fairphone 5. For more information regarding the status of the port, see the [Fairphone 5 page](<https://wiki.postmarketos.org/wiki/Fairphone_5_(fairphone-fp5)>) in the PostmarketOS Wiki.

<div align="center">
   <img src="./.docs/picture-gnome-mobile-1.jpeg" alt="Home screen on Fairphone 5 running NixOS with GNOME Mobile" width="300" hspace="10" vspace="10" />
   <img src="./.docs/picture-gnome-mobile-2.jpeg" alt="Terminal on Fairphone 5 running NixOS with GNOME Mobile" width="300" hspace="10" vspace="10" />
</div>

## Current Status

- Kernel: 7.1.2 ([`sc7280-mainline/linux@17425f5`](https://github.com/sc7280-mainline/linux/commit/17425f528fe51fef6e86847e92baffab3b78623e))

### Supported Hardware

- Audio: Both speakers and microphone are broken
- Battery: Works
- Bluetooth: Works (with audio support)
- Camera: Selfie and wide-angle cameras work (quality is not amazing)
- Cellular modem: Works
- Screen: Works
- Sensors: Partially works
  - Accelerometer: Reports the correct device orientation, but GNOME Mobile 48 autorotate does not work for some reason
  - Ambient light: Detected, but only reports an initial value of 0 lux without useful updates
- Touchscreen: Works
- Wi-Fi: Works

Additional details will be added here as development progresses.

Note: Hardware was tested using the GNOME Mobile builds. When using the minimal images, the device boots up and the screen works, but the device has to be controlled remotely over USB Serial or SSH, because there is no virtual keyboard (and thus no way to log in on the device itself).

## Getting Started

> [!CAUTION]
> Cross-compilation is currently not supported, so you need to build the images on an `aarch64-linux` NixOS host. However, because Nix has excellent support for remote builders, you can also delegate the build to a remote aarch64 builder (more info can be found further down below).

**Prerequisites:**

- A Fairphone 5 device, obviously :)
- The device must have an unlocked bootloader. Follow the instructions on the [Fairphone 5 page](<https://wiki.postmarketos.org/wiki/Fairphone_5_(fairphone-fp5)>) in the PostmarketOS Wiki if you haven't done this yet.
- An `aarch64-linux` NixOS host to build the images. Other distributions that have Nix installed may also work, but have not been tested. Alternatively, you can use a remote builder from any Nix-enabled system.

**Optional: Set up Remote Builder**

I recommend using [nixbuild.net](https://nixbuild.net) as a remote builder. It's pretty easy to set up, works well in my testing, and they provide the necessary `aarch64-linux` builders. The builds of each derivation are even cached, so subsequent builds are usually pretty fast!

First, set up an account, add your SSH public key to the service as described in their [getting started guide](https://docs.nixbuild.net/getting-started/#getting-started). Note: You don't need to set their server as a builder for your entire NixOS configuration as described in their guide (section "Quick NixOS Configuration"); you can simply set the `programs.ssh.extraConfig` and `programs.ssh.knownHosts` options in your config as described in their guide, and ignore the `nix.distributedBuilds` and `nix.buildMachines` options. This way, you can use the remote builder on-demand as needed.

Verify whether you are able to connect to their server via SSH:

```sh
sudo ssh eu.nixbuild.net shell
```

If you're able to connect, you're ready to use the remote builder to build your images.

### Add Module to your NixOS Configuration

If you want to use NixOS on your own Fairphone 5, the example configurations provided by this repository will probably not be sufficient. Add the Fairphone 5 module to your own configuration and expose the two image artifacts (for the initial flash) like this:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-fairphone-fp5.url = "github:gian-reto/nixos-fairphone-fp5";
  };

  outputs = { self, nixpkgs, nixos-fairphone-fp5, ... }: {
    nixosConfigurations.my-fairphone = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        # Import the Fairphone 5 NixOS module.
        nixos-fairphone-fp5.nixosModules.default

        # Import your own custom configuration.
        ./hosts/my-fairphone/default.nix
      ];
    };

    # Use the `mkUbootImage` and `mkDiskImage` functions provided by this flake to be able to build
    # boot and rootfs images from your custom configuration, so you can easily flash the first
    # generation of your configuration to your Fairphone 5 using `fastboot`.
    packages.aarch64-linux =
      let
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
      in {
        # U-Boot image for an Android boot slot.
        uboot-image = nixos-fairphone-fp5.lib.mkUbootImage pkgs;

        # Nested GPT image containing the ESP and your complete NixOS system.
        disk-image = nixos-fairphone-fp5.lib.mkDiskImage
          self.nixosConfigurations.my-fairphone;
      };
  };
}
```

### Build and Flash Images

> [!CAUTION]
> Flashing the image permanently erases everything in `userdata`, including Android apps, files, and settings. Back up anything you need before continuing.

> [!TIP]
> If you use remote builders, I recommend configuring Nix to always use remote builders by default on your Fairphone. This way, you don't have to rebuild locally on your phone when running `nixos-rebuild boot` or `nixos-rebuild switch`. Otherwise, builds might take a very long time or even fail due to insufficient resources.

1. Build both images from the configuration shown above:

   ```sh
   nix build .#packages.aarch64-linux.uboot-image --out-link result-uboot
   nix build .#packages.aarch64-linux.disk-image --out-link result-disk
   ```

   To delegate your configuration's builds to nixbuild.net, run:

   ```sh
   nix build .#packages.aarch64-linux.uboot-image --out-link result-uboot --max-jobs 0 --builders "ssh://eu.nixbuild.net aarch64-linux - 100 1 big-parallel,benchmark" --option builders-use-substitutes true
   nix build .#packages.aarch64-linux.disk-image --out-link result-disk --max-jobs 0 --builders "ssh://eu.nixbuild.net aarch64-linux - 100 1 big-parallel,benchmark" --option builders-use-substitutes true
   ```

2. Turn off the phone, then hold Volume Down and Power until the fastboot screen appears.
3. Connect the phone to the build host over USB-C.
4. From the directory containing `result-uboot` and `result-disk`, start a shell containing the fastboot tools:

   ```sh
   nix shell nixpkgs#android-tools
   ```

5. Flash the images and reboot:

   ```sh
   fastboot flash boot result-uboot
   fastboot erase dtbo
   fastboot flash userdata result-disk/image.raw
   fastboot reboot
   ```

The first boot may take a while while the root filesystem expands to the available space.

> [!IMPORTANT]
> When booting NixOS, the display will show various artifacts, and the screen will be black for a brief moment. This is expected behavior and doesn't mean something is wrong. Just wait a bit until the device has fully booted and the login prompt or screen appears.

### Restore Android

> [!CAUTION]
> Reinstalling Android erases NixOS and everything in `userdata`. It cannot recover previous Android user data.

Reinstall Fairphone OS using Fairphone's [official manual installation instructions](https://support.fairphone.com/hc/en-us/articles/18896094650513-How-to-manually-install-Android-on-your-Fairphone).

## Advanced Usage

In some advanced use cases, you might want to change the process of building the images, or do other customizations. In that case, you can use the `fairphone-fp5` overlay provided by this flake directly, which allows you to use the included packages in the way you want.

```nix
{
  inputs.nixos-fairphone-fp5.url = "github:gian-reto/nixos-fairphone-fp5";

  outputs = { nixpkgs, nixos-fairphone-fp5, ... }: {
    nixosConfigurations.my-fairphone = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        {
          nixpkgs.overlays = [ nixos-fairphone-fp5.overlays.default ];

          # Now you have access to all Fairphone packages:
          # pkgs.kernel-fairphone-fp5
          # pkgs.firmware-fairphone-fp5
          # pkgs.uboot-fairphone-fp5
          # pkgs.pd-mapper, pkgs.qrtr, pkgs.rmtfs, etc.
        }
        # Your custom configuration...
      ];
    };
  };
}
```

## Development & Contribution

This flake outputs the `uboot-image` package, as well as `disk-image-minimal` and `disk-image-gnome-mobile` packages for the example host configurations in `./hosts`. These can be built and flashed as described above. By default, the example user is called "admin", and the password is "admin" as well.

At the moment, the development process is mostly done by changing code, building new images, and then testing them on the device. This can be quite tedious, as the build times are relatively long (even with a remote builder), but for now this is the best way to make sure everything works as expected on the actual hardware.

### AI

The development in this repository is partially assisted by AI tools. Contributions made with the help of AI are welcome, provided that they are reviewed and tested by human contributors to ensure quality and correctness.

Coding agents must adhere to the instructions and guidelines outlined in [AGENTS.md](AGENTS.md) when working in this repository.

## Thanks

- Huge thanks to the PostmarketOS community for their incredible work on porting Linux to the Fairphone 5 (especially to Luca Weiss, the main maintainer of the Fairphone ports) and other devices. Their efforts have laid the groundwork for this NixOS port, and their documentation and resources have been invaluable throughout the development process.
- This port was also inspired by [MatthewCroughan/nixos-qcm6490](https://github.com/MatthewCroughan/nixos-qcm6490), which is an attempt to port NixOS to the SHIFTphone 8 (otter), which uses the same SoC as the Fairphone 5. Not sure if the port was successful, but the code was still an invaluable reference. Thanks, Matthew!
- [chuangzhu/nixpkgs-gnome-mobile](https://github.com/chuangzhu/nixpkgs-gnome-mobile) was an invaluable resource for getting GNOME Mobile to work on NixOS.
