// ================================================================
// Over_rain_client.qc  --  LLUVIA DE CLIENTE, lado server
// ================================================================
//------------- MOD 15/NOV/2026  port de OverHorde (13/NOV/2026)
// Un func_rainzone no crea gotas: marca la zona y la config, y la lluvia la
// dibuja el csprogs (CSQC/Over_hud_rain.qc). Aca se mide cuanto cielo ve
// cada jugador y se manda todo por stats
//
// Techo y paredes: rosa de 16 porciones x 3 anillos alrededor del ojo, mas
// el ojo mismo (MOD 17/NOV/2026, antes 8 x 2). Una celda esta abierta si cae
// en una zona cliente, el ojo la ve en horizontal y arriba tiene cielo o el
// tope de la zona
//
//------------- MOD 17/NOV/2026  func_rainzone e info_rain se mudaron a
// Over_ambient_fx.qc como en OverHorde: con el flag CLIENTE la zona llama a
// RainC_ZoneInit, sin el flag llueve con entidades
//
// Diferencias con OverHorde: los stats salen por RainC_Stat, que reenvia todo
// cada RAINC_SYNC segundos para que una partida cargada recupere la lluvia
// (OverHorde usa SendStatIfChanged con hs_force)
//
// Enganches:
//  1. progs.src despues de Overfuncbob_fade.qc, que declara .alpha, y antes
//     de Over_ambient_fx.qc
//  2. client.qc: prototipo y RainC_Frame() al principio de PlayerPostThink
//  3. csprogs.src: CSQC/Over_hud_rain.qc, HUD_DrawRain desde CSQC_DrawHud
//  Usa T_Damage y clamp (math.qc). Las keys estan en Slender.fgd
// ================================================================

float RAIN_STATS_ON   = 1;       // 0 apaga la lluvia de cliente en el server
float RAINZONE_CLIENT = 1;       // spawnflag del func_rainzone, MOD 17/NOV/2026

// stats, gemelos en CSQC/Over_hud_rain.qc
float STAT_VIEWANG    = 60;      // pitch y yaw, Ironwail no da view_angles al csqc
float STAT_VIEWVEL    = 61;      // velocidad, la gota se queda en el mundo al caminar
float STAT_RAIN_CFG   = 72;      // config de la zona, 0 = no llueve
//------------- MOD 17/NOV/2026  un stat por anillo, la porcion k es el bit 2^k
float STAT_RAIN_MASK  = 73;      // anillo interno, y el ojo en RAINC_HEAD
float STAT_RAIN_MID   = 74;      // anillo medio
float STAT_RAIN_OUT   = 75;      // anillo externo
float SVC_UPDATESTAT  = 3;       // el defs.qc vanilla no lo trae

float RAINC_DT    = 0.1;         // segundos entre muestreos por jugador
//------------- MOD 17/NOV/2026  cada radio en el centro de su banda del cliente
float RAINC_R1    = 95;          // anillo interno, el cliente lo usa de 40 a 150
float RAINC_R2    = 225;         // anillo medio, de 150 a 300
float RAINC_R3    = 410;         // anillo externo, de 300 a 520
// giro de una porcion a la siguiente, 22.5 grados en sentido antihorario
float  RAINC_COS22 = 0.92388;    // cos 22.5
float  RAINC_SIN22 = 0.38268;    // sin 22.5
vector RAINC_DIR0  = '0.98079 0.19509 0';   // centro de la porcion 0, a 11.25 grados de +x
float RAINC_LIFT  = 96;         // reintento mas arriba si la vista choca (cuestas, barandas)
float RAINC_HEAD  = 65536;       // bit del ojo, las celdas usan 1..32768
float RAINC_TAIL  = 0.5;         // segundos que siguen viajando angulos al quedar sin cielo
float RAINC_SYNC  = 1;           // segundos entre reenvios completos de los stats

// defaults de la zona
float RAINC_COUNT = 6;           // x25 gotas
float RAINC_FALL  = 800;
float RAINC_ALPHA = 0.32;

// keys del func_rainzone y del info_rain
.float splashcolor, wind_rain, rain_damage;

