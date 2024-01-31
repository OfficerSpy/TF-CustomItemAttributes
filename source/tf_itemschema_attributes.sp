#include <sourcemod>
#include <dhooks>
#include <sdkhooks>
#include <tf2attributes>
#include <tf2utils>

#pragma semicolon 1
#pragma newdecls required

#define FLT_MAX	view_as<float>(0x7f7fffff)
#define FLT_MIN	view_as<float>(0x00800000)
#define DEG2RAD(%1) ((%1) * FLOAT_PI / 180.0)

#define MAX_EDICTS	2048

#define ATTRIBUTE_ENHANCEMENTS
// #define JOINBLU_BUSTER_ROBOT

// #define EXPERIMENTAL_PERFORMANCE

enum //WeaponSound_t
{
	EMPTY,
	SINGLE,
	SINGLE_NPC,
	WPN_DOUBLE,
	DOUBLE_NPC,
	BURST,
	RELOAD,
	RELOAD_NPC,
	MELEE_MISS,
	MELEE_HIT,
	MELEE_HIT_WORLD,
	SPECIAL1,
	SPECIAL2,
	SPECIAL3,
	TAUNT,
	DEPLOY,
	NUM_SHOOT_SOUND_TYPES,
};

enum ParticleAttachment_t
{
	PATTACH_ABSORIGIN = 0,
	PATTACH_ABSORIGIN_FOLLOW,
	PATTACH_CUSTOMORIGIN,
	PATTACH_POINT,
	PATTACH_POINT_FOLLOW,
	PATTACH_WORLDORIGIN,
	PATTACH_ROOTBONE_FOLLOW
};

enum //ProjectileType_t
{
	TF_PROJECTILE_NONE,
	TF_PROJECTILE_BULLET,
	TF_PROJECTILE_ROCKET,
	TF_PROJECTILE_PIPEBOMB,
	TF_PROJECTILE_PIPEBOMB_REMOTE,
	TF_PROJECTILE_SYRINGE,
	TF_PROJECTILE_FLARE,
	TF_PROJECTILE_JAR,
	TF_PROJECTILE_ARROW,
	TF_PROJECTILE_FLAME_ROCKET,
	TF_PROJECTILE_JAR_MILK,
	TF_PROJECTILE_HEALING_BOLT,
	TF_PROJECTILE_ENERGY_BALL,
	TF_PROJECTILE_ENERGY_RING,
	TF_PROJECTILE_PIPEBOMB_PRACTICE,
	TF_PROJECTILE_CLEAVER,
	TF_PROJECTILE_STICKY_BALL,
	TF_PROJECTILE_CANNONBALL,
	TF_PROJECTILE_BUILDING_REPAIR_BOLT,
	TF_PROJECTILE_FESTIVE_ARROW,
	TF_PROJECTILE_THROWABLE,
	TF_PROJECTILE_SPELL,
	TF_PROJECTILE_FESTIVE_JAR,
	TF_PROJECTILE_FESTIVE_HEALING_BOLT,
	TF_PROJECTILE_BREADMONSTER_JARATE,
	TF_PROJECTILE_BREADMONSTER_MADMILK,
	TF_PROJECTILE_GRAPPLINGHOOK,
	TF_PROJECTILE_SENTRY_ROCKET,
	TF_PROJECTILE_BREAD_MONSTER,
	TF_PROJECTILE_JAR_GAS,
	TF_PROJECTILE_BALLOFFIRE,
	TF_NUM_PROJECTILES
};

