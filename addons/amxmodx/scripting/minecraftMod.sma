/*	
@author Rafal "DarkGL" Wiecek 
@site www.darkgl.amxx.pl
*/

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <fun>

#include <xs>

#include <cs_player_models_api>

#define PLUGIN	"Minecraft Mod"
#define AUTHOR	"DarkGL"
#define VERSION	"1.0"

const pev_old_health = pev_fuser1;
const pev_type_block = pev_iuser3;
const pev_block_ent = pev_iuser4;

const animIdle = 0;
const animPlace = 2;
const animDeploy = 3;

const maxPlayers	=	32;
const MAX_LEN		=	256;

const Float: thinkTimeSmall = 0.01;
const Float: fLittleForceDrop = 250.0;
const Float: smallBlockRadius = 70.0;
const Float: smallBlockSpeed = 350.0;
const Float: smallBlockTimeBlock = 3.0;

new const configName[]	=	"minecraft.cfg";
new const playerModel[]	=	"minecraft";

new const fullBlockClass[] = "minecraft_block";
new const smallBlockClass[] = "minecraft_pickup";

new const soundPop[] = "sound/minecraft/pop.mp3";

const Float: fSizeFull = 28.0;

new Float: fullSizeMin[] = { -14.0 , -14.0 , -14.0 };
new Float: fullSizeMax[] = { 14.0 , 14.0 , 14.0 };

new Float: smallSizeMin[] = { -1.0 , -1.0 , -1.0 };
new Float: smallSizeMax[] = { 1.0 , 1.0 , 1.0 };

new Array:objectsList;

new isCurrentDestroyingEnt[ maxPlayers + 1 ],
	bool: isCurrentDestroying[ maxPlayers + 1 ]

new Array: userEquipment[ maxPlayers + 1 ];
new userCurrentEquip[ maxPlayers + 1 ];

new currentLookEnt[ maxPlayers + 1 ];

enum structSecondary {
	DO_NOTHING,
	CREATE_BLOCK
}

enum structUserEquip {
	idItem = 0,
	itemAmount
}

enum structDrop{
	CAN_DROP,
	NO_DROP
}

enum structObject{
	objectName[ MAX_LEN ],
	maxObjectAmount,
	pluginID,
	objectHealth,
	VModel[ MAX_LEN ],
	PModel[ MAX_LEN ],
	NormalModel[ MAX_LEN ],
	LittleModel[ MAX_LEN ],
	soundPut[ MAX_LEN ],
	soundDestroy[ MAX_LEN ],
	soundDestroying[ MAX_LEN ],
	primaryDamage ,
	structSecondary:secondaryAction,
	structDrop:objectDrop,
	createBlockForwardHandle
}

new temporaryEquip[ structUserEquip ] = { 0 , 1 };

new iRetNull;

enum cvarsStruct{
	cvarRange,
	cvarPutSpeed
}

new pCvars[ cvarsStruct ];

public plugin_init(){
	
	register_plugin( PLUGIN, VERSION, AUTHOR );
	
	register_clcmd( "giveBlocks" , "giveBlocksHandle" , ADMIN_BAN );
	
	RegisterHam( Ham_Spawn , "player" , "fwSpawned" , 1 );
	
	RegisterHam( Ham_Item_Deploy , "weapon_knife" , "fwDeploy" , 1 );
	RegisterHam( Ham_CS_Item_CanDrop , "weapon_knife" , "fwCanDrop" , 0 );
	
	RegisterHam( Ham_Weapon_PrimaryAttack , "weapon_knife" , "fwPrimaryAttack" , 1 );
	RegisterHam( Ham_Weapon_SecondaryAttack , "weapon_knife" , "fwSecondaryAttack" , 1 );
	
	register_forward( FM_AddToFullPack , "fwAddToFullPack" , 1 );
	register_forward( FM_ShouldCollide, "fwShouldCollide" );  
	register_forward( FM_EmitSound, "fmEmitSound" );
	
	register_message( get_user_msgid( "TextMsg" ), "messageTextMsg" );
	
	pCvars[ cvarRange ]		=	register_cvar( "minecraftMod_range" , "300.0" );
	pCvars[ cvarPutSpeed ] 	=	register_cvar( "minecraftMod_speed_put" , "0.3" );
	
	register_think( smallBlockClass , "smallBlockThink" );
	
	createHandObject();
	createUsersEquipment();
	
	execConfig();
}

public giveBlocksHandle( id , level , cid ){
	if( !cmd_access( id , level , cid , 2 ) ){
		return PLUGIN_HANDLED;
	}
	
	new szName[ 64 ] ,
		szArgvName[ 64 ] ,
		idFound;
		
	read_argv( 1 , szArgvName , charsmax( szArgvName ) );
	
	trim( szArgvName );
	
	idFound = find_player( "bjl" , szArgvName );
	
	if( !is_user_connected( idFound ) ){
		client_print( id , print_console , "Couldn't find player" );
		
		return PLUGIN_HANDLED;
	}
	
	giveAll( idFound );
	
	get_user_name( idFound , szName , charsmax( szName ) );
	
	client_print( id , print_console , "Player %s received blocks" , szName );
	
	return PLUGIN_HANDLED;
}

