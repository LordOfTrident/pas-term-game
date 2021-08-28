{$MODE FPC}
{$MACRO ON}
{$H+}

{$DEFINE COLOR_GREY          := 8}
{$DEFINE COLOR_BRIGHTRED     := 9}
{$DEFINE COLOR_BRIGHTGREEN   := 10}
{$DEFINE COLOR_BRIGHTYELLOW  := 11}
{$DEFINE COLOR_BRIGHTBLUE    := 12}
{$DEFINE COLOR_BRIGHTMAGENTA := 13}
{$DEFINE COLOR_BRIGHTCYAN    := 14}
{$DEFINE COLOR_BRIGHTWHITE   := 15}

{$DEFINE PLR_COLOR := 1}
{$DEFINE BCK_COLOR := 2}
{$DEFINE WAL_COLOR := 3}
{$DEFINE SPW_COLOR := 4}
{$DEFINE PNT_COLOR := 5}
{$DEFINE AMO_COLOR := 6}
{$DEFINE MBX_COLOR := 7}
{$DEFINE WTR_COLOR := 8}
{$DEFINE PLW_COLOR := 9}
{$DEFINE AMW_COLOR := 10}
{$DEFINE PNW_COLOR := 11}
{$DEFINE MBW_COLOR := 12}
{$DEFINE DOR_COLOR := 13}
{$DEFINE EXT_COLOR := 14}
{$DEFINE GRS_COLOR := 15}
{$DEFINE PLG_COLOR := 16}
{$DEFINE MBG_COLOR := 17}
{$DEFINE MEG_COLOR := 18}

{$DEFINE ID_PLR := 1}
{$DEFINE ID_SHT := 2}
{$DEFINE ID_HMB := 3}
{$DEFINE ID_VMB := 4}
{$DEFINE ID_RME := 5}

program 
	Terminal2DGame;

uses
	NCurses,
	Screen,
	StrUtils,
	SysUtils;

type
	Entity = record
		PosX, PosY: ui16;
		Direction: ui8;
		Representation: ch;
		ID: ui8;
	end;

	PEntity = ^Entity;
	
	Tile = record
		Collision: bool;
		Floor: ch;
		Wall: ch;
		Pickup: ch;
	end;

	Level = record
		Map: array of array of Tile;
		SizeX, SizeY: ui16;
	end;

	PLevel = ^Level;

	T = Entity;
	{$INCLUDE list.inc}
	EntityList = List;
	
var
	i: ui8;
	
	Running: bool;
	Player: Entity;
	Lvl: Level;
	Points, MaxPoints, Ammo: ui16;
	Entities: EntityList;
	Tick: ui32;
	WaterState: ui8;
	Lvls: array of str;
	CurrentLvl: ui8;
	PlayerDied: bool;
	TimeStart, TimeStop: TDateTime;

function GetDirectionOpposite(p_Direction: ui8): ui8;
begin
	GetDirectionOpposite:= 0;
	
	case p_Direction of
		0:
			GetDirectionOpposite:= 2;
			
		1:
			GetDirectionOpposite:= 3;
			
		2:
			GetDirectionOpposite:= 0;
			
		3:
			GetDirectionOpposite:= 1;
	end;
end;

function CreateEntity(p_PosX, p_PosY: ui16; p_Direction: ui8; p_Representation: ch; p_ID: ui8): Entity;
begin
	CreateEntity.PosX:= p_PosX;
	CreateEntity.PosY:= p_PosY;
	CreateEntity.Direction:= p_Direction;
	CreateEntity.Representation:= p_Representation;
	CreateEntity.ID:= p_ID;
end;

procedure RenderEntity(p_Entity: PEntity);
begin
	Screen.WriteAt(p_Entity^.PosX, p_Entity^.PosY, p_Entity^.Representation);
end;

function MoveBox(p_Level: PLevel; p_PosX, p_PosY: ui16; p_Direction: ui8): bool;
var
	OldX, OldY: ui16;
