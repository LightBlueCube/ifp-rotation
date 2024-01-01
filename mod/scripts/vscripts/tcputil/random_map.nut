global function RandomMap_Init
global function RandomGameMode
global function ShowCustomTextOnPostmatch

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

const array<string> GAMEMODES_ALL = [ "aitdm", "at", "cp", "fw", "ttdm",/* "ctf",*/ "mfd" ]

struct{
	array<string> mapPlaylist = []
	array<string> modePlaylist = []
	string customText = ""
}file

void function RandomMap_Init()
{
	file.mapPlaylist = GetStringArrayFromConVar( "random_map_playlist" )
	file.modePlaylist = GetStringArrayFromConVar( "random_mode_playlist" )
	if( file.mapPlaylist.len() == 0 && file.modePlaylist.len() == 0 )
	{
		thread RandomGameMode()
		return
	}
	AddCallback_GameStateEnter( eGameState.Postmatch, GameStateEnter_Postmatch )
}

void function ShowCustomTextOnPostmatch( string text )
{
	file.customText = text
}

void function GameStateEnter_Postmatch()
{
	thread RandomGameMode()
}

void function RandomGameMode()
{
	if( file.modePlaylist.len() == 0 )
	{
		file.modePlaylist = RandomArrayElem( GAMEMODES_ALL )
		return RandomMap( file.modePlaylist[0] )
	}

	int i = 0
	foreach( mode in file.modePlaylist )
	{
		if( GameRules_GetGameMode() == mode )
			break
		i++
	}

	if( file.modePlaylist.len() - 1 == i )
	{
		file.modePlaylist = RandomArrayElem( GAMEMODES_ALL )
		i = 0
	}
	else
		i++
	RandomMap( file.modePlaylist[i] )
}

void function RandomMap( string mode )
{
	int i = 0
	foreach( map in file.mapPlaylist )
	{
		if( GetMapName() == map )
			break
		i++
	}

	if( file.mapPlaylist.len() - 1 == i || file.mapPlaylist.len() == 0 )
	{
		file.mapPlaylist = RandomArrayElem( MAPS_ALL )
		i = 0
	}
	else
		i++

	if( mode == "fw" && !MAPS_FW.contains( file.mapPlaylist[i] ) )
	{
		int num = FindNearlyValidFWMap( i )
		if( num < i )
			i--
		string save = file.mapPlaylist[i]
		file.mapPlaylist[i] = file.mapPlaylist[num]
		file.mapPlaylist[num] = save
	}

	string map = file.mapPlaylist[i]
	foreach( player in GetPlayerArray() )
		SendHudMessageWithPriority( player, 102, "下一局模式为："+ GetModeName( mode ) +"\n下一局地图为："+ GetMapTitleName( map ) +"\n\n"+ file.customText, -1, 0.3, < 200, 200, 255 >, < 0.5, 10, 0 > )

	wait GAME_POSTMATCH_LENGTH - 0.1

	StoreStringArrayIntoConVar( file.mapPlaylist, "random_map_playlist" )
	StoreStringArrayIntoConVar( file.modePlaylist, "random_mode_playlist" )
	RandomGamemode_SetPlaylistVarOverride( mode )
	GameRules_ChangeMap( map, mode )
}


// WARNING!!!! Respawn doesnt give way to clear the playlist overrides without map is mp_lobby
// so if u added a new playlistvar overrides, then u also need add this playlistvar's default value in "baseData" or other gamemodes data
const table<string, table<string, string> > PLAYLIST_OVERRIDES = {

	baseData = {
		max_players = "12"
		titan_shield_regen = "1"
		earn_meter_pilot_multiplier = "1"
		respawn_delay = "0"
		enable_spectre_hacking = "1"
	}

	aitdm = {
		scorelimit = "2147483647"
		timelimit = "16"
	}

	at = {
		enable_spectre_hacking = "0"
		scorelimit = "10000"
		timelimit = "16"
	}

	cp = {
		scorelimit = "2147483647"
		timelimit = "12"
	}

	fw = {
		scorelimit = "100"
		timelimit = "16"
	}

	ttdm = {
		respawn_delay = "0"
		scorelimit = "2147483647"
		timelimit = "10"
	}

	ctf = {
		earn_meter_pilot_multiplier = "2"
		respawn_delay = "0"
		scorelimit = "5"
		timelimit = "10"
	}

	mfd = {
		scorelimit = "16"
		timelimit = "12"
	}
}

void function RandomGamemode_SetPlaylistVarOverride( string mode )
{
	if( !( mode in PLAYLIST_OVERRIDES ) )
		unreachable	// crash the server

	ServerCommand( "mp_gamemode "+ mode )
	ServerCommand( "setplaylist "+ mode )
	foreach( string key, string value in PLAYLIST_OVERRIDES[ "baseData" ] )
		ServerCommand( "setplaylistvaroverrides \""+ key +"\" "+ value )
	foreach( string key, string value in PLAYLIST_OVERRIDES[ mode ] )
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
		case "fw":
			return "邊境戰爭"
		case "ttdm":
			return "泰坦爭鬥"
		case "ctf":
			return "奪旗"
		case "mfd":
			return "獵殺標記"
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
	while( i < file.mapPlaylist.len() )
	{
		if( MAPS_FW.contains( file.mapPlaylist[i] ) )
			return i
		i++
	}
	return FindNearlyValidFWMap( 0 )
}

array<string> function RandomArrayElem( array<string> a )
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