createUsersEquipment(){
	new tempEquip[ structUserEquip ];
	
	new sizeStruct	=	sizeof( tempEquip );
	
	for( new iCurrent = 1 ; iCurrent <= maxPlayers ; iCurrent++ ){
		userEquipment[ iCurrent ]	=	ArrayCreate( sizeStruct , 1 );
	}
	
	#pragma unused tempEquip
}

createHandObject(){
	new tempObject[ structObject ];
	
	new sizeObject	=	sizeof( tempObject );
	
	tempObject[ maxObjectAmount ]	=	1;
	
	tempObject[ pluginID ]	=	0;
	
	tempObject[ primaryDamage ]		=	_:10.0;
	tempObject[ secondaryAction ]	=	DO_NOTHING;	
	
	tempObject[ objectDrop ]		=	NO_DROP;
	
	tempObject[ objectHealth ]		=	0;
	
	copy( tempObject[ VModel ] , MAX_LEN - 1 , "models/v_knife.mdl" );
	copy( tempObject[ PModel ] , MAX_LEN - 1 , "models/p_knife.mdl" );
	copy( tempObject[ NormalModel ] , MAX_LEN - 1 , "models/p_knife.mdl" );
	copy( tempObject[ LittleModel ] , MAX_LEN - 1 , "models/p_knife.mdl" );
	copy( tempObject[ soundPut ] , MAX_LEN - 1 , "" );
	copy( tempObject[ soundDestroy ] , MAX_LEN - 1 , "" );
	copy( tempObject[ soundDestroying ] , MAX_LEN - 1 , "" );
	
	copy( tempObject[ objectName ] , MAX_LEN - 1 , "Hand" );
	
	objectsList	=	ArrayCreate( sizeObject , 1 );
	
	ArrayPushArray( objectsList , tempObject );
}

public fwAddToFullPack(es_state, e, ENT, HOST, hostflags, player, set){
	if( player )
		return FMRES_IGNORED;
	
	if( !is_user_alive( HOST ) ){
		return FMRES_IGNORED;
	}
	
	if( currentLookEnt[ HOST ] != ENT || !pev_valid( ENT ) ){
		return FMRES_IGNORED;
	}
	
	set_es( es_state , ES_RenderMode , kRenderTransAdd );
	set_es( es_state , ES_RenderAmt , 100.0 );
	
	return FMRES_IGNORED;
}

public client_PreThink( id ){
	if( !is_user_alive( id ) ){
		currentLookEnt[ id ] = 0;
		
		if( isCurrentDestroying[ id ] ){
			if( checkISValidEnt( isCurrentDestroyingEnt[ id ] ) ){			
				restoreHealthEnt( isCurrentDestroyingEnt[ id ] );
			}
			
			isCurrentDestroyingEnt[ id ] = 0;
			isCurrentDestroying[ id ] = false;
		}
		
		return PLUGIN_CONTINUE;
	}
	
	new Float: fStartOrigin[ 3 ];
	
	new Float: fEndOrigin[ 3 ];
	
	new iHit;
	
	new pTr = create_tr2()
	
	getPlayerStartOrigin( id , fStartOrigin );
	
	getPlayerEndOrigin( id , fEndOrigin , get_pcvar_float( pCvars[ cvarRange ] ) );
	
	engfunc( EngFunc_TraceLine , fStartOrigin , fEndOrigin , DONT_IGNORE_MONSTERS , id , pTr );
	
	iHit = get_tr2( pTr , TR_pHit );
	
	free_tr2( pTr );
	
	if( isFullBlockValid( iHit ) ){
		currentLookEnt[ id ] = iHit;
	}
	else{
		currentLookEnt[ id ] = 0;
	}
	
	if( isCurrentDestroying[ id ] ){
		if( iHit != isCurrentDestroyingEnt[ id ] ){
			
			if( checkISValidEnt( isCurrentDestroyingEnt[ id ] ) ){
				restoreHealthEnt( isCurrentDestroyingEnt[ id ] );
			}
			
			isCurrentDestroying[ id ] = false;
			isCurrentDestroyingEnt[ id ] = 0;
		}
	}
	
	return PLUGIN_CONTINUE;
}

public smallBlockThink( iEnt ){
	if( !pev_valid( iEnt ) ){
		return PLUGIN_CONTINUE;
	}
	
	new Float:fAngles[3] ,
	Float: fOrigin[ 3 ];
	
	pev( iEnt , pev_origin , fOrigin );
	
	pev( iEnt, pev_angles, fAngles );
	
	fAngles[1] += 0.8;
	
	set_pev(iEnt, pev_angles, fAngles);
	
	if( !isEntBlocked( iEnt ) ){
		
		new iEntFind = -1 ,
			iNearest = 0,
			Float: fDistance = 9999.0 ,
			Float: fOriginPlayer[ 3 ];
		
		while( ( iEntFind = engfunc( EngFunc_FindEntityInSphere , iEntFind , fOrigin , smallBlockRadius ) ) != 0 ){
			if( !pev_valid( iEntFind ) || !is_user_alive( iEntFind ) ){
				continue;
			}
			
			pev( iEntFind , pev_origin , fOriginPlayer );
			
			if(get_distance_f( fOrigin , fOriginPlayer ) < fDistance ){
				fDistance = get_distance_f( fOrigin , fOriginPlayer );
				
				iNearest = iEntFind;
			}
		}
		
		if( is_user_alive( iNearest ) ){
			set_pev( iEnt , pev_movetype , MOVETYPE_FLY );
				
			moveToPlayer( iEnt , iNearest , smallBlockSpeed , false);
				
			if( fDistance <= 35.0 ){
				addEquip( iNearest , pev( iEnt , pev_type_block ) );
					
				remove_entity( iEnt );
					
				return PLUGIN_CONTINUE;
			}
		}
		else{
			set_pev( iEnt ,pev_movetype , MOVETYPE_TOSS );
			
			set_pev( iEnt , pev_velocity , Float: { 0.0 , 0.0 , 0.0 } );
		}
	}
	
	setMinecraftThink( iEnt );
	
	return PLUGIN_CONTINUE;
}

