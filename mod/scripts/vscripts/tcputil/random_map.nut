global function RandomMap_Init
global function RandomGameMode

const array<string> MAPS_ALL = [
	"mp_black_water_canal",
	"mp_complex3",
	"mp_crashsite3",
	"mp_drydock",
	"mp_eden",
	"mp_forwardbase_kodai",
	"mp_grave",
	"mp_homestead",
	"mp_thaw",
	"mp_angel_city",
	"mp_colony02",
	"mp_relic02",
	"mp_wargames",
	"mp_glitch",
	"mp_rise" ]

const array<string> MAPS_FW = [
	"mp_forwardbase_kodai",
	"mp_grave",
	"mp_homestead",
	"mp_thaw",
	"mp_eden",
	"mp_crashsite3",
	"mp_complex3" ]

const array<string> GAMEMODES_ALL = [ "aitdm", "at", "cp", "ctf", "fw", "ttdm" ]

array<string> MAP_PLAYLIST = []
array<string> MODE_PLAYLIST = []

void function RandomMap_Init()
{
	MAP_PLAYLIST = GetStringArrayFromConVar( "random_map_playlist" )
	MODE_PLAYLIST = GetStringArrayFromConVar( "random_mode_playlist" )
	if( MAP_PLAYLIST.len() == 0 && MODE_PLAYLIST.len() == 0 )
	{
		thread RandomGameMode()
		return
	}
	AddCallback_GameStateEnter( eGameState.Postmatch, GameStateEnter_Postmatch )
	if( [ "mp_rise", "mp_eden" ].contains( GetMapName() ) || RandomInt( 3 ) == 0 )
		AddCallback_OnClientConnected( OnClientConnected )
}

void function OnClientConnected( entity player )
{
    thread SetPlayerToNightSky( player )
}

void function GameStateEnter_Postmatch()
{
	thread RandomGameMode()
}
void function RandomGameMode()
{
	if( MODE_PLAYLIST.len() == 0 )
	{
		MODE_PLAYLIST = GetRandomArrayElem( GAMEMODES_ALL )
		return RandMap( MODE_PLAYLIST[0] )
	}

	int i = 0
	foreach( mode in MODE_PLAYLIST )
	{
		if( GameRules_GetGameMode() == mode )
			break
		i++
	}

	if( MODE_PLAYLIST.len() - 1 == i )
	{
		MODE_PLAYLIST = GetRandomArrayElem( GAMEMODES_ALL )
		i = 0
	}
	else
		i++
	RandMap( MODE_PLAYLIST[i] )
}

void function RandMap( string mode )
{
	int i = 0
	foreach( map in MAP_PLAYLIST )
	{
		if( GetMapName() == map )
			break
		i++
	}


	if( MAP_PLAYLIST.len() - 1 == i || MAP_PLAYLIST.len() == 0 )
	{
		MAP_PLAYLIST = GetRandomArrayElem( MAPS_ALL )
		i = 0
	}
	else
		i++

	if( mode == "fw" && !MAPS_FW.contains( MAP_PLAYLIST[i] ) )
	{
		string save = MAP_PLAYLIST[i]
		int num = FindNearlyValidFWMap( i )
		MAP_PLAYLIST[i] = MAP_PLAYLIST[num]
		MAP_PLAYLIST[num] = save
	}

	string map = MAP_PLAYLIST[i]
	SendHudMessageToAll( "下一局模式为："+ GetModeName( mode ) +"\n下一局地图为："+ GetMapTitleName( map ) +"\n\n如果你发现了任何bug（或疑似）\n请务必反馈给我！这很重要！", -1, 0.3, 200, 200, 255, 0, 0.5, 10, 0 )

	StoreStringArrayIntoConVar( "random_map_playlist", MAP_PLAYLIST )
	StoreStringArrayIntoConVar( "random_mode_playlist", MODE_PLAYLIST )

	wait GAME_POSTMATCH_LENGTH - 0.1

	RandomGamemode_SetPlaylistVarOverride( mode )
	GameRules_ChangeMap( map, mode )
}

// utils shared //

