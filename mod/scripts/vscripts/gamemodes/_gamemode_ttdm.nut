untyped
global function GamemodeTTDM_Init

global function TTDMIntroSetup // welp this is just for fun, so we can share it with other script...

const float TTDMIntroLength = 15.0

void function GamemodeTTDM_Init()
{
	Riff_ForceSetSpawnAsTitan( eSpawnAsTitan.Always )
	Riff_ForceTitanExitEnabled( eTitanExitEnabled.Default )
	SetTTDMEject( true )
	TrackTitanDamageInPlayerGameStat( PGS_ASSAULT_SCORE )
	ScoreEvent_SetupEarnMeterValuesForMixedModes()
	SetLoadoutGracePeriodEnabled( false )

	ClassicMP_SetCustomIntro( TTDMIntroSetup, TTDMIntroLength )
	ClassicMP_ForceDisableEpilogue( true )
	SetTimeoutWinnerDecisionFunc( CheckScoreForDraw )

	AddCallback_OnPlayerKilled( AddTeamScoreForPlayerKilled ) // dont have to track autotitan kills since you cant leave your titan in this mode

	// probably needs scoreevent earnmeter values
	SetUpTTDMScoreEvents() // northstar missing

	Rodeo_SetTitanPickupBatteryAllowed( true )
	AddCallback_OnLastMinute( OnLastMinute )
	SetKillStreakEnable( false )
	AddCallback_OnPlayerRespawned( OnPlayerRespawned )

	// tempfix specifics
	SetShouldPlayDefaultMusic( true ) // play music when score or time reaches some point

	AddCallback_GameStateEnter( eGameState.Playing, OnPlaying )
}

void function OnPlayerRespawned( entity player )
{
	thread OnPlayerRespawned_Threaded( player )
}

void function OnPlayerRespawned_Threaded( entity player )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )
	DeployAndEnableWeapons( player )
	if( !player.IsTitan() )
		return
	CreateBubbleShield( player, player.GetOrigin(), player.GetAngles() )
}

void function OnLastMinute()
{
	int teamScoreAddition = abs( GameRules_GetTeamScore( TEAM_MILITIA ) - GameRules_GetTeamScore( TEAM_IMC ) ) / 25 + 2
	SetTeamScoreAddition( teamScoreAddition )
	foreach( player in GetPlayerArray() )
	{
		if( !IsValid( player ) )
			continue
		NSSendAnnouncementMessageToPlayer( player, teamScoreAddition +"倍分數獲取！", "最後1分鐘！", < 50, 50, 225 >, 255, 6 )
	}
}

// northstar missing
void function SetUpTTDMScoreEvents()
{
	// pilot kill: 15% for titans
	// titan kill: 0%
	// titan assist: 0%
	// execution: 0%
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.0, 0.15, 1.0 )
	ScoreEvent_SetEarnMeterValues( "KillTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "KillAutoTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "TitanKillTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "TitanAssist", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "Execution", 0.0, 0.0 )

	// modify override settings
	// player-controlled stuff
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.30, 0.15 )
	ScoreEvent_SetEarnMeterValues( "EliminatePilot", 0.30, 0.05 )
	ScoreEvent_SetEarnMeterValues( "PilotAssist", 0.3, 0.020001, 0.0 ) // if set to "0.03, 0.02", will display as "4%"
	ScoreEvent_SetEarnMeterValues( "KillTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "PilotBatteryStolen", 0.0, 0.10 ) // this actually just doesn't have overdrive in vanilla even
	ScoreEvent_SetEarnMeterValues( "FirstStrike", 0.3, 0.020001, 0.0 ) // if set to "0.03, 0.02", will display as "4%"
}

void function TTDMIntroSetup()
{
	// this should show intermission cam for 15 sec in prematch, before spawning players as titans
	AddCallback_GameStateEnter( eGameState.Prematch, TTDMIntroStart )
	//AddCallback_OnClientConnected( TTDMIntroShowIntermissionCam )
	// vanilla behavior...
	AddCallback_GameStateEnter( eGameState.Playing, TTDMGameStart )
	AddCallback_OnClientConnected( TTDMIntroConntectedPlayer )
}

void function TTDMIntroStart()
{
	thread TTDMIntroStartThreaded()
}

void function TTDMIntroStartThreaded()
{
	ClassicMP_OnIntroStarted()

	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsPrivateMatchSpectator( player ) )
			TTDMIntroShowIntermissionCam( player )
		else
			RespawnPrivateMatchSpectator( player )
	}
	// make this no longer a const value, so we can share it with other scripts...
	//wait TTDMIntroLength
	wait ClassicMP_GetIntroLength()

	ClassicMP_OnIntroFinished()
}