addEquip( id , type ){
	if( !is_user_connected( id ) ){
		return ;
	}
	
	new tmpArray[ structUserEquip ] ,
		tmpObject[ structObject ];
	
	for( new i = 1 ; i < ArraySize( userEquipment[ id ] ) ; i++ ){
		ArrayGetArray( userEquipment[ id ] , i , tmpArray );
		
		ArrayGetArray( objectsList , tmpArray[ idItem ] , tmpObject );
		
		if( tmpArray[ idItem ] == type ){
			if( tmpArray[ itemAmount ] < tmpObject[ maxObjectAmount ] ){
				tmpArray[ itemAmount ]++;
				
				playSound( id , soundPop , true );
				
				ArraySetArray( userEquipment[ id ] , i , tmpArray );
				
				return ;
			}
		}
	}
	
	playSound( id , soundPop , true );
	
	tmpArray[ idItem ] = type;
	tmpArray[ itemAmount ] = 1;
	
	ArrayPushArray( userEquipment[ id ] , tmpArray );
	
	return ;
}

setMinecraftThink( iEnt ){
	set_pev( iEnt , pev_nextthink , get_gametime() +  thinkTimeSmall );
}

moveToPlayer( iEnt , id , Float: fSpeed , bool: onGround ){
	if( !is_user_alive( id ) ){
		return ;
	}
	
	new Float: fOrigin[ 3 ],
	Float: fOriginPlayer[ 3 ],
	Float: fVeloc[ 3 ];
	
	pev( id, pev_origin , fOriginPlayer );
	pev( iEnt  , pev_origin , fOrigin );
	
	xs_vec_sub( fOriginPlayer , fOrigin , fVeloc );
	
	if( onGround ){
		fVeloc[ 2 ] = 0.0;
	}
	
	xs_vec_normalize( fVeloc , fVeloc );
	
	xs_vec_mul_scalar( fVeloc , fSpeed , fVeloc );
	
	set_pev( iEnt , pev_velocity , fVeloc );
	
	return ;
}


giveAll( id ){
	new iSize = ArraySize( objectsList );
	
	new tmpArray[ structUserEquip ] ,
	tmpObject[ structObject ];
	
	for( new iCurrent = 1 ; iCurrent < iSize ; iCurrent++ ){
		
		ArrayGetArray( objectsList , iCurrent , tmpObject );
		
		tmpArray[ idItem ] = iCurrent;
		tmpArray[ itemAmount ] = tmpObject[ maxObjectAmount ];
		
		ArrayPushArray( userEquipment[ id ] , tmpArray );
	}
}

public plugin_end(){
	ArrayDestroy( objectsList );
}

public plugin_natives(){
	register_native( "registerNewObject" , "registerNewObject" , 0 );
}

public plugin_precache(){
	new szModel[ 256 ];
	
	formatex( szModel , charsmax( szModel ) , "models/player/%s/%s.mdl" , playerModel , playerModel );
	
	precache_model( szModel );
	
	precache_generic( soundPop );
}

public registerNewObject( plugin , params ){
	new iSize	=	ArraySize( objectsList );
	
	new tempObject[ structObject ],
	pForward,
	iRet;
	
	get_string( 1 , tempObject[ objectName ] , MAX_LEN - 1 );
	
	tempObject[ maxObjectAmount ]		=	get_param( 2 );
	tempObject[ pluginID ]				=	plugin;
	tempObject[ objectDrop ]			=	structDrop: get_param( 3 );
	
	pForward	=	CreateOneForward( plugin , "minecraftMod_V_Model" , FP_ARRAY , FP_CELL );
	
	executeAndCopy( pForward , tempObject[ VModel ] , MAX_LEN - 1 );
	
	pForward	=	CreateOneForward( plugin , "minecraftMod_P_Model" , FP_ARRAY , FP_CELL );
	
	executeAndCopy( pForward , tempObject[ PModel ] , MAX_LEN - 1 );
	
	pForward	=	CreateOneForward( plugin , "minecraftMod_Normal_Model" , FP_ARRAY , FP_CELL );	
	
	executeAndCopy( pForward , tempObject[ NormalModel ] , MAX_LEN - 1 );
	
	pForward	=	CreateOneForward( plugin , "minecraftMod_Little_Model" , FP_ARRAY , FP_CELL );
	
	executeAndCopy( pForward , tempObject[ LittleModel ] , MAX_LEN - 1 );
	
	pForward	=	CreateOneForward( plugin , "minecraftMod_SoundPut" , FP_ARRAY , FP_CELL );
	
	executeAndCopy( pForward , tempObject[ soundPut ] , MAX_LEN - 1 );
	
	pForward	=	CreateOneForward( plugin , "minecraftMod_SoundDestroy" , FP_ARRAY , FP_CELL );
	
	executeAndCopy( pForward , tempObject[ soundDestroy ] , MAX_LEN - 1 );
	
	pForward	=	CreateOneForward( plugin , "minecraftMod_SoundDestroying" , FP_ARRAY , FP_CELL );
	
	executeAndCopy( pForward , tempObject[ soundDestroying ] , MAX_LEN - 1 );
	
	pForward	=	CreateOneForward( plugin , "minecraftMod_primaryDamage" );
	
	ExecuteForward( pForward , iRet );
	
	tempObject[ createBlockForwardHandle ] = CreateOneForward( plugin , "minecraftMod_blockCreated" , FP_CELL );
	
	tempObject[ primaryDamage ]	=	_:iRet;
	
	tempObject[ objectHealth ]	=	get_param( 4 );
	
	pForward	=	CreateOneForward( plugin , "minecraftMod_secondaryAction" );
	
	ExecuteForward( pForward , iRet );
	
	tempObject[ secondaryAction ]	=	structSecondary: iRet;
	
	ArrayPushArray( objectsList , tempObject );
	
	return iSize;
}