begin
	if p_Level^.Map[p_PosY][p_PosX].Wall <> '@' then
	begin
		MoveBox:= false;
		exit();
	end;

	OldX:= p_PosX;
	OldY:= p_PosY;

	case p_Direction of
		0:
			p_PosY-= 1;
			
		1:
			p_PosX-= 1;
			
		2:
			p_PosY+= 1;
			
		3:
			p_PosX+= 1;
	end;

	case p_Level^.Map[p_PosY][p_PosX].Collision of
		true:
		begin
			MoveBox:= false;
			exit();
		end;

		false:
		begin
			case p_Level^.Map[p_PosY][p_PosX].Floor of
				'~':
				begin
					MoveBox:= false;
					exit();
				end;
			end;
			
			case p_Level^.Map[p_PosY][p_PosX].Wall of
				'M', 'E':
				begin
					MoveBox:= false;
					exit();
				end;
				
				'@':
				begin
					if not MoveBox(p_Level, p_PosX, p_PosY, p_Direction) then
					begin
						MoveBox:= false;
						exit();
					end;
				end;
			end;
		end;
	end;
	
	p_Level^.Map[OldY][OldX].Wall:= ' ';
	p_Level^.Map[p_PosY][p_PosX].Wall:= '@';

	MoveBox:= true;
end;

function MoveEntity(p_Entity: PEntity; p_Level: PLevel; p_CanPush, p_CanCrossBarrier, p_CanKill, p_IsEnemy: bool): bool;
var 
	PosX, PosY: ui16;
begin
	if (p_Entity^.PosX >= p_Level^.SizeX) or (p_Entity^.PosY >= p_Level^.SizeY) then
	begin
		MoveEntity:= false;
		exit();
	end;

	if not p_IsEnemy then
		case p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Wall of
			'E':
			begin
				if p_CanKill then
				begin
					p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Wall:= ' ';

					MoveEntity:= false;
				end;
			end;
		end;
	
	MoveEntity:= true;

	PosX:= p_Entity^.PosX;
	PosY:= p_Entity^.PosY;

	case p_Entity^.Direction of
		0:
			p_Entity^.PosY-= 1;
			
		1:
			p_Entity^.PosX-= 1;
			
		2:
			p_Entity^.PosY+= 1;
			
		3:
			p_Entity^.PosX+= 1;
	end;

	case p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Collision of
		true:
		begin
			MoveEntity:= false;
			
			p_Entity^.PosX:= PosX;
			p_Entity^.PosY:= PosY;
		end;

		false:
		begin
			case p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Wall of
				'B':
				begin
					if not p_CanCrossBarrier then
					begin
						MoveEntity:= false;
						
						p_Entity^.PosX:= PosX;
						p_Entity^.PosY:= PosY;
					end;
				end;
				
				'E':
				begin
					if p_IsEnemy then
					begin
						MoveEntity:= false;
						
						p_Entity^.PosX:= PosX;
						p_Entity^.PosY:= PosY;
					end;
					
					if p_CanKill then
					begin
						p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Wall:= ' ';

						MoveEntity:= false;
					end;
				end;
				
				'@':
				begin
					if p_CanKill then
					begin
						p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Wall:= ' ';
						p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Collision:= false;

						MoveEntity:= false;
					end
					else if not p_CanPush or not MoveBox(p_Level, p_Entity^.PosX, p_Entity^.PosY, p_Entity^.Direction) then
					begin
						MoveEntity:= false;
						
						p_Entity^.PosX:= PosX;
						p_Entity^.PosY:= PosY;
					end;
				end;
			end;
		end;
	end;
end;

function FixEntityPos(p_Entity: PEntity; p_Level: PLevel; p_CanPush, p_CanCrossBarrier, p_CanKill, p_IsEnemy: bool): bool;
begin
	case p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Collision of
		true:
		begin
			if p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Wall = 'M' then
			begin
				FixEntityPos:= false;
				exit();
			end;
		end;
		
		false:
		begin
			if p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Wall <> '@' then
			begin
				FixEntityPos:= false;
				exit();
			end;
		end;
	end;

	FixEntityPos:= true;
						
	p_Entity^.Direction:= GetDirectionOpposite(p_Entity^.Direction);
	
	MoveEntity(p_Entity, p_Level, p_CanPush, p_CanCrossBarrier, p_CanKill, p_IsEnemy);