void function TTDMIntroShowIntermissionCam( entity player )
{
	// vanilla behavior
	//if ( GetGameState() != eGameState.Prematch )
	//	return

	thread PlayerWatchesTTDMIntroIntermissionCam( player )
}

// vanilla behavior
void function TTDMGameStart()
{
	foreach ( entity player in GetPlayerArray_Alive() )
	{
		TryGameModeAnnouncement( player ) // announce players whose already alive
		player.UnfreezeControlsOnServer() // if a player is alive they must be freezed, unfreeze them
	}
}

void function TTDMIntroConntectedPlayer( entity player )
{
	if ( GetGameState() != eGameState.Prematch )
		return

	thread TTDMIntroConntectedPlayer_Threaded( player )
}

void function TTDMIntroConntectedPlayer_Threaded( entity player )
{
	player.EndSignal( "OnDestroy" )

	RespawnAsTitan( player, false )
	if ( GetGameState() == eGameState.Prematch ) // still in intro
		player.FreezeControlsOnServer() // freeze
	else if ( GetGameState() == eGameState.Playing ) // they may connect near the end of intro
		TryGameModeAnnouncement( player )
}

void function PlayerWatchesTTDMIntroIntermissionCam( entity player )
{
	player.EndSignal( "OnDestroy" )
	ScreenFadeFromBlack( player )

	entity intermissionCam = GetEntArrayByClass_Expensive( "info_intermission" )[ 0 ]

	// the angle set here seems sorta inconsistent as to whether it actually works or just stays at 0 for some reason
	player.SetObserverModeStaticPosition( intermissionCam.GetOrigin() )
	player.SetObserverModeStaticAngles( intermissionCam.GetAngles() )
	player.StartObserverMode( OBS_MODE_STATIC_LOCKED )

	// make this no longer a const value, so we can share it with other scripts...
	//wait TTDMIntroLength
	wait ClassicMP_GetIntroLength()

	RespawnAsTitan( player, false )
	TryGameModeAnnouncement( player )
}

void function AddTeamScoreForPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( victim == attacker || ( !victim.IsPlayer() && !victim.IsTitan() ) || !attacker.IsPlayer() && GetGameState() == eGameState.Playing )
		return

	int team = GetOtherTeam( victim.GetTeam() )
	int score = 5
	if( victim.IsTitan() )
		score = 10

	AddTeamScore( team, ScoreAdditionFromTeam( team, score, 50 ) )
}

int function CheckScoreForDraw()
{
	if (GameRules_GetTeamScore(TEAM_IMC) > GameRules_GetTeamScore(TEAM_MILITIA))
		return TEAM_IMC
	else if (GameRules_GetTeamScore(TEAM_MILITIA) > GameRules_GetTeamScore(TEAM_IMC))
		return TEAM_MILITIA

	return TEAM_UNASSIGNED
}

// modified from MixedGame extra_ai_spawner.gnut: care package
const float CARE_PACKAGE_LIFETIME = 90
const float CARE_PACKAGE_WAITTIME = 10
const asset CAREPACKAGE_MODEL = $"models/vehicle/escape_pod/escape_pod.mdl"

void function OnPlaying()
{
	thread DropPodSpawnThreaded()
}

void function DropPodSpawnThreaded()
{
	while( GetGameState() == eGameState.Playing )
	{
		wait RandomFloatRange( 30, 60 )

		foreach( entity player in GetPlayerArray() )
		{
			EmitSoundOnEntityOnlyToPlayer( player, player, "Boomtown_RobotArm_90Turn" )
			NSSendLargeMessageToPlayer( player, "電池補給艙運送中! ", "打破補給艙來獲得電池", 7, "rui/callsigns/callsign_69_col" )
		}

		array< entity > points = SpawnPoints_GetTitan()
		entity node = FindBestSpawnForNPCDrop( points )

		ExtraSpawner_SpawnCarePackage( node.GetOrigin(), node.GetAngles(), CARE_PACKAGE_LIFETIME, CARE_PACKAGE_WAITTIME )

		svGlobal.levelEnt.WaitSignal( "DropPodUsed" )
	}
}

