# Tweener PC

My "Tweener PC" is affectionately called that as it contains a healthy mix of new and old technologies. From ISA, floppy drives to modern Ethernet and USB.

<img src="photos/tweener-front.jpg" width="500">

Front of the PC with DVD-RW, ZIP-750, 1.2MB 5.25", 1.44MB Floppy, CompactFlash as hard disk.

<img src="photos/tweener-disks.jpg" width="500">

With all trays open.

<img src="photos/tweener-mobo.jpg" width="500">

CD-In and Wake-on-LAN cables are used.

## Specifications

* Intel Pentium III 550Mhz 100Mhz FSB
* Asus P2B Rev 1.10 Intel 440BX motherboard
* 2x256MB PC133 SDRAM
* 32GB Sandisk Compactflash card
* NEC ND-3530A DVD-RW IDE
* ZIP-750 IDE
* 1.2MB 5.25" Floppy
* 1.44MB 3.5" Floppy

<img src="photos/tweener-cards.jpg" width="500">

Expansion cards from top left
* Resound OPL3 ISA
* ATI Radeon 9500 Pro 128MB DDR AGP 8X
* 3Com 3C905 PCI 10/100 Mbps
* Creative Sound Blaster AWE64 Gold ISA with SIMMConn 32MB

<img src="photos/tweener-awe64-simmconn.jpg" width="500">

The [SIMMConn Revival](http://simmconn.tripod.com/) allows typical SIMM-72 RAM to be store large Soundbanks. I have 32MB installed.

### Optional cards
I added drivers of these cards as I occasionally may use them for ad-hoc testing.

* Nvidia FX5500
* LSI 53C1010

## BIOS configuration

<img src="photos/tweener-bios-interrupt.jpg" width="500">

Interrupt 5 and DMA 1 have to be enabled in the BIOS for the use of ISA cards.

## Boot Configuration

The machine is configured for single-boot Windows 98SE with a bootup option to enter pure DOS configuration only. I have separate boot configurations for DOS and Windows configured in `CONFIG.SYS` and `AUTOEXEC.BAT`. The Windows version will not load the DOS specific drivers.

<img src="photos/tweener-dos-mode-select.jpg" width="500">

### Windows Mode

<img src="photos/tweener-w98-desktop.jpg" width="500">

Only the ATI and 3Com drivers are needed. Win 98SE already has the latest AWE64 drivers.

### DOS Mode

* EMM386 NOEMS configuration to enable `devicehigh` and `loadhigh`
* 3Com Packet drivers
* MTCP environment variables
* Cutemouse
* [Universal PnP Sound card enabler by Jazefox](https://www.vogons.org/viewtopic.php?f=62&t=72553)
* CDROM drivers

#### Sound

Using Jazefox's Universal PnP Sound card enabler to configure the PnP settings much faster than Creative's own tool.

<img src="photos/tweener-unisound-init.jpg" width="500">

The AWE64's FM is disabled to not conflict with the Resound OPL3.

<img src="photos/tweener-sb-diagnose.jpg" width="500">

I still keep Creative's DIAGNOSE tool to test the DRAM.

#### Network

<img src="photos/tweener-3c905-config.jpg" width="500">

After loading 3c905 packet drivers.

<img src="photos/tweener-mtcp.jpg" width="500">

Loading MTCP to prove packet drivers work.

## Sources
1. [3C905 drivers](https://lost-contact.mit.edu/afs/sur5r.net/service/drivers+doc/3com/3c905/support.3com.com/infodeli/tools/nic/3c905.htm)
2. [AWE64 PnP](https://support.creative.com/Products/ProductDetails.aspx?prodID=1848&prodName=Sound%20Blaster%20AWE64)
3. [ATI Radeon 9xxx drivers](https://www.amd.com/en/support/graphics/legacy-graphics/ati-radeon-9xxx-series/ati-radeon-9500-series5)
4. [Nvidia Forceware 80 81.98](https://www.nvidia.com/Download/Find.aspx)
5. [LSI 53C1010 x86 drivers](ftp://ftp.tyan.com/SCSI/LSI1010/111700/LSI1010.exe)
6. [LSI 53C1010 x64 drivers](http://www.edugeek.net/forums/windows-7/96515-windows-7-x64-drivers-lsi-20160-scsi-adaptor.html)
