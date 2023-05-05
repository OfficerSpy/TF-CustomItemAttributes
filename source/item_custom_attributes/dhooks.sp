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

void DHooks_Initialize()
{	
	g_DynamicDetours = new ArrayList(sizeof(DetourData));
	g_DynamicHookIds = new ArrayList();
	
	GameData gamedata = new GameData("tf2.customitemattribs");
	if (gamedata)
	{
		DHooks_AddDynamicDetour(gamedata, "CTraceFilterObject::ShouldHitEntity", DHookCallback_ShouldHitEntity_Pre);
		
		g_DHookWeaponSound = DHooks_AddDynamicHook(gamedata, "CBaseCombatWeapon::WeaponSound");
				
		delete gamedata;
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
		DHooks_HookEntity(g_DHookWeaponSound, Hook_Pre, entity, DHookCallback_WeaponSound_Pre);
}

static MRESReturn DHookCallback_ShouldHitEntity_Pre(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
	int entity = DHookGetParam(hParams, 1);
	
	//This retrieves the entity performing the trace
	//Taken from owned_building_phasing
	Address pEntity = DereferencePointer(pThis + view_as<Address>(0x04));
	int passEntity = GetEntityFromAddress(pEntity);
	
	if (IsValidClientIndex(passEntity))
	{
		bool entityhit_player = IsValidClientIndex(entity);
		
		if (entityhit_player || IsBaseObject(entity))
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

static MRESReturn DHookCallback_WeaponSound_Pre(int pThis, DHookParam hParams)
{
	int index = hParams.Get(1);
	
	if (index == SINGLE || index == BURST || index == MELEE_MISS || index == MELEE_HIT || index == MELEE_HIT_WORLD || index == RELOAD || index == SPECIAL1 || index == SPECIAL3)
	{
		char sound[256];
		switch(index)
		{
			case SINGLE, BURST, MELEE_MISS, SPECIAL1, SPECIAL3:	TF2Attrib_HookValueString("", "custom_weapon_fire_sound", pThis, sound, sizeof(sound));
			case MELEE_HIT, MELEE_HIT_WORLD:	TF2Attrib_HookValueString("", "custom_impact_sound", pThis, sound, sizeof(sound));
			case RELOAD:	TF2Attrib_HookValueString("", "custom_weapon_reload_sound", pThis, sound, sizeof(sound));
		}
		
		if (strlen(sound) > 0)
		{
			int owner = TF2_GetEntityOwner(pThis);
			float soundtime = hParams.Get(2);
			
			PrecacheSound(sound);
			EmitSoundToAll(sound, owner, _, _, _, _, _, _, _, _, _, soundtime);
			
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}