//Homing Rockets
//TODO: please use a methodmap for this shit
//Using it in the code as it is is fucking atrocious
bool HR_enabled[MAX_EDICTS + 1];
bool HR_ignoreDisguised[MAX_EDICTS + 1] = {true, ...};
bool HR_ignoreStealthed[MAX_EDICTS + 1] = {true, ...};
bool HR_followCrosshair[MAX_EDICTS + 1];
bool HR_predictTargetSpeed[MAX_EDICTS + 1] = {true, ...};
float HR_speed[MAX_EDICTS + 1] = {1.0, ...};
float HR_turnPower[MAX_EDICTS + 1];
float HR_minDotProduct[MAX_EDICTS + 1] = {-0.25, ...};
float HR_aimTIme[MAX_EDICTS + 1] = {9999.0, ...};
float HR_aimStartTime[MAX_EDICTS + 1];
float HR_acceleration[MAX_EDICTS + 1];
float HR_accelerationTime[MAX_EDICTS + 1] = {9999.0, ...};
float HR_accelerationStart[MAX_EDICTS + 1];
float HR_gravity[MAX_EDICTS + 1];
bool HR_homedIn[MAX_EDICTS + 1];
float HR_homedInAngle[MAX_EDICTS + 1][3];

ConVar sv_stepsize;

#include "item_custom_attributes/dhooks.sp"
#include "item_custom_attributes/events.sp"
#include "item_custom_attributes/sdkhooks.sp"
#include "item_custom_attributes/sdkcalls.sp"

public Plugin myinfo = 
{
	name = "[TF2] Custom Item Schema Attributes",
	author = "Officer Spy",
	description = "Checks for extra attributes that were injected by another mod.",
	version = "1.1.4",
	url = ""
};

public void OnPluginStart()
{
	sv_stepsize = FindConVar("sv_stepsize");
	
	HookGameEvents();
	SetupSDKCalls();
	DHooks_Initialize();
}

public void OnConfigsExecuted()
{
	DHooks_Toggle(true);
}

