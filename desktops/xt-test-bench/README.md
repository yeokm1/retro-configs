# XT Test Bench (1985)

This is a clone XT motherboard that was given to me with no documentation. Based on XT clone motherboards on [theretroweb](https://theretroweb.com/motherboards/s/amax-engineering-amax-2000xt), I suspect this motherboard to be [AMAX 2000XT](https://theretroweb.com/motherboards/s/amax-engineering-amax-2000xt) or similar.

I have set it up to run DOS 6.22.

<img src="photos/xttest-board.jpg" width="600">

## Hardware Specifications

* AMD/Intel 8088-1 (10 Mhz capable)
* Intel 8087-1
* 640KB RAM
* [Monotech PS/2 to XT Converter](https://monotech.fwscart.com/product/ps-2-to-xt-keyboard-converter)

<img src="photos/xttest-cpu.jpg" width="800">

50x14x7mm heatsinks are applied to 8088 and 8087 to vent off the heat to preserve chip lifespan. [Aliexpress purchase links](https://www.aliexpress.com/item/1005004923109486.html)

<img src="photos/xtbench-pc-sprint.jpg" width="600">

I fabricated the [PC Sprint](https://github.com/reeshub/pc-sprint) to use on this motherboard as a quick way to overclock the system. A 22Mhz crystal was used.

## BIOS ROM

<img src="photos/xtbench-glabios.jpg" width="600">

The BIOS was replaced with a 32KB [GLaBIOS](https://github.com/glabios/glabios) ROM.

<img src="photos/xtbench-rom.jpg" width="600">

The original BIOS was 8KB chip so I used a 32KB AT27C256R chip and duplicated the ROM image 4 times.

```bash
copy /b GLABIOS_0.4.1_8T.rom + GLABIOS_0.4.1_8T.rom + GLABIOS_0.4.1_8T.rom + GLABIOS_0.4.1_8T.rom GLABIOS_0.4.1_8T_32k.rom
```

## Expansion Cards:

<img src="photos/gg-hdmi-board.jpg" width="500">

[Graphics Gremlin HDMI](https://github.com/yeokm1/graphics-gremlin-hdmi) CGA graphics card.

<img src="photos/xttest-picomem.jpg" width="500">

[Picomem Audio Edition](https://www.serdashop.com/PicoMEM) acting as HDD emulator, Wireless NE2000 emulator and Expanded Memory.

## Configuration

<img src="photos/xttest-post.jpg" width="500">

Initial POST message

### PicoMem BIOS Configuration

<img src="photos/xtbench-picomem-config.jpg" width="500">

Wifi, EMS and HDD emulation. Provided PMEMM EMS driver is loaded to initialise the EMS memory.

<img src="photos/xtbench-picomem-mem.jpg" width="500">

4MB of EMS memory.

### Landmark System Speed Test

<img src="photos/xttest-speedtest.jpg" width="800">

* Left: PC Sprint in default clock speed
* Right: PC Sprint overclocking CPU


# Reference
1. [Manual](https://theretroweb.com/motherboards/s/amax-engineering-amax-2000xt)
2. [Picomem stuff](https://github.com/FreddyVRetro/ISA-PicoMEM/)
