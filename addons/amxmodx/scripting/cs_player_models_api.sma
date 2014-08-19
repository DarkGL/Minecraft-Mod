/*================================================================================
	
	----------------------------------
	-*- [CS] Player Models API 1.1 -*-
	----------------------------------
	
	- Allows easily setting and restoring custom player models in CS and CZ
	   (models last until player disconnects or are manually reset)
	- Built-in SVC_BAD prevention
	- Support for custom hitboxes (model index offset setting)
	- You still need to precache player models in your plugin!
	
	Original thread:
	http://forums.alliedmods.net/showthread.php?t=161255
	
================================================================================*/

// Delay between model changes (increase if getting SVC_BAD kicks)
#define MODELCHANGE_DELAY 0.2

// Delay after roundstart (increase if getting kicks at round start)
#define ROUNDSTART_DELAY 2.0

// Enable custom hitboxes (experimental, might lag your server badly with some models)
//#define SET_MODELINDEX_OFFSET

/*=============================================================================*/

#include <amxmodx>
#include <fakemeta>

#define MAXPLAYERS 32
#define MODELNAME_MAXLENGTH 32

#define TASK_MODELCHANGE 100
#define ID_MODELCHANGE (taskid - TASK_MODELCHANGE)

#define DEFAULT_MODELINDEX_T "models/player/terror/terror.mdl"
#define DEFAULT_MODELINDEX_CT "models/player/urban/urban.mdl"

// CS Player PData Offsets (win32)
#define PDATA_SAFE 2
#define OFFSET_CSTEAMS 114
#define OFFSET_MODELINDEX 491 // Orangutanz

// CS Teams
enum
{
	FM_CS_TEAM_UNASSIGNED = 0,
	FM_CS_TEAM_T,
	FM_CS_TEAM_CT,
	FM_CS_TEAM_SPECTATOR
}

#define flag_get(%1,%2)		(%1 & (1 << (%2 & 63)))
#define flag_set(%1,%2)		(%1 |= (1 << (%2 & 63)))
#define flag_unset(%1,%2)	(%1 &= ~(1 << (%2 & 63)))

new g_hasCustomModel
new Float:g_modelChangeTargetTime
new g_customPlayerModel[MAXPLAYERS+1][MODELNAME_MAXLENGTH]
#if defined SET_MODELINDEX_OFFSET
new g_customModelIndex[MAXPLAYERS+1]
#endif

public plugin_init()
{
	register_plugin("[CS] Player Models API", "1.1", "WiLS")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	register_forward(FM_SetClientKeyValue, "fw_SetClientKeyValue")
}

public plugin_natives()
{
	register_library("cs_player_models_api")
	register_native("cs_set_player_model", "native_set_player_model", 1)
	register_native("cs_reset_player_model", "native_reset_player_model", 1)
}

public native_set_player_model(id, const newmodel[])
{
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Player is not in game (%d)", id)
		return false;
	}
	
	// Strings passed byref
	param_convert(2)
	
	remove_task(id+TASK_MODELCHANGE)
	flag_set(g_hasCustomModel, id)
	
	copy(g_customPlayerModel[id], charsmax(g_customPlayerModel[]), newmodel)
	
#if defined SET_MODELINDEX_OFFSET	
	new modelPath[32+(2*MODELNAME_MAXLENGTH)]
	formatex(modelPath, charsmax(modelPath), "models/player/%s/%s.mdl", newmodel, newmodel)
	g_customModelIndex[id] = engfunc(EngFunc_ModelIndex, modelPath)
#endif
	
	new currentModel[MODELNAME_MAXLENGTH]
	fm_cs_get_user_model(id, currentModel, charsmax(currentModel))
	
	if (!equal(currentModel, newmodel))
		fm_cs_user_model_update(id+TASK_MODELCHANGE)
	
	return true;
}

public native_reset_player_model(id)
{
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Player is not in game (%d)", id)
		return false;
	}
	
	remove_task(id+TASK_MODELCHANGE)
	flag_unset(g_hasCustomModel, id)
	fm_cs_reset_user_model(id)
	
	return true;
}

public client_disconnect(id)
{
	remove_task(id+TASK_MODELCHANGE)
	flag_unset(g_hasCustomModel, id)
}

public event_round_start()
{
	// An additional delay is offset at round start
	// since SVC_BAD is more likely to be triggered there
	g_modelChangeTargetTime = get_gametime() + ROUNDSTART_DELAY
	
	// If a player has a model change task in progress,
	// reschedule the task, since it could potentially
	// be executed during roundstart
	new player
	for (player = 1; player <= get_maxplayers(); player++)
	{
		if (task_exists(player+TASK_MODELCHANGE))
		{
			remove_task(player+TASK_MODELCHANGE)
			fm_cs_user_model_update(player+TASK_MODELCHANGE)
		}
	}
}

public fw_SetClientKeyValue(id, const infobuffer[], const key[])
{
	if (flag_get(g_hasCustomModel, id) && equal(key, "model"))
	{
		static currentModel[MODELNAME_MAXLENGTH]
		fm_cs_get_user_model(id, currentModel, charsmax(currentModel))
		
		if (!equal(currentModel, g_customPlayerModel[id]) && !task_exists(id+TASK_MODELCHANGE))
			fm_cs_set_user_model(id+TASK_MODELCHANGE)
		
#if defined SET_MODELINDEX_OFFSET
		fm_cs_set_user_model_index(id)
#endif
		
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

public fm_cs_set_user_model(taskid)
{
	set_user_info(ID_MODELCHANGE, "model", g_customPlayerModel[ID_MODELCHANGE])
}

stock fm_cs_set_user_model_index(id)
{
	if (pev_valid(id) != PDATA_SAFE)
		return;
	
	set_pdata_int(id, OFFSET_MODELINDEX, g_customModelIndex[id])
}

stock fm_cs_reset_user_model_index(id)
{
	if (pev_valid(id) != PDATA_SAFE)
		return;
	
	switch (fm_cs_get_user_team(id))
	{
		case FM_CS_TEAM_T:
		{
			set_pdata_int(id, OFFSET_MODELINDEX, engfunc(EngFunc_ModelIndex, DEFAULT_MODELINDEX_T))
		}
		case FM_CS_TEAM_CT:
		{
			set_pdata_int(id, OFFSET_MODELINDEX, engfunc(EngFunc_ModelIndex, DEFAULT_MODELINDEX_CT))
		}
	}
}

stock fm_cs_get_user_model(id, model[], len)
{
	get_user_info(id, "model", model, len)
}

stock fm_cs_reset_user_model(id)
{
	dllfunc(DLLFunc_ClientUserInfoChanged, id, engfunc(EngFunc_GetInfoKeyBuffer, id))
#if defined SET_MODELINDEX_OFFSET
	fm_cs_reset_user_model_index(id)
#endif
}

stock fm_cs_user_model_update(taskid)
{
	new Float:current_time
	current_time = get_gametime()
	
	if (current_time - g_modelChangeTargetTime >= MODELCHANGE_DELAY)
	{
		fm_cs_set_user_model(taskid)
		g_modelChangeTargetTime = current_time
	}
	else
	{
		set_task((g_modelChangeTargetTime + MODELCHANGE_DELAY) - current_time, "fm_cs_set_user_model", taskid)
		g_modelChangeTargetTime = g_modelChangeTargetTime + MODELCHANGE_DELAY
	}
}

stock fm_cs_get_user_team(id)
{
	if (pev_valid(id) != PDATA_SAFE)
		return FM_CS_TEAM_UNASSIGNED;
	
	return get_pdata_int(id, OFFSET_CSTEAMS);
}
