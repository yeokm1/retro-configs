# Hand386 (2023)

This is a new 386-based palmtop released in 2023. It runs on DOS 6.22 and Windows for Workgroups (WFW) 3.11.

<img src="photos/hand386-full-setup.jpg" width="600">

Here the system is running Descent on lowest quality setting.

Windows 95 which came preinstalled in the system is not recommended.

[![Hand386 demo video](https://img.youtube.com/vi/lzJxZhzbwS4/default.jpg)](https://youtu.be/lzJxZhzbwS4)

Demo video of the Hand386 running some games and applications.

## Specifications

* Ali M6117 with chipset (386SX-40)
* Chips and Tech F65535
* YMF262-M OPL3 with YAC512 DAC
* OPL3-driven speakers
* PC-speaker
* 8MiB RAM
* 2500 mAh battery
* 128 x 150 x 16mm (measured dimensions)
* Ports
  * CF card slot
  * USB port for flash drives
  * Connector for VGA output, PS/2 mouse and keyboard
  * Connector for 8-bit ISA bus extender
  * Headphone jack

<img src="photos/hand386-delivered.jpg" width="500">

These are the items that are delivered

* 2GB CF card
* 3-slot 8-bit ISA extender
* 2x30 pin 2.00mm pitch IDC ribbon cable
* VGA, PS/2 mouse and keyboard breakout board
* 2x6 pin 2.00mm pitch IDC ribbon cable
* 2A USB charger
* USB to barrel jack charge cable

## ISA Docking station

<img src="photos/hand386-isa-cards.jpg" width="500">

3 cards are populated:

* 3Com 3C905B-TPO NIC
* Blasterboard (Sound Blaster 2.0 clone)
* RTC

The cards and ISA backplane are placed on a vertical bracket riser that was initially meant for external PCIe GPUs. Thanks to awesome PC backward compatibility, even ISA cards can fit there as well.

### 3C905

The 16-bit ISA 3C905B-TPO card can operate in 8-bit mode.

It requires an initial configuration of the address and interrupt settings. I used the 8088-compatible tool from [here](https://github.com/hackerb9/3C509B-nestor) to do that.

### RTC

The RTC performance of this device is quite poor in my opinion at an approximate error of 1 minute every 1-2 hours. On some occasions, the time is outright lost altogether. To workaround this issue, I opted to use a dedicated [RTC ISA 8 bits (Very Low Profile)](https://www.tindie.com/products/spark2k06/rtc-isa-8-bits-very-low-profile-2/).

This is the [RTC Program](https://github.com/wilco2009/RTC_micro8088) used to work with the RTC board.

## Configuration

### OS Installation

Since the device does not natively have a floppy controller, one will either have to add a floppy controller to the bus extender or install the OS with another system first.

I opted with the latter approach. I installed DOS 6.22 and WFW 3.11 on the CF card using another system. Then moved the card back to the Hand386 to continue installing other programs.

This technique can work on Windows 95 as well. You will want to do that as it will take about 2-3 hours for the native Win95 installation to complete due to the slow CPU speed. When you move the CF card, start the Add hardware wizard for Windows 95 to detect the changed hardware to install the drivers.

### Video

By default, the video BIOS locks the screen resolution to 640x480 60Hz with the right portion being cutoff. The typical DOS resolution is 720x400 70Hz (80x25 text mode). 

<img src="photos/hand386-crt-mode.jpg" width="500">
Left shows the default mode, right shows the typical mode.

We can use CT.COM obtained from the [driver pack](https://oemdrivers.com/graphics-chips-f65545) (meant for 65545) to switch it to the typical mode.

### BIOS

Not much configuration is required. However if the BIOS is reset accidentally or otherwise, the PS/2 mouse port will be disabled by default which needs to re-enabled manually.

To enter the BIOS, press and hold the `del` key while turning on the power.

<img src="photos/hand386-bios-mouse.jpg" width="500">

Go to `Advanced CMOS setup` -> `Mouse Support` and enable it.

### CH375

I faced some issues with using the default `CH375DOS.sys` as it can't mount some of my flash drivers properly. 

I have better luck with `ch375286.sys` obtained from a [Youtuber's THE PHINTAGE COLLECTOR github](https://github.com/gpdm/TPC-CH375-testsuite) when he did some some [evaluation on several drivers](https://www.youtube.com/watch?v=4WvHR_Cy2ME).

### Adlib on WFW 3.11

The Adlib (OPL) Midi driver is provided by WFW 3.11 by default so simply install it in the Drivers panel.

A third-party driver that uses the OPL chip to generate PCM sounds can be found [here](https://archive.org/details/ADLIBW_ZIP).

Note that there is no known means to disable the onboard OPL chip. If you install an OPL-capable card on the bus extender like a Sound Blaster, both will generate the FM output.

## References

1. Manuals: Provided by the store
2. [C&T F65535 datasheet](http://old.vgamuseum.info/images/stories/doc/chips/f65535.pdf)
3. [Ali M6117D datasheet](https://www.dmp.com.tw/app/webcamera/pdf/m6117d.pdf)
4. [AMIC A420616AS-50F datasheet](https://www.alldatasheet.com/view.jsp?Searchword=A420616AS-50F)
5. [39SF512_SS datasheetT](https://www.mouser.com/datasheet/2/268/40284-287606.pdf)