public fwSpawned( id ){
	if( !is_user_alive( id ) ){
		return HAM_IGNORED;
	}
	
	strip_user_weapons( id );
	
	give_item( id , "weapon_knife" );
	
	setUserModel( id );
	
	return HAM_IGNORED;
}

public fwDeploy( weaponEnt ){
	if( !pev_valid( weaponEnt ) ){
		return HAM_IGNORED;
	}
	
	new iOwner	=	pev( weaponEnt , pev_owner );
	
	if( !is_user_alive( iOwner ) ){
		return HAM_IGNORED;
	}
	
	new szModelV[ 256 ] ,
		szModelP[ 256 ];
	
	getVModel( getEquipmentID( iOwner ) , szModelV , charsmax( szModelV ) );
	getPModel( getEquipmentID( iOwner )  , szModelP , charsmax( szModelP ) );
	
	set_pev( iOwner , pev_viewmodel2 , szModelV );
	set_pev( iOwner , pev_weaponmodel2 , szModelP );
	
	return HAM_IGNORED;
}

public fwCanDrop( weaponEnt ){
	
	if( !pev_valid( weaponEnt ) ){
		return HAM_SUPERCEDE;
	}
	
	new iOwner = pev( weaponEnt , pev_owner );
	
	new equipID	=	getEquipmentID( iOwner );
	
	new tmpArray[ structObject ];
	
	ArrayGetArray( objectsList , equipID , tmpArray );
	
	if( tmpArray[ objectDrop ]  == CAN_DROP ){
		
		if( getEquipmentAmountParticular( iOwner , userCurrentEquip[ iOwner ] ) <= 0 ){
			return HAM_SUPERCEDE;
		}
		
		new Float: fOrigin[ 3 ] ,
			Float: fVeloc[ 3 ];
		
		new szModel[ 256 ];
		
		copy( szModel , charsmax( szModel ) , tmpArray[ LittleModel ] );
		
		getPlayerStartOrigin( iOwner , fOrigin );
			
		getVelocityForward( iOwner , fLittleForceDrop , fVeloc );
		
		if( createSmallBlock( iOwner , szModel , fOrigin , equipID , fVeloc ) ){
			
			setEquipmentAmountParticular( iOwner , userCurrentEquip[ iOwner ] , getEquipmentAmountParticular( iOwner , userCurrentEquip[ iOwner ] ) - 1 );
			
			if( getEquipmentAmountParticular( iOwner , userCurrentEquip[ iOwner ] ) <= 0 ){
				ArrayDeleteItem( userEquipment[ iOwner ] , userCurrentEquip[ iOwner ] );
				
				userCurrentEquip[ iOwner ] = 0;
				
				deployWeapon( iOwner );
			}
		}
	}
	
	return HAM_SUPERCEDE;
}

getVelocityForward( id , Float: fScalar ,  Float: fVeloc[ 3 ] ){
	
	new Float: fAngles[ 3 ] ,
		Float: fVector[ 3 ];
	
	pev( id , pev_v_angle , fAngles );
	
	angle_vector( fAngles , ANGLEVECTOR_FORWARD , fVector );
	
	xs_vec_normalize( fVector , fVector );
			
	xs_vec_mul_scalar( fVector , fScalar , fVeloc )
}

