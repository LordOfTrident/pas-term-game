TArray = array of T;
PT = ^T;

List = record
	Elements: TArray;
end;

PList = ^List;

procedure ListSet(p_List: PList; p_Elements: TArray);
begin
	p_List^.Elements:= p_Elements;
end;

procedure ListClear(p_List: PList);
begin
	SetLength(p_List^.Elements, 0);
end;

function ListGet(p_List: PList; p_Idx: ui32): T;
begin
	ListGet:= p_List^.Elements[p_Idx];
end;

function ListGetP(p_List: PList; p_Idx: ui32): PT;
begin
	ListGetP:= @p_List^.Elements[p_Idx];
end;

function ListLength(p_List: PList): ui32;
begin
	ListLength:= Length(p_List^.Elements);
end;

procedure ListSetValue(p_List: PList; p_Idx: ui32; p_Value: T);
begin
	p_List^.Elements[p_Idx]:= p_Value;
end;

procedure ListPush(p_List: PList; p_Value: T);
begin
	SetLength(p_List^.Elements, Length(p_List^.Elements) + 1);  
	p_List^.Elements[Length(p_List^.Elements) - 1]:= p_Value;
end;

procedure ListPop(p_List: PList);
begin
	SetLength(p_List^.Elements, Length(p_List^.Elements) - 1);
end;

procedure ListInsert(p_List: PList; p_Idx: ui32; p_Value: T);
var 
	i: ui32;
	PrevValue, SaveValue: T;
begin
	SetLength(p_List^.Elements, Length(p_List^.Elements) + 1);

	PrevValue:= p_Value;
	
	for i:= p_Idx to Length(p_List^.Elements) - 1 do
	begin
		SaveValue:= PrevValue;
		PrevValue:= p_List^.Elements[i];
		p_List^.Elements[i]:= SaveValue;
	end;
end;

procedure ListRemove(p_List: PList; p_Idx: ui32);
var 
	i: ui32;
begin
	for i:= p_Idx to Length(p_List^.Elements) - 1 do
		p_List^.Elements[i]:= p_List^.Elements[i + 1];
	
	SetLength(p_List^.Elements, Length(p_List^.Elements) - 1);
end;

type
