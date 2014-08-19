enum structSecondary {
	DO_NOTHING,
	CREATE_BLOCK
}

enum structDrop{
	CAN_DROP,
	NO_DROP
}

forward minecraftMod_V_Model( szModel[] , maxLen );

forward minecraftMod_P_Model( szModel[] , maxLen );

forward minecraftMod_Normal_Model( szModel[] , maxLen );

forward minecraftMod_Little_Model( szModel[] , maxLen );

forward Float:minecraftMod_primaryDamage();

forward structSecondary: minecraftMod_secondaryAction();

forward minecraftMod_SoundPut( szSound[] , maxLen );

forward minecraftMod_SoundDestroy( szSound[] , maxLen );

forward minecraftMod_SoundDestroying( szSound[] , maxLen );

native registerNewObject( szName[] , maxAmount , structDrop: onDrop , iHealth );

forward minecraftMod_blockCreated( iEnt );