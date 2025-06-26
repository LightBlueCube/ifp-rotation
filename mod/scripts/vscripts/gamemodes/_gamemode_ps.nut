untyped
global function GamemodePs_Init
//global function RateSpawnpoints_SpawnZones

struct {
	array<entity> spawnzones

	entity militiaActiveSpawnZone
	entity imcActiveSpawnZone

	array<entity> militiaPreviousSpawnZones
	array<entity> imcPreviousSpawnZones
} file

void function GamemodePs_Init()
{
	Riff_ForceTitanAvailability( eTitanAvailability.Never )

	AddCallback_OnPlayerKilled( GiveScoreForPlayerKill )
	ScoreEvent_SetupEarnMeterValuesForMixedModes()
	SetUpPilotSkirmishScoreEvent() // northstar missing
	SetTimeoutWinnerDecisionFunc( CheckScoreForDraw )

	AddCallback_OnPlayerRespawned( OnPlayerRespawned )
	AddCallback_OnLastMinute( OnLastMinute )

	// spawnzone stuff
	SetShouldCreateMinimapSpawnZones( true )

	//AddCallback_OnPlayerKilled( CheckSpawnzoneSuspiciousDeaths )
	//AddSpawnCallbackEditorClass( "trigger_multiple", "trigger_mp_spawn_zone", SpawnzoneTriggerInit )

	file.militiaPreviousSpawnZones = [ null, null, null ]
	file.imcPreviousSpawnZones = [ null, null, null ]

	// tempfix specifics
	SetShouldPlayDefaultMusic( true ) // play music when score or time reaches some point

	// challenge fix
	SetupGenericFFAChallenge()

	// modify override earnmeter setting
	ScoreEvent_SetEarnMeterValues( "FirstStrike", 0.6, 0.05 )
}

void function OnLastMinute()
{
	int teamScoreAddition = abs( GameRules_GetTeamScore( TEAM_MILITIA ) - GameRules_GetTeamScore( TEAM_IMC ) ) / 50 + 2
	SetTeamScoreAddition( teamScoreAddition )
	foreach( player in GetPlayerArray() )
	{
		if( !IsValid( player ) )
			continue
		RUIQueue_NSSendAnnouncementMessageToPlayer( player, teamScoreAddition +"倍分數獲取！", "最後1分鐘！", < 50, 50, 225 >, 255, 6 )
	}
}

void function OnPlayerRespawned( entity player )
{
	entity battery = Rodeo_CreateBatteryPack()
	battery.SetSkin( RandomInt( 2 ) == 0 ? 0 : 2 )	// 50% Yellow, 50% Green
	Battery_StartFX( battery )
	Rodeo_OnTouchBatteryPack_Internal( player, battery )
	thread OnPlayerRespawned_Threaded( player )
}

void function OnPlayerRespawned_Threaded( entity player )
{
	WaitFrame()
	if ( IsValid( player ) )
		PlayerEarnMeter_SetMode( player, eEarnMeterMode.DISABLED )
}

// northstar missing
void function SetUpPilotSkirmishScoreEvent()
{
	// override settings
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.05, 0.15 )
}

void function GiveScoreForPlayerKill( entity victim, entity attacker, var damageInfo )
{
	if ( victim != attacker
		 && victim.IsPlayer()
		 && IsValid( attacker )
		 && attacker.IsPlayer()
		 && GetGameState() == eGameState.Playing )
	{

		AddTeamScore( attacker.GetTeam(), ScoreAdditionFromTeam( attacker.GetTeam(), 10, 200 ) )

		if ( GetGameState() == eGameState.WinnerDetermined ) // win match with AddTeamScore()
			ScoreEvent_VictoryKill( attacker )
	}
}

int function CheckScoreForDraw()
{
	if ( GameRules_GetTeamScore( TEAM_IMC ) > GameRules_GetTeamScore( TEAM_MILITIA ) )
		return TEAM_IMC
	else if ( GameRules_GetTeamScore( TEAM_MILITIA ) > GameRules_GetTeamScore( TEAM_IMC ) )
		return TEAM_MILITIA

	return TEAM_UNASSIGNED
}