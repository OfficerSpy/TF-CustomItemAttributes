// static Handle m_hDispatchParticleEffect3;
static Handle m_hDroppedWeaponCreate;
static Handle m_hInitDroppedWeapon;
// Handle m_hSDKGetParticleColor;
static Handle m_hFireProjectile;
static Handle m_hWorldSpaceCenter;
static Handle m_hGetWeaponProjectileType;
static Handle m_hGetProjectileSpeed;
static Handle m_hVPhysicsDestroyObject;
static Handle m_hModifyProjectile;

bool InitSDKCalls(GameData hGamedata)
{
	int failCount = 0;
	
	/* StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "DispatchParticleEffect3");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); //pszParticleName
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //iAttachType
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); //pEntity
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); //pszAttachmentName
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer); //vecColor1
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer); //vecColor2
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); //bUseColors
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); //bResetAllParticlesOnEntity 
	if ((m_hDispatchParticleEffect3 = EndPrepSDKCall()) == null) { LogError("Failed to create SDKCall for DispatchParticleEffect!"); sigFailure = true; } */
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFDroppedWeapon::Create");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((m_hDroppedWeaponCreate = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFDroppedWeapon::Create!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFDroppedWeapon::InitDroppedWeapon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if ((m_hInitDroppedWeapon = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFDroppedWeapon::InitDroppedWeapon!");
		failCount++;
	}
	
	//FIXME: attempting to make this call will crash the game
	/* StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTFWeaponBase::GetParticleColor");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //iColor
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((m_hSDKGetParticleColor = EndPrepSDKCall()) == null) { LogError("Failed to create SDKCall for CTFWeaponBase::GetParticleColor!"); sigFailure = true; } */
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTFWeaponBaseGun::FireProjectile");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((m_hFireProjectile = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFWeaponBaseGun::FireProjectile!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CBaseEntity::WorldSpaceCenter");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((m_hWorldSpaceCenter = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CBaseEntity::WorldSpaceCenter!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTFWeaponBaseGun::GetWeaponProjectileType");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((m_hGetWeaponProjectileType = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFWeaponBaseGun::GetWeaponProjectileType!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTFWeaponBaseGun::GetProjectileSpeed");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);	//Returns SPEED
	if ((m_hGetProjectileSpeed = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFWeaponBaseGun::GetProjectileSpeed!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CBaseEntity::VPhysicsDestroyObject");
	if ((m_hVPhysicsDestroyObject = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CBaseEntity::VPhysicsDestroyObject!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTFWeaponBaseGun::ModifyProjectile");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((m_hModifyProjectile = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFWeaponBaseGun::ModifyProjectile!");
		failCount++;
	}
	
	if (failCount > 0)
	{
		LogError("InitSDKCalls: GameData file has %d problems!", failCount);
		return false;
	}
	
	return true;
}

/* void DispatchParticleEffect3(char[] particleName, ParticleAttachment_t attachType, int entity, char[] attachmentName, float vecColor1[3], float vecColor2[3], bool useColors = true, bool resetAllParticles = false)
{
	SDKCall(m_hDispatchParticleEffect3, particleName, attachType, entity, attachmentName, vecColor1, vecColor2, useColors, resetAllParticles);
} */

int CreateDroppedWeapon(int lastOwner, const float origin[3], const float angles[3], const char[] modelName, Address item)
{
	int entity;
	
	//Bypass MvM check in CTFDroppedWeapon::Create
	if (IsMannVsMachineMode())
	{
		GameRules_SetProp("m_bPlayingMannVsMachine", 0);
		entity = SDKCall(m_hDroppedWeaponCreate, lastOwner, origin, angles, modelName, item);
		GameRules_SetProp("m_bPlayingMannVsMachine", 1);
	}
	else
		entity = SDKCall(m_hDroppedWeaponCreate, lastOwner, origin, angles, modelName, item);
	
	return entity;
}

void InitDroppedWeapon(int droppedWeapon, int player, int weapon, bool swap, bool isSuicide = false)
{
	SDKCall(m_hInitDroppedWeapon, droppedWeapon, player, weapon, swap, isSuicide);
}

/* float[] GetWeaponParticleColor(int weapon, int color)
{
	float vec[3];
	SDKCall(m_hSDKGetParticleColor, weapon, vec, color);
	return vec;
} */

int TFWBG_FireProjectile(int weapon, int player)
{
	return SDKCall(m_hFireProjectile, weapon, player);
}

float[] WorldSpaceCenter(int entity)
{
	float vecPos[3];
	SDKCall(m_hWorldSpaceCenter, entity, vecPos);
	return vecPos;
}

int TFWBG_GetWeaponProjectileType(int weapon)
{
	return SDKCall(m_hGetWeaponProjectileType, weapon);
}

float TFWBG_GetProjectileSpeed(int weapon)
{
	return SDKCall(m_hGetProjectileSpeed, weapon);
}

void VPhysicsDestroyObject(int entity)
{
	SDKCall(m_hVPhysicsDestroyObject, entity);
}

void TFWBG_ModifyProjectile(int weapon, int proj)
{
	SDKCall(m_hModifyProjectile, weapon, proj);
}