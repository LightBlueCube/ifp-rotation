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
	if( RandomInt( 3 ) == 0 )
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

	wait GAME_POSTMATCH_LENGTH - 0.1

	StoreStringArrayIntoConVar( "random_map_playlist", MAP_PLAYLIST )
	StoreStringArrayIntoConVar( "random_mode_playlist", MODE_PLAYLIST )
	RandomGamemode_SetPlaylistVarOverride( mode )
	GameRules_ChangeMap( map, mode )
}


// WARNING!!!! Respawn doesnt give way to clear the playlist overrides without map is mp_lobby
// so if u added a new playlistvar overrides, then u also need add this playlistvar's default value in "baseData" or other gamemodes data
table<string, table<string, int> > playlistData = {

	baseData = {
		max_players = 12
		titan_shield_regen = 1
		respawn_delay = 0
		enable_spectre_hacking = 1
	}

	aitdm = {
		scorelimit = 2147483647
		timelimit = 16
	}

	at = {
		enable_spectre_hacking = 0
		scorelimit = 2147483647
		timelimit = 16
	}

	cp = {
		scorelimit = 2147483647
		timelimit = 12
	}

	ctf = {
		respawn_delay = 0
		scorelimit = 5
		timelimit = 10
	}

	fw = {
		scorelimit = 100
		timelimit = 16
	}

	ttdm = {
		respawn_delay = 0
		scorelimit = 2147483647
		timelimit = 10
	}

}

void function RandomGamemode_SetPlaylistVarOverride( string mode )
{
	if( !( mode in playlistData ) )
		unreachable	// crash the server

	ServerCommand( "mp_gamemode "+ mode )
	ServerCommand( "setplaylist "+ mode )
	foreach( string key, int value in playlistData[ "baseData" ] )
		ServerCommand( "setplaylistvaroverrides \""+ key +"\" "+ value )
	foreach( string key, int value in playlistData[ mode ] )
		ServerCommand( "setplaylistvaroverrides \""+ key +"\" "+ value )
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
