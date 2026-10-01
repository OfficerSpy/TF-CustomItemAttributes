#include <sourcemod>
#include <sdkhooks>
#include <dhooks>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

static bool m_bLateLoad;

#include "customattributes/dhooks.sp"
#include "customattributes/sdkcalls.sp"
#include "customattributes/etc/heatseekingrockets.sp"

public Plugin myinfo = 
{
	name = "Custom Item Attributes",
	author = "Officer Spy",
	description = "Checks for extra attributes that were injected by another mod.",
	version = "0.0.0",
	url = ""
};

public void OnPluginStart()
{
	if (GetExtensionFileStatus("sigsegv.ext") >= 0)
		ThrowError("This mod cannot be used with sigsegv MvM. Please unload the extension and try again.");
	
	GameData hGamedata = new GameData("tf2.customattributes");
	
	if (hGamedata)
	{
		bool bFailed = false;
		
		if (!InitDHooks(hGamedata))
			bFailed = true;
		
		hGamedata.Close();
		
		if (bFailed)
			ThrowError("Gamedata failed!");
	}
	else
	{
		ThrowError("Failed to load gamedata file \"tf2.customattributes.txt\"!");
	}
	
	//Unload inferior versions
	ServerCommand("sm plugins unload tf_itemschema_attributes");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	m_bLateLoad = late;
	
	return APLRes_Success;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "tf_projectile", false) != -1)
	{
		SDKHook(entity, SDKHook_SpawnPost, BaseProjectile_SpawnPost);
	}
}

public void BaseProjectile_SpawnPost(int entity)
{
	int weapon = GetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher");
	
	if (weapon != -1)
		OnProjectileFired(weapon, -1, entity);
	
	CheckHomingRockets(entity);
}

void OnProjectileFired(int weapon, int player, int proj)
{
	char particlename[PLATFORM_MAX_PATH]; TF2Attrib_HookValueString("", "projectile_trail_particle", weapon, particlename, sizeof(particlename));
	
	if (particlename[0])
	{
		//TODO: we disabled particle colors in the functions used, be sure to enable them when we add in color support from weapons!
		float color0[3];
		float color1[3];
		if (StrContains(particlename, "~", false) != -1)
		{
			//Trim this off, it was only here to tell us the user wants to stop all particles first
			ReplaceString(particlename, sizeof(particlename), "~", "", false);
			
			StopParticleEffects(proj);
			OSLib_DispatchParticleEffect(particlename, PATTACH_ABSORIGIN_FOLLOW, proj, NULL_STRING, NULL_VECTOR, false, color0, color1, false, false, arrEmpty);
		}
		else
		{
			OSLib_DispatchParticleEffect(particlename, PATTACH_ABSORIGIN_FOLLOW, proj, NULL_STRING, NULL_VECTOR, false, color0, color1, false, false, arrEmpty);
		}
	}
	
#if 0
	float gravity = TF2Attrib_HookValueFloat(0.0, "projectile_gravity_native", weapon);
	if (gravity != 0.0)
	{
		SetEntityGravity(proj, gravity);
	}
	
	int ignoresOtherProjectiles = TF2Attrib_HookValueInt(0, "ignores_other_projectiles", weapon);
	if (ignoresOtherProjectiles != 0)
	{
		SetEntityCollisionGroup(proj, TFCOLLISION_GROUP_ROCKET_BUT_NOT_WITH_OTHER_ROCKETS);
	}
#endif
}