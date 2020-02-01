unit Communi;

interface
{storage class}

{ Storage subclass codes }
const SDescSTypeRBC       =$01;            { Typically, flash devices }
const SDescSType8020      =$02;            { CD-ROM }
const SDescSTypeQIC       =$03;            { QIC-157 Tapes }
const SDescSTypeUFI       =$04;            { Floppy }
const SDescSType8070      =$05;            { Removable media }
const SDescSTypeSCSI      =$06;            { Transparent }
const SDescSTypeLOCKABLE  =$07;            { Password-protected }
const SDescSTypeISD200    =$f0;            { ISD200 ATA }
const SDescSTypeCYP_ATACB =$f1;            { Cypress ATACB }
const SDescSTypeDEVICE    =$ff;            { Use device's value }


{communications class}

const CDescSTypeACM  =$02;
const CDescSTypeEth  =$06;
const CDescSTypeWHCM =$08;
const CDescSTypeDMM  =$09;
const CDescSTypeMDLM =$0a;
const CDescSTypeOBEX =$0b;
const CDescSTypeEEM  =$0c;
const CDescSTypeNCM  =$0d;


implementation

end.
