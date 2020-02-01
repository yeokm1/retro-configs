unit ac97;

{
Codec registers.

Not all codecs are created equal. Refer to the spec for your specific codec.

All registers are 16bits wide.  Access to codec registers over the AC97 link
is defined by the OEM.


Secondary codec's are accessed by ORing in BIT7 of all register accesses.

%

; each codec/mixer register is 16bits
}

interface

const
ENABLED=1;
DISABLED=0;

BIT0=1;
BIT1=2;
BIT2=4;
BIT3=8;
BIT4=$10;
BIT5=$20;
BIT6=$40;
BIT7=$80;
BIT8=$100;
BIT9=$200;
BIT10=$400;
BIT11=$800;
BIT12=$1000;
BIT13=$2000;
BIT14=$4000;
BIT15=$8000;
BIT16=$10000;
BIT17=$20000;
BIT18=$40000;
BIT19=$80000;
BIT20=$100000;
BIT21=$200000;
BIT22=$400000;
BIT23=$800000;
BIT24=$1000000;
BIT25=$2000000;
BIT26=$4000000;
BIT27=$8000000;
BIT28=$10000000;
BIT29=$20000000;
BIT30=$40000000;
BIT31=$80000000;

const
CODEC_RESET_REG=00;{reset codec}
CODEC_MASTER_VOL_REG=2;{master volume}
CODEC_HP_VOL_REG=4;{headphone volume}
CODEC_MASTER_MONO_VOL_REG=6 ;{master mono volume}
CODEC_MASTER_TONE_REG=8;{master tone (R+L)}
CODEC_PCBEEP_VOL_REG=$0a;{PC beep volume}
CODEC_PHONE_VOL_REG=$0b;{phone volume}
CODEC_MIC_VOL_REG=$0e;{MIC volume}
CODEC_LINE_IN_VOL_REG=$10;{line input volume}
CODEC_CD_VOL_REG=$12;{CD volume}
CODEC_VID_VOL_REG=$14;{video volume}
CODEC_AUX_VOL_REG=$16;{aux volume}
CODEC_PCM_OUT_REG=$18;{PCM output volume}
CODEC_RECORD_SELECT_REG=$1a;{record select inputv}
CODEC_RECORD_VOL_REG=$1c;{record volume}
CODEC_RECORD_MIC_VOL_REG=$1e;{record mic volume}
CODEC_GP_REG=20;{general purpose}
CODEC_3D_CONTROL_REG=$22;{3D control}
{24 is reserved}
CODEC_POWER_CTRL_REG=$26;{powerdown control}
CODEC_EXT_AUDIO_REG=$28;{extended audio}
CODEC_EXT_AUDIO_CTRL_REG=$2a;{extended audio controlv}
 VRA_ENA			=	BIT0	;{variable rate audio}
 DRA_ENA			=	BIT1	;{double rate audio}
CODEC_PCM_FRONT_DACRATE_REG=$2c;{PCM out sample rate}
CODEC_PCM_SURND_DACRATE_REG=$2e;{surround sound sample rate}
CODEC_PCM_LFE_DACRATE_REG=$30;{LFE sample rate}
CODEC_LR_ADCRATE_REG=$32;{PCM in sample rate}
CODEC_MIC_ADCRATE_REG=$34;{mic in sample rate}


CODEC_VENDORID1_REG=$7c;{codec vendor ID 1}
CODEC_VENDORID2_REG=$7e;{codec vendor ID 2}



{
whenever 2 codecs are present in the system, use BIT7 to access the 2nd
set of registers, ie 80h-feh
}
PRIMARY_CODEC=0  ;{0-7F for primary codec}
SECONDARY_CODEC=BIT7;{80-8f registers for 2ndary}



{; player internal variables and other equates.}
const BUFFERSIZE        =     64 * 1024       	; {64k file buffer size.}
implementation

end.
