                 NON-DOS PARTITION CORRUPTION PATCH

                             Version 1.0

                              10/16/2015

                       Copyright (C) 2012-2015
                          By Rudolph R. Loew
                             
                             

The NON-DOS Partition Corruption Patch corrects a bug in IO.SYS 7 or
uncompressed IO.SYS 8. This bug causes non-active Primary Partitions to be
assigned an incorrect start sector when the last Logical Partition processed
is not recognized by DOS. A Linux or NTFS Partition are examples of such
Partitions. This can cause ghost Partitions to appear and may lead to
corruption of other Partitions.

This is the same PATCHPAR.EXE I posted to the MSFN Forum Website in 2012.



REQUIREMENTS


IO.SYS 7, IO.SYS 7.1, or uncompressed IO.SYS 8.

NOTE:  IO.SYS 8 can be uncompressed using IO8DCOMP which is also available
       on this Website.



CONTENTS

PATCHPAR.EXE    NON-DOS Partition Corruption Patch Program Version 1.0
README.TXT      This File



LICENSE

This program may be freely redistributed as long as both files are
redistributed together ansd are unmodified.



INSTALLATION

1. Go to the C:\ Folder.
2. Unhide IO.SYS by running:
   ATTRIB -S -H -R IO.SYS
3. Rename IO.SYS to IO.BAK
4. Run:
   PATCHPAR IO.BAK IO.SYS
5. Reboot



UNINSTALL

1. Go to the C:\ Folder.
2. Delete IO.SYS
3. Rename IO.BAK to IO.SYS
4. Reboot



QUESTIONS AND COMMENTS

Please direct any questions or comments about the Program or the
Documentation to me at rloew@hotmail.com.
Please send any Bug Reports to rloew@hotmail.com.



MAILING LIST

If you would like to be notified about updates and/or fixes or other products
from Rudolph Loew, E-Mail me at rloew@hotmail.com and ask to be put on my
Mailing list. Your E-Mail address will not be given out nor will you receive
any unsolicited mail. You can unsubscribe at any time.
