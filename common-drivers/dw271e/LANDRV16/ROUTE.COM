��HSRsb�p�p�p    ��     ��USWV.�.��PR�.�W
"ƄT�t�N� ��.�G
u� A�(Ms�m(Mw�U��U@t��."���Q��.������p"�ˋ�.�Y�� �t��� +G;�r��G� :GwG�
�S�.�? [t$��t�Ӄ�tP�.�� +G;�Xs������������).�W.�W.�? t���.��&�=�t��u�V�u�^u�.���.���.�.��u�^���.��D���  ��v8�$.8r�����v�Iv�EtMt�u
Q���Yt��.�� .+W�;�r����.�� .�G�.�G��ZX^_[]�V.�6^ ��@.�L(^���}��Á�}��Á�x}��Á��}��Á��,}��Á��E}��Á���}��õ��+����� ���t@��#�@t9��*�P+�+Ҏ��/<�Xu���t� ���x �t,��u�:&\ u	� z�/<�t+��Á� �s� �b �u��2PRS���� �^ �\ P� �^ �X�fuš\ V�  �^�|*XX����&�M��;��Ð    NetWareDriverLAN WS  ELINKSUP$          �PW�!.�>^ �u�ȯt0QUSRV���Ў�^Z[]u��>^ �` �!&��� ��&�E�� Y_X.�� .�.� �����O��Ju�U+��ô1����!ROUTE-DOS-$    1L � � �I�, �!�G�6����Jr��;�u�U�h]tz�� �u�\ 1���|���� ����%�!�t�>^ �.` �_��>`  t�>^ �!&��� ��&�E�� �� P�� ��&���&�T&�|&�|�ຍ���&�>u�
������E�t�����t�����t������ t� ����t�������� ��?W��w�<�t�"O��uA����u����[;�r;�r� L�!.�?
u��w� �9����$� +ҋ�"uCC�+������N �\ ����+����t�����u��t+����ø5�!�� �� �&�_����� u�������	&�G�;G�u���?
� ���=�
�?���n�\�h&����<�u�r�W�y�Q�܋�&�,����9&����1��&��+����!��#&�
��/u�ĺH*��&� �/����
� ��<	w0����+��-����E������W������B���ru+�;�u��u�����
;�t��
� ��
�u���<r����ø������뢀E�+�S��[u;�t
�݁=!tS��[u+��+�;�r�٠�1���>;�.=��y˸g�y���s�Et:����5�!����;�uZ�%�� �!�.�>;����۾� ����I���!������I����& @��&�>  t�@.;, t�&� ��; tٌ�;�t�����=�r��= w����=8r�8� ���	���*������ ���� �,+��tR�<-t</uF�ֿJ��}�]�����5�<ar<zw$߮��u���u3�"u�+���US�}��[rn�t���
�>Í\�� �� ��
t/F�����<=u���@u��� tB��W�}�< _s���
��
*���r��w󤖸" ������$��
��
�Ҹ�
t��|�L�!USW+���+��KONCF�$<0r^<9v��uU <arO<fwK�����O��r?�Hu��t$+�G�A��������Q�� O��Yr�;�u�
�u���@t	$�ʹ������ˋ�_[]����	  
�,�$Q� :�tW�a	�_��Y�P�X+�+���	+��7R:�t��� XCC�?u��s��'�d 
    +�V���( ��^�R�
��u� �m ���������� �$� ��^�t��<$t��K ���'@'�Au��
� � 
�E ��!�?
�,���q�c Press ANY key to continue...$ 0�t��0P���!X��Ë�|$t:�0�. �*�d�����*�
���������: �������T�< tJ� ��
�	�!�ô ����uF<w�N+��.
$

is invalidis not supported
is too big The parameter "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
	Node Address	Source Route$Local Segment$
	$	$VeRsIoN=Novell Source Routing Driver for DOS ODI  v2.23 (960513) 
(c) Copyright 1989 - 1997, by Novell Inc. All rights reserved.

$ROUTE  U,BOARD=b,CLEAR,DEF,GBR,HOPS=h,MBR,NODES=n,TIME=t,TRA=ta,TRO=to,XTX=x

U	Unload a previously installed Source Router from memory.
BOARD=b	The board number as assigned by ODI.
CLEAR	CLEAR ALL Nodes from a previously loaded Source Router.
DEF	Send DEFault (Unknown) Node Addresses ALL ROUTES Broadcast.
	If NOT entered, SINGLE ROUTE Broadcast is ASSUMED.
GBR	Send Broadcast (FFFF FFFF FFFF) Addresses ALL ROUTES Broadcast.
	If NOT entered, SINGLE ROUTE Broadcast is ASSUMED.
HOPS=h	The number of bridge hops.  The DEFAULT is 07, MAXIMUM is 13.
MBR	Send Multicast (C000 xxxx xxxx) Addresses ALL ROUTES Broadcast.
	If NOT entered, SINGLE ROUTE Broadcast is ASSUMED.
NODES=n	The number of NODE Addresses to support.  The DEFAULT is 16,
	MAXIMUM is 1000.  If LESS THAN 08, then 08 is used.
TIME=t	The number of seconds to wait before a known route is timed
	out.  The DEFAULT is 10, MAXIMUM is 3640.  If 0, the route
	will NEVER time out.$TRA=ta	A number specifying a THIS RING ALTERNATE count for Broadcasts.
	The Source Router will ALTERNATE betweed SOURCE Routed and NON-
	SOURCE Routed frames.  The DEFAULT is 00, MAXIMUM is 255.
TRO=to	A number specifying a THIS RING ONLY count for Broadcasts.
	The DEFAULT is 00, MAXIMUM is 255.
XTX=x	The number of times to transmit on a timed out route.  The
	DEFAULT is 02, MAXIMUM is 255.
ALL Parameters are OPTIONAL, are NOT case sensitive, and may be entered in ANY
order. They may be used to SET the Source Router that is being loaded, or
CHANGE the configuration of a PREVIOUSLY loaded Source Router.$ALL$dSource Routing Table has been CLEARED$	DEFault Node     (Unknown$	Broadcast (FFFF FFFF FFFF$	Multicast (C000 xxxx xxxx$	ROUTE is not loaded$eBOARD #x NOT Found; Source Router will POLL for it$� Current ROUTE.com parameters for Board #1 are:

$	Maximum HOPS = $ Bridges; NODES = $; Aging TIME = $ Seconds.
	This Ring $Alternate (TRA) Count = $Only (TRO) Count = $) Addresses are sent $SINGLE$ ROUTE Broadcast.
$fBoard #1 does not support Source Routing$A TSR is loaded above ROUTE.com$ROUTE.com for board #1 has been unloaded$gYou are using the WRONG verion of ROUTE.com$; Extra Transmit (XTX) Count = $?@=�U@�F@�BOARD���CLEAR@E�D-@!�DEF@
�GBR@�HOPS��LSB@�MBR@�MSB@�NODES��TIME��TRA��TRO��XTX�  