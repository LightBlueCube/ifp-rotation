untyped

global function GamemodeCP_Init
global function RateSpawnpoints_CP
global function DEV_PrintHardpointsInfo

// needed for sh_gamemode_cp_dialogue
global array<entity> HARDPOINTS

struct HardpointStruct
{
	entity hardpoint
	entity trigger
	entity prop

	array<entity> imcCappers
	array<entity> militiaCappers
}

struct CP_PlayerStruct
{
	entity player
	bool isOnHardpoint
	array<float> timeOnPoints //floats sorted same as in hardpoints array not by ID
}

struct {
	bool ampingEnabled = true

	array<HardpointStruct> hardpoints
	array<CP_PlayerStruct> players
	table<entity,int> playerAssaultPoints
	table<entity,int> playerDefensePoints
} file

void function GamemodeCP_Init()
{
	file.ampingEnabled = GetCurrentPlaylistVarInt( "cp_amped_capture_points", 1 ) == 1

	RegisterSignal( "HardpointCaptureStart" )
	ScoreEvent_SetupEarnMeterValuesForMixedModes()
	CapturePointScoreEventSetUp()

	AddCallback_OnPlayerKilled(GamemodeCP_OnPlayerKilled)
	AddCallback_EntitiesDidLoad( SpawnHardpoints )
	AddCallback_GameStateEnter( eGameState.Playing, StartHardpointThink )
	AddCallback_OnClientConnected(GamemodeCP_InitPlayer)
	AddCallback_OnClientDisconnected(GamemodeCP_RemovePlayer)

	AddCallback_OnLastMinute( OnLastMinute )
	AddCallback_GameStateEnter( eGameState.Prematch, OnPrematchStart )
	AiGameModes_SetNPCWeapons( "npc_soldier", [ "mp_weapon_rspn101", "mp_weapon_dmr", "mp_weapon_r97", "mp_weapon_lmg", "mp_weapon_rocket_launcher", "mp_weapon_defender" ] )
	AiGameModes_SetNPCWeapons( "npc_spectre", [ "mp_weapon_hemlok_smg", "mp_weapon_doubletake", "mp_weapon_mastiff", "mp_weapon_rocket_launcher", "mp_weapon_mgl" ] )
	AiGameModes_SetNPCWeapons( "npc_stalker", [ "mp_weapon_hemlok_smg", "mp_weapon_lstar", "mp_weapon_mastiff", "mp_weapon_defender", "mp_weapon_mgl" ] )
	AITdm_SetSquadsPerTeam( 3 )
	AITdm_SetReapersPerTeam( 1 )

	// tempfix specifics
	SetShouldPlayDefaultMusic( true ) // play music when score or time reaches some point
	EarnMeterMP_SetPassiveGainProgessEnable( true ) // enable earnmeter gain progressing like vanilla
}

//added aispawn in cp! ttf1 like!
void function OnPrematchStart()
{
	// don't run spawning code if ains and nms aren't up to date
	if ( GetAINScriptVersion() == AIN_REV && GetNodeCount() != 0 )
	{
		thread SpawnIntroBatch_Threaded( TEAM_MILITIA )
		thread SpawnIntroBatch_Threaded( TEAM_IMC )
	}

	// Starts skyshow, this also requiers AINs but doesn't crash if they're missing
	if ( !Flag( "LevelHasRoof" ) )
		thread StratonHornetDogfightsIntense()
}

void function OnLastMinute()
{
	int teamScoreAddition = abs( GameRules_GetTeamScore( TEAM_MILITIA ) - GameRules_GetTeamScore( TEAM_IMC ) ) / 100 + 2
	SetTeamScoreAddition( teamScoreAddition )
	foreach( player in GetPlayerArray() )
	{
		if( !IsValid( player ) )
			continue
		RUIQueue_NSSendAnnouncementMessageToPlayer( player, teamScoreAddition +"倍分數獲取！", "最後1分鐘！", < 50, 50, 225 >, 255, 6 )
	}
}

