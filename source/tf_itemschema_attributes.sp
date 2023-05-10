#include <sourcemod>
#include <dhooks>
#include <tf2attributes>
#include <tf2utils>

#pragma semicolon 1
#pragma newdecls required

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

public Plugin myinfo = 
{
	name = "[TF2] Custom Item Schema Attributes",
	author = "Officer Spy",
	description = "Checks for extra attributes that were injected by another mod.",
	version = "1.0.2",
	url = ""
};

public void OnPluginStart()
{
	sv_stepsize = FindConVar("sv_stepsize");
	
	HookGameEvents();
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