public void OnEntityCreated(int entity, const char[] classname)
{	
	if (StrContains(classname, "tf_projectile") != -1)
		SDKHook(entity, SDKHook_SpawnPost, ProjectileSpawnPost);
	
	DHooks_OnEntityCreated(entity, classname);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	//Simulating here as if this was CTFPlayer::TFPlayerThink
	float stepMult = TF2Attrib_HookValueFloat(1.0, "mult_step_height", client);
	
	if (stepMult != 1.0)
		SetEntPropFloat(client, Prop_Send, "m_flStepSize", stepMult * sv_stepsize.FloatValue);
	
	return Plugin_Continue;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	switch(condition)
	{
		case TFCond_ParachuteDeployed:
		{
			int parachuteRedeploy = TF2Attrib_HookValueInt(0, "parachute_redeploy", client);
			
			if (parachuteRedeploy != 0)
				TF2_RemoveCondition(client, condition);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, PlayerOnTakeDamage);
	
	DHooks_OnClientPutInServer(client);
}

void SetCustomProjectileModel(int weapon, int proj)
{
#if defined ATTRIBUTE_ENHANCEMENTS
	char classname[128]; GetEntityClassname(proj, classname, sizeof(classname));
	
	//Ignore grenades, game already does this for them
	if (StrContains(classname, "tf_projectile_pipe") == -1)
	{
		//Not a custom attribute, but an enhancement
		char modelName[128]; TF2Attrib_HookValueString("", "custom_projectile_model", weapon, modelName, sizeof(modelName));
		if (strlen(modelName) > 0)
			SetEntityModel(proj, modelName);
	}
#endif
	
	float modelScale = TF2Attrib_HookValueFloat(1.0, "mult_projectile_scale", weapon);
	if (modelScale != 1.0)
		SetEntPropFloat(proj, Prop_Send, "m_flModelScale", modelScale);
	
	float collScale = TF2Attrib_HookValueFloat(0.0, "custom_projectile_size", weapon);
	if (collScale != 0.0)
	{
		float min[3], max[3];
		
		min[0] -= collScale;
		min[1] -= collScale;
		min[2] -= collScale;
		
		max[0] += collScale;
		max[1] += collScale;
		max[2] += collScale;
		
		VS_SetSize(proj, min, max);
	}
}

void CustomlyModifyLaunchedProjectile(int weapon, int projectile, bool isNativeSpawned)
{
	char particleName[128]; TF2Attrib_HookValueString("", "projectile_trail_particle", weapon, particleName, sizeof(particleName));
	if (strlen(particleName) > 0)
	{
		// float color0[3], color1[3];
		
		// color0 = GetWeaponParticleColor(weapon, 1);
		// color1 = GetWeaponParticleColor(weapon, 2);
		
		//TODO: replace temporary entity with DispatchParticleEffect with color
		if (StrContains(particleName, "~") != -1)
		{
			ReplaceString(particleName, sizeof(particleName), "~", "");
			
			TE_SetupTFParticleEffect(particleName, NULL_VECTOR, _, _, projectile, PATTACH_ABSORIGIN_FOLLOW, _, true);
			TE_SendToAll();
		}
		else
		{
			TE_SetupTFParticleEffect(particleName, NULL_VECTOR, _, _, projectile, PATTACH_ABSORIGIN_FOLLOW, _, false);
			TE_SendToAll();
		}
	}
	
	//Natively spawned projectiles already have this done to them
	//Only modify the ones created by the mod
	if (!isNativeSpawned)
		TFWBG_ModifyProjectile(weapon, projectile);
	
	float gravity = TF2Attrib_HookValueFloat(0.0, "projectile_gravity_native", weapon);
	
	if (gravity != 0.0)
		SetEntityGravity(projectile, gravity);
	
	char soundName[128]; TF2Attrib_HookValueString("", "projectile_sound", weapon, soundName, sizeof(soundName));
	
	if (strlen(soundName) > 0)
	{
		PrecacheSound(soundName);
		BaseEntity_EmitSound(projectile, soundName);
	}
}

//TODO: maybe implement CTakeDamageInfo into here at some point?
void ApplyOnHitAttributes(int weapon, int victim, int attacker, float damage)
{
	char soundName[128]; TF2Attrib_HookValueString("", "custom_hit_sound", weapon, soundName, sizeof(soundName));
	
	if (strlen(soundName) > 0)
	{
		PrecacheSound(soundName);
		BaseEntity_EmitSound(victim, soundName);
	}
}

//CBaseEntity *ent, Vector *pNewPosition, Vector *pNewVelocity, QAngle *pNewAngles, QAngle *pNewAngVelocity
bool PerformCustomPhysics(int ent, float pNewPosition[3], float pNewVelocity[3], float pNewAngles[3], float pNewAngVelocity[3])
{
	int proj = ent;
	// float seek = 0.0;
	if (!IsValidEntity(proj))
		return false;
	
	if (!HR_enabled[proj])
		return false;
	
	float time = float(GetEntProp(ent, Prop_Send, "m_flSimulationTime")) - float(GetEntProp(ent, Prop_Send, "m_flAnimTime"));
	
	float speed_calculated = HR_speed[proj] + HR_acceleration[proj] * UTIL_Clamp(time - HR_accelerationStart[proj], 0.0, HR_accelerationTime[proj]);
	
	float interval = (3000.0 / speed_calculated) * 0.014;
	
	if (HR_turnPower[proj] != 0.0 && time >= HR_aimStartTime[proj] && time < HR_aimTIme[proj] && GetGameTickCount() % RoundToCeil(interval / GetTickInterval()) == 0)
	{
		float target_vec[3]; target_vec = NULL_VECTOR;
		
		if (HR_followCrosshair[proj])
		{
			int owner = TF2_GetEntityOwner(proj);
			if (owner != -1)
			{
				float ownerEyeAngles[3]; GetClientEyeAngles(owner, ownerEyeAngles);
				float vForward[3]; GetAngleVectors(ownerEyeAngles, vForward, NULL_VECTOR, NULL_VECTOR);
				
				float vTemp[3];	vTemp = GetEyePosition(owner);
				vTemp[0] = vTemp[0] + 4000.0 * vForward[0];
				vTemp[1] = vTemp[1] + 4000.0 * vForward[1];
				vTemp[2] = vTemp[2] + 4000.0 * vForward[2];
				
				Handle trace = TR_TraceRayFilterEx(GetEyePosition(owner), vTemp, MASK_SHOT, RayType_EndPoint, TraceFilterIgnoreFriendlyCombatItems, owner);
				
				TR_GetEndPosition(target_vec, trace);
				
				delete trace;
			}
		}
		else
		{
			float target_dotproduct = FLT_MIN;
			int target_player = -1;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i))
					continue;
				
				if (!IsPlayerAlive(i))
					continue;
				
				if (TF2_GetClientTeam(i) == TFTeam_Spectator)
					continue;
				
				if (TF2_GetClientTeam(i) == TF2_GetTeam(proj))
					continue;
				
				if (HR_ignoreDisguised[proj])
					if (TF2_IsPlayerInCondition(i, TFCond_Disguised) && GetDisguiseTeam(i) == TF2_GetTeam(proj))
						continue;
				
				if (HR_ignoreStealthed[proj])
					if (IsStealthed(i) && GetPercentInvisible(i) >= 0.75 && !TF2_IsPlayerInCondition(i, TFCond_CloakFlicker) && !TF2_IsPlayerInCondition(i, TFCond_OnFire) && !TF2_IsPlayerInCondition(i, TFCond_Jarated) && !TF2_IsPlayerInCondition(i, TFCond_Bleeding))
						continue;
				
				float delta[3]; SubtractVectors(WorldSpaceCenter(i), WorldSpaceCenter(proj), delta);
				
				float mindotproduct = HR_minDotProduct[proj];
				
				float deltaNoramlized[3];	NormalizeVector(delta, deltaNoramlized);
				float newVelocityNormalized[3];	NormalizeVector(pNewVelocity, newVelocityNormalized);
				float dotproduct = GetVectorDotProduct(deltaNoramlized, newVelocityNormalized);
				
				if (dotproduct < mindotproduct)
					continue;
				
				if (dotproduct > target_dotproduct)
				{
					bool noclip = GetEntityMoveType(proj) == MOVETYPE_NOCLIP;
					
					Handle trace;
					
					if (!noclip)
						trace = TR_TraceRayFilterEx(WorldSpaceCenter(i), WorldSpaceCenter(proj), MASK_SOLID_BRUSHONLY, RayType_EndPoint, Filter_IgnoreData, i);
					
					if (noclip || !TR_DidHit(trace) || TR_GetEntityIndex(trace) == proj)
					{
						target_player = i;
						target_dotproduct = dotproduct;
					}
					
					delete trace;
				}
			}
			
			if (IsValidEntity(target_player))
			{
				target_vec = WorldSpaceCenter(target_player);
				float target_distance = GetVectorDistance(WorldSpaceCenter(proj), WorldSpaceCenter(target_player));
				
				if (HR_predictTargetSpeed[proj])
				{
					float vTemp[3]; vTemp = GetAbsVelocity(target_player);
					vTemp[0] = vTemp[0] * target_distance / speed_calculated;
					vTemp[1] = vTemp[1] * target_distance / speed_calculated;
					vTemp[2] = vTemp[2] * target_distance / speed_calculated;
					
					AddVectors(target_vec, vTemp, target_vec);
				}
			}
		}
		
		if (!IsZeroVector(target_vec))
		{
			float angToTarget[3];
			
			float vTemp[3]; SubtractVectors(target_vec, WorldSpaceCenter(proj), vTemp);
			GetVectorAngles(vTemp, angToTarget);
			
			HR_homedIn[proj] = true;
			HR_homedInAngle[proj] = angToTarget;
		}
		else
			HR_homedIn[proj] = false;
	}
		
	if (HR_homedIn[proj])
	{
		float ticksPerSecond = 1.0 / GetGameFrameTime();
		pNewAngVelocity[0] = (UTIL_ApproachAngle(HR_homedInAngle[proj][0], pNewAngles[0], HR_turnPower[proj] * GetGameFrameTime()) - pNewAngles[0]) * ticksPerSecond;
		pNewAngVelocity[1] = (UTIL_ApproachAngle(HR_homedInAngle[proj][1], pNewAngles[1], HR_turnPower[proj] * GetGameFrameTime()) - pNewAngles[1]) * ticksPerSecond;
		pNewAngVelocity[2] = (UTIL_ApproachAngle(HR_homedInAngle[proj][2], pNewAngles[2], HR_turnPower[proj] * GetGameFrameTime()) - pNewAngles[2]) * ticksPerSecond;
	}
	
	if (time < HR_aimTIme[proj])
	{
		float vTemp[3];	vTemp = pNewAngVelocity;
		ScaleVector(vTemp, GetGameFrameTime());
		AddVectors(pNewAngles, vTemp, pNewAngles);
	}
	
	float vecOrientation[3];
	GetAngleVectors(pNewAngles, vecOrientation, NULL_VECTOR, NULL_VECTOR);
	
	float vTemp[3];	vTemp = vecOrientation;
	ScaleVector(vTemp, speed_calculated);
	
	float vTemp1[3]; vTemp1[2] = -HR_gravity[proj] * time;
	AddVectors(vTemp, vTemp1, pNewVelocity);
	
	//No gravity bitches?
	
	float vTemp2[3];	vTemp2 = pNewVelocity;
	ScaleVector(vTemp2, GetGameFrameTime());
	
	AddVectors(pNewPosition, vTemp2, pNewPosition);
	return true;
}

