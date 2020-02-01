unit Vid;

interface
{ Video Interface Class Code $0E}

{ Video Interface Subclass Codes
{ (USB_Video_Class_1.1.pdf, A.2 Video Interface Subclass Code)}
const  VDescSTypeUndefined  =$00;
const  VDescSTypeControl    =$01;
const  VDescSTypeStreaming  =$02;
const  VDescSTypeCollection =$03;

{ Video Interface Protocol Codes }
const  VideoProtocolUndefined=$00;

{ Video Class-Specific Descriptor Types }
const  CS_UNDEFINED                              =$20;
const  CS_DEVICE                                 =$21;
const  CS_CONFIGURATION                          =$22;
const  CS_STRING                                 =$23;
const  CS_INTERFACE                              =$24;
const  CS_ENDPOINT                               =$25;

{ Video Class-Specific VideoControl Interface Descriptor Subtypes}
{ (USB_Video_Class_1.1.pdf, A.5 Video Class-Specific VC Interface Descriptor Subtypes)}
const  VC_DESCRIPTOR_UNDEFINED                   =$00;
const  VC_HEADER                                 =$01;
const  VC_INPUT_TERMINAL                         =$02;
const  VC_OUTPUT_TERMINAL                        =$03;
const  VC_SELECTOR_UNIT                          =$04;
const  VC_PROCESSING_UNIT                        =$05;
const  VC_EXTENSION_UNIT                         =$06;

{ Video Class-Specific VideoStreaming Interface Descriptor Subtypes
{ (USB_Video_Class_1.1.pdf, A.6 Video Class-Specific VS Interface Descriptor Subtypes)}
const  VS_UNDEFINED                              =$00;
const  VS_INPUT_HEADER                           =$01;
const  VS_OUTPUT_HEADER                          =$02;
const  VS_STILL_IMAGE_FRAME                      =$03;
const  VS_FORMAT_UNCOMPRESSED                    =$04;
const  VS_FRAME_UNCOMPRESSED                     =$05;
const  VS_FORMAT_MJPEG                           =$06;
const  VS_FRAME_MJPEG                            =$07;
const  VS_FORMAT_MPEG2TS                         =$0A;
const  VS_FORMAT_DV                              =$0C;
const  VS_COLORFORMAT                            =$0D;
const  VS_FORMAT_FRAME_BASED                     =$10;
const  VS_FRAME_FRAME_BASED                      =$11;
const  VS_FORMAT_STREAM_BASED                    =$12;

{ Video Class-Specific Endpoint Descriptor Subtypes
{ (USB_Video_Class_1.1.pdf, A.7 Video Class-Specific Endpoint Descriptor Subtypes)     }
const  EP_UNDEFINED                              =$00;
const  EP_GENERAL                                =$01;
const  EP_ENDPOINT                               =$02;
const  EP_INTERRUPT                              =$03;

{ Video Class-Specific Request Codes
{ (USB_Video_Class_1.1.pdf, A.8 Video Class-Specific Request Codes)                     }
const  RC_UNDEFINED                              =$00;
const  SET_CUR                                   =$01;
const  GET_CUR                                   =$81;
const  GET_MIN                                   =$82;
const  GET_MAX                                   =$83;
const  GET_RES                                   =$84;
const  GET_LEN                                   =$85;
const  GET_INFO                                  =$86;
const  GET_DEF                                   =$87;

{ VideoControl Interface Control Selectors
{ (USB_Video_Class_1.1.pdf, A.9.1 VideoControl Interface Control Selectors)}
const  VC_CONTROL_UNDEFINED                      =$00;
const  VC_VIDEO_POWER_MODE_CONTROL               =$01;
const  VC_REQUEST_ERROR_CODE_CONTROL             =$02;

{ Request Error Code Control
{ (USB_Video_Class_1.1.pdf, 4.2.1.2 Request Error Code Control)}
const  NO_ERROR_ERR                              =$00;
const  NOT_READY_ERR                             =$01;
const  WRONG_STATE_ERR                           =$02;
const  POWER_ERR                                 =$03;
const  OUT_OF_RANGE_ERR                          =$04;
const  INVALID_UNIT_ERR                          =$05;
const  INVALID_CONTROL_ERR                       =$06;
const  INVALID_REQUEST_ERR                       =$07;
const  UNKNOWN_ERR                               =$FF;


{ Terminal Control Selectors
{ (USB_Video_Class_1.1.pdf, A.9.2 Terminal Control Selectors)}
const  TE_CONTROL_UNDEFINED                      =$00;

{ Selector Unit Control Selectors
{ (USB_Video_Class_1.1.pdf, A.9.3 Selector Unit Control Selectors)}
const  SU_CONTROL_UNDEFINED                      =$00;
const  SU_INPUT_SELECT_CONTROL                   =$01;

{ Camera Terminal Control Selectors
{ (USB_Video_Class_1.1.pdf, A.9.4 Camera Terminal Control Selectors)}
const  CT_CONTROL_UNDEFINED            		  =$00;
const  CT_SCANNING_MODE_CONTROL            	  =$01;
const  CT_AE_MODE_CONTROL                  	  =$02;
const  CT_AE_PRIORITY_CONTROL              	  =$03;
const  CT_EXPOSURE_TIME_ABSOLUTE_CONTROL         =$04;
const  CT_EXPOSURE_TIME_RELATIVE_CONTROL         =$05;
const  CT_FOCUS_ABSOLUTE_CONTROL       	      =$06;
const  CT_FOCUS_RELATIVE_CONTROL       	      =$07;
const  CT_FOCUS_AUTO_CONTROL               	  =$08;
const  CT_IRIS_ABSOLUTE_CONTROL            	  =$09;
const  CT_IRIS_RELATIVE_CONTROL            	  =$0A;
const  CT_ZOOM_ABSOLUTE_CONTROL            	  =$0B;
const  CT_ZOOM_RELATIVE_CONTROL            	  =$0C;
const  CT_PANTILT_ABSOLUTE_CONTROL         	  =$0D;
const  CT_PANTILT_RELATIVE_CONTROL         	  =$0E;
const  CT_ROLL_ABSOLUTE_CONTROL            	  =$0F;
const  CT_ROLL_RELATIVE_CONTROL            	  =$10;
const  CT_PRIVACY_CONTROL                  	  =$11;

{ Processing Unit Control Selectors
{ (USB_Video_Class_1.1.pdf, A.9.5 Processing Unit Control Selectors)}
const  PU_CONTROL_UNDEFINED            	   	  =$00;
const  PU_BACKLIGHT_COMPENSATION_CONTROL         =$01 ;
const  PU_BRIGHTNESS_CONTROL               	  =$02;
const  PU_CONTRAST_CONTROL                 	  =$03;
const  PU_GAIN_CONTROL                 	   	  =$04;
const  PU_POWER_LINE_FREQUENCY_CONTROL 	   	  =$05;
const  PU_HUE_CONTROL                  	   	  =$06;
const  PU_SATURATION_CONTROL           	   	  =$07;
const  PU_SHARPNESS_CONTROL            	   	  =$08;
const  PU_GAMMA_CONTROL                	   	  =$09;
const  PU_WHITE_BALANCE_TEMPERATURE_CONTROL      =$0A ;
const  PU_WHITE_BALANCE_TEMPERATURE_AUTO_CONTROL =$0B ;
const  PU_WHITE_BALANCE_COMPONENT_CONTROL        =$0C ;
const  PU_WHITE_BALANCE_COMPONENT_AUTO_CONTROL   =$0D ;
const  PU_DIGITAL_MULTIPLIER_CONTROL   	      =$0E    ;
const  PU_DIGITAL_MULTIPLIER_LIMIT_CONTROL       =$0F ;
const  PU_HUE_AUTO_CONTROL             	      =$10    ;
const  PU_ANALOG_VIDEO_STANDARD_CONTROL          =$11 ;
const  PU_ANALOG_LOCK_STATUS_CONTROL   	      =$12    ;

{ Extension Unit Control Selectors
{ (USB_Video_Class_1.1.pdf, A.9.6 Extension Unit Control Selectors)}
const  XU_CONTROL_UNDEFINED            	   	  =$00

;{ VideoStreaming Interface Control Selectors
;{ (USB_Video_Class_1.1.pdf, A.9.7 VideoStreaming Interface Control Selectors)}
const  VS_CONTROL_UNDEFINED             	      =$00;
const  VS_PROBE_CONTROL                 	      =$01;
const  VS_COMMIT_CONTROL                     	  =$02;
const  VS_STILL_PROBE_CONTROL               	  =$03;
const  VS_STILL_COMMIT_CONTROL                   =$04 ;
const  VS_STILL_IMAGE_TRIGGER_CONTROL      	  =$05;
const  VS_STREAM_ERROR_CODE_CONTROL       	      =$06;
const  VS_GENERATE_KEY_FRAME_CONTROL     	      =$07;
const  VS_UPDATE_FRAME_SEGMENT_CONTROL    	      =$08;
const  VS_SYNC_DELAY_CONTROL              	      =$09;


{ Defined Bits Containing Capabilities of the Control
{ (USB_Video_Class_1.1.pdf, 4.1.2 Table 4-3 Defined Bits Containing Capabilities of the Control)}
const  SUPPORTS_GET                 	          =$01;
const  SUPPORTS_SET                              =$02 ;
const  STATE_DISABLED                            =$04 ;
const  AUTOUPDATE_CONTROL                        =$08 ;
const  ASYNCHRONOUS_CONTROL                      =$10 ;

{ USB Terminal Types
{ (USB_Video_Class_1.1.pdf, B.1 USB Terminal Types)}
const  TT_VENDOR_SPECIFIC         	            =$0100;
const  TT_STREAMING               	            =$0101;

{ Input Terminal Types
{ (USB_Video_Class_1.1.pdf, B.2 Input Terminal Types)}
const  ITT_VENDOR_SPECIFIC                     =$0200;
const  ITT_CAMERA                              =$0201;
const  ITT_MEDIA_TRANSPORT_INPUT               =$0202;

{ Output Terminal Types
{ (USB_Video_Class_1.1.pdf, B.3 Output Terminal Types)}
const  OTT_VENDOR_SPECIFIC                     =$0300;
const  OTT_DISPLAY                             =$0301;
const  OTT_MEDIA_TRANSPORT_OUTPUT              =$0302;

{ External Terminal Types
{ (USB_Video_Class_1.1.pdf, B.4 External Terminal Types)}
const  EXTERNAL_VENDOR_SPECIFIC                =$0400;
const  COMPOSITE_CONNECTOR                     =$0401;
const  SVIDEO_CONNECTOR                        =$0402;
const  COMPONENT_CONNECTOR                     =$0403;


implementation

end.
