/* ================================================================
 Over_ambient_fx.qc  LLUVIA DE ENTIDADES, by Rel_71

------------- MOD 17/NOV/2026  port de Over H 
algun dia voy a terminar el header de esto por que hay mas que contar aqui
 Con el flag CLIENTE la zona se la queda Over_rain_client.qc (RainC_ZoneInit)
================================================================
*/ 

// defaults de la zona de entidades
float ODE_RN_RATE  = 0.05;       // segundos entre pasadas             key ode_rate
float ODE_RN_COUNT = 4;          // gotas por pasada                   key count
float ODE_RN_FALL  = 500;        // velocidad de caida                 key height
float ODE_RN_LIFE  = 3;          // segundos de vida si no toca nada   key wait
float ODE_RN_DIST  = 1200;       // radio de activacion por jugador    key speed
float ODE_RN_CHECK = 1;          // segundos entre chequeos            key ode_check
float ODE_RN_ALPHA = 0.6;        // transparencia de la gota           key alpha


float  ODE_RN_WIND = 0.4;        // fraccion de la caida que se corre en -y
vector ODE_RN_TILT = '0 0 -30';  // roll de la gota 

// colores de la salpicadura, indices de la paleta de quake
float ODE_RN_SPLASH1 = 41;       // azul
float ODE_RN_SPLASH2 = 57;       // verde
float ODE_RN_SPLASH3 = 138;      // morado

.float ode_rate, ode_check;

//proto por si las dudas
void() ode_rain_think;

// TRUE si un jugador esta a menos de speed del centro del brush
float() ode_fx_client_near =
{
	local entity c;
	local vector center;

	center = (self.absmin + self.absmax) * 0.5;
	c = find(world, classname, "player");
	while (c != world)
	{
		if (vlen(c.origin - center) < self.speed)
			return TRUE;
		c = find(c, classname, "player");
	}
	return FALSE;
};

// la gota toco algo salpica segun el color, acido opcional y se borra
void() ode_rain_touch =
{
	if      (self.splashcolor == 1) particle(self.origin + '0 0 6', '0 0 -1', ODE_RN_SPLASH1, 8);
	else if (self.splashcolor == 2) particle(self.origin + '0 0 6', '0 0 -1', ODE_RN_SPLASH2, 8);
	else if (self.splashcolor == 3) particle(self.origin + '0 0 6', '0 0 -1', ODE_RN_SPLASH3, 8);

	if (self.rain_damage > 0 && other.takedamage)
		T_Damage(other, self, world, self.rain_damage);

	remove(self);
};

// dormida cada ode_check segundos mira si hay alguien cerca
void() ode_rain_check =
{
	if (ode_fx_client_near())
	{
		self.delay     = time + self.ode_check;
		self.think     = ode_rain_think;
		self.nextthink = time + self.ode_rate;
		return;
	}
	self.nextthink = time + self.ode_check;
};

// despierta count gotas por pasada desde la cara superior del brush
void() ode_rain_think =
{
	local entity d;
	local vector p;
	local float  n;
	local string mdl;

	// cada ode_check segundos vuelve a mirar, si no hay nadie se duerme
	if (time >= self.delay)
	{
		if (!ode_fx_client_near())
		{
			self.think     = ode_rain_check;
			self.nextthink = time + self.ode_check;
			return;
		}
		self.delay = time + self.ode_check;
	}

	// modelo segun el color, los tres precacheados en el spawn de la zona
	if      (self.splashcolor == 2) mdl = "progs/ver_gota2.mdl";
	else if (self.splashcolor == 3) mdl = "progs/ver_gota3.mdl";
	else                            mdl = "progs/ver_gota1.mdl";

	n = self.count;
	while (n > 0)
	{
		p_x = self.absmin_x + random() * (self.absmax_x - self.absmin_x);
		p_y = self.absmin_y + random() * (self.absmax_y - self.absmin_y);
		p_z = self.absmax_z;

		d           = spawn();
		d.classname = "ode_rain";
		setmodel(d, mdl);
		setorigin(d, p);
		setsize(d, '0 0 0', '0 0 0');
		d.movetype = MOVETYPE_FLYMISSILE;   // vuela recto y llama al touch
		d.solid    = SOLID_BBOX;
		d.alpha    = self.alpha;

		d.velocity_z = -self.height;
		if (self.wind_rain)
		{
			d.velocity_y = -self.height * ODE_RN_WIND;
			d.angles     = ODE_RN_TILT;
		}

		// config del touch, copiada de la zona a la gota
		d.splashcolor = self.splashcolor;
		d.rain_damage = self.rain_damage;
		d.touch       = ode_rain_touch;
		d.think       = SUB_Remove;          // timeout si no toca nada
		d.nextthink   = time + self.wait;

		n = n - 1;
	}
	self.nextthink = time + self.ode_rate;
};

// ---------------------------------------------------------------- entidades

// zona de lluvia con el flag CLIENTE la dibuja el csprogs, sin el flag
// emite gotas como entidades
void() func_rainzone =
{
	setmodel(self, self.model);
	setsize(self, self.mins, self.maxs);
	self.solid    = SOLID_NOT;
	self.movetype = MOVETYPE_NONE;

	if (self.spawnflags & RAINZONE_CLIENT) { RainC_ZoneInit(); return; }

	if (!self.count)       self.count       = ODE_RN_COUNT;
	if (!self.ode_rate)    self.ode_rate    = ODE_RN_RATE;
	if (!self.height)      self.height      = ODE_RN_FALL;
	if (!self.wait)        self.wait        = ODE_RN_LIFE;
	if (!self.speed)       self.speed       = ODE_RN_DIST;
	if (!self.ode_check)   self.ode_check   = ODE_RN_CHECK;
	if (!self.alpha)       self.alpha       = ODE_RN_ALPHA;
	if (!self.splashcolor) self.splashcolor = 1;

	// los tres colores, un info_rain puede cambiar splashcolor en juego
	precache_model("progs/ver_gota1.mdl");
	precache_model("progs/ver_gota2.mdl");
	precache_model("progs/ver_gota3.mdl");

	// invisible como un trigger, absmin y absmax ya quedaron del setmodel
	self.modelindex = 0;
	self.model = "";

	// arranca dormida y escalonada para no caer todas en el mismo frame
	self.think     = ode_rain_check;
	self.nextthink = time + random() * self.ode_check;
};

float SF_INFORAIN_WIND = 1;      // seteado = viento, sin setear = vertical
float SF_INFORAIN_DMG  = 2;      // seteado = aplica rain_damage, sin setear = sin acido

// al dispararse copia sus keys seteadas a los func_rainzone de su target,
// viento y acido siempre segun sus flags. Igual que en OverHorde
void() info_rain_use =
{
	local entity z;

	z = find(world, targetname, self.target);
	while (z != world)
	{
		if (z.classname == "func_rainzone")
		{
			if (self.count)       z.count       = self.count;
			if (self.ode_rate)    z.ode_rate    = self.ode_rate;
			if (self.height)      z.height      = self.height;
			if (self.wait)        z.wait        = self.wait;
			if (self.speed)       z.speed       = self.speed;
			if (self.ode_check)   z.ode_check   = self.ode_check;
			if (self.splashcolor) z.splashcolor = self.splashcolor;
			z.wind_rain = 0;
			if (self.spawnflags & SF_INFORAIN_WIND) z.wind_rain = 1;
			z.rain_damage = 0;
			if (self.spawnflags & SF_INFORAIN_DMG) z.rain_damage = self.rain_damage;
		}
		z = find(z, targetname, self.target);
	}
};

void() info_rain =
{
	self.use = info_rain_use;
};
