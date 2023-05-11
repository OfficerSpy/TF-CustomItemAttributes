Handle g_hSDKDispatchParticleEffect3;
// Handle g_hSDKGetParticleColor;

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
	if ((g_hSDKDispatchParticleEffect3 = EndPrepSDKCall()) == null) { LogError("Failed to create SDKCall for DispatchParticleEffect!"); sigFailure = true; }
	
	//FIXME: attempting to make this call will crash the game
	/* StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFWeaponBase::GetParticleColor");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //iColor
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((g_hSDKGetParticleColor = EndPrepSDKCall()) == null) { LogError("Failed to create SDKCall for CTFWeaponBase::GetParticleColor!"); sigFailure = true; } */
	
	if (sigFailure)
		SetFailState("One or more signatures failed!");
}

void DispatchParticleEffect3(char[] particleName, ParticleAttachment_t attachType, int entity, char[] attachmentName, float vecColor1[3], float vecColor2[3], bool useColors = true, bool resetAllParticles = false)
{
	SDKCall(g_hSDKDispatchParticleEffect3, particleName, attachType, entity, attachmentName, vecColor1, vecColor2, useColors, resetAllParticles);
}

/* float[] GetWeaponParticleColor(int weapon, int color)
{
	float vec[3];
	SDKCall(g_hSDKGetParticleColor, weapon, vec, color);
	return vec;
} */