public fwPrimaryAttack( weaponEnt ){
	if( !pev_valid( weaponEnt ) ){
		return HAM_IGNORED;
	}
	
	new iOwner	=	pev( weaponEnt , pev_owner );
	
	if( !is_user_alive( iOwner ) ){
		return HAM_IGNORED;
	}
	
	new Float: fStartOrigin[ 3 ];
	
	new Float: fEndOrigin[ 3 ];
	
	new iHit;
	
	new pTr = create_tr2()
	
	getPlayerStartOrigin( iOwner , fStartOrigin );
	
	getPlayerEndOrigin( iOwner , fEndOrigin , get_pcvar_float( pCvars[ cvarRange ] ) );
	
	engfunc( EngFunc_TraceLine , fStartOrigin , fEndOrigin , DONT_IGNORE_MONSTERS , iOwner , pTr );
	
	iHit = get_tr2( pTr , TR_pHit );
	
	free_tr2( pTr );
	
	if( !checkISValidEnt( iHit ) ){
		return HAM_IGNORED;
	}
	
	if( isCurrentDestroying[ iOwner ] ){
		if( isCurrentDestroyingEnt[ iOwner ]  != iHit && checkISValidEnt( isCurrentDestroyingEnt[ iOwner ] ) ){
			new Float: fHealth;
			
			pev( isCurrentDestroyingEnt[ iOwner ] , pev_old_health , fHealth );
			
			set_pev( isCurrentDestroyingEnt[ iOwner ] , pev_health , fHealth );
		}
	}
	
	isCurrentDestroying[ iOwner ] 	= true;
	isCurrentDestroyingEnt[ iOwner ] = iHit;
	
	new Float: fDamage = getEquipmentDamageParticular( iOwner );
	new Float: fHealth;
	
	pev( iHit , pev_health , fHealth );
	
	fHealth -= fDamage;
	
	new tmpArray[ structObject ];
	
	ArrayGetArray( objectsList , pev( iHit , pev_type_block ), tmpArray );
	
	if( fHealth <= 0.0 ){
		
		new szModel[ 256 ] ,
			Float: fOrigin[ 3 ] ,
			Float: fVeloc[ 3 ];
		
		copy( szModel , charsmax( szModel ) , tmpArray[ LittleModel ] );
			
		pev( iHit , pev_origin , fOrigin );
		
		fVeloc[ 0 ] = random_float( 0.0 , 30.0 );
		fVeloc[ 1 ] = random_float( 0.0 , 30.0 );
		fVeloc[ 2 ] = random_float( 150.0 , 250.0 );
		
		createSmallBlock( iOwner , szModel , fOrigin , pev( iHit , pev_type_block ) , fVeloc , false );
		
		emit_sound( iHit , CHAN_AUTO , tmpArray[ soundDestroy ] , VOL_NORM , ATTN_NORM , 0 , PITCH_NORM );
		
		remove_entity( iHit );
	}
	else{
		set_pev( iHit , pev_health , fHealth );
		
		if( !equal( tmpArray[ soundDestroying ] , "" ) ){
			emit_sound( iHit , CHAN_AUTO , tmpArray[ soundDestroying ] , VOL_NORM , ATTN_NORM , 0 , PITCH_NORM );
		}
	}
	
	return HAM_IGNORED;
}

public fwSecondaryAttack( weaponEnt ){
	if( !pev_valid( weaponEnt ) ){
		return HAM_IGNORED;
	}
	
	new iOwner	=	pev( weaponEnt , pev_owner );
	
	if( !is_user_alive( iOwner ) ){
		return HAM_IGNORED;
	}
	
	new structSecondary: actionTO	=	getAction( iOwner );
	
	if( actionTO == DO_NOTHING ){
		return HAM_IGNORED;
	}
	
	if( getEquipmentAmountParticular( iOwner , userCurrentEquip[ iOwner ] ) <= 0 ){
		return HAM_IGNORED;
	}
	
	setWeaponAnim( iOwner , animPlace );
	
	if( placeBlock( iOwner ) ){
		setEquipmentAmountParticular( iOwner , userCurrentEquip[ iOwner ] , getEquipmentAmountParticular( iOwner , userCurrentEquip[ iOwner ] ) - 1 );
		
		client_print( iOwner ,print_center, "Klocki [ %d / %d ]" , getEquipmentAmountParticular( iOwner , userCurrentEquip[ iOwner ] ) , getMaxCurrent( iOwner ) )
		
		if( getEquipmentAmountParticular( iOwner , userCurrentEquip[ iOwner ] ) <= 0 ){
			ArrayDeleteItem( userEquipment[ iOwner ] , userCurrentEquip[ iOwner ] );
			
			userCurrentEquip[ iOwner ] = 0;
			
			deployWeapon( iOwner );
			
			remove_task( iOwner );
		}
	}
	
	new Float:Delay = get_pdata_float( weaponEnt, 46, 4) * get_pcvar_float( pCvars[ cvarPutSpeed ] ) ;
	
	set_pdata_float( weaponEnt, 46, Delay, 4);
	set_pdata_float( weaponEnt, 47, Delay, 4);
	set_pdata_float( weaponEnt, 48, Delay, 4);
	
	set_task( 0.7 , "setAnimIdle" , iOwner );
	
	return HAM_IGNORED;
}

public setAnimIdle( id ){
	if( !is_user_connected( id ) ){
		return ;
	}
	
	setWeaponAnim( id , animIdle );
}

public client_connect( id ){
	isCurrentDestroying[ id ] = false;
	isCurrentDestroyingEnt[ id ] = 0;
	
	userCurrentEquip[ id ]	=	0;
	
	ArrayPushArray( userEquipment[ id ] , temporaryEquip );
}

public client_disconnect( id ){
	isCurrentDestroying[ id ] = false;
	isCurrentDestroyingEnt[ id ] = 0;
	
	userCurrentEquip[ id ]	=	0;
	
	ArrayClear( userEquipment[ id ] );
}

