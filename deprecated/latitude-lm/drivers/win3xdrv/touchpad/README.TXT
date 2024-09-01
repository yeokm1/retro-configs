README.TXT for the Synaptics TouchPad

This file contains supplemental information for the
Synaptics TouchPad Driver install disk.

____________________________________________________________

README FILE CONTENTS

1.   GETTING STARTED
     1.1  Installation
     1.2  Using the Synaptics TouchPad
     1.3  Special Features

2.   WINDOWS 95 SUPPORT
     2.1  Driver Installation
     2.2  Using the Synaptics TouchPad Control Panel
     2.3  Restoring Your Installation

3.   WINDOWS 3.1 SUPPORT
     3.1  Driver Installation
     3.2  Using the Synaptics TouchPad Control Panel
     3.3  Restoring Your Installation

4.   DOS SUPPORT

5.   FILES ON THE INSTALL DISK

____________________________________________________________

1.   GETTING STARTED

1.1  Installation

     If the Synaptics TouchPad is built into your computer,
     the necessary drivers should already be loaded and
     ready to use.

     If you are adding this device to your system, upgrading
     to a newer driver version, or restoring your original
     configuration, see the installation instructions later
     in this document.

1.2  Using the Synaptics TouchPad

     To move the cursor, place the finger lightly on the
     sensor pad and move in the desired direction. If you
     reach the end of the pad, lift your finger and place it
     back down on the other side of the pad. If you find
     yourself doing this too often, configure the driver to
     increase the horizontal and vertical sensitivity.

     In most computers, the TouchPad has two buttons which
     work just like left and right mouse buttons. You can
     also tap on the pad to simulate a left button click. A
     light, quick tap works best.

     To simulate holding the mouse button down ("dragging"
     an icon or selection), use the tap-and-drag gesture.
     This feels much like a double-click, except that the
     finger remains on the pad after the second tap: Tap,
     lift, tap, hold and move. The simulated button remains
     held as long as the finger remains on the pad.

1.3  Special Features

     The Synaptics TouchPad Control Panel allows you to
     customize the features of the TouchPad. As well as all
     the controls of a regular mouse control panel, the
     "TouchPad" page offers these unique features:

     * Edge Motion. During a tap-and-drag gesture, if your
       finger comes up against the edge of the pad, the
       cursor keeps moving as long as you hold your finger
       there.  In the Control Panel, you can choose between
       no Edge Motion, Edge Motion during drags (the
       default), or Edge Motion all the time.

     * Touch Sensitivity. By moving this slider, you can
       make the TouchPad more or less sensitive to a light
       touch of the finger.

     * Locking Drag. With this option, the tap-and-drag
       gestures keep "holding the mouse button down" even
       after you lift your finger from the pad. Tap your
       finger again to end the drag.

     * Corner Taps. This is a way to simulate a two-button
       mouse entirely with finger gestures. With Corner
       Taps, tapping in the upper-right corner of the pad
       clicks the right mouse button, and tapping anywhere
       else clicks the left mouse button.

     * Hop Gesture. This is an alternate two-button gesture.
       With your finger resting on the pad, if you lift and
       quickly tap a good distance to the left or right, you
       get a right-button click instead of a left-button
       click. Tapping near where your finger was resting
       before produces the usual left-button click.

     * Three-button mode. If you have software that requires
       a 3-button mouse, select this option. The TouchPad
       simulates a 3-button mouse where tapping gestures
       operate the "left" mouse button, and the two physical
       switches operate the "middle" and "right"  mouse
       buttons.

     In the DOS driver, you can control these features by
     editing the MOUSE.INI file or using command line
     switches. See SYNTOUCH.TXT for details, or type
     "SYNTOUCH ?" to see a list of command line switches.

____________________________________________________________

2.   WINDOWS 95 SUPPORT

