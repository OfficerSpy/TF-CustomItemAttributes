static DynamicHook m_hPerformCustomPhysics;

bool InitDHooks(GameData hGamedata)
{
	int iFailCount = 0;
	
	if (!RegisterHook(hGamedata, m_hPerformCustomPhysics, "CBaseEntity::PerformCustomPhysics"))
		iFailCount++;
	
	if (iFailCount > 0)
	{
		LogError("InitDHooks: found %d problem(s) with gamedata!", iFailCount);
		return false;
	}
	
	return true;
}

void DHooks_HomingRocket(int iProjectile)
{
	m_hPerformCustomPhysics.HookEntity(Hook_Pre, iProjectile, DHookCallback_PerformCustomPhysics_Pre);
}

static MRESReturn DHookCallback_PerformCustomPhysics_Pre(int pThis, DHookParam hParams)
{
	float vNewPosition[3], vNewVelocity[3], vNewAngles[3], vNewAngVelocity[3];
	
	hParams.GetVector(1, vNewPosition);
	hParams.GetVector(2, vNewVelocity);
	hParams.GetVector(3, vNewAngles);
	hParams.GetVector(4, vNewAngVelocity);
	
	if (PerformCustomPhysics(pThis, vNewPosition, vNewVelocity, vNewAngles, vNewAngVelocity))
	{
		hParams.SetVector(1, vNewPosition);
		hParams.SetVector(2, vNewVelocity);
		hParams.SetVector(3, vNewAngles);
		hParams.SetVector(4, vNewAngVelocity);
		
#if 0
		PrintToChatAll("vNewPosition %.2f %.2f %.2f", vNewPosition[0], vNewPosition[1], vNewPosition[2]);
		PrintToChatAll("vNewVelocity %.2f %.2f %.2f", vNewVelocity[0], vNewVelocity[1], vNewVelocity[2]);
		PrintToChatAll("vNewAngles %.2f %.2f %.2f", vNewAngles[0], vNewAngles[1], vNewAngles[2]);
		PrintToChatAll("vNewAngVelocity %.2f %.2f %.2f", vNewAngVelocity[0], vNewAngVelocity[1], vNewAngVelocity[2]);
#endif
		
		return MRES_ChangedHandled;
	}
	
	return MRES_Ignored;
}

static bool RegisterDetour(GameData gd, const char[] fnName, DHookCallback pre = INVALID_FUNCTION, DHookCallback post = INVALID_FUNCTION)
{
	DynamicDetour hDetour;
	hDetour = DynamicDetour.FromConf(gd, fnName);
	
	if (hDetour)
	{
		if (pre != INVALID_FUNCTION)
			hDetour.Enable(Hook_Pre, pre);
		
		if (post != INVALID_FUNCTION)
			hDetour.Enable(Hook_Post, post);
	}
	else
	{
		delete hDetour;
		LogError("Failed to detour \"%s\"!", fnName);
		
		return false;
	}
	
	delete hDetour;
	
	return true;
}

static bool RegisterHook(GameData gd, DynamicHook &hook, const char[] fnName)
{
	hook = DynamicHook.FromConf(gd, fnName);
	
	if (hook == null)
	{
		LogError("Failed to setup DynamicHook for \"%s\"!", fnName);
		return false;
	}
	
	return true;
}