public fmEmitSound(id, iChannel, szSound[], Float:fVol, Float:fAttn, iFlags, iPitch ){
	
	static blockSounds[][] = {
		"weapons/knife_slash2.wav",
		"weapons/knife_slash1.wav",
		"weapons/knife_hitwall1.wav"
	}
	
	if( equal( szSound, "common/wpn_denyselect.wav" ) )
		showEquip( id );
	
	for( new iCurrent = 0 ; iCurrent < sizeof blockSounds ; iCurrent++ ){
		
		if( equal( blockSounds[ iCurrent ] , szSound ) ){
			
			return FMRES_SUPERCEDE;
			
		}
	}
	
	return FMRES_IGNORED;
}

public messageTextMsg(){
	
	new textmsg[ 64 ]
	get_msg_arg_string(2, textmsg, charsmax(textmsg))
	
	if (equal(textmsg, "#Weapon_Cannot_Be_Dropped"))
		return PLUGIN_HANDLED
	
	return PLUGIN_CONTINUE
}

execConfig(){
	new szPath[ 256 ];
	
	formatex( szPath[ get_configsdir( szPath , charsmax( szPath ) ) ] , charsmax( szPath ) - strlen( szPath ) , "/%s" , configName );
	
	server_cmd( "exec ^"%s^"" , szPath );
	server_exec();
}

setUserModel( id ){
	cs_set_player_model( id , playerModel );
}

getEquipmentID( id ){
	new tmpArray[ structUserEquip ];
	
	ArrayGetArray( userEquipment[ id ] , userCurrentEquip[ id ] , tmpArray );
	
	return tmpArray[ idItem ];
}

Float: getEquipmentDamageParticular( id ){
	new tmpArray[ structUserEquip ] ,
		tmpArrayObject[ structObject ];
	
	ArrayGetArray( userEquipment[ id ] , userCurrentEquip[ id ] , tmpArray );

	ArrayGetArray( objectsList , tmpArray[ idItem ] , tmpArrayObject );
	
	return Float:tmpArrayObject[ primaryDamage ];
}

getEquipmentIDParticular( id , equipID ){
	new tmpArray[ structUserEquip ];
	
	ArrayGetArray( userEquipment[ id ] , equipID , tmpArray );
	
	return tmpArray[ idItem ];
}

getEquipmentAmountParticular( id , equipID ){
	new tmpArray[ structUserEquip ];
	
	ArrayGetArray( userEquipment[ id ] , equipID , tmpArray );
	
	return tmpArray[ itemAmount ];
}

getMaxCurrent( id ){
	new tmpArray[ structUserEquip ] ,
		tmpArrayObject[ structObject ];
	
	ArrayGetArray( userEquipment[ id ] , userCurrentEquip[ id ] , tmpArray );
	
	ArrayGetArray( objectsList , tmpArray[ idItem ] , tmpArrayObject );
	
	return tmpArrayObject[ maxObjectAmount ];
}

setEquipmentAmountParticular( id , equipID , amount ){
	new tmpArray[ structUserEquip ];
	
	ArrayGetArray( userEquipment[ id ] , equipID , tmpArray );
	
	tmpArray[ itemAmount ] = amount;
	
	ArraySetArray( userEquipment[ id ] , equipID , tmpArray );
}

getVModel( itemID , szModel[] , maxLen ){
	new tmpArray[ structObject ];
	
	ArrayGetArray( objectsList , itemID , tmpArray );
	
	copy( szModel , maxLen , tmpArray[ VModel ] );
}

getPModel( itemID , szModel[] , maxLen ){
	new tmpArray[ structObject ];
	
	ArrayGetArray( objectsList , itemID , tmpArray );
	
	copy( szModel , maxLen , tmpArray[ PModel ] );
}

getArrayObjectField( itemID , structObject:structField ){
	new tmpArray[ structObject ];
	
	ArrayGetArray( objectsList , itemID , tmpArray );
	
	return tmpArray[ structField ];
}

getNameItem( itemID , szName[] , maxLen ){
	new tmpArray[ structObject ];
	
	ArrayGetArray( objectsList , itemID , tmpArray );
	
	copy( szName , maxLen , tmpArray[ objectName ] );
}

executeAndCopy( pForward , toCopy[] , maxLen ){
	new arrayString[ 256 ];
	
	ExecuteForward( pForward , iRetNull , PrepareArray( arrayString , sizeof( arrayString ) , 1 ) , charsmax( arrayString ) );
	
	copy( toCopy , maxLen , arrayString ); 
}

structSecondary: getAction( id ){
	return structSecondary:getArrayObjectField( getEquipmentID( id ) , secondaryAction );
}

showEquip( id , page = 0 ){
	if( !is_user_alive( id ) ){
		return ;
	}
	
	new pMenu	=	menu_create( "Equipment" , "equipMenuHandle" );
	
	new szName[ 64 ] ,
		szTmp[ 256 ] ,
		iTmp[ 16 ];
	
	for( new iCurrent = 0 ; iCurrent < ArraySize( userEquipment[ id ] ) ; iCurrent++ ){
		getNameItem( getEquipmentIDParticular( id , iCurrent ) , szName , charsmax( szName ) );
		
		formatex( szTmp , charsmax( szTmp ) , "%s [%i/%i]" , szName , getEquipmentAmountParticular( id , iCurrent ) ,getArrayObjectField( getEquipmentIDParticular( id , iCurrent ) , maxObjectAmount ) );
		
		num_to_str( iCurrent , iTmp , charsmax( iTmp ) );
		
		menu_additem( pMenu , szTmp , iTmp );
	}
	
	menu_display( id , pMenu , page );
}

