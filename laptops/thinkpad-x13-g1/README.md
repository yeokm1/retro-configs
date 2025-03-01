# Thinkpad X13 Gen 1 (Intel)

The Thinkpad X13 Gen 1 (Intel) is a modern laptop released in 2020. I believe it is of the last Thinkpad generation to support UEFI-CSM that supports legacy 16-bit OSes and S3 sleep state.

Background of this project can be read from my [blog post](https://yeokhengmeng.com/2024/08/dos-on-thinkpad-x13-gen1/).

<img src="photos/x13g1-front-egpu-dock-full.jpg" width="500">

The machine is configured to boot to DOS 6.22 from a USB flash drive.

[![X13G1 demo video](https://img.youtube.com/vi/-mTmZqoNeFA/default.jpg)](https://youtu.be/-mTmZqoNeFA)

Demo video of CPUID, Descent, Doom, Planet X3, ChatGPT, Checkit

[![X13G1 demo video](https://img.youtube.com/vi/eUb_hN1R-no/default.jpg)](https://youtu.be/eUb_hN1R-no)

Demo video running 8088 Domination.

## Specifications

These are the specifications specific to the Thinkpad I have:

* Intel Core i5-10310U 1.7Ghz (6M Cache, up to 4.40 GHz)
* Intel UHD Graphics
* 16GB RAM (soldered in)
* High Definition (HD) Audio with Realtek ALC3287 codec
* 13.3" IPS display with 1920x1080 resolution
* uSD card slot
* 512GB SK hynix Gold P31 PCIe 3.0 NVME (for booting modern OS)
* 4GB USB 2.0 Sandisk Cruzer Titanium (for DOS boot)
* Intel Gigabit PRO/1000
* Intel Wi-Fi 6 AX201, 802.11ax 2x2 Wi-Fi + Bluetooth 5.1 (soldered in)
* Ports
    * 1x USB 3.2 Gen 1
    * 1x USB 3.2 Gen 1 (Always On)
    * 1x USB-C 3.2 Gen 1
    * 1x USB-C 3.2 Gen 2 / Thunderbolt 3
    * 1x HDMI 1.4b
    * 1x Ethernet extension connector
    * 1x Headphone / microphone combo jack (3.5mm)

## BIOS setup

To enable the system to boot DOS, the following settings have to be set:

<img src="photos/x13g1-bios-uefi-csm.jpg" width="500">

UEFI-CSM legacy enabled. For this option to be set, Secure Boot and Kernel DMA has to be disabled.

<img src="photos/x13g1-bios-secure-boot.jpg" width="500">

Secure Boot disabled

<img src="photos/x13g1-bios-kernel-dma.jpg" width="500">

Kernel DMA protection disabled

## DOS setup

I opted to have the DOS installed on an external USB flash drive as it requires a legacy MBR partition table. I do not want it to intefere with the internal NVME drive containing my modern operating systems with the GPT partition table.

<img src="photos/x13g1-dos-setup.jpg" width="500">

A USB floppy drive/emulator can be used to do the installation as the BIOS recognises the drive and assigns it the `A:` drive letter.

## DOS Configuration

The `config.sys` and `autoexec.bat` configuration has been customised by me to load the appropriate menu option depending on my needs.

* JEMMEX combined XMS and EMS driver that is required for SBEMU
* * HIMEM.SYS does not work
* MTCP environment variables
* MS LAN Manager to load NDIS driver
* NDIS to Packet Driver Shim.

<img src="photos/x13g1-boot-menu.jpg" width="500">

The first option that is not legible is `Basic DOS Mode` to not load memory, sound and network drivers for a relatively clean start. The other options load a combination of different sound and network drivers.

## Audio configuration

<img src="photos/x13g1-with-sbemu.jpg" width="500">

Sound Blaster and OPL3 support is provided by the [SBEMU](https://github.com/crazii/SBEMU) driver which can utilise modern sound hardware.

## Network Configuration

<img src="photos/x13g1-intel-driver-cannot.jpg" width="500">

The internal I-219 Gigabit ethernet adapter could not be initialised despite loading the latest DOS drivers from Intel.

<img src="photos/x13g1-intel-lan-detection.jpg" width="500">

Intel's own NVMcheck tool can pick it up though. Shown here is including the I-210 in my Caldigit TS3 Plus dock.

To get network connectivity, the other option is to go through the onboard Thunderbolt 3 port.

All the 3 network adapters I tried requires NDIS 2 drivers provided by the manufacturer to be loaded by MS LAN Manager and a NDIS to Packet Driver Shim.

### Realtek 8125 2.5GbE via Thunderbolt eGPU dock

<img src="photos/x13g1-rtl8125.jpg" width="500">

A 2.5GBE link can actually be negotiated as shown by the driver if the cable and the other end is capable of it. In practice though, the actual speed is nowhere near.

### Apple Thunderbolt 2 1GbE with TB3-TB2 adapter (Broadcom)

<img src="photos/x13g1-apple-tb2-ethernet.jpg" width="500">

The Apple Thunderbolt (2) to Gigabit Ethernet Adapter can be used in conjuction with an also Apple Thunderbolt 3 (USB-C) to Thunderbolt 2 Adapter. 

The Ethernet adapter is based on the Broadcom BCM57762 chip. Hence I used a B57 NDIS2 driver.

I noticed the B57 driver introduces an unexplained slowdown in my system such that games are unplayable.

### Caldigit TS3 Plus 1GbE via Thunderbolt 3 (Intel I210)

<img src="photos/x13g1-i210.jpg" width="500">

This adapter generally works okay.

I-210 has unexplained random JEMMEX exception crashes together if run together with SBEMU.

### Network speed test

I did a short study of the performance and memory usage of the 3 adapters. I used a similar [test procedure detailed](https://www.brutman.com/mTCP/mTCP_Performance.html) by Michael Brutman (creator of DOS MTCP network tools). 

<img src="photos/x13g1-speedtest.jpg" width="500">

I did a point-to-point connection between the DOS machine and my Framework running Kubuntu with a 2.5GbE Ethernet Expansion Card of RTL8156 chipset.

```bash
# Linux command to create empty 64MiB file
fallocate -l 64M 64MiB.img

# Receiving
# DOS system: 
spdtest -receive -listen 2000
# Linux side: 
time nc -N 192.168.1.71 2000 < bogus.bin

# Sending
# DOS system: 
spdtest -send -listen 2000 -mb 64
# Linux side: 
time nc -d 192.168.1.71 2000 > bogus.bin
```

#### Network speed test and memory results

|              | Send Rate (KB/s) | Recv Rate (KB/s) | protman | driver | disk_pkt |
|--------------|------------------|------------------|---------|--------|----------|
| Realtek 8125 | 16440.1          | 29135.7          | 128     | 42288  | 2736     |
| BCM57        | 7960.4           | 14791.4          | 128     | 53168  | 2736     |
| Intel I210   | 26698.5          | 19793.4          | 128     | 56336  | 2736     |

The last 3 columns show the memory usage of the different driver components in bytes. 

We can observe the transfer speeds do not even come close to the 1 Gbit/s or 125000 KB/s.

## Performance benchmarks

I ran several benchmark applications from [Phil's Computer Lab DOS Benchmark Pack](https://www.philscomputerlab.com/dos-benchmark-pack.html) in stock configuration. 

[![X13G1 benchmark video](https://img.youtube.com/vi/YMfRvdlx4pg/default.jpg)](https://youtu.be/YMfRvdlx4pg)

These are the results:

| Time  | Idx | Description                      | Real mode                               | Protected Mode              |
|-------|-----|----------------------------------|-----------------------------------------|-----------------------------|
| 00:06 | 1   | 3DBench (Superscape) 1.0         | 11.1 (incorrect)                        |                             |
| 00:23 | 2   | 3DBench (Superscape) 1.0c        | 106.5                                   |                             |
| 00:43 | 3   | Chris's 3D Benchmark             | 218.1 score, 130.8 FPS                  |                             |
| 01:10 | 5   | PC Player benchmark 320x200 8bpp | 139.4                                   |                             |
| 01:45 | 6   | PC Player benchmark 640x480 8bpp | 22.2                                    |                             |
| 02:19 | a   | Doom min. details                | 2134 gametics, 294 realtics, 253.04 FPS |                             |
| 02:43 | b   | Doom max. details                | 2134 gametics, 1799 realtics, 41.52 FPS |                             |
| 03:49 | c   | Quake timedemo                   | 969 Frames, 7.5s, 128.4 FPS             |                             |
| 04:10 | d   | Quake timedemo 360x480           | 969 Frames, 21.7s, 44.7FPS              |                             |
| 04:48 | m   | TOPBENCH 3.8                     | 290                                     |                             |
| 04:55 | n   | Speedsys 4.78                    | 2904.46 score                           |                             |
| 08:16 | e   | Quake timedemo 640x480           | Crash (likely insufficient memory)      | 969 frames, 167.4s, 5.8 FPS |
| 11:23 | l   | Landmark System Speed Test 6.00  | Cannot start                            | Unreliable results          |

## Sources

1. [X13 Hardware Maintenance Manual](https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x13-type-20t2-20t3)
2. [Microsoft Network Client 3.0](https://archive.org/details/MSCLIENT30)
3. [Vogons forum guide on DOS networking](https://www.vogons.org/viewtopic.php?f=61&t=61823&p=691154#p691154)
4. [Realtek NDIS2 driver](https://www.realtek.com/Download/List?cate_id=584)
5. [MTCP speed test guide](https://www.brutman.com/mTCP/mTCP_Performance.html)
6. [Packet drivers](https://packetdriversdos.net/)
7. [Intel DOS](https://www.intel.com/content/www/us/en/download/2595/intel-ethernet-adapter-drivers-for-ms-dos-final-release.html)
