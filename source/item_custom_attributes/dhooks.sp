//I really should stop using this structure
//But I love it soo much

enum struct DetourData
{
	DynamicDetour detour;
	DHookCallback callbackPre;
	DHookCallback callbackPost;
}

static ArrayList g_DynamicDetours;
static ArrayList g_DynamicHookIds;

static DynamicHook g_DHookWeaponSound;
static DynamicHook g_DHookIsDeflectable;
static DynamicHook g_DHookEvent_Killed;
static DynamicHook g_DHookFireProjectile;
static DynamicHook g_DHookPerformCustomPhysics;
static DynamicHook g_DHookCheckFalling;

#if defined ATTRIBUTE_ENHANCEMENTS
static DynamicHook g_DHookGetCustomProjectileModel;
#endif

static Address g_pGameMovement;
static int iOffsetGameMovement_Player;

void DHooks_Initialize()
{	
	g_DynamicDetours = new ArrayList(sizeof(DetourData));
	g_DynamicHookIds = new ArrayList();
	
	GameData hGamedata = new GameData("tf2.customitemattribs");
	if (hGamedata)
	{
#if defined EXPERIMENTAL_PERFORMANCE
		DHooks_AddDynamicDetour(hGamedata, "CTraceFilterObject::ShouldHitEntity", DHookCallback_ShouldHitEntity_Pre);
#endif
		
		DHooks_AddDynamicDetour(hGamedata, "CTFPlayerShared::StunPlayer", DHookCallback_StunPlayer_Pre);
		DHooks_AddDynamicDetour(hGamedata, "CBaseObject::FindSnapToBuildPos", DHookCallback_FindSnapToBuildPos_Pre, DHookCallback_FindSnapToBuildPos_Post); //TODO: replace with FindBuildPointOnPlayer
		DHooks_AddDynamicDetour(hGamedata, "CTFPlayer::IsAllowedToTaunt", DHookCallback_IsAllowedToTaunt_Pre);
		DHooks_AddDynamicDetour(hGamedata, "CGameMovement::PlayerMove", DHookCallback_PlayerMove_Pre);
		
		g_DHookWeaponSound = DHooks_AddDynamicHook(hGamedata, "CBaseCombatWeapon::WeaponSound");
		g_DHookIsDeflectable = DHooks_AddDynamicHook(hGamedata, "CBaseEntity::IsDeflectable");
		g_DHookEvent_Killed = DHooks_AddDynamicHook(hGamedata, "CTFPlayer::Event_Killed");
		g_DHookFireProjectile = DHooks_AddDynamicHook(hGamedata, "CTFWeaponBaseGun::FireProjectile");
		g_DHookPerformCustomPhysics = DHooks_AddDynamicHook(hGamedata, "CBaseEntity::PerformCustomPhysics");
		g_DHookCheckFalling = DHooks_AddDynamicHook(hGamedata, "CGameMovement::CheckFalling");
		
#if defined ATTRIBUTE_ENHANCEMENTS
		g_DHookGetCustomProjectileModel = DHooks_AddDynamicHook(hGamedata, "CTFWeaponBaseGun::GetCustomProjectileModel");
#endif
		
		iOffsetGameMovement_Player = hGamedata.GetOffset("CGameMovement::player");
		
		delete hGamedata;
	}
	else
	{
		SetFailState("Could not find tf2.customitemattribs gamedata!");
	}
}

static DynamicHook DHooks_AddDynamicHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (!hook)
	{
		LogError("Failed to create hook setup handle for %s", name);
	}
	
	return hook;
}

static void DHooks_HookEntity(DynamicHook hook, HookMode mode, int entity, DHookCallback callback)
{
	if (hook)
	{
		int hookid = hook.HookEntity(mode, entity, callback, DHookRemovalCB_OnHookRemoved);
		if (hookid != INVALID_HOOK_ID)
		{
			g_DynamicHookIds.Push(hookid);
		}
	}
}

public void DHookRemovalCB_OnHookRemoved(int hookid)
{
	int index = g_DynamicHookIds.FindValue(hookid);
	if (index != -1)
	{
		g_DynamicHookIds.Erase(index);
	}
}

static void DHooks_AddDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		DetourData data;
		data.detour = detour;
		data.callbackPre = callbackPre;
		data.callbackPost = callbackPost;
		
		g_DynamicDetours.PushArray(data);
	}
	else
	{
		LogError("Failed to create detour setup handle for %s", name);
	}
}

