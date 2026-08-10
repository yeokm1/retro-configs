

Here is the current version of the DOS32AWE utility based on the DOS/32A DOS Extender. Now Sound Blaster DOS MIDI synthesizer with Creative's AWEUTIL is also possible for Protected mode DOS games thus allowing you to use MIDI sound banks of your taste while what's best -- you don't need any additional wavetable modules/PCBs/ external MIDI synthesizers, etc. for your ISA AWE Creative Sound Blasters . This utility also assists the VIA's Sound Blaster emulation (VIAFMTSR) that uses VIA chipset south bridges for protected mode games otherwise they hang, fail or sound choppy. If you wonder how to use the DOS32AWE, first ensure the AWEUTIL is loaded as TSR (AWEUTIL /EM:xxx) and then start you game with "DOS32AWE yourgamename" or alternatively replace the DOS4GW .EXE in your games's directory (if exists separately there and is not already bound to the main executable) with the renamed to DOS4GW.EXE DOS32AWE.EXE file.
The DOS32AWE is a DOS32/A DOS Extender modification which is capable of redirecting MIDI sound hardware accesses of DOS Extended applications running in protected mode to the real mode Creative's original AWEUTIL (when loaded as TSR) MIDI emulator. This archive contains the latest Version 1.9 of the DOS32AWE which is stable and refuses to run under PM environment (like EMM386, QEMM, 386MAX, windows dos box, etc.) because is intended to extend raw/clean DOS (with or without XMS). DOS32AWE compatibility with memory managers is considered from time to time though not considered important because DOS Extenders manage all available RAM themselves and provide it to the extended DOS applications.
 
Here is what DOS32AWE is NOT compatible with (to my knowledge) :
1. Transport Tycoon since that series of games is built for completely different Phar Lap DOS Extender;
2. Sideline which is of Asian origin *extremely* buggy game that can only be made running somehow under EMM386 despite the game itself uses no EMS . Most likely the EMM386's V86 monitor skips and constraints some of the game's bugs. If you have more in-depth info on that your advice is welcome. 
3. Terra Nova. The game loads the FF.SBK sound font by itself so you can replace that with your favorite .SBK (renaming it to FF.SBK) and thus you would achieve what DOS32AWE is doing for all other DOS4G extended games.










;
; Copyright (C) 1996-2006 by Narech K. All rights reserved.
;
; Redistribution  and  use  in source and  binary  forms, with or without
; modification,  are permitted provided that the following conditions are
; met:
;
; 1.  Redistributions  of  source code  must  retain  the above copyright
; notice, this list of conditions and the following disclaimer.
;
; 2.  Redistributions  in binary form  must reproduce the above copyright
; notice,  this  list of conditions and  the  following disclaimer in the
; documentation and/or other materials provided with the distribution.
;
; 3. The end-user documentation included with the redistribution, if any,
; must include the following acknowledgment:
;
; "This product uses DOS/32 Advanced DOS Extender technology."
;
; Alternately,  this acknowledgment may appear in the software itself, if
; and wherever such third-party acknowledgments normally appear.
;
; 4.  Products derived from this software  may not be called "DOS/32A" or
; "DOS/32 Advanced".
;
; THIS  SOFTWARE AND DOCUMENTATION IS PROVIDED  "AS IS" AND ANY EXPRESSED
; OR  IMPLIED  WARRANTIES,  INCLUDING, BUT  NOT  LIMITED  TO, THE IMPLIED
; WARRANTIES  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED.  IN  NO  EVENT SHALL THE  AUTHORS  OR  COPYRIGHT HOLDERS BE
; LIABLE  FOR  ANY DIRECT, INDIRECT,  INCIDENTAL,  SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL  DAMAGES  (INCLUDING, BUT NOT  LIMITED TO, PROCUREMENT OF
; SUBSTITUTE  GOODS  OR  SERVICES;  LOSS OF  USE,  DATA,  OR  PROFITS; OR
; BUSINESS  INTERRUPTION) HOWEVER CAUSED AND  ON ANY THEORY OF LIABILITY,
; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
; OTHERWISE)  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
; ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
;