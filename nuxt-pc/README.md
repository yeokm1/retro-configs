# NuXT PC

My NuXt PC is based on a modern 8088-based XT motherboard in a uATX form factor.

<img src="photos/nuxt-external.jpg" width="500">

Front of the PC with IDE HDD caddy (just a filler), Gotek Floppy emulator with HxC firmware, 3.5" 1.44 MB HDD.

<img src="photos/nuxt-internal.jpg" width="500">

## Specifications

* NEC V20 overclocked to 9.55Mhz via BIOS setting
* NuXT motherboard
* 640KiB conventional RAM
* 512MB Sandisk Compactflash card
* 1.44MB 3.5" Floppy

<img src="photos/nuxt-isa-cards.jpg" width="500">

Expansion cards from top left

* National Semiconductor NE2000plus+
* EPP Parallel Port 
* Creative Sound Blaster 16 CT2950 CQM
* RTC ISA 8 bits (Very Low Profile)

## DOS Boot Configuration

The machine is configured for single-boot DOS 6.22. The BIOS is a modified version to support the RTC card. Only one primary partition is created to use the full 512MB CF card.

<img src="photos/nuxt-booting.jpg" width="500">

* NE2000 modified 8-bit driver
* MTCP environment variables
* Cutemouse
* SBPNPXT to configure Sound Blaster ISA PnP

<img src="photos/nuxt-postboot.jpg" width="500">

Finished the boot process

<img src="photos/nuxt-network.jpg" width="500">

Loading MTCP to prove packet drivers work.

## Sources
1. [Modified BIOS with RTC feature](https://github.com/spark2k06/micro_8088/tree/master/BIOS)
2. [NE2000 8-bit driver](https://github.com/yeokm1/ne2000plus-collection)