end;

procedure RenderLevel(p_PosX, p_PosY: ui16; p_Level: PLevel);
var 
	i, j: ui16;
	ToRender: ch;
begin
	Screen.SetAttribute(0);
	ToRender:= ' ';

	for i:= 0 to p_Level^.SizeY - 1 do
		for j:= 0 to p_Level^.SizeX - 1 do
		begin
			case p_Level^.Map[i][j].Wall of
				' ', 'M', 'B':
				begin
					case p_Level^.Map[i][j].Floor of
						'G':
						begin
							Screen.SetColor(GRS_COLOR);
							
							ToRender:= '`';
						end;
						
						'F':
						begin
							Screen.SetColor(EXT_COLOR);
							
							ToRender:= 'X';
						end;
					else
						case p_Level^.Map[i][j].Pickup of
							'.':
							begin
								case p_Level^.Map[i][j].Floor of
									'~':
										Screen.SetColor(PNW_COLOR);
								else
									Screen.SetColor(PNT_COLOR);
								end;
								
								ToRender:= '.';
							end;
							
							'A':
							begin
								case p_Level^.Map[i][j].Floor of
									'~':
										Screen.SetColor(AMW_COLOR);
								else
									Screen.SetColor(AMO_COLOR);
								end;
								
								ToRender:= 'A';
							end;
						else
							case p_Level^.Map[i][j].Floor of
								'~':
								begin
									Screen.SetColor(WTR_COLOR);

									case WaterState of
										0:
											ToRender:= '-';
											
										1:
											ToRender:= '~';

										2:
											ToRender:= '=';
										
										3:
											ToRender:= '~';
									else
										ToRender:= '~';
									end;
								end;
							else
								Screen.SetColor(BCK_COLOR);
								ToRender:= ' ';
							end;
						end;
					end;
				end;

				'D':
				begin
					if Points = MaxPoints then
					begin
						p_Level^.Map[i][j].Collision:= false;
						p_Level^.Map[i][j].Wall:= ' ';
					end;
					
					Screen.SetColor(DOR_COLOR);
					Screen.SetAttribute(A_ALTCHARSET);
					
					ToRender:= #48;
				end;
				
				'@':
				begin
					case p_Level^.Map[i][j].Floor of
						'G':
							Screen.SetColor(MBG_COLOR);
					else
						Screen.SetColor(SPW_COLOR);
					end;

					ToRender:= '@';
				end;
				
				'#':
				begin
					Screen.SetColor(WAL_COLOR);
					Screen.SetAttribute(A_ALTCHARSET);
					ToRender:= #48;
				end;
			else
				Screen.SetColor(BCK_COLOR);
				ToRender:= ' ';
			end;
			
			Screen.WriteAt(p_PosX + j, p_PosY + i, ToRender);

			Screen.SetAttribute(0);
		end;
end;

procedure InitLevel(p_Level: PLevel; p_Entity: PEntity; p_Map: str);
var 
	i: ui16;
	PosX, PosY: ui16;
	Skip: bool;
