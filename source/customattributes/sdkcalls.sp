static Handle m_hGetWeaponProjectileType;
static Handle m_hGetProjectileSpeed;
static Handle m_hShouldCollide;

bool InitSDKCalls(GameData hGamedata)
{
	int iFailCount = 0;
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTFWeaponBaseGun::GetWeaponProjectileType");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	if ((m_hGetWeaponProjectileType = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFWeaponBaseGun::GetWeaponProjectileType!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTFWeaponBaseGun::GetProjectileSpeed");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if ((m_hGetProjectileSpeed = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFWeaponBaseGun::GetProjectileSpeed!");
		iFailCount++;
	}
	
	char sTempConfFileName[] = "sdkhooks.games/engine.ep2v";
	GameData hTempConf = new GameData(sTempConfFileName);
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hTempConf, SDKConf_Virtual, "ShouldCollide");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	if ((m_hShouldCollide = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CBaseEntity::ShouldCollide from file %s.txt", sTempConfFileName);
		iFailCount++;
	}
	
	hTempConf.Close();
	
	if (iFailCount > 0)
	{
		LogError("InitSDKCalls: GameData file has %d problem(s)!", iFailCount);
		return false;
	}
	
	return true;
}

int GetWeaponProjectileType(int weapon)
{
	return SDKCall(m_hGetWeaponProjectileType, weapon);
}

float GetProjectileSpeed(int weapon)
{
	return SDKCall(m_hGetProjectileSpeed, weapon);
}

bool ShouldCollide(int entity, int collisionGroup, int contentsMask)
{
	return SDKCall(m_hShouldCollide, entity, collisionGroup, contentsMask);
}