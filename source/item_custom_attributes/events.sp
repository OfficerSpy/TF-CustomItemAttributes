void HookGameEvents()
{
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (IsValidClientIndex(attacker))
	{
		char iconName[256];	TF2Attrib_HookValueString("", "custom_kill_icon", attacker, iconName, sizeof(iconName));
		
		//Change kill icon for everyone
		if (strlen(iconName) > 0)
		{
			event.SetString("weapon", iconName);
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}