void function CapturePointScoreEventSetUp()
{
	// override settings
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.10, 0.10 )

	// ampHP specific
	ScoreEvent_SetEarnMeterValues( "ControlPointCapture", 0.2, 0.1 )
	ScoreEvent_SetEarnMeterValues( "ControlPointHold", 0.08, 0.020001 )
	ScoreEvent_SetEarnMeterValues( "ControlPointAmped",0.2, 0.1 )
	ScoreEvent_SetEarnMeterValues( "ControlPointAmpedHold", 0.08, 0.020001 )

	ScoreEvent_SetEarnMeterValues( "HardpointAssault", 0.1, 0.05 )
	ScoreEvent_SetEarnMeterValues( "HardpointDefense", 0.1, 0.05 )
	ScoreEvent_SetEarnMeterValues( "HardpointPerimeterDefense", 0.1, 0.05 )
	ScoreEvent_SetEarnMeterValues( "HardpointSiege", 0.1, 0.05 )
	ScoreEvent_SetEarnMeterValues( "HardpointSnipe", 0.1, 0.05 )

	// modify override settings
	// player-controlled stuff
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.30, 0.10 )
	ScoreEvent_SetEarnMeterValues( "EliminatePilot", 0.30, 0.05 )
	ScoreEvent_SetEarnMeterValues( "PilotAssist", 0.3, 0.020001, 0.0 ) // if set to "0.03, 0.02", will display as "4%"
	ScoreEvent_SetEarnMeterValues( "KillTitan", 0.3, 0.10, 0.0 )
	ScoreEvent_SetEarnMeterValues( "PilotBatteryStolen", 0.0, 0.10 ) // this actually just doesn't have overdrive in vanilla even
	ScoreEvent_SetEarnMeterValues( "FirstStrike", 0.3, 0.020001, 0.0 ) // if set to "0.03, 0.02", will display as "4%"

	// ai
	ScoreEvent_SetEarnMeterValues( "KillGrunt", 0.13, 0.020001, 0.5 )
	ScoreEvent_SetEarnMeterValues( "KillSpectre", 0.13, 0.020001, 0.5 )
	ScoreEvent_SetEarnMeterValues( "LeechSpectre", 0.13, 0.020001 )
	ScoreEvent_SetEarnMeterValues( "KillStalker", 0.13, 0.020001, 0.5 )
	ScoreEvent_SetEarnMeterValues( "KillSuperSpectre", 0.2, 0.1, 0.5 )

	// display type
	// default case is adding a eEventDisplayType.CENTER, required for client to show earnvalue on screen
	ScoreEvent_SetEventDisplayTypes( "ControlPointCapture", GetScoreEvent( "ControlPointCapture" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "ControlPointHold", GetScoreEvent( "ControlPointHold" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "ControlPointAmped", GetScoreEvent( "ControlPointAmped" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "ControlPointAmpedHold", GetScoreEvent( "ControlPointAmpedHold" ).displayType | eEventDisplayType.CENTER )

	ScoreEvent_SetEventDisplayTypes( "HardpointAssault", GetScoreEvent( "HardpointAssault" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "HardpointDefense", GetScoreEvent( "HardpointDefense" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "HardpointPerimeterDefense", GetScoreEvent( "HardpointPerimeterDefense" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "HardpointSiege", GetScoreEvent( "HardpointSiege" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "HardpointSnipe", GetScoreEvent( "HardpointSnipe" ).displayType | eEventDisplayType.CENTER )
}

void function GamemodeCP_OnPlayerKilled(entity victim, entity attacker, var damageInfo)
{
	HardpointStruct attackerCP
	HardpointStruct victimCP
	CP_PlayerStruct victimStruct
	if(!attacker.IsPlayer())
		return

	//hardpoint forever capped mitigation

	foreach(CP_PlayerStruct p in file.players)
		if(p.player==victim)
			victimStruct=p

	foreach(HardpointStruct hardpoint in file.hardpoints)
	{
		if(hardpoint.imcCappers.contains(victim))
		{
			victimCP = hardpoint
			thread removePlayerFromCapperArray_threaded(hardpoint.imcCappers,victim)
		}

		if(hardpoint.militiaCappers.contains(victim))
		{
			victimCP = hardpoint
			thread removePlayerFromCapperArray_threaded(hardpoint.militiaCappers,victim)
		}

		if(hardpoint.imcCappers.contains(attacker))
			attackerCP = hardpoint
		if(hardpoint.militiaCappers.contains(attacker))
			attackerCP = hardpoint

	}
	if(victimStruct.isOnHardpoint)
		victimStruct.isOnHardpoint = false

	//prevent medals form suicide
	if(attacker==victim)
		return

	if((victimCP.hardpoint!=null)&&(attackerCP.hardpoint!=null))
	{
		if(victimCP==attackerCP)
		{
			if(victimCP.hardpoint.GetTeam()==attacker.GetTeam())
			{
				AddPlayerScore( attacker , "HardpointDefense", victim )
				attacker.AddToPlayerGameStat(PGS_DEFENSE_SCORE,POINTVALUE_HARDPOINT_DEFENSE)
				UpdatePlayerScoreForChallenge(attacker,0,POINTVALUE_HARDPOINT_DEFENSE)
			}
			else if((victimCP.hardpoint.GetTeam()==victim.GetTeam())||(GetHardpointCappingTeam(victimCP)==victim.GetTeam()))
			{
				AddPlayerScore( attacker, "HardpointAssault", victim )
				attacker.AddToPlayerGameStat(PGS_ASSAULT_SCORE,POINTVALUE_HARDPOINT_ASSAULT)
				UpdatePlayerScoreForChallenge(attacker,POINTVALUE_HARDPOINT_ASSAULT,0)
			}
		}
	}
	else if((victimCP.hardpoint!=null))//siege or snipe
	{

		if(Distance(victim.GetOrigin(),attacker.GetOrigin())>=HARDPOINT_RANGED_ASSAULT_DIST)//1875 inches(units) are 47.625 meters
		{
			AddPlayerScore( attacker , "HardpointSnipe", victim )
			attacker.AddToPlayerGameStat(PGS_ASSAULT_SCORE,POINTVALUE_HARDPOINT_SNIPE)
			UpdatePlayerScoreForChallenge(attacker,POINTVALUE_HARDPOINT_SNIPE,0)
		}
		else{
			AddPlayerScore( attacker , "HardpointSiege", victim )
			attacker.AddToPlayerGameStat(PGS_ASSAULT_SCORE,POINTVALUE_HARDPOINT_SIEGE)
			UpdatePlayerScoreForChallenge(attacker,POINTVALUE_HARDPOINT_SIEGE,0)
		}
	}
	else if(attackerCP.hardpoint!=null)//Perimeter Defense
	{
		if(attackerCP.hardpoint.GetTeam()==attacker.GetTeam())
		{
			AddPlayerScore( attacker , "HardpointPerimeterDefense", victim)
			attacker.AddToPlayerGameStat(PGS_DEFENSE_SCORE,POINTVALUE_HARDPOINT_PERIMETER_DEFENSE)
			UpdatePlayerScoreForChallenge(attacker,0,POINTVALUE_HARDPOINT_PERIMETER_DEFENSE)
		}
	}

	foreach(CP_PlayerStruct player in file.players) //Reset Victim Holdtime Counter
	{
		if(player.player == victim)
			player.timeOnPoints = [0.0,0.0,0.0]
	}
}

void function removePlayerFromCapperArray_threaded(array<entity> capperArray,entity player)
{
	WaitFrame()
	FindAndRemove(capperArray,player)

}

void function RateSpawnpoints_CP( int checkClass, array<entity> spawnpoints, int team, entity player )
{
	if ( IsSwitchSidesBased() && HasSwitchedSides() == 1 )
		team = GetOtherTeam( team )

	// check hardpoints, determine which ones we own
	array<entity> startSpawns = SpawnPoints_GetPilotStart( team )
	vector averageFriendlySpawns

	// average out startspawn positions
	foreach ( entity spawnpoint in startSpawns )
		averageFriendlySpawns += spawnpoint.GetOrigin()

	averageFriendlySpawns /= startSpawns.len()

	entity friendlyHardpoint // determine our furthest out hardpoint
	foreach ( entity hardpoint in HARDPOINTS )
	{
		if ( hardpoint.GetTeam() == player.GetTeam() && GetGlobalNetFloat( "objective" + GetHardpointGroup(hardpoint) + "Progress" ) >= 0.95 )
		{
			if ( IsValid( friendlyHardpoint ) )
			{
				if ( Distance2D( averageFriendlySpawns, hardpoint.GetOrigin() ) > Distance2D( averageFriendlySpawns, friendlyHardpoint.GetOrigin() ) )
					friendlyHardpoint = hardpoint
			}
			else
				friendlyHardpoint = hardpoint
		}
	}

	vector ratingPos
	if ( IsValid( friendlyHardpoint ) )
		ratingPos = friendlyHardpoint.GetOrigin()
	else
		ratingPos = averageFriendlySpawns

	foreach ( entity spawnpoint in spawnpoints )
	{
		// idk about magic number here really
		float rating = 1.0 - ( Distance2D( spawnpoint.GetOrigin(), ratingPos ) / 1000.0 )
		spawnpoint.CalculateRating( checkClass, player.GetTeam(), rating, rating )
	}
}

void function SpawnHardpoints()
{
	foreach ( entity spawnpoint in GetEntArrayByClass_Expensive( "info_hardpoint" ) )
	{
		if ( GameModeRemove( spawnpoint ) )
			continue

		// spawnpoints are CHardPoint entities
		// init the hardpoint ent
		int hardpointID = 0
		string group = GetHardpointGroup(spawnpoint)
			if ( group == "B" )
				hardpointID = 1
			else if ( group == "C" )
				hardpointID = 2

		spawnpoint.SetHardpointID( hardpointID )
		SpawnHardpointMinimapIcon( spawnpoint )

		HardpointStruct hardpointStruct
		hardpointStruct.hardpoint = spawnpoint
		hardpointStruct.prop = CreatePropDynamic( spawnpoint.GetModelName(), spawnpoint.GetOrigin(), spawnpoint.GetAngles(), 6 )
		thread PlayAnim( hardpointStruct.prop, "mh_inactive_idle" )

		entity trigger = GetEnt( expect string( spawnpoint.kv.triggerTarget ) )
		hardpointStruct.trigger = trigger

		file.hardpoints.append( hardpointStruct )
		HARDPOINTS.append( spawnpoint ) // for vo script
		spawnpoint.s.trigger <- trigger // also for vo script

		SetGlobalNetEnt( "objective" + group + "Ent", spawnpoint )

		// set up trigger functions
		trigger.SetEnterCallback( OnHardpointEntered )
		trigger.SetLeaveCallback( OnHardpointLeft )
	}
}

void function SpawnHardpointMinimapIcon( entity spawnpoint )
{
	// map hardpoint id to eMinimapObject_info_hardpoint enum id
	int miniMapObjectHardpoint = spawnpoint.GetHardpointID() + 1

	spawnpoint.Minimap_SetCustomState( miniMapObjectHardpoint )
	spawnpoint.Minimap_AlwaysShow( TEAM_MILITIA, null )
	spawnpoint.Minimap_AlwaysShow( TEAM_IMC, null )
	spawnpoint.Minimap_SetAlignUpright( true )

	SetTeam( spawnpoint, TEAM_UNASSIGNED )
}

// functions for handling hardpoint netvars
void function SetHardpointState( HardpointStruct hardpoint, int state )
{
	SetGlobalNetInt( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "State", state )
	hardpoint.hardpoint.SetHardpointState( state )
}

int function GetHardpointState( HardpointStruct hardpoint )
{
	return GetGlobalNetInt( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "State" )
}

void function SetHardpointCappingTeam( HardpointStruct hardpoint, int team )
{
	SetGlobalNetInt( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "CappingTeam", team )
}

int function GetHardpointCappingTeam( HardpointStruct hardpoint )
{
	return GetGlobalNetInt( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "CappingTeam" )
}

void function SetHardpointCaptureProgress( HardpointStruct hardpoint, float progress )
{
	SetGlobalNetFloat( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "Progress", progress )
}

float function GetHardpointCaptureProgress( HardpointStruct hardpoint )
{
	return GetGlobalNetFloat( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "Progress" )
}


void function StartHardpointThink()
{
	thread TrackChevronStates()

	foreach ( HardpointStruct hardpoint in file.hardpoints )
		thread HardpointThink( hardpoint )
}

void function CapturePointForTeam(HardpointStruct hardpoint, int Team)
{
	SetHardpointState(hardpoint,CAPTURE_POINT_STATE_CAPTURED)
	SetTeam( hardpoint.hardpoint, Team )
	SetTeam( hardpoint.prop, Team )
	EmitSoundOnEntityToTeam( hardpoint.hardpoint, "hardpoint_console_captured", Team )
	GamemodeCP_VO_Captured( hardpoint.hardpoint )

	array<entity> allCappers
	allCappers.extend(hardpoint.militiaCappers)
	allCappers.extend(hardpoint.imcCappers)

	foreach(entity player in allCappers)
	{
		if ( IsValid( player ) )
		{
			if( player.IsPlayer() )
			{
				AddPlayerScore( player,"ControlPointCapture", player )
				player.AddToPlayerGameStat(PGS_ASSAULT_SCORE,POINTVALUE_HARDPOINT_CAPTURE)
				UpdatePlayerScoreForChallenge(player,POINTVALUE_HARDPOINT_CAPTURE,0)
			}
		}
	}
}

void function NeturalizeHardPoint( HardpointStruct hardpoint )
{
	EmitSoundOnEntityToTeam( hardpoint.hardpoint, "hardpoint_console_nuetral", GetOtherTeam( hardpoint.hardpoint.GetTeam() ) )
	SetHardpointState( hardpoint,CAPTURE_POINT_STATE_UNASSIGNED )
	SetTeam( hardpoint.hardpoint, TEAM_UNASSIGNED )
	SetTeam( hardpoint.prop, TEAM_UNASSIGNED )

}

void function GamemodeCP_InitPlayer(entity player)
{
	CP_PlayerStruct playerStruct
	playerStruct.player = player
	playerStruct.timeOnPoints = [0.0,0.0,0.0]
	playerStruct.isOnHardpoint = false
	file.players.append(playerStruct)
	file.playerAssaultPoints[player] <- 0
	file.playerDefensePoints[player] <- 0
	thread PlayerThink(playerStruct)
}

void function GamemodeCP_RemovePlayer(entity player)
{
	foreach(index,CP_PlayerStruct playerStruct in file.players)
	{
		if(playerStruct.player==player)
			file.players.remove(index)
	}
	if(player in file.playerAssaultPoints)
		delete file.playerAssaultPoints[player]
	if(player in file.playerDefensePoints)
		delete file.playerDefensePoints[player]
}

void function PlayerThink(CP_PlayerStruct player)
{

	if(!IsValid(player.player))
		return

	if(!player.player.IsPlayer())
		return

	while(!GamePlayingOrSuddenDeath())
		WaitFrame()

	float lastTime = Time()
	WaitFrame()

	while(GamePlayingOrSuddenDeath()&&IsValid(player.player))
	{
		float currentTime = Time()
		float deltaTime = currentTime - lastTime

		if(player.isOnHardpoint)
		{
			bool hardpointBelongsToPlayerTeam = false

			foreach(index,HardpointStruct hardpoint in file.hardpoints)
			{
				if(GetHardpointState(hardpoint)>=CAPTURE_POINT_STATE_CAPTURED)
				{
					if((hardpoint.hardpoint.GetTeam()==TEAM_MILITIA)&&(hardpoint.militiaCappers.contains(player.player)))
						hardpointBelongsToPlayerTeam = true

					if((hardpoint.hardpoint.GetTeam()==TEAM_IMC)&&(hardpoint.imcCappers.contains(player.player)))
						hardpointBelongsToPlayerTeam = true
				}
				if(hardpointBelongsToPlayerTeam)
				{
					player.timeOnPoints[index] += deltaTime
					if(player.timeOnPoints[index]>=10)
					{
						player.timeOnPoints[index] -= 10
						if(GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_AMPED)
						{
							AddPlayerScore(player.player,"ControlPointAmpedHold", player.player)
							player.player.AddToPlayerGameStat( PGS_DEFENSE_SCORE, POINTVALUE_HARDPOINT_AMPED_HOLD )
							UpdatePlayerScoreForChallenge(player.player,0,POINTVALUE_HARDPOINT_AMPED_HOLD)
						}
						else
						{
							AddPlayerScore(player.player,"ControlPointHold", player.player)
							player.player.AddToPlayerGameStat( PGS_DEFENSE_SCORE, POINTVALUE_HARDPOINT_HOLD )
							UpdatePlayerScoreForChallenge(player.player,0,POINTVALUE_HARDPOINT_HOLD)
						}
					}
					break
				}
			}
		}
		lastTime = currentTime
		WaitFrame()
	}
}

void function SetCapperAmount( table<int, table<string, int> > capStrength, array<entity> entities )
{
	foreach(entity p in entities)
	{
		if( IsValid( p ) )
		{
			if ( p.IsPlayer() && p.IsTitan() )
			{
				capStrength[p.GetTeam()]["titans"] += 1
			}
			else if ( p.IsPlayer() )
			{
				capStrength[p.GetTeam()]["pilots"] += 1
			}
		}
	}
}

void function HardpointThink( HardpointStruct hardpoint )
{
	entity hardpointEnt = hardpoint.hardpoint
	//int hardpointEHandle = hardpointEnt.GetEncodedEHandle()

	float lastTime = Time()
	float lastScoreTime = Time()
	bool hasBeenAmped = false

	// for maps like complex3, if running classicMPNoIntro it won't start capping
	// reassign cappers already in trigger before game starts
	foreach ( HardpointStruct hardpointStruct in file.hardpoints )
	{
		array<entity> touchingEnts = GetAllEntitiesInTrigger( hardpointStruct.trigger )
		// run the enter function for them
		foreach( entity ent in touchingEnts )
			OnHardpointEntered( hardpointStruct.trigger, ent )
	}

	EmitSoundOnEntity( hardpointEnt, "hardpoint_console_idle" )

	WaitFrame() // wait a frame so deltaTime is never zero

	while ( GamePlayingOrSuddenDeath() )
	{
		table<int, table<string, int> > capStrength = {
			[TEAM_IMC] = {
				pilots = 0,
				titans = 0,
			},
			[TEAM_MILITIA] = {
				pilots = 0,
				titans = 0,
			}
		}

		float currentTime = Time()
		float deltaTime = currentTime - lastTime

		SetCapperAmount( capStrength, hardpoint.militiaCappers )
		SetCapperAmount( capStrength, hardpoint.imcCappers )

		int imcPilotCappers = capStrength[TEAM_IMC]["pilots"]
		int imcTitanCappers = capStrength[TEAM_IMC]["titans"]

		int militiaPilotCappers = capStrength[TEAM_MILITIA]["pilots"]
		int militiaTitanCappers = capStrength[TEAM_MILITIA]["titans"]

		int imcCappers = ( imcTitanCappers + militiaTitanCappers ) > 0 ? imcTitanCappers : imcPilotCappers
		int militiaCappers = ( imcTitanCappers + militiaTitanCappers ) <= 0 ? militiaPilotCappers : militiaTitanCappers

		int cappingTeam
		int capperAmount = 0
		bool hardpointBlocked = false

		if((imcCappers > 0) && (militiaCappers > 0))
		{
			hardpointBlocked = true
		}
		else if ( imcCappers > 0 )
		{
			cappingTeam = TEAM_IMC
			capperAmount = imcCappers
		}
		else if ( militiaCappers > 0 )
		{
			cappingTeam = TEAM_MILITIA
			capperAmount = militiaCappers
		}
		capperAmount = minint(capperAmount, 3)

		if(hardpointBlocked)
		{
			SetHardpointState(hardpoint,CAPTURE_POINT_STATE_HALTED)
		}
		else if(cappingTeam==TEAM_UNASSIGNED) // nobody on point
		{
			// messed up, not using now
			//if((GetHardpointState(hardpoint)>=CAPTURE_POINT_STATE_AMPED) || (GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_SELF_UNAMPING))
			//{
			//	if (GetHardpointState(hardpoint) == CAPTURE_POINT_STATE_AMPED)
			//		SetHardpointState(hardpoint,CAPTURE_POINT_STATE_SELF_UNAMPING) // plays a pulsating effect on the UI only when the hardpoint is amped
			//}
			// modified to fit self_unamping icon
			// the "8" will work for proper hints however
			//if((GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_AMPED)||(GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_AMPING)||(GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_SELF_UNAMPING)||(GetHardpointState(hardpoint)==8))
			if((GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_AMPED)||(GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_AMPING))
			{
				SetHardpointCappingTeam(hardpoint,hardpointEnt.GetTeam())
				SetHardpointCaptureProgress(hardpoint,max(1.0,GetHardpointCaptureProgress(hardpoint)-(deltaTime/HARDPOINT_AMPED_DELAY)))
				if(GetHardpointCaptureProgress(hardpoint)<=1.001) // unamp
				{
					if (GetHardpointState(hardpoint) == CAPTURE_POINT_STATE_AMPED) // only play 2inactive animation if we were amped
						thread PlayAnim( hardpoint.prop, "mh_active_2_inactive" )
					SetHardpointState(hardpoint,CAPTURE_POINT_STATE_CAPTURED)
				}
			}
			if(GetHardpointState(hardpoint)>=CAPTURE_POINT_STATE_CAPTURED)
				SetHardpointCappingTeam(hardpoint,TEAM_UNASSIGNED)
		}
		else if(hardpointEnt.GetTeam()==TEAM_UNASSIGNED) // uncapped point
		{
			if(GetHardpointCappingTeam(hardpoint)==TEAM_UNASSIGNED) // uncapped point with no one inside
			{
				SetHardpointCaptureProgress( hardpoint, min(1.0,GetHardpointCaptureProgress( hardpoint ) + ( deltaTime / CAPTURE_DURATION_CAPTURE * capperAmount) ) )
				SetHardpointCappingTeam(hardpoint,cappingTeam)
				if(GetHardpointCaptureProgress(hardpoint)>=1.0)
				{
					CapturePointForTeam(hardpoint,cappingTeam)
					hasBeenAmped = false
				}
			}
			else if(GetHardpointCappingTeam(hardpoint)==cappingTeam) // uncapped point with ally inside
			{
				SetHardpointCaptureProgress( hardpoint,min(1.0, GetHardpointCaptureProgress( hardpoint ) + ( deltaTime / CAPTURE_DURATION_CAPTURE * capperAmount) ) )
				if(GetHardpointCaptureProgress(hardpoint)>=1.0)
				{
					CapturePointForTeam(hardpoint,cappingTeam)
					hasBeenAmped = false
				}
			}
			else // uncapped point with enemy inside
			{
				SetHardpointCaptureProgress( hardpoint,max(0.0, GetHardpointCaptureProgress( hardpoint ) - ( deltaTime / CAPTURE_DURATION_CAPTURE * capperAmount) ) )
				if(GetHardpointCaptureProgress(hardpoint)==0.0)
				{
					SetHardpointCappingTeam(hardpoint,cappingTeam)
					if(GetHardpointCaptureProgress(hardpoint)>=1)
					{
						CapturePointForTeam(hardpoint,cappingTeam)
						hasBeenAmped = false
					}
				}
			}
		}
		else if(hardpointEnt.GetTeam()!=cappingTeam) // capping enemy point
		{
			SetHardpointCappingTeam(hardpoint,cappingTeam)
			SetHardpointCaptureProgress( hardpoint,max(0.0, GetHardpointCaptureProgress( hardpoint ) - ( deltaTime / CAPTURE_DURATION_CAPTURE * capperAmount) ) )
			if(GetHardpointCaptureProgress(hardpoint)<=1.0)
			{
				if (GetHardpointState(hardpoint) == CAPTURE_POINT_STATE_AMPED) // only play 2inactive animation if we were amped
					thread PlayAnim( hardpoint.prop, "mh_active_2_inactive" )
				SetHardpointState(hardpoint,CAPTURE_POINT_STATE_CAPTURED) // unamp
			}
			// there should be a neturality between capping
			//if(GetHardpointCaptureProgress(hardpoint)<=0.0)
			//{
			//	SetHardpointCaptureProgress(hardpoint,1.0)
			//	CapturePointForTeam(hardpoint,cappingTeam)
			//	hasBeenAmped = false
			//}
			if(GetHardpointCaptureProgress(hardpoint)<=0.0) // neutralize
			{
				SetHardpointCaptureProgress(hardpoint,0.0)
				NeturalizeHardPoint( hardpoint )
				hasBeenAmped = false
			}
		}
		else if(hardpointEnt.GetTeam()==cappingTeam) // capping allied point
		{
			SetHardpointCappingTeam(hardpoint,cappingTeam)
			if(GetHardpointCaptureProgress(hardpoint)<1.0) // not amped
			{
				SetHardpointCaptureProgress(hardpoint,GetHardpointCaptureProgress(hardpoint)+(deltaTime/CAPTURE_DURATION_CAPTURE*capperAmount))
			}
			else if(file.ampingEnabled)//amping or reamping
			{
				// i have no idea why but putting it CAPTURE_POINT_STATE_AMPING will say 'CONTESTED' on the UI
				// since whether the point is contested is checked above, putting the hardpoint state to a value of 8 fixes it somehow
				//if(GetHardpointState(hardpoint)<=CAPTURE_POINT_STATE_AMPING)
				//	SetHardpointState(hardpoint, 8 )
				if(GetHardpointState(hardpoint)<CAPTURE_POINT_STATE_AMPING)
					SetHardpointState(hardpoint,CAPTURE_POINT_STATE_AMPING)
				SetHardpointCaptureProgress( hardpoint, min( 2.0, GetHardpointCaptureProgress( hardpoint ) + ( deltaTime / HARDPOINT_AMPED_DELAY * capperAmount ) ) )
				if(GetHardpointCaptureProgress(hardpoint)==2.0&&!(GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_AMPED))
				{
					SetHardpointState( hardpoint, CAPTURE_POINT_STATE_AMPED )
					// can't use the dialogue functions here because for some reason GamemodeCP_VO_Amped isn't global?
					PlayFactionDialogueToTeam( "amphp_youAmped" + GetHardpointGroup(hardpoint.hardpoint), cappingTeam )
					PlayFactionDialogueToTeam( "amphp_enemyAmped" + GetHardpointGroup(hardpoint.hardpoint), GetOtherTeam( cappingTeam ) )
					thread PlayAnim( hardpoint.prop, "mh_inactive_2_active" )

					if(!hasBeenAmped)
					{
						hasBeenAmped=true

						array<entity> allCappers
						allCappers.extend(hardpoint.militiaCappers)
						allCappers.extend(hardpoint.imcCappers)

						foreach(entity player in allCappers)
						{
							if ( IsValid( player ) )
							{
								if(player.IsPlayer())
								{
									EmitHardPointCapturingSound( hardpoint, player )
									AddPlayerScore(player,"ControlPointAmped", player)
									player.AddToPlayerGameStat(PGS_DEFENSE_SCORE,POINTVALUE_HARDPOINT_AMPED)
									UpdatePlayerScoreForChallenge(player,0,POINTVALUE_HARDPOINT_AMPED)
								}
							}
						}
					}
				}
			}
		}

		if ( hardpointEnt.GetTeam() != TEAM_UNASSIGNED && GetHardpointState( hardpoint ) >= CAPTURE_POINT_STATE_CAPTURED && currentTime - lastScoreTime >= TEAM_OWNED_SCORE_FREQ && !hardpointBlocked&&!(cappingTeam==GetOtherTeam(hardpointEnt.GetTeam())))
		{
			lastScoreTime = currentTime
			if ( GetHardpointState( hardpoint ) == CAPTURE_POINT_STATE_AMPED )
				AddTeamScore( hardpointEnt.GetTeam(), ScoreAdditionFromTeam( hardpointEnt.GetTeam(), 10, 300 ) )
			else if( GetHardpointState( hardpoint) >= CAPTURE_POINT_STATE_CAPTURED)
				AddTeamScore( hardpointEnt.GetTeam(), ScoreAdditionFromTeam( hardpointEnt.GetTeam(), 5, 300 ) )
		}

		foreach(entity player in hardpoint.imcCappers)
		{
			if( IsValid( player ) )
			{
				//Remote_CallFunction_Replay( player,"ServerCallback_HardpointChanged", hardpointEHandle )
				//if(DistanceSqr(player.GetOrigin(),hardpointEnt.GetOrigin())>1200000)
				//	FindAndRemove(hardpoint.imcCappers,player)
				if ( Distance2D( player.GetOrigin(),hardpoint.trigger.GetOrigin() ) > 2000 )
					FindAndRemove( hardpoint.imcCappers, player )
			}
		}
		foreach(entity player in hardpoint.militiaCappers)
		{
			if( IsValid( player ) )
			{
				//Remote_CallFunction_Replay( player,"ServerCallback_HardpointChanged", hardpointEHandle )
				//if(DistanceSqr(player.GetOrigin(),hardpointEnt.GetOrigin())>1200000)
				//	FindAndRemove(hardpoint.militiaCappers,player)
				if ( Distance2D( player.GetOrigin(),hardpoint.trigger.GetOrigin() ) > 2000 )
					FindAndRemove( hardpoint.militiaCappers, player )
			}
		}


		lastTime = currentTime
		WaitFrame()
	}
}

// doing this in HardpointThink is effort since it's for individual hardpoints
// so we do it here instead
void function TrackChevronStates()
{
	// you get 1 amped arrow for chevron / 4, 1 unamped arrow for every 1 the amped chevrons

	while ( true )
	{
		table <int, int> chevrons = {
			[TEAM_IMC] = 0,
			[TEAM_MILITIA] = 0,
		}

		foreach ( HardpointStruct hardpoint in file.hardpoints )
		{
			foreach ( k, v in chevrons )
			{
				if ( k == hardpoint.hardpoint.GetTeam() )
					chevrons[k] += ( hardpoint.hardpoint.GetHardpointState() == CAPTURE_POINT_STATE_AMPED ) ? 4 : 1
			}
		}

		SetGlobalNetInt( "imcChevronState", chevrons[TEAM_IMC] )
		SetGlobalNetInt( "milChevronState", chevrons[TEAM_MILITIA] )

		WaitFrame()
	}
}

void function OnHardpointEntered( entity trigger, entity player )
{
	HardpointStruct hardpoint
	foreach ( HardpointStruct hardpointStruct in file.hardpoints )
		if ( hardpointStruct.trigger == trigger )
			hardpoint = hardpointStruct

	if ( player.GetTeam() == TEAM_IMC )
	{
		hardpoint.imcCappers.append( player )
		if( player.IsPlayer() )
		{
			EmitHardPointCapturingSound( hardpoint, player )
			PlayFactionDialogueToPlayer( "amphp_friendlyCapping" + GetHardpointGroup(hardpoint.hardpoint), player )
			player.SetPlayerNetInt( "playerHardpointID", hardpoint.hardpoint.GetHardpointID() )
		}
	}
	else
	{
		hardpoint.militiaCappers.append( player )
		if( player.IsPlayer() )
		{
			EmitHardPointCapturingSound( hardpoint, player )
			PlayFactionDialogueToPlayer( "amphp_friendlyCapping" + GetHardpointGroup(hardpoint.hardpoint), player )
			player.SetPlayerNetInt( "playerHardpointID", hardpoint.hardpoint.GetHardpointID() )
		}
	}
	foreach(CP_PlayerStruct playerStruct in file.players)
		if(playerStruct.player == player)
			playerStruct.isOnHardpoint = true
}

void function EmitHardPointCapturingSound( HardpointStruct hardpoint, entity player )
{
	StopHardPointCapturingSound( player )
	if( GetHardpointState(hardpoint) == CAPTURE_POINT_STATE_AMPED )
		EmitSoundOnEntityOnlyToPlayer( player, player, "Hardpoint_Amped_ProgressBar" )
	else
		EmitSoundOnEntityOnlyToPlayer( player, player, "Hardpoint_ProgressBar" )
}

void function StopHardPointCapturingSound( entity player )
{
	StopSoundOnEntity( player, "Hardpoint_Amped_ProgressBar" )
	StopSoundOnEntity( player, "Hardpoint_ProgressBar" )
}

void function OnHardpointLeft( entity trigger, entity player )
{
	HardpointStruct hardpoint
	foreach ( HardpointStruct hardpointStruct in file.hardpoints )
		if ( hardpointStruct.trigger == trigger )
			hardpoint = hardpointStruct

	if ( player.GetTeam() == TEAM_IMC )
		FindAndRemove( hardpoint.imcCappers, player )
	else
		FindAndRemove( hardpoint.militiaCappers, player )
	if( player.IsPlayer() )
	{
		StopHardPointCapturingSound( player )
		player.SetPlayerNetInt( "playerHardpointID", 69 ) // magic number
	}
	foreach(CP_PlayerStruct playerStruct in file.players)
		if(playerStruct.player == player)
			playerStruct.isOnHardpoint = false
}

string function CaptureStateToString( int state )
{
	switch ( state )
	{
		case CAPTURE_POINT_STATE_UNASSIGNED:
			return "UNASSIGNED"
		case CAPTURE_POINT_STATE_HALTED:
			return "HALTED"
		case CAPTURE_POINT_STATE_CAPTURED:
			return "CAPTURED"
		case CAPTURE_POINT_STATE_AMPING:
			return "AMPING"
		case CAPTURE_POINT_STATE_AMPED:
			return "AMPED"
	}
	return "UNKNOWN"
}

void function DEV_PrintHardpointsInfo()
{
	foreach (entity hardpoint in HARDPOINTS)
	{

		printt(
			"Hardpoint:", GetHardpointGroup(hardpoint),
			"|Team:", Dev_TeamIDToString(hardpoint.GetTeam()),
			"|State:", CaptureStateToString(hardpoint.GetHardpointState()),
			"|Progress:", GetGlobalNetFloat("objective" + GetHardpointGroup(hardpoint) + "Progress")
		)
	}
}

string function GetHardpointGroup(entity hardpoint) //Hardpoint Entity B on Homestead is missing the Hardpoint Group KeyValue
{
	if((GetMapName()=="mp_homestead")&&(!hardpoint.HasKey("hardpointGroup")))
		return "B"

	return string(hardpoint.kv.hardpointGroup)
}

void function UpdatePlayerScoreForChallenge(entity player,int assaultpoints = 0,int defensepoints = 0)
{
	if(player in file.playerAssaultPoints)
	{
		file.playerAssaultPoints[player] += assaultpoints
		if( file.playerAssaultPoints[player] >= 1000 && !HasPlayerCompletedMeritScore(player) )
		{
			AddPlayerScore(player,"ChallengeCPAssault")
			SetPlayerChallengeMeritScore(player)
		}
	}

	if(player in file.playerDefensePoints)
	{
		file.playerDefensePoints[player] += defensepoints
		if( file.playerDefensePoints[player] >= 500 && !HasPlayerCompletedMeritScore(player) )
		{
			AddPlayerScore(player,"ChallengeCPDefense")
			SetPlayerChallengeMeritScore(player)
		}
	}
}