entity rainc_zones;              // cadena de zonas, sin inicializador
float  rainc_force;              // RainC_Stat manda aunque no haya cambio, sin inicializador
.entity rainc_next;
.entity rainc_zone;              // zona del jugador en el ultimo muestreo
.float  rainc_mask, rainc_time, rainc_hurt, rainc_until, rainc_sync;
.float  rainc_mid, rainc_out;    // MOD 17/NOV/2026  anillos medio y externo
.float  hs_viewang, hs_vel, hs_rainc_cfg, hs_rainc_mask, hs_rainc_mid, hs_rainc_out;

// spawn de la zona, self = el brush ya con setmodel
void() RainC_ZoneInit =
{
	if (!self.count)       self.count       = RAINC_COUNT;
	if (!self.height)      self.height      = RAINC_FALL;
	if (!self.alpha)       self.alpha       = RAINC_ALPHA;
	if (!self.splashcolor) self.splashcolor = 1;
	// invisible como un trigger, absmin y absmax ya quedaron del setmodel
	self.modelindex = 0;
	self.model = "";
	self.rainc_next = rainc_zones;
	rainc_zones = self;
};

// zona sobre p: dentro de su huella XY y bajo su tope
entity(vector p) RainC_ZoneAt =
{
	local entity z;

	z = rainc_zones;
	while (z != world)
	{
		if (p_x >= z.absmin_x && p_x <= z.absmax_x)
		if (p_y >= z.absmin_y && p_y <= z.absmax_y)
		if (p_z <= z.absmax_z)
			return z;
		z = z.rainc_next;
	}
	return world;
};

// arriba de p hay cielo o el tope de la zona
float(entity z, vector p) RainC_SkyAbove =
{
	if (p_z >= z.absmax_z) return TRUE;
	traceline(p, [p_x, p_y, z.absmax_z], TRUE, self);
	if (trace_fraction == 1) return TRUE;
	return pointcontents(trace_endpos + '0 0 2') == CONTENT_SKY;
};

// celda en pt: zona, vista horizontal desde el ojo y cielo arriba
float(vector eye, vector pt) RainC_Cell =
{
	local entity z;

	z = RainC_ZoneAt(pt);
	if (z == world) return FALSE;
	traceline(eye, pt, TRUE, self);
	if (trace_fraction < 1)
	{
		pt_z = pt_z + RAINC_LIFT;
		traceline(eye, pt, TRUE, self);
		if (trace_fraction < 1) return FALSE;
	}
	return RainC_SkyAbove(z, pt);
};

//------------- MOD 17/NOV/2026  16 porciones x 3 anillos
// celdas de self: la porcion k es el bit 2^k en rainc_mask (interno, mas
// RAINC_HEAD el ojo), rainc_mid y rainc_out. Las porciones van de 22.5
// grados desde +x en sentido antihorario y se miden en su centro.
// El cliente arma el mismo bit en rain_cell_open
void() RainC_Sample =
{
	local vector eye, ray;
	local float k, bit, inner, middle, outer, tx;

	eye = self.origin + self.view_ofs;
	self.rainc_zone = RainC_ZoneAt(eye);
	self.rainc_mask = 0;
	self.rainc_mid  = 0;
	self.rainc_out  = 0;
	if (self.rainc_zone == world) return;

	inner  = 0;
	middle = 0;
	outer  = 0;
	if (RainC_SkyAbove(self.rainc_zone, eye)) inner = RAINC_HEAD;
	ray = RAINC_DIR0;
	bit = 1;
	k = 0;
	while (k < 16)
	{
		if (RainC_Cell(eye, eye + ray * RAINC_R1)) inner  = inner  | bit;
		if (RainC_Cell(eye, eye + ray * RAINC_R2)) middle = middle | bit;
		if (RainC_Cell(eye, eye + ray * RAINC_R3)) outer  = outer  | bit;

		// gira ray 22.5 grados a la porcion siguiente
		tx    = ray_x;
		ray_x = tx * RAINC_COS22 - ray_y * RAINC_SIN22;
		ray_y = tx * RAINC_SIN22 + ray_y * RAINC_COS22;
		bit = bit * 2;
		k = k + 1;
	}
	self.rainc_mask = inner;
	self.rainc_mid  = middle;
	self.rainc_out  = outer;
};

