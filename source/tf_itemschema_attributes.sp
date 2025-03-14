#include <sourcemod>
#include <dhooks>
#include <sdkhooks>
#include <tf2attributes>
#include <tf2utils>

#pragma semicolon 1
#pragma newdecls required

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

ConVar sv_stepsize;

#include "item_custom_attributes/dhooks.sp"
#include "item_custom_attributes/events.sp"
#include "item_custom_attributes/sdkhooks.sp"
#include "item_custom_attributes/sdkcalls.sp"
#include "item_custom_attributes/etc/heatseekingrockets.sp"

public Plugin myinfo = 
{
	name = "[TF2] Custom Item Schema Attributes",
	author = "Officer Spy",
	description = "Checks for extra attributes that were injected by another mod.",
	version = "1.1.6",
	url = ""
};

public void OnPluginStart()
{
	HookGameEvents();
	
	GameData gd = new GameData("tf2.customitemattribs");
	
	if (gd)
	{
		bool bFailed = false;
		
		if (!InitSDKCalls(gd))
			bFailed = true;
		
		if (!InitDHooks(gd))
			bFailed = true;
		
		delete gd;
		
		if (bFailed)
			SetFailState("Gamedata failed!");
	}
	else
	{
		SetFailState("Failed to load gamedata file tf2.customitemattribs.txt");
	}
}

public void OnConfigsExecuted()
{
	sv_stepsize = FindConVar("sv_stepsize");
}

public void OnEntityCreated(int entity, const char[] classname)
{	
	if (StrContains(classname, "tf_projectile") != -1)
		SDKHook(entity, SDKHook_SpawnPost, BaseProjectile_SpawnPost);
	
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
	SDKHook(client, SDKHook_OnTakeDamage, Player_OnTakeDamage);
	
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