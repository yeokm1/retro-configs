# Tweener PC

My "Tweener PC" is affectionately called that as it contains a healthy mix of new and old technologies. From ISA, 3.5" and 5.25" floppy drives to modern Ethernet and USB.

The machine is configured for single-boot Windows 98SE with a bootup option to enter pure DOS configuration only.

<img src="photos/tweener-front.jpg" width="500">

Front of the PC with DVD-RW, ZIP-750, 1.2MB 5.25", 1.44MB Floppy, CompactFlash as hard disk.

<img src="photos/tweener-disks.jpg" width="500">

With all trays open.

<img src="photos/tweener-mobo.jpg" width="600">

CD-In and Wake-on-LAN cables are used.

<img src="photos/tweener-post.jpg" width="500">

A very retro BIOS POST screen from yesteryears.

Video of bootup sequence: https://www.youtube.com/watch?v=SrTD2QFwS8w

<img src="photos/tweener-gotek-external.jpg" width="500">

I recently switched the floppy drive to a Gotek flashed with FlashFloppy firmware.

<img src="photos/tweener-gotek-pins.jpg" width="500">

A piezo is added virtual motor sounds. Jumpers are placed on JC and S1 to select for IBM PC compatible according to this [documentation](https://github.com/keirf/flashfloppy/wiki/Initial-Setup).

## Specifications

<img src="photos/tweener-cpu.jpg" width="300">

* Intel Pentium III 667Mhz 133Mhz FSB 
* * Socket 370 (FC-PGA)
* * 1300 Mhz actual but BIOS cannot recognise this CPU hence I cannot set a multiplier higher than 5.0x therefore the original speed cannot be reached.
* Asus CUV4X motherboard
* * VIA VT82C694Z chipset
* * 2x USB 1 
* * 1x ECP/EPP Parallel port
* * 1x external RS232 port
* * UltraDMA/66 IDE controller
* 3x512MB PC133 SDRAM
* * Software limited to 512MB RAM
* 32GB Sandisk Compactflash card
* Sony AW-G170A DVD-RW IDE
* ZIP-750 IDE
* 1.2MB 5.25" Floppy
* 1.44MB 3.5" Floppy

### Expansion cards

<img src="photos/tweener-gfx-front.jpg" width="500">

Galaxy Nvidia Geforce 5500 256MB

<img src="photos/tweener-network-card.jpg" width="500">

3Com 3C905 PCI 10/100 Mbps

<img src="photos/tweener-awe64-simmconn.jpg" width="500">

Creative Sound Blaster AWE64 Gold ISA with SIMMConn

The [SIMMConn Revival](http://simmconn.tripod.com/) allows typical SIMM-72 RAM to store large Soundbanks. I have 32MB installed.

## BIOS ISA configuration

Some system resources have to be allocated to the ISA bus for use by the sound card.

<img src="photos/tweener-isa-irq.jpg" width="600">

<img src="photos/tweener-isa-dma.jpg" width="600">

Interrupt 5 and DMA 1 have to be enabled in the BIOS.

## Boot Configuration

The machine is configured for single-boot Windows 98SE with a bootup option to enter pure DOS configuration only. I have separate boot configurations for DOS and Windows configured in `CONFIG.SYS` and `AUTOEXEC.BAT`. The Windows version will not load the DOS specific drivers.

<img src="photos/tweener-dos-mode-select.jpg" width="500">

### Windows Mode

<img src="photos/tweener-w98-desktop.jpg" width="500">

Only the Nvidia, 3Com and SCSI drivers are needed. Win 98SE already has the latest AWE64 drivers.

#### RAM limit

The Windows 98 installer will not start if the PC has more than 1GB of RAM.

To overcome this, I inserted only one stick of RAM and installed the operating system to completion.

<img src="photos/tweener-limit-ram.png" width="600">

After completion, I used `msconfig` to limit the recognised RAM to 512MB for better stability. Then inserted in the other 2 sticks.

#### Windows Nvidia driver

The latest Win 9x Nvidia driver 81.98 does not support this Geforce2 GTS Pro model so I used a slightly older version 71.84.

#### Windows Sound Drivers

One can opt to not to install any sound drivers as Win 98 SE already supports the AWE64 gold by default.

However, if you need the utilities like `AWE Control` and Midi player, you have to install the AWE64 Gold CD which will come with updated drivers.

The problem with these drivers is that it will overwrite the `BLASTER` variable in `autoexec.bat` on shutdown to something you may not want.

<img src="photos/tweener-win-sound-config.png" width="600">

To overcome this, we have to set the Windows sound card resources to match the DOS settings so it will overwrite the same thing back.

#### Windows Midi

Since this AWE64 Gold has extra memory thanks to SIMMCONN, I can load extra soundfonts to it.

<img src="photos/tweener-win-midi.png" width="400">

One good Soundfont to consider is the [Roland SC-55 SoundFont](https://github.com/trevor0402/SC55Soundfont/releases) by [Trevor0402](https://github.com/trevor0402).

To use in DOS games, simply point the DOS game to use General Midi at the appropriate port usually 330.

Do note that loading a large sound font will take many seconds and has to be done on every bootup thus delaying system start. One may want to select a smaller sound font before shutdown to prevent this issue.

### DOS Mode

* EMM386 NOEMS configuration to enable `devicehigh` and `loadhigh`
* 3Com Packet drivers
* MTCP environment variables
* Cutemouse
* [Universal PnP Sound card enabler by Jazefox](https://www.vogons.org/viewtopic.php?f=62&t=72553)
* CDROM drivers

#### DOS Sound

<img src="photos/tweener-unisound-init.jpg" width="500">

Using Jazefox's Universal PnP Sound card enabler to configure the PnP settings much faster than Creative's own tool under DOS.

<img src="photos/tweener-sb-diagnose.jpg" width="500">

I still keep Creative's DIAGNOSE tool to test the DRAM.

#### Network

<img src="photos/tweener-3c905-config.jpg" width="500">

After loading 3c905 packet drivers.

<img src="photos/tweener-mtcp.jpg" width="500">

Loading MTCP to prove packet drivers work.

## CUV4X BIOS

I flashed the latest stable BIOS Version 1009 dated
2001/08/09. 

## Sources
1. [3C905 drivers](https://lost-contact.mit.edu/afs/sur5r.net/service/drivers+doc/3com/3c905/support.3com.com/infodeli/tools/nic/3c905.htm)
2. [AWE64 Gold CD](https://www.philscomputerlab.com/drivers-for-awe64-gold.html)
3. [Nvidia Forceware drivers for Win 9x](https://www.philscomputerlab.com/nvidia-9x-graphics-drivers.html/)
4. [LSI 53C1010 x86 drivers](ftp://ftp.tyan.com/SCSI/LSI1010/111700/LSI1010.exe)
5. [LSI 53C1010 x64 drivers](http://www.edugeek.net/forums/windows-7/96515-windows-7-x64-drivers-lsi-20160-scsi-adaptor.html)
6. [BIOS sources](https://www.asus.com/supportonly/CUV4X/HelpDesk_BIOS/)
