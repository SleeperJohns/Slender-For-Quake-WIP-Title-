// ====================================================
// cl_util.qc  --  utilidades de dibujo del cliente by Rel71
// ====================================================
//------------- MOD inicial 15/NOV/2026
// numeros grandes de la barra de Quake, del gfx.wad: num_0..9 y num_minus,
// anum_ son los rojos. En el csqc los lumps del wad se piden como gfx/<lump>
// ================================================================

const float CL_NUM_W = 24;       // ancho y alto de un digito

// va en CSQC_Init
void() CL_NumPrecache =
{
	local float i;

	i = 0;
	while (i < 10)
	{
		precache_pic(strcat("gfx/num_", ftos(i)));
		precache_pic(strcat("gfx/anum_", ftos(i)));
		i = i + 1;
	}
	precache_pic("gfx/num_minus");
	precache_pic("gfx/anum_minus");
};

// como el Sbar_DrawNum original del motor
void(vector pos, float num, float digits, float red) CL_DrawNum =
{
	local string s, pre, c;
	local float l, i;

	s = ftos(num);
	l = strlen(s);
	if (l > digits)
	{
		s = substring(s, l - digits, digits);
		l = digits;
	}
	pos_x = pos_x + (digits - l) * CL_NUM_W;

	pre = "gfx/num_";
	if (red) pre = "gfx/anum_";
	i = 0;
	while (i < l)
	{
		c = substring(s, i, 1);
		if (c == "-") c = "minus";
		drawpic(pos, strcat(pre, c), [CL_NUM_W, CL_NUM_W], '1 1 1', 1, 0);
		pos_x = pos_x + CL_NUM_W;
		i = i + 1;
	}
};
