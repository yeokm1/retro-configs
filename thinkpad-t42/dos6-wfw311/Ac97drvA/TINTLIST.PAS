{(******************************************************************************
**           FEEDBACK IS GREATLY APPRECIATED, AS IT INSPIRES ME TO
**                    CONTINUE RELEASING FREE SOFTWARE
** Feedback to:
**
**                               Eric  Lawrence
**                           Applications Architect
**	                              Bayden Systems
**
**	 Send registration email to bayden@bigfoot.com
**        Check for updates at   www.bayden.com
**
**  TIntegerList v2.0
**
**  To use:
**  Simply add TIntList to your the top of your unit in the 'uses' clause.
**  Then you can create and use TIntegerLists just like you create and use
**  TStringLists!
**
**                        Idea and Original code by:
**                                Mark Bracey
**
**  This code may be used, modified, included in applications without any
**  license agreements as long as the disclaimers are accepted.  Credit should
**  be given where it is due.
**
**  Disclaimer:
**  This software is released into the public domain on the strict understanding
**  that neither myself nor any associates nor companies I work for have any
**  liability, explicit or implied.
**
**  Possible Enhancements:
**	                        Beats me.  Any ideas?
*******************************************************************************)}

unit TIntList;

interface
   uses classes;

Type
   TIntegerList = class(TList)

private
 procedure SetInteger(Index: Integer; Value: LongInt);
 function GetInteger(Index: Integer):LongInt;
public
 property Items [index: Integer]: LongInt read GetInteger write SetInteger;
 procedure Add(Value: LongInt);
  procedure Insert(index:word;Value: LongInt);
 function IndexOf(Value: LongInt): Integer;
 procedure Sort;
end;

function SortHelper(Item1, Item2: Pointer): Integer;

implementation

function SortHelper(Item1, Item2: Pointer): Integer;
begin
   if (LongInt(Item1)<LongInt(Item2)) then result:=-1
       else
           if (LongInt(Item1)>LongInt(Item2)) then result:=1
               else
                   result:=0;
end;

procedure TIntegerList.Sort;
begin
{   inherited Sort(SortHelper);}
end;

function TIntegerList.IndexOf(Value: LongInt): Integer;
begin
   result:=inherited IndexOf(Pointer(Value));
end;

procedure TIntegerList.SetInteger(Index: Integer; Value: LongInt);
begin
   inherited Items[Index]:= Pointer(Value);
end;

function TIntegerList.GetInteger(Index: Integer): LongInt;
begin
   Result:= LongInt(inherited Items[Index]);
end;

procedure TIntegerList.Add(Value: LongInt);
begin
   inherited Add(Pointer(Value));
end;

procedure TIntegerList.Insert(index:word;Value: LongInt);
begin
   inherited Insert(index,Pointer(Value));
end;

end.
