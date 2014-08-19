#include <amxmodx>
#include <amxmisc>

#include <fakemeta>
#include <hamsandwich>

#include <xs>

#define PLUGIN	"Cow"
#define AUTHOR	"DarkGL"
#define VERSION	"1.0"

new const pev_next_journey = pev_fuser1;
new	const pev_state = pev_iuser1;
new	const pev_velocity_journey = pev_vuser1;

enum CowState{
	STATE_IDLE,
	STATE_WALK
}

enum CowSequences{
	SEQUENCE_COW_IDLE,
	SEQUENCE_COW_WALK
}

enum CowSkins{
	SKIN_COW_NORMAL,
	SKIN_COW_MUSHROOM
}

new Float: fMins[ 3 ] = { -20.0 , -20.0 , 0.0 },
	Float: fMaxs[ 3 ] = { 20.0 , 20.0 , 30.0 };

new const cowModel[] = "models/minecraft/cow/cow.mdl";

new const COW_CLASS_NAME[] = "minecraft_cow";

new pCvarCowHealth ,
	pCvarCowSpeed;

public plugin_init(){
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	pCvarCowHealth 	=	register_cvar( "minecraft_cowHealth" , "100.0" );
	pCvarCowSpeed	=	register_cvar( "minecraftCow_spped" , "80.0" );
	
	register_clcmd( "say /cow" , "cow" );
	register_clcmd( "say /cowm" , "cowm" );
}

public cow( id ){
	_createCow( Float:{ 0.0 , 0.0 , 65.0 } , SKIN_COW_NORMAL );
}

public cowm( id ){
	_createCow(  Float:{ 0.0 , 0.0 , 65.0 } , SKIN_COW_MUSHROOM );
}

public plugin_precache(){
	precache_model( cowModel );
}

public plugin_natives(){
	register_native( "minecraft_mob_cow_create" , "_createCow" , 1 );
}

public _createCow( Float: fOrigin[ 3 ] , CowSkins: skin ){
	new iEnt = engfunc( EngFunc_CreateNamedEntity , engfunc( EngFunc_AllocString , "info_target" ) );
	
	if( !pev_valid( iEnt ) ){
		return PLUGIN_CONTINUE;
	}
	
	set_pev( iEnt , pev_classname , 	COW_CLASS_NAME );
	set_pev( iEnt , pev_solid , 		SOLID_BBOX );
	set_pev( iEnt , pev_movetype , 		MOVETYPE_STEP );
	
	set_pev( iEnt , pev_health , 		get_pcvar_float( pCvarCowHealth ) );
	set_pev( iEnt , pev_max_health , 	get_pcvar_float( pCvarCowHealth ) );
	
	set_pev( iEnt , pev_takedamage , 	1.0 );
	
	set_pev( iEnt , pev_animtime,		get_gametime() );
	set_pev( iEnt , pev_framerate,		1.0 );
	set_pev( iEnt , pev_sequence,		_:SEQUENCE_COW_IDLE );
	
	set_pev( iEnt , pev_gravity , 1.0 );
	
	engfunc( EngFunc_SetOrigin , 	iEnt , fOrigin );
	engfunc( EngFunc_SetModel , 	iEnt , cowModel );
	engfunc( EngFunc_SetSize ,		iEnt , fMins , fMaxs );
	
	engfunc( EngFunc_DropToFloor,	iEnt );
	
	set_pev( iEnt , pev_skin , _:skin );
	
	set_pev( iEnt , pev_nextthink , get_gametime() + 0.1 );
	set_pev( iEnt , pev_next_journey , get_gametime() );
	
	RegisterHamFromEntity( Ham_TakeDamage , iEnt , "fwTakeDamageCow" );
	RegisterHamFromEntity( Ham_Think , iEnt , "fwThink" );
	
	return PLUGIN_CONTINUE;
}

public fwTakeDamageCow( this, idinflictor, idattacker , Float:fDamage , damagebits ){
	return HAM_IGNORED;
}

public fwThink( iEnt ){
	if( !pev_valid( iEnt ) ){
		return HAM_IGNORED;
	}
	
	if( pev( iEnt , pev_next_journey ) < get_gametime() ){
		
		new Float: fRandTime = random_float( 2.0 , 10.0 );
		
		new randomState = random( 2 );
		
		if( !randomState ){
			set_pev( iEnt , pev_velocity_journey , Float:{ 0.0 , 0.0 , 0.0 } );
			
			set_pev( iEnt , pev_state , _:STATE_IDLE );
			
			set_pev( iEnt , pev_sequence , 		_:SEQUENCE_COW_IDLE );
			set_pev( iEnt , pev_animtime,		get_gametime() );
			set_pev( iEnt , pev_framerate,		1.0 );
		}
		else{
		
			new Float: fVeloc[ 3 ] = { 0.0, 0.0 , 0.0 };
			new Float: fAngles[ 3 ];
			
			fVeloc[ 0 ] = random_float( -1.0 , 1.0 );
			fVeloc[ 1 ] = random_float( -1.0 , 1.0 );
			
			xs_vec_normalize( fVeloc , fVeloc );
			
			xs_vec_mul_scalar( fVeloc , random_float( get_pcvar_float( pCvarCowSpeed ) / 2.0 , get_pcvar_float( pCvarCowSpeed ) ) , fVeloc );
			
			set_pev( iEnt , pev_velocity_journey , fVeloc );
			
			vector_to_angle( fVeloc , fAngles );
	
			set_pev( iEnt , pev_angles , fAngles );
			
			set_pev( iEnt , pev_state , _:STATE_WALK );
		}
		
		set_pev( iEnt , pev_next_journey , get_gametime() + fRandTime );
	}
	
	playAnimation( iEnt , _:( pev( iEnt , pev_state ) == _:STATE_WALK ? SEQUENCE_COW_WALK : SEQUENCE_COW_IDLE ) );
	
	new Float: fVelocCurrent[ 3 ],
			Float: fVelocSet[ 3 ],
			Float: fVelocOld[ 3 ];
	
	pev( iEnt , pev_velocity , fVelocCurrent );
	pev( iEnt , pev_velocity_journey , fVelocOld );
		
	fVelocSet[ 0 ]	=	fVelocOld[ 0 ];
	fVelocSet[ 1 ]	=	fVelocOld[ 1 ];
	fVelocSet[ 2 ]	=	fVelocCurrent[ 2 ];
		
	set_pev( iEnt , pev_velocity , fVelocSet );
	
	set_pev( iEnt , pev_nextthink , get_gametime() + 0.1 )
	
	return HAM_IGNORED;
}

playAnimation( iEnt , iSequence ){
	if( pev( iEnt , pev_sequence ) != iSequence ){
		set_pev( iEnt , pev_sequence , 		iSequence );
		set_pev( iEnt , pev_animtime,		get_gametime() );
		set_pev( iEnt , pev_framerate,		1.0 );
	}
}