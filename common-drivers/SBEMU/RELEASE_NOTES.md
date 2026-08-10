# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-beta.6] - 2026-06-16
### :sparkles: New Features
- [`3869f9e`](https://github.com/crazii/SBEMU/commit/3869f9e780a7365e9a326bd2f06e561f3e2991ae) - change /FIXTC from siwtch to threshold in Hz. (merge 7f6ea67). *(commit by [@crazii](https://github.com/crazii))*
- [`c2aeb80`](https://github.com/crazii/SBEMU/commit/c2aeb80f035bd031126d7c098a0f812f0f22d955) - swap stereo (left/right channel), build swtich, no runtime option. (merge 26c6a4f & f5c0616) *(commit by [@crazii](https://github.com/crazii))*
- [`85fc657`](https://github.com/crazii/SBEMU/commit/85fc657d89545b10e07307c33bbce562daf7599a) - improve mixing and SF/OPL volume balancing. (merge c9172d0). *(commit by [@crazii](https://github.com/crazii))*
- [`95c1da4`](https://github.com/crazii/SBEMU/commit/95c1da40f96e8481181875e763a27fb631a0a1a7) - [EXPERIMENTAL] enable IF on feeding sound buffer to provide better IRQ0 timing. (merge aba928c) *(commit by [@crazii](https://github.com/crazii))*

### :bug: Bug Fixes
- [`5d72285`](https://github.com/crazii/SBEMU/commit/5d722852401626c77b6e0fd4652899d727ac0f0d) - OPL volume x1.5 (merge 39b8a1d) *(commit by [@crazii](https://github.com/crazii))*
- [`521aa1e`](https://github.com/crazii/SBEMU/commit/521aa1e58afec6d9f1c83aab1cf66d56a7cc8c11) - set T for BLASTER env. (merge 77155a4) *(commit by [@crazii](https://github.com/crazii))*
- [`daa0c83`](https://github.com/crazii/SBEMU/commit/daa0c836034d047f12bbbc1322f6aba3fb812726) - change /VOL volume range from [0,9] to [0, 100] for better granuarity control. if you previously set /VOL8 in your AUTOEXEC.BAT, then a simple change to /VOL80 would be fine. for more details, check the "/VOL" in README.txt (merge 3471ab7) *(commit by [@crazii](https://github.com/crazii))*
- [`c940a0e`](https://github.com/crazii/SBEMU/commit/c940a0e1cb8c3c0ac0ef4e370b7b631e90c197f4) - fix Virtual DMA flipflop bug when accessed by BIOS (HP T5720) in duke3d and rott. (merge 5d7b649). *(commit by [@crazii](https://github.com/crazii))*

### :memo: Documentation Changes
- [`a2178ce`](https://github.com/crazii/SBEMU/commit/a2178ce60055b68679696583b553ca07752ebd25) - update readme on /T and /K. (merge cd373ca) *(commit by [@crazii](https://github.com/crazii))*

[1.0.0-beta.6]: https://github.com/crazii/SBEMU/compare/1.0.0-beta.6rc2...1.0.0-beta.6

# User instructions

## Available files

If you wish to use SBEMU and its dependencies in an existing DOS installation, you'll find the necessary
files in `SBEMU.zip`.

Alternatively, `SBEMU-FD13-USB.img.xz` provides SBEMU and is dependencies preconfigured inside a compressed
bootable FreeDOS image that you can write to a USB flash drive or an SD card.

<details>
<summary>Preparing a bootable USB drive</summary>

## Preparing a bootable USB drive

The USB image can be written to a USB drive or SD card using a tool like [balenaEtcher](https://etcher.balena.io/).

The advantage of using Etcher is that you don't have to decompress the `.xz` archive first.
It will decompress such files automatically, before writing the image to the target drive.
</details>
<details>
<summary>Booting the USB image in a virtual machine</summary>

## Booting the USB image in a virtual machine

You can run the image in a VM with QEMU as follows:

```shell
unxz SBEMU-FD13-USB.img.xz
qemu-system-i386 -drive file=SBEMU-FD13-USB.img,format=raw -device AC97
```

If you wish to test Intel HDA compatibility instead of ICHx AC'97 compatibility, replace `AC97` with `intel-hda` in the last command above.
On Linux, you can include the parameter `--enable-kvm` to run the VM with hardware-assisted virtualization.

If you prefer to use another hypervisor, such as VirtualBox or VMware, you may have to convert the raw image to a supported VM image format first:

```shell
unxz SBEMU-FD13-USB.img.xz
qemu-img convert -f raw -O vmdk SBEMU-FD13-USB.img SBEMU-FD13-USB.vmdk
```

**NOTE**: Although VMs can sometimes be useful during development, testing and debugging, you should not rely on those for actual hardware compatibility testing, since the sound cards that the hypervisors emulate are themselves merely approximations of actual hardware, and will not behave like the real thing in every single corner case.
Basically, you shouldn't test emulators on other emulators.
</details>
<details>
<summary>Where can I get some DOS games to test with?</summary>

## Where can I get some DOS games to test with?

There are multiple convenient distributions out there that contain DOS games that can be distributed freely and legally.
Specifically freeware, shareware, open source and free demo versions.

Here are a few links to such distributions:

- [The PC/DOS Mini](http://vieju.net/pcdosmini/), a compilation of 100+ DOS games ready to play for free
- [GAFFA DOS Shareware/Freeware Pack](https://archive.org/details/gaffa-dos-shareware-pack) (please [donate to the Internet Archive](https://archive.org/donate/), by the way!️ ❤️)
</details>
