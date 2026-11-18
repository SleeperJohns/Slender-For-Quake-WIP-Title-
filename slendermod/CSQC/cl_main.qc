// ==========================================================================
// cl_main.qc  --  entradas del motor al csprogs by Rel71
// =========================================================================
//------------- MOD inicial 15/NOV/2026
/* 
Ironwail solo tiene el simple CSQC: CSQC_Init, CSQC_DrawHud y
 CSQC_DrawScores

esto es la composicion de toda la estructura y desde aqui deribo a los submodulos
hud, rain y estatica en un futuro
*/
// =================================================================

void(float apilevel, string enginename, float engineversion) CSQC_Init =
{
	CL_NumPrecache();
};

// cada frame, virtsize ya viene en la escala de scr_sbarscale
void(vector virtsize, float showscores) CSQC_DrawHud =
{
	if (intermission) return;
	HUD_DrawRain(virtsize);      // primero, queda debajo del hud (Over_hud_rain.qc)
	HUD_DrawStatus(virtsize);    // cl_hud.qc
};

// declarada en cl_csdefs.qc, por ahora sin marcador
void(vector virtsize, float showscores) CSQC_DrawScores =
{
};