void DHooks_Toggle(bool enable)
{
	for (int i = 0; i < g_DynamicDetours.Length; i++)
	{
		DetourData data;
		if (g_DynamicDetours.GetArray(i, data))
		{
			if (data.callbackPre != INVALID_FUNCTION)
			{
				if (enable)
				{
					data.detour.Enable(Hook_Pre, data.callbackPre);
				}
				else
				{
					data.detour.Disable(Hook_Pre, data.callbackPre);
				}
			}
			
			if (data.callbackPost != INVALID_FUNCTION)
			{
				if (enable)
				{
					data.detour.Enable(Hook_Post, data.callbackPost);
				}
				else
				{
					data.detour.Disable(Hook_Post, data.callbackPost);
				}
			}
		}
	}
	
	if (!enable)
	{
		//Remove virtual hooks
		for (int i = g_DynamicHookIds.Length - 1; i >= 0; i--)
		{
			int hookid = g_DynamicHookIds.Get(i);
			DynamicHook.RemoveHook(hookid);
		}
	}
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "tf_weapon") != -1)
	{
		SDKHook(entity, SDKHook_SpawnPost, DHooksWeaponSpawnPost);
		DHooks_HookEntity(g_DHookWeaponSound, Hook_Pre, entity, DHookCallback_WeaponSound_Pre);
	}
	
	if (StrContains(classname, "tf_projectile") != -1)
	{
		DHooks_HookEntity(g_DHookIsDeflectable, Hook_Pre, entity, DHookCallback_IsDeflectable_Pre);
		DHooks_HookEntity(g_DHookPerformCustomPhysics, Hook_Pre, entity, DHookCallback_PerformCustomPhysics_Pre);
	}
}

void DHooks_OnClientPutInServer(int client)
{
	DHooks_HookEntity(g_DHookEvent_Killed, Hook_Pre, client, DHookCallback_EventKilled_Pre);
}

public void DHooksWeaponSpawnPost(int entity)
{
	if (IsWeaponBaseGun(entity))
	{
		DHooks_HookEntity(g_DHookFireProjectile, Hook_Post, entity, DHookCallback_FireProjectile_Post);
		
#if defined ATTRIBUTE_ENHANCEMENTS
		DHooks_HookEntity(g_DHookGetCustomProjectileModel, Hook_Post, entity, DHookCallback_GetCustomProjectileModel_Post);
#endif
	}
}

#if defined EXPERIMENTAL_PERFORMANCE
static MRESReturn DHookCallback_ShouldHitEntity_Pre(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
	int entity = DHookGetParam(hParams, 1); //The entity we're hitting
	
	//This retrieves the entity performing the trace
	//Taken from owned_building_phasing
	Address pEntity = DereferencePointer(pThis + view_as<Address>(0x04));
	int passEntity = GetEntityFromAddress(pEntity);
	
	if (IsValidClientIndex(passEntity))
	{
		bool entityhit_player = IsValidClientIndex(entity);
		
#if defined JOINBLU_BUSTER_ROBOT
		if (entityhit_player || (IsBaseObject(entity) && !IsSentryBusterRobot(passEntity)))
#else
		if (entityhit_player || IsBaseObject(entity))
#endif
		{
			int not_solid = TF2Attrib_HookValueInt(0, "not_solid_to_players", passEntity);
			
			//This player doesn't collide with players or buildings
			if (not_solid != 0)
			{
				hReturn.Value = false;
				return MRES_Supercede;
			}
			
			if (entityhit_player)
			{
				int not_solid1 = TF2Attrib_HookValueInt(0, "not_solid_to_players", entity);
				
				//Players and buildings don't collide with this player
				if (not_solid1 != 0)
				{
					hReturn.Value = false;
					return MRES_Supercede;
				}
			}
		}
	}
	
	return MRES_Ignored;
}
#endif //EXPERIMENTAL_PERFORMANCE

static MRESReturn DHookCallback_StunPlayer_Pre(Address pThis, DHookParam hParams)
{
	int player = TF2Util_GetPlayerFromSharedAddress(pThis);
	float stun = TF2Attrib_HookValueFloat(1.0, "mult_stun_resistance", player);
	
	if (stun != 1.0)
	{
		float slowdown = hParams.Get(2);
		
		slowdown *= stun;
		hParams.Set(2, slowdown);
		
		return MRES_ChangedHandled;
	}
	
	return MRES_Ignored;
}

