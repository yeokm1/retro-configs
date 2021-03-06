# IBM 5155 Portable PC

The IBM 5155 Portable is a PC released in 1984. It is based on the IBM XT released in 1983 but in a "portable" form with internal amber monochrome CRT monitor.

Don't let the name fool you, at 13.6kg, it is heavier than many modern desktop PCs.

<img src="photos/5155-front.jpg" width="500">

Front of the PC with 5.25" 360K floppy and Gotek Floppy emulator with HxC firmware.

<img src="photos/5155-internal.jpg" width="500">

Using up all the ISA slots except the harder-to-use Slot 8.

<img src="photos/5155-back-opened.jpg" width="500">

All the rear IO ports.

<img src="photos/5155-xtideboot.jpg" width="500">

An XT-IDE card is used which has a boot loader to boot from selected disks.

<img src="photos/5155-network.jpg" width="500">

Connecting to the network is possible.

## Specifications

<img src="photos/5155-intel-cpu.jpg" width="500">

* Intel 8088 4.77Mhz
* Intel 8087 FPU
* Motherboard has 640KB upgrade kit installed (See next section)

Motherboards from early IBM PCs are bare with most of the external functionality provided by ISA cards.

<img src="photos/5155-isa-cards.jpg" width="500">

Expansion cards from top left

* IBM CGA Graphics Adapter
* 3Com Etherlink II TP 3C503 10Mbps Ethernet
* [Aitor Gómez's RTC ISA 8 Bits XT](https://hackaday.io/project/168972-rtc-isa-8-bits-pcxt)
* [Sergey Kiselev Floppy Disk and Serial Controller](http://www.malinov.com/Home/sergeys-projects/isa-fdc-and-uart)
* [Glitch Works XT-IDE Rev 4](https://www.glitchwrks.com/2017/11/23/xt-ide-rev4)
* Transcend 40-pin IDE Flash Module
* [Blasterboard: a modern SB 2.0 clone (faulty)](https://www.tindie.com/products/jrlab/blasterboard-a-complete-8-bit-isa-sound-card/)
* AP138B Parallel Port card

The IDE flash module is used as the system seems to run more stable with it than from CompactFlash cards.

<img src="photos/5155-ct2950.jpg" width="500">

The Blasterboard seems to be faulty probably due to soldering. So the final sound card I used is a Creative SB16 CT2950. It does not have the actual OPL3 chip but uses a CQM clone. 

## 640K upgrade

I used the [RAM upgrade kit from Monotech PCs](https://monotech.fwscart.com/640K_RAM_Upgrade_for_IBM_5160/p6083514_20677547.aspx) to boost the default 256KB conventional memory to the maximum of 640KB. Therefore saving an ISA slot for another function which would have otherwise gone to a separate RAM card.

<img src="photos/5155-mem-chips.jpg" width="500">

Replacing Bank 0 and Bank 1 with the 18x 256K-bit chips from the kit.

<img src="photos/5155-u84.jpg" width="500">

Adding the 74LS158 multiplexer/decoder chip to empty socket U84.

<img src="photos/5155-u48-pal.jpg" width="500">

The terminals 1 and 8 of the IBM Programmable Array Logic (PAL) chip at U44 are required to be shorted.

As the IBM5155 uses the older version of an XT motherboard, it does not have a jumper terminal to do the shorting easily. A wire has to be wrapped around the chip legs to do the shorting.

More information for this upgrade can be found [here](http://minuszerodegrees.net/5160/motherboard/5160_upgrading_256k_motherboard_to_640k.pdf).


## DOS Boot Configuration

The machine is configured for single-boot DOS 6.22 and very similar to my NuXT PC's configuration.

* MTCP environment variables
* Crynwr 3C503 packet driver
* Get time from RTC

As the SB16 CT2950 is an ISA PNP card, some initialisation is required before it can be used. The latest version of a modern initialisation app [Unisound](https://www.vogons.org/viewtopic.php?t=72553) at time of writing unfortunately cannot detect this card. I have to use an alternative [SBPNPXT by dca2](https://www.vogons.org/viewtopic.php?p=479466#p479466).

## RTC

I was experimenting in getting an Real-time clock to work with this system with little success.

Many thanks to Aitor Gómez's [RTC ISA 8 Bits XT](https://hackaday.io/project/168972-rtc-isa-8-bits-pcxt) and his help. I managed to reprogram his board to use the `240h` address and get it to work.

1. [RTC SPLD Binaries](https://github.com/spark2k06/hardware/tree/master/RTC8088/SPLD)
2. [RTC Program from dieymir](http://www.vcfed.org/forum/showthread.php?71958-RTC-ISA-8-bits-(Very-Low-Profile)&p=606650#post606650)

<img src="photos/5155-isartc.jpg" width="500">

### Unused RTC programs for reference
1. [DS1216E RTC program](https://www.brutman.com/PCjr/DS1216E.html)
2. [David_M generic clock program](http://minuszerodegrees.net/rtc/rtc.htm)

## Rescue Floppy

The `DSKA0001_dos6boot.img` is a 1.44MB floppy image containing a minimal DOS environment and a subset of MTCP's tools. 

This is used for initial boot/install as the Transcend Flash Module's IDE connector is using a female connector which is hard to connect to a USB-IDE adapter. Thus I can't easily copy files to it.

After booting from the floppy image, I start an FTP server and then copy the rest of the files to it.

## Manuals

1. [Technical Reference](http://www.minuszerodegrees.net/manuals/IBM_5155_5160_Technical_Reference_6280089_MAR86.pdf)
2. [Operations Manual](http://classiccomputers.info/down/IBM/IBM_PC_Portable_5155/IBM_5155_Guide_to_Operations_6936571_JAN84.pdf)
3. [PSU Review by Hugo Holden](http://worldphaco.com/uploads/The_IBM_5155_POWER_SUPPLY.pdf)
4. [IBM5160 and IBM5155 motherboard versions](http://minuszerodegrees.net/5160/motherboard/5160_motherboard_revisions.htm)
5. [SBPNPXT by dca2](https://www.vogons.org/viewtopic.php?p=479466#p479466)
