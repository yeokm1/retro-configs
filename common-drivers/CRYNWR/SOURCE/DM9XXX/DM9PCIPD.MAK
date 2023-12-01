#****************************************************************************
#									    *
#   dm9pcipd.mak -- Microsoft NMAKE format makefile for building Packet     *
#   Driver of PCI Fast Ethernet adapter using DAVICOM's DM9102 Fast         *
#   Ethernet Controller.						    *
#									    *
#   Assembler:		Microsoft Macro Assembler 6.11			    *
#   Linker:		Microsoft Segmented Executable Linker V5.31.009     *
#									    *
#****************************************************************************
PROJ		= DM9PCIPD
PROJFILE	= DM9PCIPD.MAK

MAJ_VER 	= 1
MIN_VER 	= 4
GEN_VER 	= 1

DEBUG		= 0
SW_ONE_PKT	= 1
SINGLE_PORT	= 1
DEBUGDOS	= 0
HOMEPNA 	= 1

OBJDIR = .

# S, M, C, L, H memory model
MODEL = L

ASM	= masm
LINK	= link

AFLAGS_G  = /ML /L /W2 /DMAJ_VER=$(MAJ_VER) /DMIN_VER=$(MIN_VER) /DGEN_VER=$(GEN_VER)
AFLAGS_D  = /Zi
AFLAGS_R  =
AMACROS =


!IF "$(DEBUG)" == "1"
AFLAGS = $(AFLAGS_G) $(AFLAGS_D) $(AMACROS)
LFLAGS = /CO
!ELSE
AFLAGS = $(AFLAGS_G) $(AFLAGS_R) $(AMACROS)
LFLAGS =
!ENDIF

!IF "$(SW_ONE_PKT)" == "1"
AFLAGS = $(AFLAGS) /DSW_ONE_PKT
!ENDIF

!IF "$(SINGLE_PORT)" == "1"
AFLAGS = $(AFLAGS) /DSINGLE_PORT
!ENDIF

!IF "$(HOMEPNA)" == "1"
AFLAGS = $(AFLAGS) /DHOMEPNA
!ENDIF

!IF "$(DEBUGDOS)" == "1"
AFLAGS = $(AFLAGS) /DDEBUGDOS

OBJS	= $(OBJDIR)\head.obj \
	  $(OBJDIR)\dbg.obj \
	  $(OBJDIR)\phy.obj \
	  $(OBJDIR)\davicom.obj \
	  $(OBJDIR)\initpci.obj \
	  $(OBJDIR)\tail.obj

!ELSE
OBJS	= $(OBJDIR)\head.obj \
	  $(OBJDIR)\phy.obj \
	  $(OBJDIR)\davicom.obj \
	  $(OBJDIR)\initpci.obj \
	  $(OBJDIR)\tail.obj
!ENDIF


OBJECT = $(PROJ).com

ALL : $(OBJECT)

$(OBJECT) : $(PROJ).exe
	exe2com $(PROJ).exe
	del $(PROJ).exe


$(OBJDIR)\$(PROJ).exe : $(OBJS)
	$(LINK) $(LFLAGS) @<< $(PROJ).lrf
$(OBJS: = +
)
$@;
<<

#$(OBJDIR)\head.obj : head.asm \
#		      defs.asm
#
#$(OBJDIR)\davicom.obj : davicom.asm \
#			 defs.asm \
#			 printcur.asm \
#			 printdig.asm 9100.asm
#
#$(OBJDIR)\tail.obj : tail.asm \
#		      defs.asm \
#		      pktutil.asm \
#		      verifypi.asm \
#		      printea.asm \
#		      pkterr.asm
#
#$(OBJDIR)\phy.obj : phy.asm \
#		     phy.inc
#
#$(OBJDIR)\initpci.obj : initpci.asm \
#			 hardware.asd \
#			 rtdata.inc \
#			 dm9100.mac \
#			 xmt.inc \
#			 rcv.inc

!IF 0
$(OBJDIR)\head.obj : $(@B).asm
	$(AS) $(AFLAGS) $(@B).asm,$@,$(@B);

$(OBJDIR)\davicom.obj : $(@B).asm
	$(AS) $(AFLAGS) $(@B).asm,$@,$(@B);

$(OBJDIR)\tail.obj : $(@B).asm
	$(AS) $(AFLAGS) $(@B).asm,$@,$(@B);

$(OBJDIR)\phy.obj : phy.asm \
		    phy.inc

$(OBJDIR)\initpci.obj : initpci.asm \
			hardware.asd \
			rtdata.inc \
			dm9100.mac \
			xmt.inc \
			rcv.inc
!ENDIF

#Inference Rule Definitions
.asm.obj:
	$(ASM) $(AFLAGS) $**,$@;

.c.obj:
	$(CC) $(CFLAGS) $**.c