void function RandomGamemode_SetPlaylistVarOverride( string mode )
{
	ServerCommand( "mp_gamemode "+ mode )
	ServerCommand( "setplaylist "+ mode )

	if( mode == "aitdm" )
	{
		ServerCommand( "setplaylistvaroverrides \"scorelimit\" 2147483647" )
		ServerCommand( "setplaylistvaroverrides \"timelimit\" 18" )
	}
	if( mode == "at" )
	{
		ServerCommand( "setplaylistvaroverrides \"scorelimit\" 2147483647" )
		ServerCommand( "setplaylistvaroverrides \"timelimit\" 16" )
	}
	if( mode == "cp" )
	{
		ServerCommand( "setplaylistvaroverrides \"scorelimit\" 2147483647" )
		ServerCommand( "setplaylistvaroverrides \"timelimit\" 12" )
	}
	if( mode == "ctf" )
	{
		ServerCommand( "setplaylistvaroverrides \"respawn_delay\" 0" )
		ServerCommand( "setplaylistvaroverrides \"scorelimit\" 5" )
		ServerCommand( "setplaylistvaroverrides \"timelimit\" 10" )
	}
	if( mode == "fw" )
	{
		ServerCommand( "setplaylistvaroverrides \"scorelimit\" 100" )
		ServerCommand( "setplaylistvaroverrides \"timelimit\" 16" )
	}
	if( mode == "ttdm" )
	{
		ServerCommand( "setplaylistvaroverrides \"respawn_delay\" 0" )
		ServerCommand( "setplaylistvaroverrides \"scorelimit\" 2147483647" )
		ServerCommand( "setplaylistvaroverrides \"timelimit\" 10" )
	}
	if( mode == "lts" )
	{
		ServerCommand( "setplaylistvaroverrides \"scorelimit\" 0" )
		ServerCommand( "setplaylistvaroverrides \"timelimit\" 3" )
	}
}

string function GetModeName( string mode )
{
	switch( mode )
	{
		case "aitdm":
			return "消耗戰"
		case "at":
			return "賞金追緝"
		case "cp":
			return "強化據點"
		case "ctf":
			return "奪旗"
		case "fw":
			return "邊境戰爭"
		case "ttdm":
			return "泰坦爭鬥"
	}
	return "UNKNOWN"
}

string function GetMapTitleName( string map )
{
	switch( map )
	{
		case "mp_black_water_canal":
			return "黑水運河"
		case "mp_angel_city":
			return "天使城"
		case "mp_drydock":
			return "乾塢"
		case "mp_eden":
			return "伊甸"
		case "mp_colony02":
			return "殖民地"
		case "mp_relic02":
			return "遺跡"
		case "mp_grave":
			return "新興城鎮"
		case "mp_thaw":
			return "係外行星"
		case "mp_glitch":
			return "異常"
		case "mp_homestead":
			return "家園"
        case "mp_wargames":
			return "戰爭游戲"
        case "mp_forwardbase_kodai":
            return "虎大前進基地"
		case "mp_complex3":
			return "綜合設施"
		case "mp_rise":
			return "崛起"
		case "mp_crashsite3":
			return "墜機現場"
	}
	return "UNKNOWN"
}

int function FindNearlyValidFWMap( int start )
{
	int i = start
	while( i < MAP_PLAYLIST.len() )
	{
		if( MAPS_FW.contains( MAP_PLAYLIST[i] ) )
			return i
		i++
	}
	return FindNearlyValidFWMap( 0 )
}

array<string> function GetRandomArrayElem( array<string> a )
{
	array<string> b = a
	array<string> c = []
	while( b.len() > 0 )
	{
		string randElem = b[ RandomInt( b.len() ) ]
		b.removebyvalue( randElem )
		c.append( randElem )
	}
	return c
}

array<string> function GetStringArrayFromConVar( string convar )
{
    return split( GetConVarString( convar ), "," )
}

// 用于更新整个ConVar数组
string function StoreStringArrayIntoConVar( string convar, array<string> arrayToStore )
{
    string builtString = ""
    foreach ( string item in arrayToStore )
    {
        if ( builtString == "" ) // 第一个元素，不添加逗号
            builtString = item
        else // 后续元素，在开头添加一个逗号用来分隔，通过GetStringArrayFromConVar()可以将其转化为数组
            builtString += "," + item
    }

    // 更新ConVar
    SetConVarString( convar, builtString )
    // 返回构造好的字符串
    return builtString
}