public equipMenuHandle( id , menu , item ){
	if( item == MENU_EXIT ){
		
		menu_destroy( menu );
		
		return PLUGIN_CONTINUE;
	}
	
	new access ,
	szInfo[ 256 ],
	szName[ 256 ],
	callback;
	
	menu_item_getinfo( menu , item , access , szInfo , charsmax( szInfo ) , szName , charsmax( szName ) , callback );
	
	menu_destroy( menu );
	
	new itemID = str_to_num( szInfo );
	
	if( itemID < 0 || itemID >= ArraySize( userEquipment[ id ] ) ){
		itemID = 0;
	}
	
	userCurrentEquip[ id ] = itemID;
	
	if( !is_user_alive( id ) ){
		return PLUGIN_CONTINUE;
	}
	
	deployWeapon( id );
	
	return PLUGIN_CONTINUE;
}

deployWeapon( id ){
	new weaponEnt = find_ent_by_owner( -1 , "weapon_knife" , id );
	
	if( pev_valid( weaponEnt ) ){
		fwDeploy( weaponEnt );
		
		setWeaponAnim( id , animDeploy );
	}
}

public fwShouldCollide( const iTouched, const iOther ){
	
    if( IsSmallBlock( iOther ) && IsSmallBlock( iTouched ) ){  
		forward_return( FMV_CELL, 0 );  
		return FMRES_SUPERCEDE;  
	}
	
    return FMRES_IGNORED;  
}  

bool: IsSmallBlock( iEnt ){
	if( !pev_valid( iEnt ) ){
		return false;
	}
	
	new szClass[ 256 ];
	
	pev( iEnt , pev_classname , szClass , charsmax( szClass ) );
	
	if( !equal( szClass , smallBlockClass ) ){
		return false;
	}
	
	return true;
}

bool: placeBlock( id ){
	if( !is_user_alive( id ) ){
		return false;
	}
	
	new structSecondary: actionTo	=	getAction( id );
	
	if( actionTo != CREATE_BLOCK ){
		return false;
	}
	
	new Float: fStartOrigin[ 3 ];
	
	new Float: fEndOrigin[ 3 ];
	
	new iHit ,
	Float: fFraction,
	Float: vecEndPos[ 3 ] ,
	Float: vecNormal[ 3 ];
	
	new pTr = create_tr2()
	
	getPlayerStartOrigin( id , fStartOrigin );
	
	getPlayerEndOrigin( id , fEndOrigin , get_pcvar_float( pCvars[ cvarRange ] ) );
	
	engfunc( EngFunc_TraceLine , fStartOrigin , fEndOrigin , DONT_IGNORE_MONSTERS , id , pTr );
	
	getTRInformations( pTr , iHit , fFraction , vecEndPos , vecNormal );
	
	free_tr2( pTr );
	
	if( iHit == -1 && 1.0 - fFraction < 0.01 ){
		return false;
	}
	
	if( checkISValidEnt( iHit ) ){
		calculateOriginFromEnt( vecEndPos , vecNormal , iHit );
	}
	else{
		normalizeOrigin( vecEndPos );
	}
	
	
	if( engfunc( EngFunc_FindEntityInSphere , -1 , vecEndPos , ( fSizeFull / 2.0 ) - 2.0 ) != 0){
		return false;
	}
	
	new tmpArray[ structObject ];
	
	ArrayGetArray( objectsList , getEquipmentID( id ) , tmpArray );	
	
	return createFullBlock( vecEndPos, getEquipmentID( id ) , tmpArray );
}

calculateOriginFromEnt( Float: vecEndPos[ 3 ] , Float: vecNormal[ 3 ] , iEnt ){
	new Float: fOrigin[ 3 ];
	
	pev( iEnt , pev_origin , fOrigin );
	
	xs_vec_copy( fOrigin , vecEndPos );
	
	for( new iCurrent = 0 ; iCurrent < 3 ; iCurrent++ ){
		if( vecNormal[ iCurrent ] > 0.1 ){
			vecEndPos[ iCurrent ] += fSizeFull;
		}
		else if( vecNormal[ iCurrent ] < -0.1 ){
			vecEndPos[ iCurrent ] -= fSizeFull;
		} 
	}
}

bool: checkISValidEnt( iEnt ){
	if( !pev_valid( iEnt ) ){
		return false;
	}
	
	new szClass[ 256 ];
	
	pev( iEnt , pev_classname , szClass , charsmax( szClass ) );
	
	if( !equal( szClass , fullBlockClass ) ){
		return false;
	}
	
	return true;
}

normalizeOrigin( Float: vecEndPos[ 3 ] ){
	vecEndPos[ 0 ] = normalizeOriginOne( vecEndPos[ 0 ] );
	vecEndPos[ 1 ] = normalizeOriginOne( vecEndPos[ 1 ] );
	vecEndPos[ 2 ] = normalizeOriginOne( vecEndPos[ 2 ] );
	
}

Float:normalizeOriginOne( Float: fOrigin ){
	new fAmount = floatround( floatdiv( fOrigin , fSizeFull ) , floatround_floor );
	
	if( fOrigin - ( float( fAmount ) * fSizeFull ) > fSizeFull / 2.0 ){
		fAmount += 1;
	}
	
	return float( fAmount ) * fSizeFull;
}

