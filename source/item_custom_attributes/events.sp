void HookGameEvents()
{
	HookEvent("player_death", Event_PlayerDeath_Change, EventHookMode_Pre);
}

public Action Event_PlayerDeath_Change(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (IsValidClientIndex(attacker))
	{
		//Change kill icon for everyone
		char iconName[128];	TF2Attrib_HookValueString("", "custom_kill_icon", attacker, iconName, sizeof(iconName));
		if (strlen(iconName) > 0)
		{
			event.SetString("weapon", iconName);
			event.SetString("weapon_logclassname", iconName);
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}