entity function FindBestSpawnForNPCDrop( array<entity> spawnPoints )
{
	array<entity> validSpawnPoints

	foreach( team in [ TEAM_MILITIA, TEAM_IMC ] )
	{
		entity zone = DecideSpawnZone_Generic( spawnPoints, team )

		if ( IsValid( zone ) )
		{
			foreach ( entity spawn in spawnPoints )
			{
				// spawn from too far shouldn't count!
				if ( Distance2D( spawn.GetOrigin(), zone.GetOrigin() ) > 4000 )
					continue
				validSpawnPoints.append( spawn )
			}
		}
	}

	// no spawn zone valid or we can't find any valid point in zone...
	if ( validSpawnPoints.len() == 0 )
		validSpawnPoints = spawnPoints

	return validSpawnPoints[ RandomInt( validSpawnPoints.len() ) ]
}

void function ExtraSpawner_SpawnCarePackage( vector pos, vector rot, float lifeTime, float waitTime )
{
	thread ExtraSpawner_SpawnCarePackage_Threaded( pos, rot, lifeTime, waitTime )
}

void function ExtraSpawner_SpawnCarePackage_Threaded( vector pos, vector rot, float lifeTime, float waitTime )
{
	vector surfaceNormal = < 0, 0, 1 >
	int index = GetParticleSystemIndex( $"P_ar_titan_droppoint" )
	entity targetEffect = StartParticleEffectInWorld_ReturnEntity( index, pos, surfaceNormal )
	EffectSetControlPointVector( targetEffect, 1, < 50, 50, 255 > )
	targetEffect.DisableHibernation()

	wait waitTime

	entity animPod = CreateDropPod( pos + < 0, 0, -30 >, <0,0,0> )
	waitthread LaunchAnimDropPod( animPod, "pod_testpath", pos, rot )
	if( IsValid( animPod ) )
		animPod.Destroy()
	EffectSetControlPointVector( targetEffect, 1, < 0,190,0 > ) // green

	entity pod = CreatePropScript( CAREPACKAGE_MODEL, pos + < 0, 0, -30 >, < 0, 0, 0 >, 6 )
	pod.SetDamageNotifications( true )
	pod.SetDeathNotifications( true )
	pod.SetTakeDamageType( DAMAGE_YES )
	pod.SetMaxHealth( 400 )
	pod.SetHealth( 400 )
	SetObjectCanBeMeleed( pod, true )
	AddEntityCallback_OnDamaged( pod, PodOnDamaged )

    float endTime = Time() + lifeTime
	while( endTime > Time() )
	{
		WaitFrame()
		if( !IsValid( pod ) )
			break
	}

	svGlobal.levelEnt.Signal( "DropPodUsed" )
	if ( IsValid( targetEffect ) )
		EffectStop( targetEffect )

	float batteryCount = RandomFloatRange( 4, 6 )
	for ( float i = 1.0; i <= batteryCount; i += 1.0 )
	{
		entity newBattery = Rodeo_CreateBatteryPack()
		newBattery.SetSkin( RandomInt( 2 ) == 0 ? 0 : 2 )	// 50% Yellow, 50% Green
		Battery_StartFX( newBattery )
		newBattery.s.touchEnabledTime = Time() + 2
		vector direction = AnglesToForward( <0, i/batteryCount * 360.0, 0> )
		newBattery.SetOrigin( pos + < 0, 0, 100 > + direction * 30 )
		newBattery.SetAngles( <0, 0, 0 > )
		newBattery.SetVelocity( direction * RandomFloatRange( 200, 600 ) + <0, 0, RandomFloatRange( 400, 600 )> )
	}
	PlayImpactFXTable( pos, null, "exp_satchel" )
	EmitSoundAtPosition( TEAM_UNASSIGNED, pos + < 0, 0, 60 >, "BatteryCrate_Explosion" )
	if( IsValid( pod ) )
		pod.Destroy()
}

void function PodOnDamaged( entity pod, var damageInfo )
{
	if( !IsValid( pod ) )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	attacker.NotifyDidDamage( pod, DamageInfo_GetHitBox( damageInfo ), DamageInfo_GetDamagePosition( damageInfo ), DamageInfo_GetCustomDamageType( damageInfo ), DamageInfo_GetDamage( damageInfo ), DamageInfo_GetDamageFlags( damageInfo ), DamageInfo_GetHitGroup( damageInfo ), DamageInfo_GetWeapon( damageInfo ), DamageInfo_GetDistFromAttackOrigin( damageInfo ) )
	float damage = DamageInfo_GetDamage( damageInfo )
	int health = pod.GetHealth()
	health -= int( damage )

	if ( health <= 0 )
		pod.Destroy()
	else
		pod.SetHealth( health )
}