public bool TraceFilterIgnoreFriendlyCombatItems(int entity, int contentsMask, any data)
{
	char classname[64];	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (StrEqual(classname, "entity_revive_marker") || StrEqual(classname, "entity_medigun_shield"))
	{
		if (TF2_GetTeam(entity) == TF2_GetClientTeam(data))
			return false;
		
		//m_bNoChain check but we don't care about it
	}
	
	return !(entity == data);
}

public bool Filter_IgnoreData(int entity, int contentsMask, any data)
{
	return entity != data;
}

stock bool IsValidClientIndex(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

stock bool IsBaseObject(int entity)
{
	return HasEntProp(entity, Prop_Data, "CBaseObjectUpgradeThink");
}

//From stocksoup/memory.inc
stock Address DereferencePointer(Address addr) {
	// maybe someday we'll do 64-bit addresses
	return view_as<Address>(LoadFromAddress(addr, NumberType_Int32));
}

//From stocksoup/memory.inc
stock int GetEntityFromAddress(Address pEntity) {
	static int offs_RefEHandle;
	if (offs_RefEHandle) {
		return LoadEntityHandleFromAddress(pEntity + view_as<Address>(offs_RefEHandle));
	}
	
	// if we don't have it already, attempt to lookup offset based on SDK information
	// CWorld is derived from CBaseEntity so it should have both offsets
	int offs_angRotation = FindDataMapInfo(0, "m_angRotation"),
			offs_vecViewOffset = FindDataMapInfo(0, "m_vecViewOffset");
	if (offs_angRotation == -1) {
		ThrowError("Could not find offset for ((CBaseEntity) CWorld)::m_angRotation");
	} else if (offs_vecViewOffset == -1) {
		ThrowError("Could not find offset for ((CBaseEntity) CWorld)::m_vecViewOffset");
	} else if ((offs_angRotation + 0x0C) != (offs_vecViewOffset - 0x04)) {
		char game[32];
		GetGameFolderName(game, sizeof(game));
		ThrowError("Could not confirm offset of CBaseEntity::m_RefEHandle "
				... "(incorrect assumption for game '%s'?)", game);
	}
	
	// offset seems right, cache it for the next call
	offs_RefEHandle = offs_angRotation + 0x0C;
	return GetEntityFromAddress(pEntity);
}

//From stocksoup/memory.inc
stock int LoadEntityHandleFromAddress(Address addr) {
	return EntRefToEntIndex(LoadFromAddress(addr, NumberType_Int32) | (1 << 31));
}

//From stocksoup/tf/entity_prop_stocks.inc
stock int TF2_GetEntityOwner(int entity) {
	return GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
}

stock bool IsMiniBoss(int client)
{	
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_bIsMiniBoss"));
}

stock void VS_SetSize(int entity, float mins[3], float maxs[3])
{
	char buffer[256]; Format(buffer, sizeof(buffer), "!self.SetSize(Vector(%.2f, %.2f, %.2f), Vector(%.2f, %.2f, %.2f))", mins[0], mins[1], mins[2], maxs[0], maxs[1], maxs[2]);
	
	SetVariantString(buffer);
	AcceptEntityInput(entity, "RunScriptCode");
}

stock Address GetEconItemView(int item)
{
	char netclass[32];
	if (GetEntityNetClass(item, netclass, sizeof(netclass)))
	{
		int offset = FindSendPropInfo(netclass, "m_Item");
		
		if (offset < 0)
			ThrowError("Failed to find m_Item on: %s", netclass);
		
		return GetEntityAddress(item) + view_as<Address>(offset);
	}
	
	return Address_Null;
}

stock float[] GetEyePosition(int client)
{		
	float v[3];
	GetClientEyePosition(client, v);
	return v;
}

//From stocksoup/entity_prop_stocks.inc
stock int GetEntityModelPath(int entity, char[] buffer, int maxlen) {
	return GetEntPropString(entity, Prop_Data, "m_ModelName", buffer, maxlen);
}

stock bool IsMannVsMachineMode()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
}

