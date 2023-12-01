This manual describes how to setup the device driver of TOSHIBA ATAPI
CD/DVD-ROM Drive.
This device driver is exclusive use of following TOSHIBA ATAPI CD/DVD-ROM
drives.
  XM-5602B, XM-5702B, XM-6002B, XM-6102B, XM-6202B, XM-6302B, XM-6402B,
  XM-6502B, XM-6602B, XM-6702B,
  XM-1502B, XM-1602B, XM-2402B, XM-1702B, XM-1802B, XM-1902B, XM-7002B,
  XM-7002Bc,XM-7102B,
  SD-M1002, SD-M1102, SD-M1202, SD-M1212, SD-M1222, SD-M1302, SD-M1402,
  SD-C2202, SD-C2302, SD-C2402,
  SD-R1002(*1)

(*1) This device driver does not support writing ability.

-----------------------------------------------------------------------

How to setup the CD-ROM device driver.

1. Copy CD/DVD-ROM device driver to the system disk.

2. Add the following line to CONFIG.SYS of the system disk.
        LASTDRIVE=Z
        DEVICE=<drive>:<path>\CDROMDRV.SYS <option switch>

    ¥ Option switch
        /D:<device name>     Specifying the device name.
                             Must match the device name of MSCDEX.EXE.

        /V                   Display the detailed information on power up.

        /E                   Driver runs with the highest PIO mode by detecting
                             PIO capability of CD/DVD-ROM drive.

        /B                   Driver enables the DMA transfer.
                             When specifying this option, the driver runs with
                             the highest DMA mode by detecting DMA capability
                             of CD/DVD-ROM drive.

        [For example]
        Copying device driver to C:\CDROM, specifying TOSCD001 in the device
        name.
                DEVICE=C:\CDROM\CDROMDRV.SYS /D:TOSCD001

3. Add the following line to AUTOEXEC.BAT.
        C:\DOS\MSCDEX.EXE /D:<device name>

4. Restart computer.


Note:

1. The following is the restrictive item for (/B) option switch.
  (1) Driver supports DMA transfer only when Intel PIIX, PIIX3 and PIIX4 
      PCI Chip Set.
  (2) When application buffer address (store CD/DVD-ROM data) is not word
      align, the driver will not DMA transfer. (Use PIO transfer)
  (3) When doing DMA transfer with Intel PIIX3 PCI chip set, use EMM386.EXE
      version is more than 4.49.
      (EMM386.EXE Version4.49 should be in MS-DOS 6.22.)
  (4) When DMA transfering, load EMM386.EXE before this device driver is
      loaded into system.

2. Port and IRQ used by this driver often can not run successfully when
   conflicting with the drives (and drivers) of other companies.
