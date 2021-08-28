{$H+}

unit
	Screen;

interface
	type
		i32 = LongInt;
		i16 = SmallInt;
		i8  = ShortInt;
		
		ui32 = Cardinal;
		ui16 = Word;
		ui8  = Byte;

		str  = String;
		ch   = Char;
		bool = Boolean;

	procedure Update();
	
	procedure FillScreen(p_Char: ch);
	procedure WriteAt(p_PosX, p_PosY: ui16; p_Text: str);
	procedure WriteAt(p_PosX, p_PosY: ui16; p_Char: ch);
	
	procedure SetAttribute(p_Attr: ui32);
	procedure SetColor(p_Color: ui8);
	procedure SetScreenSize(p_SizeX, p_SizeY: ui16);

implementation
	uses
		NCurses;

	type
		Pixel = record
			Color: ui8;
			Attribute: ui32;
			Char: ch;
		end;

	var
		Pixels: array of array of Pixel;
		ScreenX: ui16;
		ScreenY: ui16;

		LastAttr: ui32;
		LastColor: ui8;

	procedure Update();
	var
		i, j: ui16;
		PrevAttr: ui32;
	begin
		Move(0, 0);

		PrevAttr:= 0;
		
		for i:= 0 to ScreenY - 1 do
		begin
			for j:= 0 to ScreenX - 1 do
			begin
				if PrevAttr <> Pixels[i][j].Attribute then
				begin
					AttrOff(PrevAttr);

					PrevAttr:= Pixels[i][j].Attribute;
					
					AttrOn(PrevAttr);
				end;

				AttrOn(COLOR_PAIR(Pixels[i][j].Color));

				if (Pixels[i][j].Char < #32) or (Pixels[i][j].Char > #126) then
					Pixels[i][j].Char:= #32;
					
				addch(ui8(Pixels[i][j].Char));
				
				AttrOff(COLOR_PAIR(Pixels[i][j].Color));
			end;
		end;
	
		AttrOff(PrevAttr);
	
		Refresh();
	end;

	procedure FillScreen(p_Char: ch);
	var 
		i, j: ui16;
	begin
		for i:= 0 to ScreenY - 1 do
		begin
			for j:= 0 to ScreenX - 1 do
			begin
				Pixels[i][j].Char:= p_Char;
				Pixels[i][j].Color:= LastColor;
				Pixels[i][j].Attribute:= LastAttr;
			end;
		end;
	end;
	
	procedure WriteAt(p_PosX, p_PosY: ui16; p_Text: str);
	var 
		i, PosX: ui16;
	begin
		for i:= 1 to Length(p_Text) do
		begin
			PosX:= p_PosX + i - 1;
			
			if (PosX >= ScreenX) or (p_PosY >= ScreenY) then
				break;

			Pixels[p_PosY][PosX].Char:= p_Text[i];
			Pixels[p_PosY][PosX].Color:= LastColor;
			Pixels[p_PosY][PosX].Attribute:= LastAttr;
		end;
	end;
	
	procedure WriteAt(p_PosX, p_PosY: ui16; p_Char: ch);
	begin
		if (p_PosX >= ScreenX) or (p_PosY >= ScreenY) then
			exit();

		Pixels[p_PosY][p_PosX].Char:= p_Char;
		Pixels[p_PosY][p_PosX].Color:= LastColor;
		Pixels[p_PosY][p_PosX].Attribute:= LastAttr;
	end;
	
	procedure SetAttribute(p_Attr: ui32);
	begin
		LastAttr:= p_Attr;
	end;
	
	procedure SetColor(p_Color: ui8);
	begin
		LastColor:= p_Color;
	end;
	
	procedure SetScreenSize(p_SizeX, p_SizeY: ui16);
	var 
		i: ui16;
	begin
		ScreenY:= p_SizeY;
		ScreenX:= p_SizeX;

		SetLength(Pixels, ScreenY);

		for i:= 0 to ScreenY - 1 do
		begin
			SetLength(Pixels[i], ScreenX);
		end;
	end;

initialization
	begin
		InitScr();

		Raw();
		NoEcho();
		KeyPad(StdScr, true);
		Timeout(-1);
		NoDelay(StdScr, true);

		Start_Color();
		Use_Default_Colors();
		Curs_Set(0);

		SetLength(Pixels, 1);
		SetLength(Pixels[0], 1);

		ScreenX:= 1;
		ScreenY:= 1;

		LastAttr:= 0;
		LastColor:= 0;
	end;

finalization
	begin
		endwin();
	end;

end.
