# IBM 5155 Portable PC

The IBM 5155 Portable is a PC released in 1984. It is based on the IBM XT released in 1983 but in a "portable" form with internal amber monochrome CRT monitor.

Don't let the name fool you, at 13.6kg, it is heavier than many modern desktop PCs.

<img src="photos/5155-front.jpg" width="500">

Front of the PC with 5.25" 360K floppy and Gotek Floppy emulator with HxC firmware.

<img src="photos/5155-internal.jpg" width="500">

Using up almost all the ISA slots.

<img src="photos/5155-xtideboot.jpg" width="500">

An XT-IDE card is used which has a boot loader to boot from selected disks.

## Specifications

<img src="photos/5155-intel-cpu.jpg" width="500">

* Intel 8088 4.77Mhz
* Intel 8087 FPU
* Motherboard only has 256K onboard

Motherboards from early IBM PCs are bare with most of the external functionality provided by ISA cards.

<img src="photos/5155-isa-cards.jpg" width="500">

Expansion cards from top left

* IBM CGA Graphics
* 3Com 3C503 10Mbps Ethernet
* XT-IDE Rev 4
* Creative Sound Blaster 16 CT2950 CQM
* Bidirectional Parallel Port
* Monotech MicroRAM - 640K + UMB RAM
* Transcend 40-pin IDE Flash Module
* Floppy Disk and Serial Controller

The IDE flash module is used as the system seems to run more stable with it than from CompactFlash cards.

## DOS Boot Configuration

The machine is configured for single-boot DOS 6.22 and very similar to the NuXT PC.

* Crynwr 3C503 packet driver
* MTCP environment variables
* Cutemouse
* SBPNPXT to configure Sound Blaster ISA PnP

At the end of the boot process, it will sync the time from an NTP server as there is currently no RTC in the system.

## Extra files

I was experimenting in getting an Real-time clock to work with this system but did not manage to succeed. I'm just including the files I tried as reference.

1. [DS1216E RTC program](https://www.brutman.com/PCjr/DS1216E.html)
2. [David_M generic clock program](http://minuszerodegrees.net/rtc/rtc.htm)

The `DSKA0001_dos6boot.img` is a 1.44MB floppy image containing a minimal DOS environment and a subset of MTCP's tools. 

This is used for initial boot/install as the Transcend Flash Module's IDE connector is using a female connector which is hard to connect to a USB-IDE adapter. Thus I can't easily copy files to it.

After booting from the floppy image, I start an FTP server and then copy the rest of the files to it.

## Manuals

1. [Technical Reference](http://www.minuszerodegrees.net/manuals/IBM_5155_5160_Technical_Reference_6280089_MAR86.pdf)
2. [Operations Manual](http://classiccomputers.info/down/IBM/IBM_PC_Portable_5155/IBM_5155_Guide_to_Operations_6936571_JAN84.pdf)
3.  [PSU Review by Hugo Holden](http://worldphaco.com/uploads/The_IBM_5155_POWER_SUPPLY.pdf)