2.1  Driver Installation

     To install the Synaptics TouchPad driver for
     Windows 95:

     - From the Start menu, select "Settings", "Control
       Panel", then "Mouse" to open the Mouse Properties
       sheet.

     - Click the "General" tab, then click the "Change"
       button.

     - Click "Have Disk" and insert the driver disk in your
       floppy drive. Confirm or correct the file path
       (normally "a:\"), then click "OK".

     - Click "Synaptics TouchPad", then "OK" to copy the
       driver files to your system.

     - After the files are copied, the Mouse Properties
       sheet will show the new device name. Click "Close".

     - The "System Settings Change" dialog will offer to
       restart your computer so the new settings can take
       effect. Select "Yes".

2.2  Using the Synaptics TouchPad Control Panel

     To change your Synaptics TouchPad settings under
     Windows 95:

     - From the Start menu, select "Settings", "Control
       Panel", then "Mouse" to open the Mouse Properties
       sheet.

     - Click the "General" tab, then click the "Options"
       button to bring up the Synaptics TouchPad Control
       Panel.

     - The available controls are grouped into five
       categories (Pointer, Motion, Orientation, Shortcuts,
       TouchPad). Some of these options also appear on the
       standard Mouse Properties tabs. However, in most
       cases they are best controlled through the Synaptics
       TouchPad pages. Online Help is provided for all
       topics.

     - When you are satisfied with your settings, click OK
       to close the Synaptics TouchPad Control Panel, then
       OK to close Mouse Properties.

2.3  Restoring Your Installation

     The Synaptics TouchPad drivers are compatible with most
     standard mice and similar pointing devices. However, if
     you do change drivers to use another device, you can
     restore the Synaptics TouchPad installation (including
     your control panel settings) as follows:

     - From the Start menu, select "Settings", "Control
       Panel", then "Mouse" to open the Mouse Properties
       sheet.

     - Click the "General" tab, then click the "Change"
       button.

     - If "Synaptics TouchPad" does not appear in the first
       list of pointing device models, click "Show All
       Devices". In the Manufacturers column, click
       "Synaptics."

     - Click "Synaptics TouchPad", then "OK" to copy the
       driver files to your system.

     - If the "Copying Files..." step cannot find the driver
       files, it will ask you to correct the source path.
       Enter "c:\syntouch" (using the same drive letter as
       your Windows 95 installation), then click "OK".

     - After the files are copied, the Mouse Properties
       sheet will show the new device name. Click "Close".

     - The "System Settings Change" dialog will offer to
       restart your computer so the new settings can take
       effect. Select "Yes".

____________________________________________________________

3.   WINDOWS 3.1 SUPPORT

3.1  Driver Installation

     To install the Synaptics TouchPad driver for Windows
     3.1 (including Windows 3.11 or Windows for Workgroups)
     or any DOS version (3.3 or later is recommended):

     - If Windows is running, exit to DOS. The installer
       cannot be run from inside Windows or from a Windows
       DOS session.

     - Insert the driver disk in your floppy drive.

     - Type "A:\INST31" (using the appropriate drive letter)
       and follow the prompts. You will be asked to confirm
       the installation type (DOS, Windows, or both), the
       driver directory, and whether the DOS driver should
       be loaded at startup time. If you are unsure about
       any question, simply accept the default response.

     - If you allowed the install program to update
       AUTOEXEC.BAT, it will offer to reboot your system
       with the new settings. The Windows driver will become
       active the next time you start Windows.

3.2  Using the Synaptics TouchPad Control Panel

     - From the Program Manager, open the Main program
       group, then double-click on Control Panel.

     - Double-click the Synaptics TouchPad icon to bring up
       the Synaptics TouchPad Control Panel. (This enhanced
       control panel replaces the standard Mouse Control
       Panel.)

     - The available controls are grouped into five
       categories (Pointer, Motion, Orientation, Shortcuts,
       TouchPad). Online Help is provided for all topics.

     - When you are satisfied with your settings, click OK
       to close the Synaptics TouchPad Control Panel.

3.3  Restoring Your Installation

     The Synaptics TouchPad drivers are compatible with most
     standard mice and similar pointing devices. However, if
     you do change drivers to use another device, you can
     restore the Synaptics TouchPad installation (including
     your control panel settings) as follows:

     - If Windows is running, exit to DOS. The installer
       cannot be run from inside Windows or from a Windows
       DOS session.

     - Change to the drive and directory containing your
       Synaptics TouchPad installation (e.g., C:\SYNTOUCH).

     - Type "INST31" and follow the prompts. Make certain
       you specify the same installation path where the
       files currently reside. This will cause the installer
       to restore the previous configuration using those
       files and saved settings.

     - If you allowed the install program to update
       AUTOEXEC.BAT, it will offer to reboot your system
       with the new settings. The Windows driver will become
       active the next time you start Windows.

____________________________________________________________

4.   DOS SUPPORT

     The Windows 95 install procedure described above
     automatically includes the DOS driver, SYNTOUCH.COM.
     This driver provides the support needed for DOS
     applications, either full-screen or windowed.

     If you are not running Windows 95, use the INST31
     program to install the Synaptics TouchPad drivers for
     DOS only, Windows only (version 3.1), or both DOS and
     Windows.

     Some of the pointing device settings (such as
     sensitivity, acceleration and orientation) are shared
     between the DOS and Windows drivers. The easiest way to
     set these options is through the Synaptics TouchPad
     Control Panel in Windows. The DOS driver will pick up
     any changes the next time it starts up.

     Other settings (such as the pointer options) may differ
     between DOS and Windows, and are stored separately in
     the MOUSE.INI file. You can change the DOS settings
     directly by editing this file or by adding option
     switches to the SYNTOUCH command line. See the
     SYNTOUCH.TXT file for details.

____________________________________________________________

5.   FILES ON THE INSTALL DISK

     README.TXT     This file

     SYNTOUCH.INF   Windows 95 setup script
     INST31.EXE     Windows 3.1 (or DOS) install program

     SYNTOUCH.DRV   Windows driver
     SYNTOUCH.DLL   Windows control panel
     SYNTOUCH.HLP   Windows help file
     SFTTABS.DLL    Windows control panel interface
     XMVMD.386      Windows Virtual Mouse Device
     XPOINT.EXE     Windows pointer enhancements

     SYNTOUCH.COM   DOS driver
     SYNTOUCH.TXT   DOS driver options and switches
     MOUSE.INI      DOS and Windows configuration file

____________________________________________________________
