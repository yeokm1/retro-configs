Table of different Ethernet DIX types
=====================================
(DIX = Dec Intel Xerox)

When receiving packets from your LAN adapter (ex. through crynrware packet 
drivers) you must know what type of CPU your computer has. This is important 
for data representation.

The type (length) field in an Ethernet frame always corresponds to a Big Endian 
system (ex. Motorola 68000, etc.).

Intel 80x86 CPUs are Little Endian systems so you have to swap the lo and hi
byte of a word.

Ex. DOD IP = 0800h -> Swap -> 0008h (on a 80x86 PC)

Type     Description
====     =============================

0600     XNS
0601     XNS Address Translation
0800     DOD IP
0801     X.75 internet
0802     NBS internet
0803     ECMA internet
0804     Chaosnet
0805     X.25 Level 3
0806     ARP
0807     XNS Compatibility
081C     Symbolics private
0888     Xyplex
0889     Xyplex
088A     Xyplex
0900     UngermannÄBass net debugr
0A00     Xerox PUP
0A01     Xerox PUP Address Translation
0BAD     Banyan Systems
0BAF     Banyan Echo
1000     Berkeley trailer negotiation
1001     Berkeley trailer encapsulation
1002     Berkeley trailer encapsulation
1003     Berkeley trailer encapsulation
1004     Berkeley trailer encapsulation
1005     Berkeley trailer encapsulation
1006     Berkeley trailer encapsulation
1007     Berkeley trailer encapsulation
1008     Berkeley trailer encapsulation
1009     Berkeley trailer encapsulation
100A     Berkeley trailer encapsulation
100B     Berkeley trailer encapsulation
100C     Berkeley trailer encapsulation
100D     Berkeley trailer encapsulation
100E     Berkeley trailer encapsulation
100F     Berkeley trailer encapsulation
1234     DCA Ä Multicast
1600     VALID system protocol
1989     Artificial Horizons (dogfight simulator)
3C00     3Com NBP
3C01     3Com NBP
3C02     3Com NBP
3C03     3Com NBP
3C04     3Com NBP
3C05     3Com NBP
3C06     3Com NBP
3C07     3Com NBP
3C08     3Com NBP
3C09     3Com NBP
3C0A     3Com NBP
3C0B     3Com NBP
3C0C     3Com NBP
3C0D     3Com NBP
4242     PCS Basic Block Protocol
4321     THD Ä Diddle
5208     BBN Simnet Private
6000     DNA experimental
6001     DNA Dump/Load ÄMOPÄ
6002     DNA Remote Console ÄMOPÄ
6003     DNA IV Routing Layer
6004     DEC: Local Area Transport
6005     DEC: Diagnostics
6006     DEC: Customer Use
6007     DEC: LAVC
6008     DEC Unassigned (AMBER?)
6009     DEC Unassigned (MUMPS?)
6010     3Com
6011     3Com
6012     3Com
6013     3Com
6014     3Com
7000     UngermannÄBass download
7001     UngermannÄBass NIUs
7002     UngermannÄBass diagnostic/loopback
7003     UngermannÄBass
7005     UngermannÄBass Bridge
7007     OS/9 Microware
7009     OS/9 Net ?
7020     Sintrom (was LRT)
7021     Sintrom (was LRT)
7022     Sintrom (was LRT)
7023     Sintrom (was LRT)
7024     Sintrom (was LRT)
7025     Sintrom (was LRT)
7026     Sintrom (was LRT)
7027     Sintrom (was LRT)
7028     Sintrom (was LRT)
7029     Sintrom (was LRT)
7030     RacalÄInterlan
7031     Prime NTS
7034     Cabletron
8003     Cronus VLN
8004     Cronus Direct
8005     HP Probe
8006     Nestar
8008     AT&T/Standford
8010     Excelan
8013     Silicon Graphics diagnostic
8014     Silicon Graphics network games
8015     Silicon Graphics
8016     Silicon Graphics XNS Nameserver
8019     Apollo DOMAIN
802E     Tymshare
802F     Tigan
8035     Reverse ARP
8036     Aeonic Systems
8037     IPX (Netware)
8038     DEC: bridge
8039     DEC: DSM/DDP
803A     DEC: (Argonaut console ?)
803B     DEC: (VAXELN ?)
803C     DEC: (NMSV? DNA Naming?)
803D     DEC: encryption
803E     DEC: distributed time service
803F     DEC: LAN Traffic Monitor
8040     DEC: NetBIOS Datagrams
8041     DEC: Local Area System Transport
8042     DEC Unassigned
8044     Planning Research Corp.
8046     AT&T
8047     AT&T
8048     DEC: DECamds
8049     ExperData
805B     VMTP/RFCÄ1045
805C     Stanford V Kernel, version 6.0
805D     Evans & Sutherland
8060     Little Machine
8062     Counterpoint Computers
8065     University of Mass. at Amherst
8066     University of Mass. at Amherst
8067     Veeco Integrated Automation
8068     General Dynamics
8069     AT&T
806A     Autophon
806C     ComDesign
806D     Compugraphic Corp.
806E     Landmark Graphics Corp.
806F     Landmark Graphics Corp.
8070     Landmark Graphics Corp.
8071     Landmark Graphics Corp.
8072     Landmark Graphics Corp.
8073     Landmark Graphics Corp.
8074     Landmark Graphics Corp.
8075     Landmark Graphics Corp.
8076     Landmark Graphics Corp.
8077     Landmark Graphics Corp.
807A     Matra
807B     Dansk Data Elektronic
807C     Merit Internodal
807D     Vitalink Communications
807E     Vitalink Communications
807F     Vitalink Communications
8080     Vitalink TransLAN III Mgmt
8081     Counterpoint Computers
8082     Counterpoint Computers
8083     Counterpoint Computers
8088     Xyplex
8089     Xyplex
808A     Xyplex
809B     EtherTalk (AppleTalk)
809C     Datability
809D     Datability
809E     Datability
809F     Spider Systems
80A3     Nixdorf
80A4     Siemens Gammasonics
80A5     Siemens Gammasonics
80A6     Siemens Gammasonics
80A7     Siemens Gammasonics
80A8     Siemens Gammasonics
80A9     Siemens Gammasonics
80AA     Siemens Gammasonics
80AB     Siemens Gammasonics
80AC     Siemens Gammasonics
80AD     Siemens Gammasonics
80AE     Siemens Gammasonics
80AF     Siemens Gammasonics
80B0     Siemens Gammasonics
80B1     Siemens Gammasonics
80B2     Siemens Gammasonics
80B3     Siemens Gammasonics
80C0     DCA: Data Exchange Cluster
80C1     DCA: Data Exchange Cluster
80C2     DCA: Data Exchange Cluster
80C3     DCA: Data Exchange Cluster
80C6     Pacer Software
80C7     Appplitek Corp.
80C8     Intergraph Corp.
80C9     Intergraph Corp.
80CA     Intergraph Corp.
80CB     Intergraph Corp.
80CC     Intergraph Corp.
80CD     Harris Corporation
80CE     Harris Corporation
80CF     Taylor Instrument
80D0     Taylor Instrument
80D1     Taylor Instrument
80D2     Taylor Instrument
80D3     Rosemount Corp.
80D4     Rosemount Corp.
80D5     IBM SNA Service on Ethernet
80DD     Varian Associates
80DE     TRFS (Integrated Solutions ...)
80DF     TRFS (Integrated Solutions ...)
80E0     AllenÄBradley
80E1     AllenÄBradley
80E2     AllenÄBradley
80E3     AllenÄBradley
80E4     Datability
80E5     Datability
80E6     Datability
80E7     Datability
80E8     Datability
80E9     Datability
80EA     Datability
80EB     Datability
80EC     Datability
80ED     Datability
80EE     Datability
80EF     Datability
80F0     Datability
80F2     Retix
80F3     AppleTalk AARP
80F4     Kinetics
80F5     Kinetics
80F7     Apollo Computers
80FF     Wellfleet 
8100     Wellfleet
8101     Wellfleet
8102     Wellfleet
8103     Wellfleet
8107     Symbolics
8108     Symbolics
8109     Symbolics
812B     Talaris
8130     Waterloo Microsystems
8131     VG Laboratory Systems
8137     Novell NetWare
8138     Novell ?
8139     KTI
813A     KTI
813B     KTI
813C     KTI
813D     KTI
814C     SNMP over Ethernet
814F     Technically Elite Concepts
817D     XTP
81D6     Lantastic
8582     Kalpana
8888     HP LanProbe ?
9000     Loopback
9001     3Com: XNS Mngmt
9002     3Com: TCP/IP Mngmt
9003     3Com: loopback detection
AAAA     DECNET ???
FF00     BBN VITALÄLanBridge