getTRInformations( pTr , &iHit , & Float: fFraction , Float:vecEndPos[ 3 ] , Float:vecNormal[ 3 ] ){
	iHit = get_tr2( pTr , TR_pHit );
	
	get_tr2( pTr , TR_flFraction , fFraction );
	
	get_tr2( pTr , TR_vecEndPos , vecEndPos );
	
	get_tr2( pTr , TR_vecPlaneNormal , vecNormal );
}

getPlayerStartOrigin( id , Float:fStartOrigin[ 3 ] ){
	new Float: fOrigin[ 3 ] ,
	Float: fView[ 3 ];
	
	pev( id , pev_origin, fOrigin );
	pev( id , pev_view_ofs , fView );
	
	xs_vec_add( fOrigin , fView , fStartOrigin );
}

getPlayerEndOrigin( id , Float:fEndOrigin[ 3 ] , Float: fScalar ){
	new Float: fStartOrigin[ 3 ];
	
	new Float: fAngles[ 3 ] ,
	Float: fVectorForward[ 3 ];
	
	getPlayerStartOrigin( id , fStartOrigin );
	
	pev( id , pev_v_angle , fAngles );
	
	angle_vector( fAngles , ANGLEVECTOR_FORWARD , fVectorForward );
	
	xs_vec_normalize( fVectorForward , fVectorForward );
	
	xs_vec_mul_scalar( fVectorForward , fScalar , fVectorForward );
	
	xs_vec_add( fStartOrigin , fVectorForward , fEndOrigin);
}

bool: createFullBlock( Float: fOrigin[ 3 ] , type , blockStruct[] ){
	
	new iEnt = createBlock( blockStruct[ NormalModel ] , fOrigin );
	
	if( !pev_valid( iEnt ) ){
		return false;
	}
	
	set_pev( iEnt , pev_classname , fullBlockClass );
	
	set_pev( iEnt , pev_solid , SOLID_BBOX );
	set_pev( iEnt , pev_movetype , MOVETYPE_NONE );
	
	set_pev( iEnt , pev_type_block , type );
	
	set_pev( iEnt , pev_health , float( blockStruct[ objectHealth ] ) );
	set_pev( iEnt , pev_old_health , float( blockStruct[ objectHealth ] ) );
	
	engfunc( EngFunc_SetSize , iEnt , fullSizeMin , fullSizeMax );
	
	emit_sound( iEnt , CHAN_STATIC , blockStruct[ soundPut ] , VOL_NORM , ATTN_NORM , 0 , PITCH_NORM );
	
	new iRet;
	
	ExecuteForward( blockStruct[ createBlockForwardHandle ] , iRet , iEnt );
	
	return true;
}

bool: createSmallBlock( iOwner , szModel[] , Float: fOrigin[ 3 ] , type , Float: fVelocity[ 3 ] = { 0.0 , 0.0 , 0.0 } , bool: block = true ){
	
	new iEnt = createBlock( szModel , fOrigin );
	
	if( !pev_valid( iEnt ) ){
		return false;
	}
	
	set_pev( iEnt , pev_classname , smallBlockClass );
	
	set_pev( iEnt , pev_owner , iOwner );
	
	set_pev( iEnt , pev_solid , SOLID_BBOX );
	set_pev( iEnt , pev_movetype , MOVETYPE_TOSS );
	
	set_pev( iEnt , pev_velocity , fVelocity );
	
	remove_task( iEnt );
	
	if( block ){
		set_pev( iEnt , pev_block_ent , 1 );
	
		set_task( smallBlockTimeBlock , "unBlockBlock" , iEnt );
	}
	
	set_pev( iEnt , pev_type_block , type );
	
	engfunc( EngFunc_SetSize , iEnt , smallSizeMin , smallSizeMax );
	
	setMinecraftThink( iEnt );
	
	return true;
}

createBlock( szModel[] , Float: fOrigin[ 3 ] ){
	if(entity_count() >= global_get(glb_maxEntities)){
		return 0;
	}
	
	new iEnt = engfunc( EngFunc_CreateNamedEntity , engfunc( EngFunc_AllocString , "info_target" ) );
	
	if( !pev_valid( iEnt ) ){
		return 0;
	}
	
	engfunc( EngFunc_SetOrigin , iEnt , fOrigin );
	engfunc( EngFunc_SetModel , iEnt , szModel );
	
	return iEnt;
}

restoreHealthEnt( iEnt ){
	new Float: fHealth;
			
	pev( iEnt , pev_old_health , fHealth );
			
	set_pev( iEnt, pev_health , fHealth );
}

bool: isFullBlockValid( iEnt ){
	if( !pev_valid( iEnt ) ){
		return false;
	}
	
	new szClassName[ 256 ];
	
	pev( iEnt , pev_classname , szClassName , charsmax( szClassName ) );
	
	if( !equal( szClassName , fullBlockClass ) ){
		return false;
	}
	
	return true;
}

bool: isEntBlocked( iEnt ){
	return bool: pev( iEnt , pev_block_ent );
}

public unBlockBlock( iEnt ){
	if( !pev_valid( iEnt ) ){
		return ;
	}
	
	set_pev( iEnt , pev_block_ent , 0 );
}

stock setWeaponAnim(id, anim) {
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end();
}

stock playSound( id , const soundPop[] , mp3 = true ){
	if( mp3 ){
		client_cmd( id , "mp3 play %s" , soundPop );
	}
}
