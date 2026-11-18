// ================================================================
// cl_hud.qc  --  HUD del Slender By Rel71
// ================================================================
//------------- MOD inicial 15/NOV/2026
/*
a fecha nov 15 todavia no estamos seugros de que apariencia deberia de tener el 
hud por lo que solo voy a implementar el minimo de informacion que se necesita 
*/


void(vector vs) HUD_DrawStatus =
{
	local vector bar;
	local float v;

	bar = [(vs_x - 320) * 0.5, vs_y - CL_NUM_W, 0];

	v = getstatf(STAT_ARMOR);
	CL_DrawNum(bar + '24 0 0', v, 3, v <= 25);
	v = getstatf(STAT_HEALTH);
	CL_DrawNum(bar + '136 0 0', v, 3, v <= 25);
	v = getstatf(STAT_AMMO);
	CL_DrawNum(bar + '248 0 0', v, 3, v <= 10);
};