// lluvia acida: rain_damage por segundo con cielo sobre el ojo
// inflictor world para que no empuje
void() RainC_Acid =
{
	if (self.rainc_zone == world) return;
	if (self.rainc_zone.rain_damage <= 0) return;
	if (!(self.rainc_mask & RAINC_HEAD)) return;
	if (self.health <= 0 || !self.takedamage) return;
	if (time < self.rainc_hurt) return;
	self.rainc_hurt = time + 1;
	T_Damage(self, world, world, self.rainc_zone.rain_damage);
};

// config en 16 bits: count (4) | caida/50 (5) | alpha*15 (4) | color (2)
// | viento (1). Nunca da 0 porque count va de 1 a 15
float(entity z) RainC_PackCfg =
{
	local float c, f, a, col, w;

	c   = clamp(rint(z.count), 1, 15);
	f   = clamp(rint(z.height / 50), 1, 31);
	a   = clamp(rint(z.alpha * 15), 1, 15);
	col = clamp(rint(z.splashcolor), 1, 3);
	w   = 0;
	if (z.wind_rain) w = 1;
	return c + f * 16 + a * 512 + col * 8192 + w * 32768;
};

// angulos a 1/8 de grado: (pitch+180)*8 + yaw*8*4096
float(vector a) RainC_PackViewAng =
{
	local float p, y;

	p = clamp(rint((a_x + 180) * 8), 0, 4095);
	y = a_y - floor(a_y / 360) * 360;
	y = rint(y * 8);
	if (y >= 2880) y = 0;
	return p + y * 4096;
};

// velocidad: 8 bits por eje con +128, 16 u/s por paso
float(vector v) RainC_PackVel =
{
	local float x, y, z;

	x = clamp(rint(v_x / 16) + 128, 0, 255);
	y = clamp(rint(v_y / 16) + 128, 0, 255);
	z = clamp(rint(v_z / 16) + 128, 0, 255);
	return x + y * 256 + z * 65536;
};

// manda el stat st a self si cambio o si toca reenvio, cache en un campo
void(float st, float val, .float cache) RainC_Stat =
{
	if (!rainc_force && self.cache == val) return;
	self.cache = val;
	msg_entity = self;
	WriteByte(MSG_ONE, SVC_UPDATESTAT);
	WriteByte(MSG_ONE, st);
	WriteLong(MSG_ONE, val);
};

// cada frame con self = jugador. Angulos y velocidad solo viajan mientras
// hay cielo y un rato despues, para el fundido de salida
void() RainC_Frame =
{
	local float cfg;

	if (!RAIN_STATS_ON) return;
	if (time >= self.rainc_time)
	{
		self.rainc_time = time + RAINC_DT;
		RainC_Sample();
		RainC_Acid();
	}
	cfg = 0;
	if (self.rainc_zone != world) cfg = RainC_PackCfg(self.rainc_zone);
	if (self.rainc_mask || self.rainc_mid || self.rainc_out)   // MOD 17/NOV/2026
		self.rainc_until = time + RAINC_TAIL;

	rainc_force = FALSE;
	if (time >= self.rainc_sync)
	{
		self.rainc_sync = time + RAINC_SYNC;
		rainc_force = TRUE;
	}
	RainC_Stat(STAT_RAIN_CFG,  cfg,             hs_rainc_cfg);
	RainC_Stat(STAT_RAIN_MASK, self.rainc_mask, hs_rainc_mask);
	RainC_Stat(STAT_RAIN_MID,  self.rainc_mid,  hs_rainc_mid);    // MOD 17/NOV/2026
	RainC_Stat(STAT_RAIN_OUT,  self.rainc_out,  hs_rainc_out);
	if (time < self.rainc_until)
	{
		RainC_Stat(STAT_VIEWANG, RainC_PackViewAng(self.v_angle), hs_viewang);
		RainC_Stat(STAT_VIEWVEL, RainC_PackVel(self.velocity),    hs_vel);
	}
};