begin
	p_Level^.SizeY:= 0;
	p_Level^.SizeX:= 0;

	for i:= 1 to Length(p_Map) do
	begin
		if p_Map[i] = #10 then
		begin
			if p_Level^.SizeX = 0 then
				p_Level^.SizeX:= i - 1;
			
			Inc(p_Level^.SizeY);
		end;
	end;

	SetLength(p_Level^.Map, p_Level^.SizeY);
	
	PosX:= 0;
	PosY:= 0;
	
	Skip:= false;
	SetLength(p_Level^.Map[PosY], p_Level^.SizeX);
	
	for i:= 1 to Length(p_Map) do
	begin
		if Skip then
		begin
			if p_Map[i] = #10 then
				Skip:= false;
			
			continue;
		end;
		
		if p_Map[i] = #10 then
		begin
			PosX:= 0;
			Inc(PosY);
			if p_Level^.SizeY > PosY then
				SetLength(p_Level^.Map[PosY], p_Level^.SizeX);

			continue;
		end
		else if PosX >= p_Level^.SizeX then
		begin
			PosX:= 0;
			Inc(PosY);
			if p_Level^.SizeY > PosY then
				SetLength(p_Level^.Map[PosY], p_Level^.SizeX);
			Skip:= true;

			continue;
		end
		else
		begin
			p_Level^.Map[PosY][PosX].Collision:= false;
			p_Level^.Map[PosY][PosX].Wall:= ' ';
			p_Level^.Map[PosY][PosX].Floor:= ' ';
			p_Level^.Map[PosY][PosX].Pickup:= ' ';
			
			case p_Map[i] of
				'P':
				begin
					p_Entity^.PosX:= PosX;
					p_Entity^.PosY:= PosY;
				end;
				
				'F':
					p_Level^.Map[PosY][PosX].Floor:= 'F';
				
				'D':
				begin
					p_Level^.Map[PosY][PosX].Collision:= true;
					p_Level^.Map[PosY][PosX].Wall:= 'D';
				end;

				'H':
				begin
					p_Level^.Map[PosY][PosX].Wall:= 'M';
					
					ListPush(@Entities, CreateEntity(PosX, PosY, 1, #97, ID_HMB));
				end;
				
				'V':
				begin
					p_Level^.Map[PosY][PosX].Wall:= 'M';
					
					ListPush(@Entities, CreateEntity(PosX, PosY, 0, #97, ID_VMB));
				end;
				
				'E':
				begin
					p_Level^.Map[PosY][PosX].Wall:= 'E';
					
					ListPush(@Entities, CreateEntity(PosX, PosY, Random(4), 'E', ID_RME));
				end;

				'B':
					p_Level^.Map[PosY][PosX].Wall:= 'B';
				
				'G':
					p_Level^.Map[PosY][PosX].Floor:= 'G';

				'N':
					p_Level^.Map[PosY][PosX].Collision:= true;

				'#':
				begin
					p_Level^.Map[PosY][PosX].Collision:= true;
					p_Level^.Map[PosY][PosX].Wall:= '#';
				end;

				'@':
					p_Level^.Map[PosY][PosX].Wall:= '@';

				'A':
					p_Level^.Map[PosY][PosX].Pickup:= 'A';
				
				'.':
				begin
					Inc(MaxPoints);
					
					p_Level^.Map[PosY][PosX].Pickup:= '.';
				end;
				
				'~':
					p_Level^.Map[PosY][PosX].Floor:= '~';
			end;
		end;

		Inc(PosX);
	end;
end;

procedure EntityCheckPickup(p_Entity: PEntity; p_Level: PLevel);
begin
	if (p_Entity^.PosX >= p_Level^.SizeX) or (p_Entity^.PosY >= p_Level^.SizeY) then
		exit();

	case p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Pickup of
		'.':
		begin
			p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Pickup:= ' ';
			Inc(Points);
		end;

		'A':
		begin
			p_Level^.Map[p_Entity^.PosY][p_Entity^.PosX].Pickup:= ' ';
			Inc(Ammo);
		end;
	end;
end;

procedure Init();
begin
	Player.PosX:= 1;
	Player.PosY:= 1;
	Player.Direction:= 0;
	Player.Representation:= #45;
	Player.ID:= ID_PLR;

	Points:= 0;
	Ammo:= 0;
	WaterState:= 0;
	MaxPoints:= 0;
	Tick:= 0;
	PlayerDied:= false;

	ListClear(@Entities);
    
	InitLevel(@Lvl, @Player, Lvls[CurrentLvl]);

	Randomize;

	Screen.SetColor(BCK_COLOR);
	Screen.FillScreen(' ');
	Screen.WriteAt(1, 1, 'Entering map ' + IntToStr(CurrentLvl + 1) + ': "' + ParamStr(CurrentLvl + 1) + '"');
	Screen.WriteAt(1, 2, 'Press enter to continue.');

	Screen.Update();
	
	while getch <> 10 do
	begin
	end;

	TimeStart:= Now();
end;

procedure Input();
var
	Representation: ch;
begin
	case getch() of
		KEY_RESIZE:
			Screen.SetScreenSize(GetMaxX(StdScr), GetMaxY(StdScr));

		i32('q') and 31:
		begin
			Running:= false;
			CurrentLvl:= Length(Lvls);
		end;

		i32('n') and 31:
			Running:= false;

		i32('w'):
		begin
			Player.Direction:= 0;
			Player.Representation:= #45;
			MoveEntity(@Player, @Lvl, true, true, false, false);
		end;
		
		i32('a'):
		begin
			Player.Direction:= 1;
			Player.Representation:= #44;
			MoveEntity(@Player, @Lvl, true, true, false, false);
		end;
		
		i32('s'):
		begin
			Player.Direction:= 2;
			Player.Representation:= #46;
			MoveEntity(@Player, @Lvl, true, true, false, false);
		end;
		
		i32('d'):
		begin
			Player.Direction:= 3;
			Player.Representation:= #43;
			MoveEntity(@Player, @Lvl, true, true, false, false);
		end;

		32:
		begin
			if Ammo > 0 then
			begin
				case Player.Direction of
					0, 2:
						Representation:= #120;
					
					1, 3:
						Representation:= #113;
				else
					Representation:= '-';
				end;
				
				ListPush(@Entities, CreateEntity(Player.PosX, Player.PosY, Player.Direction, Representation, ID_SHT));

				Ammo-= 1;
			end;
		end;
	end;

	case Lvl.Map[Player.PosY][Player.PosX].Wall of
		'M':
		begin
			PlayerDied:= true;
			Running:= false;
		end;
		
		'E':
		begin
			PlayerDied:= true;
			Running:= false;
		end;
	end;

	EntityCheckPickup(@Player, @Lvl);
end;

procedure Render();
var
	i: ui16;
	Ent: PEntity;
begin
	Screen.SetColor(BCK_COLOR);
	Screen.SetAttribute(0);
	Screen.FillScreen(' ');

	if Tick mod 15 = 0 then 
		Inc(WaterState);
		
	if WaterState > 3 then
		WaterState:= 0;

	RenderLevel(0, 0, @Lvl);

	case Lvl.Map[Player.PosY][Player.PosX].Floor of
		'~':
			Screen.SetColor(PLW_COLOR);

		'G':
			Screen.SetColor(PLG_COLOR);

		'F':
		begin
			PlayerDied:= false;
			Running:= false;
		end;
	else
		Screen.SetColor(PLR_COLOR);
	end;
	
	Screen.SetAttribute(A_ALTCHARSET);
	RenderEntity(@Player);
	Screen.SetAttribute(0);
	
	i:= 0;
	while i < ListLength(@Entities) do
	begin
		Ent:= ListGetP(@Entities, i);

		case Ent^.ID of
			ID_SHT:
			begin
				if Tick mod 2 = 0 then
				begin
					if not MoveEntity(Ent, @Lvl, false, true, true, false) then
					begin
						ListRemove(@Entities, i);
						
						continue;
					end;
				end;

				if (Ent^.PosX <> Player.PosX) or (Ent^.PosY <> Player.PosY) then
				begin
					case Lvl.Map[Ent^.PosY][Ent^.PosX].Floor of
						'~':
							Screen.SetColor(PNW_COLOR);

						'G':
							Screen.SetColor(PLG_COLOR);
					else
						Screen.SetColor(PNT_COLOR);
					end;
					
					Screen.SetAttribute(A_ALTCHARSET);
					
					RenderEntity(Ent);
					
					Screen.SetAttribute(0);
				end;
			end;

			ID_HMB:
			begin
				if Tick mod 4 = 0 then
					if not FixEntityPos(Ent, @Lvl, false, false, false, false) then
					begin
						Lvl.Map[Ent^.PosY][Ent^.PosX].Wall:= ' ';

						if not MoveEntity(Ent, @Lvl, false, false, false, false) then
							Ent^.Direction:= GetDirectionOpposite(Ent^.Direction);
		
						Lvl.Map[Ent^.PosY][Ent^.PosX].Wall:= 'M';
					end;

				Screen.SetAttribute(A_ALTCHARSET);

				case Lvl.Map[Ent^.PosY][Ent^.PosX].Floor of
					'~':
						Screen.SetColor(MBW_COLOR);

					'G':
						Screen.SetColor(MEG_COLOR);
				else
					Screen.SetColor(MBX_COLOR);
				end;
								
				RenderEntity(Ent);
				
				Screen.SetAttribute(0);
			end;
			
			ID_VMB:
			begin
				if Tick mod 4 = 0 then
					if not FixEntityPos(Ent, @Lvl, false, false, false, false) then
					begin
						Lvl.Map[Ent^.PosY][Ent^.PosX].Wall:= ' ';

						if not MoveEntity(Ent, @Lvl, false, false, false, false) then
							Ent^.Direction:= GetDirectionOpposite(Ent^.Direction);
						
						Lvl.Map[Ent^.PosY][Ent^.PosX].Wall:= 'M';
					end;

				Screen.SetAttribute(A_ALTCHARSET);

				case Lvl.Map[Ent^.PosY][Ent^.PosX].Floor of
					'~':
						Screen.SetColor(MBW_COLOR);
						
					'G':
						Screen.SetColor(MEG_COLOR);
				else
					Screen.SetColor(MBX_COLOR);
				end;
				
				RenderEntity(Ent);
				
				Screen.SetAttribute(0);
			end;

			ID_RME:
			begin
				if Lvl.Map[Ent^.PosY][Ent^.PosX].Wall = ' ' then
				begin
					ListRemove(@Entities, i);

					continue;
				end;
				
				if Tick mod 15 = 0 then
				begin
					Lvl.Map[Ent^.PosY][Ent^.PosX].Wall:= ' ';
					
					MoveEntity(Ent, @Lvl, false, false, false, true);

					Lvl.Map[Ent^.PosY][Ent^.PosX].Wall:= 'E';

					Ent^.Direction:= Random(4);
				end;

				case Lvl.Map[Ent^.PosY][Ent^.PosX].Floor of
					'~':
						Screen.SetColor(MBW_COLOR);
						
					'G':
						Screen.SetColor(MEG_COLOR);
				else
					Screen.SetColor(MBX_COLOR);
				end;
				
				RenderEntity(Ent);
			end;
		end;

		Inc(i);
	end;

	Screen.SetColor(BCK_COLOR);
	Screen.WriteAt(1, Lvl.SizeY + 1, 'Points: ' + IntToStr(Points));
	Screen.WriteAt(1, Lvl.SizeY + 2, 'Ammo: ' + IntToStr(Ammo));
	Screen.WriteAt(1, Lvl.SizeY + 3, 'WASD to move, Space to shoot, CTRL+Q to quit');
	
	Screen.Update();
end;

procedure Start();
begin
	Running:= true;

	while Running do
	begin
		napms(10);
		
		Input();
		Render();

		Inc(Tick);
	end;
end;

procedure Finish();
begin
	TimeStop:= Now();
	
	Screen.SetColor(BCK_COLOR);
	Screen.FillScreen(' ');

	if PlayerDied then
		Screen.WriteAt(1, 1, 'You died!')
	else
		Screen.WriteAt(1, 1, 'You won!');
		
	Screen.WriteAt(1, 2, 'Points collected: ' + IntToStr(Points) + '/' + IntToStr(MaxPoints));
	Screen.WriteAt(1, 3, 'Time Taken: ' + FormatDateTime('hh:nn:ss:zzz', TimeStop - TimeStart));
	Screen.WriteAt(1, 4, 'Press enter to continue.');

	Screen.Update();

	while getch <> 10 do
	begin
	end;
	
	if not PlayerDied then
		Inc(CurrentLvl);
end;

function ReadMapFile(p_FileName: str): str;
var
	fhnd: Text;
	LineString: str;
	ReadingMap: bool;
begin
	if not FileExists(p_FileName) then
	begin
		ReadMapFile:= '';
		exit();
	end;
	
	ReadingMap:= false;
	ReadMapFile:= '';
	
	Assign(fhnd, p_FileName);
	Reset(fhnd);

	while not EOF(fhnd) do
	begin
		ReadLn(fhnd, LineString);

		if Length(LineString) > 0 then
			case LineString[1] of
				'{':
				begin
					ReadingMap:= true;

					continue;
				end;

				'}':
				begin
					ReadingMap:= false;

					continue;
				end;
			end;
		
		if ReadingMap then
			ReadMapFile+= LineString + #10;
	end;
	
	Close(fhnd);
end;

begin
	Screen.SetScreenSize(GetMaxX(StdScr), GetMaxY(StdScr));
	
	Init_Pair(BCK_COLOR, COLOR_WHITE,         COLOR_BLACK);
	Init_Pair(PLR_COLOR, COLOR_BRIGHTYELLOW,  COLOR_BLACK);
	Init_Pair(WAL_COLOR, COLOR_WHITE,         COLOR_WHITE);
	Init_Pair(SPW_COLOR, COLOR_BRIGHTMAGENTA, COLOR_BLACK);
	Init_Pair(PNT_COLOR, COLOR_BRIGHTYELLOW,  COLOR_BLACK);
	Init_Pair(AMO_COLOR, COLOR_GREEN,         COLOR_BLACK);
	Init_Pair(MBX_COLOR, COLOR_RED,           COLOR_BLACK);
	Init_Pair(WTR_COLOR, COLOR_BRIGHTCYAN,    COLOR_BLUE);
	Init_Pair(PLW_COLOR, COLOR_BRIGHTYELLOW,  COLOR_BLUE);
	Init_Pair(AMW_COLOR, COLOR_GREEN,         COLOR_BLUE);
	Init_Pair(PNW_COLOR, COLOR_YELLOW,        COLOR_BLUE);
	Init_Pair(MBW_COLOR, COLOR_RED,           COLOR_BLUE);
	Init_Pair(DOR_COLOR, COLOR_GREY,          COLOR_GREY);
	Init_Pair(EXT_COLOR, COLOR_YELLOW,        COLOR_BLACK);
	Init_Pair(GRS_COLOR, COLOR_BRIGHTGREEN,   COLOR_GREEN);
	Init_Pair(PLG_COLOR, COLOR_BRIGHTYELLOW,  COLOR_GREEN);
	Init_Pair(MBG_COLOR, COLOR_BRIGHTMAGENTA, COLOR_GREEN);
	Init_Pair(MEG_COLOR, COLOR_RED,           COLOR_GREEN);
	
	SetLength(Lvls, ParamCount());

	for i:= 1 to ParamCount() do
		Lvls[i - 1]:= ReadMapFile(ParamStr(i));
		
	CurrentLvl:= 0;

	while CurrentLvl < Length(Lvls) do
	begin
		if FileExists(ParamStr(CurrentLvl + 1)) then
		begin
			Init();
			Start();
			Finish();
		end
		else
			Inc(CurrentLvl);
	end;
		
	Screen.SetColor(BCK_COLOR);
	Screen.FillScreen(' ');

	if ParamCount() = 0 then
	begin
		Screen.WriteAt(1, 1, 'Usage: app <map_file_names>');
		Screen.WriteAt(1, 2, 'Press enter to quit.');
	end
	else
		Screen.WriteAt(1, 1, 'No more maps found, press enter to quit.');

	Screen.Update();
	
	while getch <> 10 do
	begin
	end;
end.
