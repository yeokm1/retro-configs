
                                    SHCDX33F

                       Derived from SHSUCDX V3.03 Freeware,
                            Copyright 2005 Jason Hood.
                    Derived from SHSUCDX V1.4b by John McCoy.


    Description
  ===============

    SHCDX33F is an unloadable "CD-ROM redirector" substitute for MSCDEX.  It
    supports up to 10 drives.   Each drive is single-sector buffered and the
    last 10 directory entries are cached.    Each unit of each driver can be
    assigned a specific drive letter.


    Usage
  =========

    Run SHCDX33F with the name of one or more CD-ROM device drivers.  If the
    drivers are valid, SHCDX33F will install a drive letter for each unit on
    each driver.

    Options
    -------

        /D      driver and drive manipulation
        /L      drive letter
        /C      memory usage
        /V      memory statistics or option information
        /~      tilde usage
        /R      read-only attribute usage
        /I      install
        /U      unload
        /Q      quiet

    /D - Driver

    This option is used to specify the name of the device driver.     It can
    also indicate which unit(s) should be assigned and to what letter.   The
    complete syntax is:

        /D[:][?|*]driver[,[letter][,[unit][,[max]]]]

    DRIVER is the name of the device driver installed to control the  CD-ROM
    drive.  Prefixing the driver with '?' will silently ignore it if it does
    not exist (or is not actually a CD-ROM).    Prefixing with '*' will also
    ignore it, but a drive will be reserved (see below).

    LETTER is the first drive letter to assign to the units on this  driver.
    The  default  is  the  first  available letter.  Note: the drive letters
    assigned to subsequent units will always be higher than  those  assigned
    to previous units.

    UNIT is the first unit on this driver to be assigned a drive.  Unit 0 is
    the default.

    MAX is the maximum number of units on this driver to be assigned drives.
    The default is all units (or all remaining units, if UNIT is given).

    Once installed, /D by itself will display the assigned drives and return
    the number of drives assigned.    [NOTE:  This is NOT part of SHCDX33F].

    /D - Drive manipulation

    At install time, /D can also be used to  reserve  space  for  additional
    drives.  Use  a  single  digit  to  indicate  how  many drives should be
    reserved (eg: /D1).  (If you should happen to have a device driver  name
    with  a single digit, use the '?' prefix.)  After installation, the same
    option will remove the drive(s) that were last assigned.  It is possible
    to  specify both forms of /D, in which case the current drive(s) will be
    removed, then the new drive(s) added.

    /L - Letter

    This option is an alternative to the LETTER component of  /D,  which  it
    must  follow  (ie:  /D:driver /L:letter).  It can also be used to return
    the number of drives installed (/L:0, will return 255 if not  installed)
    and the letter of each assigned drive (/L:1, /L:2, etc., with A: = 1 and
    255 if the drive is not assigned).

    /C - Memory usage

    By default, SHCDX33F will load itself into high memory,if available, or
    into low memory if it is already high.   This option will prevent that.

    /V - Memory statistics

    When this option is used at installation, a summary of memory usage will
    be displayed.  This summary includes:

        Static          code and variables
        Dynamic         data for each drive and paragraph rounding
        Total           overall memory usage

    /V - Information

    When used with /?, or  after  installation,  this  option  displays  the
    compile- and run-time options of SHCDX33F.   This information includes:

        8086/386        the minimum processor required
        CD root form    TRUENAME will return \\D.\A.\ instead of D:\
        High Sierra     the original format for the CD file system
        Joliet          the Windows format for long names
        image on CD     enables access to an image which is itself on a CD

    /~ - Tilde usage

    The ISO standard allows for CDs to have names up to  31  characters  and
    Joliet  can have names up to 64 characters.  When this is reduced to 8.3
    for DOS it may lead to duplicated entries.  This option will remove  the
    duplication by appending a tilded number after the name (similar to what
    Windows does).  By default, tildes are off.  This option is also  avail-
    able  after  installation.  By itself it will toggle the status (ie.  if
    tildes are currently on, /~ will turn them off and vice versa).   Tildes
    can  be explicitly turned on or off by adding a '+' or '-' sign (ie: /~+
    will turn tildes on, irrespective of the current state).

    /R - Read-only attribute usage

    By default, files on the CD are given the  read-only  attribute.  Should
    you  wish to remove this attribute, this option will do so.  As with /~,
    it can be used after installation and it accepts '+' and '-'.

    /I - Install

    Normally SHCDX33F will refuse to install if it detects another redirector
    (such as MSCDEX).   This option will cause SHCDX33F to install anyway.

    /U - Unload

    Unhook the interrupt, free the memory and mark the drive(s) as invalid.

    /Q - Quiet

    Prevent display of the sign-on banner (the copyright notice).  /Q+  will
    only display the drive assignments (when used after install '-' will in-
    dicate a removed drive and '+' an added drive).


    OTHER PROGRAMS
  ==================

    SHCDX33F has not been tested with SMARTDRV, DOSLFN, etc. and is intended
    for use as a basic "CD-ROM redirector" program only.


    Critical Errors
  ===================

    A critical error is only generated on the initial access to the CD.   If
    a read error occurs, the calling function will fail with error 15 (drive
    not ready).  If an image is located on a CD, and that CD is removed,  do
    NOT  abort,  but fail and then abort (the first error is for the CD, the
    second is for the image).


    Additional CD-ROM Functions
  ===============================

    SHCDX33F has an additional installation check:

        Int 2F
        AX = 1100
        BX = BABE
        Return:
          BX = BABE if SHCDX33F v3 not installed, otherwise:
          BL = compile-time flags
          BH = release number
          ES:DI -> drive table
          CX = number of drives
          DX = size of each entry

        Compile-time flags:
        Bit 0 = 0 if 386, 1 if 8086
            1 = 1 if CD root form (\\D.\A.\)
            2 = 1 if High Sierra is supported
            3 = 1 if Joliet is supported
            4 = 1 if image on CD is supported

    There are also functions to control the tilde and read-only state:

        Int 2F
        AX = 150F
        CL = -1
          CH = 0: Get current tilde state in AX (0 off, -1 on)
               1: Set current tilde state from BX (0 off, anything else on)
               2: Get read-only attribute in AX (0 = off, 1 = on)
               3: Set read-only attribute from BX (0 off, anything else on)

        Carry will be cleared (MSCDEX will set carry).

    Finally, there is a function to convert a CD directory name to an FCB:

        Int 2F
        AX = 150F
        CL = -2
          ES:SI -> pointer to directory entry
          ES:DI -> 11-byte buffer for FCB name
             DX = alias number (0 for none)

    The alias number is the number of the directory entry within the sector,
    plus  64  times  the  sector number (both zero based).  For example, the
    third entry in the third sector of a directory would have an alias  num-
    ber of 130 (2 + 2 * 64).


    Exit Codes
  ==============

        0       Uninstalled, help, option set
        1-32    Drive number of first installed drive (A=1)
        246     Invalid or unknown option
        247     Unable to uninstall
        248     Not enough memory
        249     No drives assigned (ie. not installed)
        250     No drive letters available
        251     Unit on driver does not exist
        252     Invalid or non-existant driver
        253     Already installed
        254     Unsupported version of DOS
        255     386 required


    Examples
  ============

    SHCDX33F /D:SHSU-CDH

    SHCDX33F finds the first available drive letter and assigns it to device
    unit  0  of  the  driver SHSU-CDH.  If there is a second and/or third CD
    drive they are assigned to  the  next  available  letters  in  sequence.
    Drive letters in use are skipped.  The first CD supported by a driver is
    device unit 0 regardless of its SCSI address.

    SHCDX33F /D:IDE-CD,F /D:?USB-CD,U /D:*SHSU-CDH,W /L:0

    Assign drive F to the IDE-CD driver, or abort if it is  not  loaded.  If
    the  USB-CD driver is loaded, assign it to drive U; else do nothing.  If
    the SHSU-CDH driver is loaded, assign it to drive W; else reserve  space
    for it, so it can be loaded later.    SHCDX33F will return the number of
    drives assigned (or 252 if aborted).

    SHCDX33F /L:0

    If SHCDX33F is not installed, it returns 255.   Otherwise, the number of
    assigned drives (which can be 0).  In either case, nothing is displayed.

    SHCDX33F /D:CD001,,1,1 /D:CD001,,4,1

    SHCDX33F assigns the first available drive letter to device unit 1 of
    driver CD001 and the next letter to unit 4.    This permits access to
    non-contiguous drive units, without having to support unneeded units.


    History
  ===========

    Legend: + added, - bug-fixed, * changed.

    V3.03F - 1-Aug-12
    * SHCDX33F directory or non-directory input flagged, for directory-
        only caching using UDVD2 or UIDE (saves cache space for disks).

    V3.03E - 9 Jul, 2009
    - SHCDX33E /I switch added, per user request.

    V3.03D - 30 May, 2009
    - SHCDX33D drive not-ready stack ERROR fixed.

    V3.03C - 9 November, 2006
    + SHCDX33C stack increased to 534 bytes.   The author is DISGUSTED at
        having to add this change, but BAD drivers and BIOS programs that
        use too much stack still DO exist!

    V3.03B - 20 October, 2006
    - SHCDX33B corrected to display "No Drives Assigned" properly.

    V3.03A - 26 December, 2005:
    + Smaller SHCDX33A added, assembles properly with 16-bit NASM.

    v3.03 - 20 December, 2005:
    - incorrectly restored UMB state
    + /I will install even if a redirector is already present
    + /D by itself will display drive assignments and return number assigned
      [NOTE:  /I and /D changes were NOT added in SHCDX33A.

    v3.02 - 5 May, 2005:
    + set drive number in device driver's header (needed by I_Cache)
    + Int2F/AX=1500 will return AL=FF (needed by XCD in DESQview/X)
    + SMARTDrive install check will return a release number in BH
    + /Q+ to only display drive assignments
    * if loaded high, relocate low (/C will then keep high)
    - /? wouldn't work if a different version was installed
    * removed default driver (/D:drives by itself can now install)
    * modified the installer, binary is now a lot smaller
    * more NASM macros

    v3.01 - 5 March, 2005:
    - Joliet support for non-English users (use ISO if no DOSLFN 0.40a)
    * removed DR-DOS INSTALL support, use INSTALLLAST (or define DOSMOVES)
    + ignore unsupported MSCDEX options (/E/K/S/M)
    + /L enhanced to return drives assigned, drive numbers
    - 386 check was using near conditional jumps
    - preserve AH in redirector install check
    * display error if /C used after install

    v3.00 - 30 November, 2004:
    * clean slate.


  ==================================
    Jack Ellis, 2 August, 2012.
    Jason Hood, 20 December, 2005.

