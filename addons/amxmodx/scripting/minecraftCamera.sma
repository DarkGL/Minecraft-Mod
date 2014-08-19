/*	
@author Rafal "DarkGL" Wiecek 
@site www.darkgl.amxx.pl
*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <xs>

#define PLUGIN	"Minecraft Camera"
#define AUTHOR	"DarkGL"
#define VERSION	"1.0"

new const g_sCamclass[] = "PlayerCamera";
new pMenu;

public plugin_init(){
	
	register_plugin( PLUGIN, VERSION, AUTHOR )
	
	register_clcmd( "say /mineCamera" , "cameraMenu" );
	register_clcmd( "say_team /mineCamera" , "cameraMenu" );
	
	pMenu	=	menu_create( "Minecraft Camera" , "menuHandle" );
	
	menu_additem( pMenu , "Widok pierwszoosobowy" , "1" );
	menu_additem( pMenu , "Widok za plecow" , "2" );
	menu_additem( pMenu , "Widok z przodu" , "3" );
	
	menu_setprop( pMenu , MPROP_EXITNAME , "Wyjscie" );
	
	register_forward( FM_Think, "Think_PlayerCamera" );
}

public cameraMenu( id ){
	
	menu_display( id , pMenu );
	
	return PLUGIN_HANDLED;
}

public menuHandle( id , menu , item ){
	
	if( item == MENU_EXIT || !is_user_alive( id ) ){
		return PLUGIN_CONTINUE;
	}
	
	new szInfo[ 256 ],
	szName[ 256 ],
	access,
	callback;
	
	menu_item_getinfo( menu , item , access , szInfo , charsmax( szInfo ) , szName , charsmax( szName ) , callback );
	
	item	=	str_to_num( szInfo );
	
	switch( item ){
		case 1:{
			set_view( id , CAMERA_NONE );
		}
		case 2:{
			Create_PlayerCamera( id , 0 );
		}
		case 3:{
			Create_PlayerCamera( id , 1 );
		}
	}
	
	menu_display( id , pMenu );
	
	return PLUGIN_CONTINUE;
}

Create_PlayerCamera( id , type )
{
	new iEnt; static const sClassname[] = "classname";
	while( ( iEnt = engfunc( EngFunc_FindEntityByString, iEnt, sClassname, g_sCamclass ) ) != 0 )
	{
		if( pev( iEnt, pev_owner) == id )
		{
			remove_entity( iEnt );
		}
	}
	
	static const sInfo_target[] = "info_target";
	iEnt = engfunc( EngFunc_CreateNamedEntity, engfunc( EngFunc_AllocString, sInfo_target ) )
	
	if( !iEnt )
		return;
	
	static const sCam_model[] = "models/w_usp.mdl";
	set_pev( iEnt, pev_classname, g_sCamclass );
	engfunc( EngFunc_SetModel, iEnt, sCam_model );
	
	set_pev( iEnt, pev_solid, SOLID_TRIGGER );
	set_pev( iEnt, pev_movetype, MOVETYPE_FLY );
	set_pev( iEnt, pev_owner, id );
	
	set_pev( iEnt , pev_iuser1 , type );
	
	set_pev( iEnt, pev_rendermode, kRenderTransTexture );
	set_pev( iEnt, pev_renderamt, 0.0 );
	
	engfunc( EngFunc_SetView, id, iEnt );
	set_pev( iEnt, pev_nextthink, get_gametime() );
}

public Think_PlayerCamera( iEnt )
{
	if( !pev_valid( iEnt ) ){
		return FMRES_IGNORED;
	}
	
	static sClassname[32];
	pev( iEnt, pev_classname, sClassname, sizeof sClassname - 1 );
	
	if( !equal( sClassname, g_sCamclass ))
		return FMRES_IGNORED;
	
	static iOwner;
	iOwner = pev( iEnt, pev_owner );
	
	if( !is_user_alive( iOwner ) )
		return FMRES_IGNORED;
	
	static iButtons;
	iButtons = pev( iOwner, pev_button );
	
	if( iButtons & IN_USE )
	{
		engfunc( EngFunc_SetView, iOwner, iOwner );
		engfunc( EngFunc_RemoveEntity, iEnt );
		return FMRES_IGNORED;
	}
	
	static Float:fOrigin[3], Float:fAngle[3], Float: fView[ 3 ] , Float: fOriginNew[ 3 ];
	pev( iOwner, pev_origin, fOrigin );
	pev( iOwner , pev_view_ofs , fView );
	
	pev( iOwner, pev_v_angle, fAngle );
	
	static Float:fVBack[3];
	angle_vector( fAngle, ANGLEVECTOR_FORWARD, fVBack );
	
	xs_vec_add( fOrigin , fView , fOrigin );
	
	if( pev( iEnt , pev_iuser1 ) == 0 ){
		xs_vec_neg( fVBack , fVBack );
	}
	
	fOriginNew[2] = fOrigin[ 2 ] + 20.0;
	
	xs_vec_mul_scalar( fVBack , 150.0 , fVBack );
	
	xs_vec_add( fOrigin , fVBack , fOriginNew );
	
	trace_line( iOwner , fOrigin , fOriginNew , fOriginNew );
	
	engfunc( EngFunc_SetOrigin, iEnt, fOriginNew );
	
	xs_vec_sub( fOrigin, fOriginNew , fOrigin );
	xs_vec_normalize( fOrigin , fOrigin );
	
	vector_to_angle(  fOrigin ,  fOrigin );
	
	fOrigin[ 0 ] *= -1;
	
	set_pev( iEnt, pev_angles,  fOrigin );
	set_pev( iEnt, pev_nextthink, get_gametime() );
	
	return FMRES_HANDLED;
}