//This is a dumb way of doing this but I cannot be bothered to find
//the signature for CBaseObject::FindBuildPointOnPlayer right now
static MRESReturn DHookCallback_FindSnapToBuildPos_Pre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			int noSap = TF2Attrib_HookValueInt(0, "cannot_be_sapped", i);
			
			//Make this bot unsappable
			if (noSap > 0)
				TF2_AddCondition(i, TFCond_Sapped);
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_FindSnapToBuildPos_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			int noSap = TF2Attrib_HookValueInt(0, "cannot_be_sapped", i);
			
			if (noSap > 0)
				TF2_RemoveCondition(i, TFCond_Sapped);
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_IsAllowedToTaunt_Pre(int pThis, DHookReturn hReturn)
{
	int cannotTaunt = TF2Attrib_HookValueInt(0, "cannot_taunt", pThis);
	
	if (cannotTaunt)
	{
		hReturn.Value = false;
		return MRES_Supercede;
	}
	
	if (IsPlayerAlive(pThis))
	{
		int allowTaunt = TF2Attrib_HookValueInt(0, "always_allow_taunt", pThis);
		
		if (allowTaunt > 1 || (allowTaunt == 1 && !TF2_IsPlayerInCondition(pThis, TFCond_Taunting)))
		{
			hReturn.Value = true;
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_PlayerMove_Pre(Address pThis)
{
	//This detour only serves one purpose, and it's to obtain the g_pGameMovement object in memory
	//Ideally there is probably a better way, but this seemed like the easiest option for now
	if (!g_pGameMovement)
	{
		g_pGameMovement = pThis;
		
		DHookRaw(g_DHookCheckFalling, false, g_pGameMovement, _, DHookCallback_CheckFalling_Pre);
		
		LogMessage("DHookCallback_PlayerMove_Pre: setting raw data of g_pGameMovement");
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_WeaponSound_Pre(int pThis, DHookParam hParams)
{
	int index = hParams.Get(1);
	
	if (index == SINGLE || index == BURST || index == MELEE_MISS || index == MELEE_HIT || index == MELEE_HIT_WORLD || index == RELOAD || index == SPECIAL1 || index == SPECIAL3)
	{
		char sound[128];
		switch(index)
		{
			case SINGLE, BURST, MELEE_MISS, SPECIAL1, SPECIAL3:	TF2Attrib_HookValueString("", "custom_weapon_fire_sound", pThis, sound, sizeof(sound));
			case MELEE_HIT, MELEE_HIT_WORLD:	TF2Attrib_HookValueString("", "custom_impact_sound", pThis, sound, sizeof(sound));
			case RELOAD:	TF2Attrib_HookValueString("", "custom_weapon_reload_sound", pThis, sound, sizeof(sound));
		}
		
		if (strlen(sound) > 0)
		{
			// int owner = TF2_GetEntityOwner(pThis);
			float soundtime = hParams.Get(2);
			
			PrecacheSound(sound);
			EmitSoundToAll(sound, _, _, _, _, _, _, _, _, _, _, soundtime);
			
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_IsDeflectable_Pre(int pThis, DHookReturn hReturn)
{
	int weapon = GetEntPropEnt(pThis, Prop_Send, "m_hOriginalLauncher");
	
	if (weapon == -1)
		return MRES_Ignored;
	
	int cannotDeflect = TF2Attrib_HookValueInt(0, "projectile_no_deflect", weapon);
	
	if (cannotDeflect != 0)
	{
		hReturn.Value = false;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_EventKilled_Pre(int pThis, DHookParam hParams)
{
	//TODO: get data from CTakeDamageInfo
	for (int w = 0; w <= TFWeaponSlot_Melee; w++)
	{
		int weapon = GetPlayerWeaponSlot(pThis, w);
		
		if (weapon != -1 && weapon != TF2_GetClientActiveWeapon(pThis))
		{
			int droppedWeapon = TF2Attrib_HookValueInt(0, "is_dropped_weapon",  weapon);
			
			if (droppedWeapon != 0)
			{
				float angles[3]; GetClientAbsAngles(pThis, angles);
				int dropped = CreateDroppedWeapon(pThis, GetEyePosition(pThis), angles, GetWorldModel(weapon), GetEconItemView(weapon));
				
				if (IsValidEntity(dropped))
					InitDroppedWeapon(dropped, pThis, weapon, false, false);
			}
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_FireProjectile_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	static bool bSkip;
	
	//Prevent a recursive detour
	if (bSkip)
		return MRES_Ignored;
	
	int proj = hReturn.Value;
	int player = hParams.Get(1);
	int attr_projectile_count = TF2Attrib_HookValueInt(1, "mult_projectile_count", pThis);
	
	if (proj > 0)
		SetCustomProjectileModel(pThis, proj);
	
	bSkip = true;
	for (int i = 1; i < attr_projectile_count; i++) //Start from 1 since we still let the original pass
	{
		int newProj = TFWBG_FireProjectile(pThis, player);
		CustomlyModifyLaunchedProjectile(pThis, newProj, false);
	}
	bSkip = false;
	
	//Modify the original
	if (proj > 0)
		CustomlyModifyLaunchedProjectile(pThis, proj, true);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_PerformCustomPhysics_Pre(int pThis, DHookParam hParams)
{
	float newPosition[3], newVelocity[3], newAngles[3], newAngVelocity[3];
	
	hParams.GetVector(1, newPosition);
	hParams.GetVector(2, newVelocity);
	hParams.GetVector(3, newAngles);
	hParams.GetVector(4, newAngVelocity);
	
	if (PerformCustomPhysics(pThis, newPosition, newVelocity, newAngles, newAngVelocity))
	{
		hParams.SetVector(1, newPosition);
		hParams.SetVector(2, newVelocity);
		hParams.SetVector(3, newAngles);
		hParams.SetVector(4, newAngVelocity);
		
		/* PrintToChatAll("newPosition %.2f %.2f %.2f", newPosition[0], newPosition[1], newPosition[2]);
		PrintToChatAll("newVelocity %.2f %.2f %.2f", newVelocity[0], newVelocity[1], newVelocity[2]);
		PrintToChatAll("newAngles %.2f %.2f %.2f", newAngles[0], newAngles[1], newAngles[2]);
		PrintToChatAll("newAngVelocity %.2f %.2f %.2f", newAngVelocity[0], newAngVelocity[1], newAngVelocity[2]); */
		
		return MRES_ChangedHandled;
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CheckFalling_Pre(Address pThis)
{
	Address playerPtr = view_as<Address>(LoadFromAddress(pThis + view_as<Address>(iOffsetGameMovement_Player), NumberType_Int32));
	int player = GetEntityFromAddress(playerPtr);
	
	float fall = GetEntPropFloat(player, Prop_Send, "m_flFallVelocity");
	
	if (Player_GetGroundEntity(player) != -1 && IsPlayerAlive(player) && fall > 0.0)
	{
		float fallMinVel = TF2Attrib_HookValueFloat(0.0, "kb_fall_min_velocity", player);
		float kbRadius = TF2Attrib_HookValueFloat(0.0, "kb_fall_radius", player);
		float kbStunTime = TF2Attrib_HookValueFloat(0.0, "kb_fall_stun_time", player);
		float kbStrength = TF2Attrib_HookValueFloat(0.0, "kb_fall_force", player);
		float kbDamage = TF2Attrib_HookValueFloat(0.0, "kb_fall_damage", player);
		
		if (fallMinVel != 0.0 && fall > fallMinVel)
		{
			if (kbRadius == 0.0)
				kbRadius = 230.0;
			
			if (kbStunTime == 0.0)
				kbStunTime = 5.0;
			
			if (kbStrength == 0.0)
				kbStrength = 300.0;
			
			if (kbDamage == 0.0)
				kbDamage = 50.0;
			
			float point[3]; GetClientAbsOrigin(player, point);
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) == GetClientTeam(player))
					continue;
				
				float themEyePos[3]; GetClientEyePosition(i, themEyePos);
				float toPlayer[3]; SubtractVectors(themEyePos, point, toPlayer);
				
				//This is literally a recreation of CTFGameRules::PushAllPlayersAway
				if (GetVectorLength(toPlayer, true) < kbRadius * kbRadius)
				{
					toPlayer[2] = 0.0;
					NormalizeVector(toPlayer, toPlayer);
					toPlayer[2] = 1.0;
					
					float vPush[3]; vPush = toPlayer;
					ScaleVector(vPush, kbStrength);
					
					VS_ApplyAbsVelocityImpulse(i, vPush);
					SDKHooks_TakeDamage(i, player, player, kbDamage, DMG_FALL, -1, NULL_VECTOR, point);
					
					if (!IsMiniBoss(i) && kbStunTime > 0.0)
						TF2_StunPlayer(i, kbStunTime, 0.85, 2, player);
				}
			}
		}
	}
	
	return MRES_Ignored;
}

#if defined ATTRIBUTE_ENHANCEMENTS
static MRESReturn DHookCallback_GetCustomProjectileModel_Post(int pThis, DHookParam hParams)
{
	char model_path[256]; hParams.GetString(1, model_path, sizeof(model_path));
	
	// PrintToChatAll("GetCustomProjectileModel %s", model_path);
	
	//The function is called before a custom model is set on the weapon but
	//it's not precached so we precache it here to prevent an engine crash
	if (strlen(model_path) > 0)
		PrecacheModel(model_path);
	
	return MRES_Ignored;
}
#endif