//From stocksoup/tf/entity_prop_stocks.inc
stock int TF2_GetClientActiveWeapon(int client) {
	return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

stock char[] GetWorldModel(int entity)
{
	int index = GetEntProp(entity, Prop_Send, "m_iWorldModelIndex");
	char model[128]; ModelIndexToString(index, model, sizeof(model));
	return model;
}

stock void ModelIndexToString(int index, char[] model, int size)
{
	int table = FindStringTable("modelprecache");
	ReadStringTable(table, index, model, size);
}

stock bool IsSentryBusterRobot(int client)
{
	char model[PLATFORM_MAX_PATH];	GetClientModel(client, model, sizeof(model));
	
	// return StrEqual(model, "models/bots/demo/bot_sentry_buster.mdl");
	return StrContains(model, "sentry_buster") != -1;
}

stock bool IsWeaponBaseGun(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseGunZoomOutIn");
}

stock int GetProjectileOriginalLauncher(int projectile)
{
	return GetEntPropEnt(projectile, Prop_Send, "m_hOriginalLauncher");
}

stock float CalculateProjectileSpeed(int weapon)
{
	if (!IsValidEntity(weapon))
		return 0.0;
	
	float speed = 0.0;
	
	int weaponid = TF2Util_GetWeaponID(weapon);
	int projid = TF2Attrib_HookValueInt(0, "override_projectile_type", weapon);
	
	if (projid == 0)
		projid = TFWBG_GetWeaponProjectileType(weapon);
	
	switch(projid)
	{
		case TF_PROJECTILE_ROCKET:	speed = 1100.0;
		case TF_PROJECTILE_FLARE:	speed = 2000.0;
		case TF_PROJECTILE_SYRINGE:	speed = 1000.0;
		case TF_PROJECTILE_ENERGY_RING:
		{
			int penetrate = TF2Attrib_HookValueInt(0, "energy_weapon_penetration", weapon);
			speed = penetrate ? 840.0 : 1200.0;
		}
		case TF_PROJECTILE_BALLOFFIRE:	speed = 3000.0;
		default:	speed = TFWBG_GetProjectileSpeed(weapon);
	}
	
	if (weaponid != TF_WEAPON_GRENADELAUNCHER && weaponid != TF_WEAPON_CANNON && weaponid != TF_WEAPON_CROSSBOW && weaponid != TF_WEAPON_COMPOUND_BOW && weaponid != TF_WEAPON_GRAPPLINGHOOK && weaponid != TF_WEAPON_SHOTGUN_BUILDING_RESCUE)
	{
		float mult_speed = TF2Attrib_HookValueFloat(1.0, "mult_projectile_speed", weapon);
		speed *= mult_speed;
	}
	
	if (projid == TF_PROJECTILE_ROCKET)
	{
		int specialist = TF2Attrib_HookValueInt(0, "rocket_specialist", weapon);
		speed *= RemapVal(float(specialist), 1.0, 4.0, 1.15, 1.6);
	}
	
	return speed;
}

stock float ClampFloat(const float val, const float minVal, const float maxVal)
{
	if (val < minVal)
		return minVal;
	else if (val > maxVal)
		return maxVal;
	else
		return val;
}

stock TFTeam TF2_GetTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
}

