rem A sample batch file which loads the packet drivers and starts the bridge
rem Load the packet driver for the first interface
de100pd 0x60 3 0xd000 0x300
de100pd 0x61 2 0xd200 0x320
de100pd 0x62 5 0xc000 0x340
rem This bridge has three interfaces and hash tabel flush time is 40 mins
yapcbr 3 40
