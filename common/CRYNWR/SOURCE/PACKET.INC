{
ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
º Filename       : PACKET.INC    ³  Program / Unit : [ ]               º
º Description    : Include file  ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶
º                  for constants                                       º
º                                                                      º
ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶
º Compiler       : TURBO PASCAL 7.0                                    º
º OS-Version     : MS-DOS 6.0                                          º
º Last edit      : 17-SEPT-93                                          º
ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶
º Author         : Oliver Rehmann                                      º
º Copyright      : Oliver Rehmann                                      º
ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼
}
{$IFNDEF CL_ETHERNET}

CONST

{ Packet driver interface classes }
CL_NONE	        = 0;
CL_ETHERNET     = 1;
CL_PRONET_10	= 2;
CL_IEEE8025	= 3;
CL_OMNINET	= 4;
CL_APPLETALK	= 5;
CL_SERIAL_LINE	= 6;
CL_STARLAN	= 7;
CL_ARCNET	= 8;
CL_AX25		= 9;
CL_KISS		= 10;
CL_IEEE8023	= 11;
CL_FDDI 	= 12;
CL_INTERNET_X25 = 13;
CL_LANSTAR	= 14;
CL_SLFP 	= 15;
CL_NETROM	= 16;
NCLASS		= 17;

{ Packet driver interface types (not a complete list) }
TC500		= 1;
PC2000		= 10;
WD8003		= 14;
PC8250		= 15;
ANYTYPE		= $ffff;

{ Packet driver function call numbers. From Appendix B. }
DRIVER_INFO		= 1;
ACCESS_TYPE		= 2;
RELEASE_TYPE		= 3;
SEND_PKT		= 4;
TERMINATE		= 5;
GET_ADDRESS		= 6;
RESET_INTERFACE		= 7;
GET_PARAMETERS		= 10;
AS_SEND_PKT		= 11;
SET_RCV_MODE		= 20;
GET_RCV_MODE		= 21;
SET_MULTICAST_LIST	= 22;
GET_MULTICAST_LIST	= 23;
GET_STATISTICS		= 24;
SET_ADDRESS		= 25;

{ Packet driver error return codes. From Appendix C. }

NO_ERROR	= 0;
BAD_HANDLE	= 1;	{ invalid handle number }
NO_CLASS	= 2;	{ no interfaces of specified class found }
NO_TYPE		= 3;	{ no interfaces of specified type found }
NO_NUMBER	= 4;	{ no interfaces of specified number found }
BAD_TYPE	= 5;	{ bad packet type specified }
NO_MULTICAST	= 6;	{ this interface does not support multicast }
CANT_TERMINATE	= 7;	{ this packet driver cannot terminate }
BAD_MODE	= 8;	{ an invalid receiver mode was specified }
NO_SPACE	= 9;	{ operation failed because of insufficient space }
TYPE_INUSE	= 10;	{ the type had previously been accessed, and not released }
BAD_COMMAND	= 11;	{ the command was out of range, or not	implemented }
CANT_SEND	= 12;	{ the packet couldn't be sent (usually	hardware error) }
CANT_SET	= 13;	{ hardware address couldn't be changed (> 1 handle open) }
BAD_ADDRESS	= 14;	{ hardware address has bad length or format }
CANT_RESET	= 15;	{ couldn't reset interface (> 1 handle open) }

CARRY_FLAG	= 1;

{$ENDIF	}
