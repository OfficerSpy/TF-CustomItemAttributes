Handle g_hDispatchParticleEffect3;
Handle g_hDroppedWeaponCreate;
Handle g_hInitDroppedWeapon;
// Handle g_hSDKGetParticleColor;
Handle g_hFireProjectile;

void SetupSDKCalls()
{
	Handle hConf = LoadGameConfigFile("tf2.customitemattribs");
	bool sigFailure;
		
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "DispatchParticleEffect3");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); //pszParticleName
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //iAttachType
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); //pEntity
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); //pszAttachmentName
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer); //vecColor1
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer); //vecColor2
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); //bUseColors
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); //bResetAllParticlesOnEntity 
	if ((g_hDispatchParticleEffect3 = EndPrepSDKCall()) == null) { LogError("Failed to create SDKCall for DispatchParticleEffect!"); sigFailure = true; }
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFDroppedWeapon::Create");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_hDroppedWeaponCreate = EndPrepSDKCall()) == null) { LogError("Failed to create SDKCall for CTFDroppedWeapon::Create!"); sigFailure = true; }
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFDroppedWeapon::InitDroppedWeapon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if ((g_hInitDroppedWeapon = EndPrepSDKCall()) == null) { LogError("Failed to create SDKCall for CTFDroppedWeapon::InitDroppedWeapon!"); sigFailure = true; }
	
	//FIXME: attempting to make this call will crash the game
	/* StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFWeaponBase::GetParticleColor");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //iColor
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((g_hSDKGetParticleColor = EndPrepSDKCall()) == null) { LogError("Failed to create SDKCall for CTFWeaponBase::GetParticleColor!"); sigFailure = true; } */
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFWeaponBaseGun::FireProjectile");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_hFireProjectile = EndPrepSDKCall()) == null) { LogError("Failed to create SDKCall for CTFWeaponBaseGun::FireProjectile!"); sigFailure = true; }
	
	if (sigFailure)
		SetFailState("One or more signatures failed!");
}

void DispatchParticleEffect3(char[] particleName, ParticleAttachment_t attachType, int entity, char[] attachmentName, float vecColor1[3], float vecColor2[3], bool useColors = true, bool resetAllParticles = false)
{
	SDKCall(g_hDispatchParticleEffect3, particleName, attachType, entity, attachmentName, vecColor1, vecColor2, useColors, resetAllParticles);
}

int CreateDroppedWeapon(int lastOwner, const float origin[3], const float angles[3], const char[] modelName, Address item)
{
	int entity;
	
	//Bypass MvM check in CTFDroppedWeapon::Create
	if (IsMannVsMachineMode())
	{
		GameRules_SetProp("m_bPlayingMannVsMachine", 0);
		entity = SDKCall(g_hDroppedWeaponCreate, lastOwner, origin, angles, modelName, item);
		GameRules_SetProp("m_bPlayingMannVsMachine", 1);
	}
	else
		entity = SDKCall(g_hDroppedWeaponCreate, lastOwner, origin, angles, modelName, item);
	
	return entity;
}

void InitDroppedWeapon(int droppedWeapon, int player, int weapon, bool swap, bool isSuicide = false)
{
	SDKCall(g_hInitDroppedWeapon, droppedWeapon, player, weapon, swap, isSuicide);
}

/* float[] GetWeaponParticleColor(int weapon, int color)
{
	float vec[3];
	SDKCall(g_hSDKGetParticleColor, weapon, vec, color);
	return vec;
} */

int TFWeaponFireProjectile(int weapon, int player)
{
	return SDKCall(g_hFireProjectile, weapon, player);
}