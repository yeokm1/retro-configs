CGroup	group	code
	assume	cs:CGroup, ds:CGroup, es:nothing, ss:nothing

;include	ETH_386.INC
include	ETH_RTNS.INC
include	LMSTRUCT.INC
include	GETCNFG.INC
include	BICNIC.INC

code	segment word public use32 'Code'

include	eth_386.asm

code    ends
end
