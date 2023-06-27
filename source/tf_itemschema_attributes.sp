#include <sourcemod>
#include <dhooks>
#include <sdkhooks>
#include <tf2attributes>
#include <tf2utils>

#pragma semicolon 1
#pragma newdecls required

#define ATTRIBUTE_ENHANCEMENTS
// #define JOINBLU_BUSTER_ROBOT

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
	version = "1.0.7",
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
		
		VScriptSetSize(proj, min, max);
	}
}

bool IsWeaponBaseGun(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseGunZoomOutIn");
}

void CustomlyModifyLaunchedProjectile(int weapon, int projectile, bool isNativeSpawned)
{
	char particleName[128]; TF2Attrib_HookValueString("", "projectile_trail_particle", weapon, particleName, sizeof(particleName));
	if (strlen(particleName) > 0)
	{
		float color0[3], color1[3];
		
		// color0 = GetWeaponParticleColor(weapon, 1);
		// color1 = GetWeaponParticleColor(weapon, 2);
		
		//FIXME: this works in RequestFrame but not here?
		//I'm not sure how that makes sense since overload 1 works in SpawnPost
		//Also the original particle is removed even with reset set to false
		if (StrContains(particleName, "~") != -1)
		{
			ReplaceString(particleName, sizeof(particleName), "~", "");
			DispatchParticleEffect3(particleName, PATTACH_ABSORIGIN_FOLLOW, projectile, "trail", color0, color1, true, true);
		}
		else
			DispatchParticleEffect3(particleName, PATTACH_ABSORIGIN_FOLLOW, projectile, "trail", color0, color1, true, false);
	}
	//TODO: ModifyProjectile but ignore native spawned
	
	char soundName[128];	TF2Attrib_HookValueString("", "projectile_sound", weapon, soundName, sizeof(soundName));
	if (strlen(soundName) > 0)
	{
		PrecacheSound(soundName);
		EmitSoundToAll(soundName);
	}
}

//TODO: maybe implement CTakeDamageInfo into here at some point?
void ApplyOnHitAttributes(int weapon, int victim, int attacker, float damage)
{
	char str[128];	TF2Attrib_HookValueString("", "custom_hit_sound", weapon, str, sizeof(str));
	if (strlen(str) > 0)
	{
		PrecacheSound(str);
		EmitSoundToAll(str, victim);
	}
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
	char model[PLATFORM_MAX_PATH];
	GetClientModel(client, model, PLATFORM_MAX_PATH);
	return StrEqual(model, "models/bots/demo/bot_sentry_buster.mdl");
}

stock void VScriptSetSize(int entity, float mins[3], float maxs[3])
{
	char buffer[256]; Format(buffer, sizeof(buffer), "!self.SetSize(Vector(%.2f, %.2f, %.2f), Vector(%.2f, %.2f, %.2f))", mins[0], mins[1], mins[2], maxs[0], maxs[1], maxs[2]);
	
	SetVariantString(buffer);
	AcceptEntityInput(entity, "RunScriptCode");
}