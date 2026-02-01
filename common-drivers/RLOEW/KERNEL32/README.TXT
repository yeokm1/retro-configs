               KERNEL32 2GiB BUG PATCH FOR WINDOWS 98/98SE

                             Version 1.4

                              01/07/2011

                        Copyright (C) 2010-2011
                          By Rudolph R. Loew
                             
                             

The KERNEL32 2GiB Bug Fix corrects the handling of File Seek Commands (both
lseek and SetFilePointer) so that Files up to 4GiB are correctly handled.
This Patch handles all three Seek Modes (From Beginning, Current Position and
From End). The Public Domain Copy2GB Patch for this problem only correctly
handles the Seek from Beginning Mode.



CAUTION

Some poorly written applications do 32-Bit relative Seeks to points before
the Beginning of a File expecting the Seek to fail. With this Patch only
Seeks to -1 will Fail. All other such Seeks are assumed to be a Seek to a
point nearly 4GiB after the Beginning of the File. The Seek will not fail and
any Writes will cause the File to grow to nearly 4GiB in length. There is no
way to distinguish between these possible intended actions unless full 64-Bit
Offsets are specified, so no fix is possible without compromising support
for Files up to 4GiB.



REQUIREMENTS

Windows 98 or 98SE.
A separate Version is available for Windows 95.



CONTENTS

KERNEL32.DLL    Version 4.10.2225 of KERNEL32.DLL with Patch Version 1.4
README.TXT      This File
LICENSE.TXT     License Terms and Conditions



INSTALLATION

1. Unzip all files.
2. Boot into DOS not a DOS Box.
3. Backup your existing WINDOWS\SYSTEM\KERNEL32.DLL File.
4. Copy the extracted KERNEL32.DLL file to your WINDOWS\SYSTEM Folder.



UPGRADE

1. Unzip all files.
2. Boot into DOS not a DOS Box.
3. Copy the extracted KERNEL32.DLL file to your WINDOWS\SYSTEM Folder.



UNINSTALL

1. Boot into DOS not a DOS Box.
2. Delete the KERNEL32.DLL file in your WINDOWS\SYSTEM Folder.
3. Restore your original WINDOWS\SYSTEM\KERNEL32.DLL File.



LICENSE

Read the Licensing terms and conditions in the LICENSE.TXT file before
using this Software. Installation of the Driver constitutes acceptance
of all of the terms and conditions in the LICENSE.TXT file.



QUESTIONS AND COMMENTS

Please direct any questions or comments about the Program or the
Documentation to me at rloew@hotmail.com.
Please send any Bug Reports to rloew@hotmail.com.



MAILING LIST

If you would like to be notified about updates and/or fixes or other products
from Rudolph Loew, E-Mail me at rloew@hotmail.com and ask to be put on my
Mailing list. Your E-Mail address will not be given out nor will you receive
any unsolicited mail. You can unsubscribe at any time.
