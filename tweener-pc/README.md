# Tweener PC

My "Tweener PC" is affectionately called that as it contains a healthy mix of new and old technologies. From ISA, floppy drives to modern Ethernet and USB.

<img src="photos/tweener-front.jpg" width="500">

Front of the PC with DVD-RW, ZIP-750, 1.2MB 5.25", 1.44MB Floppy, CompactFlash as hard disk.

<img src="photos/tweener-disks.jpg" width="500">

With all trays open.

<img src="photos/tweener-mobo.jpg" width="500">

## Specifications

These are the specifications specific to the Thinkpad I have:

* Intel Pentium III 550Mhz 100Mhz FSB
* MSI MS6163 Pro Intel 440BX motherboard
* ATI Radeon 9500 Pro 128MB DDR AGP 8X
* 2x 256MB PC133 SDRAM
* Creative Sound Blaster AWE64 Gold ISA
* Resound OPL3 ISA
* 3Com 3C905 PCI 10/100 Mbps
* VIA USB 2.0 PCI Controller
* 32GB Sandisk Compactflash card
* DVD-RW IDE
* ZIP-750 IDE
* 1.2MB 5.25" Floppy
* 1.44MB 3.5" Floppy

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
* Creative PnP manager to configure AWE64
* CDROM drivers

<img src="photos/tweener-3c905-config.jpg" width="500">

After loading 3c905 packet drivers.

<img src="photos/tweener-mtcp.jpg" width="500">

Loading MTCP to prove packet drivers work.

## Sources
1. [3C905 drivers](https://lost-contact.mit.edu/afs/sur5r.net/service/drivers+doc/3com/3c905/support.3com.com/infodeli/tools/nic/3c905.htm)
2. [AWE64 PnP](https://support.creative.com/Products/ProductDetails.aspx?prodID=1848&prodName=Sound%20Blaster%20AWE64)
3. [ATI Radeon 9xxx drivers](https://www.amd.com/en/support/graphics/legacy-graphics/ati-radeon-9xxx-series/ati-radeon-9500-series5)


