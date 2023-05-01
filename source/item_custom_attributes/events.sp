void HookGameEvents()
{
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (IsValidClientIndex(attacker))
	{
		char strIcon[256];
		TF2Attrib_HookValueString("", "custom_kill_icon", attacker, strIcon, sizeof(strIcon));
		
		//Change kill icon for everyone
		if (strlen(strIcon) > 0)
		{
			event.SetString("weapon", strIcon);
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}