stock TFTeam GetDisguiseTeam(int client)
{
	return view_as<TFTeam>(GetEntProp(client, Prop_Send, "m_nDisguiseTeam"));
}

stock bool IsStealthed(int client)
{
	return (TF2_IsPlayerInCondition(client, TFCond_Cloaked) || TF2_IsPlayerInCondition(client, TFCond_Stealthed) || TF2_IsPlayerInCondition(client, TFCond_StealthedUserBuffFade));
}

stock float GetPercentInvisible(int client)
{
	static int iOffset = -1;
	if (iOffset == -1)
		iOffset = FindSendPropInfo("CTFPlayer", "m_flInvisChangeCompleteTime") - 8;
	
	return GetEntDataFloat(client, iOffset);
}

stock float[] GetAbsVelocity(int entity)
{
	float v[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", v);
	return v;
}

stock float fmodf(float num, float denom)
{
	return num - denom * RoundToFloor(num / denom);
}

stock void SinCos( float rad, float &s, float &c )
{
	s = Sine( rad );
	c = Cosine( rad );
}

stock float UTIL_AngleNormalize(float angle)
{
	angle = fmodf(angle, 360.0);
	if (angle > 180.0) angle -= 360.0;
	if (angle < -180.0) angle += 360.0;
	return angle;
}

stock float UTIL_AngleDiff(float firstAngle, float secondAngle)
{
	float diff = fmodf(firstAngle - secondAngle, 360.0);
	if ( firstAngle > secondAngle )
	{
		if ( diff >= 180 )
			diff -= 360;
	}
	else
	{
		if ( diff <= -180 )
			diff += 360;
	}
	return diff;
}

stock float UTIL_ApproachAngle( float target, float value, float speed )
{
	float delta = UTIL_AngleDiff(target, value);

	// Speed is assumed to be positive
	if ( speed < 0 )
		speed = -speed;

	if ( delta < -180 )
		delta += 360;
	else if ( delta > 180 )
		delta -= 360;

	if ( delta > speed )
		value += speed;
	else if ( delta < -speed )
		value -= speed;
	else 
		value = target;

	return value;
}

stock float UTIL_Clamp(float f1, float f2, float f3)
{
	return (f1 > f3 ? f3 : (f1 < f2 ? f2 : f1));
}

stock float RemapVal(float val, float A, float B, float C, float D)
{
	if (A == B)
		return val >= B ? D : C;
	else
		return C + (D - C) * (val - A) / (B - A);
}

stock void VS_SetMoveType(int entity, MoveType movetype, int movecollide)
{
	char buffer[256]; Format(buffer, sizeof(buffer), "!self.SetMoveType(%d, %d)", movetype, movecollide);
	
	SetVariantString(buffer);
	AcceptEntityInput(entity, "RunScriptCode");
}

//From stocksoup/tf/tempents_stocks.inc
stock void TE_SetupTFParticleEffect(const char[] name, const float vecOrigin[3],
		const float vecStart[3] = NULL_VECTOR, const float vecAngles[3] = NULL_VECTOR,
		int entity = -1, ParticleAttachment_t attachType = PATTACH_ABSORIGIN,
		int attachPoint = -1, bool bResetParticles = false) {
	int particleTable, particleIndex;
	
	if ((particleTable = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE) {
		ThrowError("Could not find string table: ParticleEffectNames");
	}
	
	if ((particleIndex = FindStringIndex(particleTable, name)) == INVALID_STRING_INDEX) {
		ThrowError("Could not find particle index: %s", name);
	}
	
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", vecOrigin[0]);
	TE_WriteFloat("m_vecOrigin[1]", vecOrigin[1]);
	TE_WriteFloat("m_vecOrigin[2]", vecOrigin[2]);
	TE_WriteFloat("m_vecStart[0]", vecStart[0]);
	TE_WriteFloat("m_vecStart[1]", vecStart[1]);
	TE_WriteFloat("m_vecStart[2]", vecStart[2]);
	TE_WriteVector("m_vecAngles", vecAngles);
	TE_WriteNum("m_iParticleSystemIndex", particleIndex);
	
	if (entity != -1) {
		TE_WriteNum("entindex", entity);
	}
	
	if (attachType != PATTACH_ABSORIGIN) {
		TE_WriteNum("m_iAttachType", view_as<int>(attachType));
	}
	
	if (attachPoint != -1) {
		TE_WriteNum("m_iAttachmentPointIndex", attachPoint);
	}
	
	TE_WriteNum("m_bResetParticles", bResetParticles ? 1 : 0);
}

stock int Player_GetGroundEntity(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
}

stock void VS_ApplyAbsVelocityImpulse(int entity, float inVecImpulse[3])
{
	char buffer[256]; Format(buffer, sizeof(buffer), "!self.ApplyAbsVelocityImpulse(Vector(%f, %f, %f))", inVecImpulse[0], inVecImpulse[1], inVecImpulse[2]);
	
	SetVariantString(buffer);
	AcceptEntityInput(entity, "RunScriptCode");
}

stock void ZeroVector(float origin[3])
{
	origin = NULL_VECTOR;
}

stock bool IsZeroVector(float origin[3])
{
	return origin[0] == NULL_VECTOR[0] && origin[1] == NULL_VECTOR[1] && origin[2] == NULL_VECTOR[2];
}

stock bool IsEntityAPlayer(int entity)
{
	return entity > 0 && entity <= MaxClients;
}

stock void VS_EmitSound(int entity, char[] soundName)
{
	char buffer[PLATFORM_MAX_PATH]; Format(buffer, sizeof(buffer), "self.EmitSound(\"%s\")", soundName);
	
	SetVariantString(buffer);
	AcceptEntityInput(entity, "RunScriptCode");
}

stock void BaseEntity_EmitSound(int entity, char[] soundname, float soundtime = 0.0)
{
	float volume = SNDVOL_NORMAL;
	
	int foundIndex = FindCharInString(soundname, '|');
	
	if (foundIndex != -1)
	{
		char prefix[5];
		
		SplitString(soundname, "|", prefix, sizeof(prefix));
		ReplaceString(prefix, sizeof(prefix), "=", "");
		
		volume = StringToFloat(prefix);
		volume /= 100.0;
		
		//NOTE: pretty sure there's a better way to do this...
		strcopy(soundname, PLATFORM_MAX_PATH, soundname[foundIndex + 1]);
	}
	
	//Try soundscript first, otherwise emit raw sound file
	if (!EmitGameSoundToAll(soundname, entity, SND_NOFLAGS, -1, NULL_VECTOR, NULL_VECTOR, false, soundtime))
		EmitSoundToAll(soundname, entity, SNDCHAN_AUTO, SNDLEVEL_NONE, SND_NOFLAGS, volume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, soundtime);
}