/*
Buenas Rel here
este es un port casi al calco desde alkaline puesto que funciona mucho mejor que el original func bob
del dp300, el unico agregado extra es que ahora puedes tener un bobber con alpha y SIN COLICION

de verdad la mento que este comentado en español pero es mi idioma nativo y se me hace mucho mas facil asi	

ÑÑÑÑÑÑ
*/
 

/*
Hey, Rel here.
This is a near-exact port from Alkaline, as it functions much better than the original 'func_bob' from the DP300 build
 The only addition is that you can now have a 'bobber' with alpha transparency and NO COLLISION.
 */

/*
	FUNC_BOBBING

a lot has been done here to never ever rely on values that are repeatedly summed
over time, as floating point error will cause gradual drift.

usually, movers use self.ltime so that time doesn't advance for them while they're
blocked, preventing SUB_CalcMove from being shifted off the end of its motion and
screwing up doors. we don't do that here, because accumulated time error in .ltime  
will cause bobbings to slowly slide out of phase with each other and not keep good 
time. if the mapper sets an oscillation period of 5.0 seconds, the mover damn sure
better oscillate once every exactly 5 seconds, not '5-ish'.

engine structure requires that mover thinks be scheduled using .ltime because that's
what it compares a MOVETYPE_PUSH's nextthink against, but we can use global time for
actual positioning/velocity. it requires some particular gymnastics in the .blocked()
function, but the result is precise and seamless.

.wait: wavelength in seconds
.delay: current phase offset (0-1)
.search_time: origin point in time of the cosine wave. whenever we save it, we shift
	it backwards by the current .delay * .wait
.length: think rate, usually 0.1 but can be lower on hyperactive bobbers
*/

const float SFLAG_BOB_CRUSHER = 2;
const float SFLAG_BOB_NONSOLID = 4;
const float SFLAG_BOB_STOPLOW = 8;
const float SFLAG_BOB_STOPMID = 16;
const float SFLAG_BOB_STOPHI = 32;
const float SFLAG_BOB_RANDPHASE = 64;   // arranca en una fase random (desincroniza bobs) / it starts in a random phase
const float SFLAG_BOB_STOP = 8+16+32;

// think rate (el ".length" de Alkaline) dp300 no tenia este campo, ni este servidor
.float length;

//-no pragma autoproto asi que los prototipos van primero
void() func_bobbing_think;
void() func_bobbing_spawn;


void() func_bobbing_blocked =
{
	// T_Damage estandar de 4 argumentos
	T_Damage(other, self, self, self.dmg);
	
	if (self.spawnflags & SFLAG_BOB_CRUSHER)	// don't reverse
		return;
	
	// reversing direction entails reversing the phase
	self.delay = (self.delay * -1) + 1 + (self.length / self.wait);
	// put it one think in the future too
	
	// set new starting conditions to reanchor the reverse movement at
	// the moment of contact
	self.search_time = time - self.delay * self.wait - self.length;
	// subtracting .length puts the reversed wave one more think in the past.
	// if we don't we'll get a frame of 0 movement
	
	// start new movement now or we'll be a CRUSHER anyway
	func_bobbing_think();
}

void() func_bobbing_use = 
{
	self.think = func_bobbing_think;
	
	if (self.state == 2)	// a future stop was requested but we never reached it
		self.state = 1;		// go back to being plain old 'on'
	else
		self.state = !self.state;
	
	if (self.state)	// start immediately
	{
		self.search_time = time - self.delay * self.wait;
		//sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);	// move
		self.think();
		return;
	}
	
	if (self.spawnflags & SFLAG_BOB_STOP)	// stop at an apex, not immediately
	{
		self.state = 2;
		return;
	}
	
	// stop immediately
	sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);	// cut off move sound with stop sound
	self.nextthink = 0;
}

vector(float phase) func_bobbing_pos =
{
	vector pos;
	float cosD;

	//-------------MOD INI 29/octubre/2026
	// coseno exacto con makevectors  como Alkaline  ver SinCos en math.qc
	cosD = (1 - cos_deg(360 * phase)) / 2;	// flip -1/1 and scale to 0-1
	pos = self.pos1 + (cosD * (self.pos2 - self.pos1));
	return pos;
}



void() func_bobbing_think =
{
	if (!self.state)
	{
		self.velocity = VEC_ORIGIN;
		return;
	}

	vector dst;
	float phase;
	float atLow, atHigh, stop;
	
	// always derive current phase from a fixed starting time rather than
	// summing an offset every think, or we'll accumulate error and drift
	phase = (time - self.search_time) / self.wait;
	phase = phase - floor(phase);	// fraccion 0-1 (equivale a "% 1", sin el opcode de modulo)
	if (phase < self.delay)
		phase += 1;	// don't wrap yet
	
	atLow = (self.delay < 0.5 && phase >= 0.5);
	atHigh = (self.delay < 1 && phase >= 1);
	
	if (self.state == 2) // stop at our earliest convenience
	{
		if (atLow && (self.spawnflags & SFLAG_BOB_STOPLOW))
		{
			phase = 0.5;
			stop = TRUE;
		}
		else if (atHigh && (self.spawnflags & SFLAG_BOB_STOPHI))
		{
			phase = 0;
			stop = TRUE;
		}
		else if (self.spawnflags & SFLAG_BOB_STOPMID)
		{
			if (self.delay < 0.25 && phase >= 0.25)
			{
				phase = 0.25;
				stop = TRUE;
			}
			else if (self.delay < 0.75 && phase >= 0.75)
			{
				phase = 0.75;
				stop = TRUE;
			}		
		}
	}	
	else if ( atLow || atHigh )
	{
		// when we pass either apex, repeat the noises
		//sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);	// move
		//sound (self, CHAN_BODY, self.noise, 1, ATTN_NORM);	// stop
	}
	
	if (stop)
	{
		self.state = 0;
		sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);	// cut off move sound with stop sound
	}
	
	self.delay = phase;
	if (self.delay > 1)	// now we can wrap
		self.delay -= 1;
	
	// whither are we going
	dst = func_bobbing_pos(phase);
	
	self.velocity = (dst - self.origin) / self.length;
	self.nextthink = self.ltime + self.length;
}

/*QUAKED func_bobbing (0 .5 .8) ? START_OFF CRUSHER STOP_LOW STOP_MID STOP_HIGH - - START_INVIS
Bobbing platform. Moves in a smooth sine wave. Build at the center of motion, specify 'wait' for the wavelength in seconds and 'distance' for the amplitude (distance from end to end) in units.
Trigger to freeze/reactivate.

"angle" set bob axis
"distance" total distance of bob, will move half this far in either direction
"pos1"/"pos2" ignore angle/distance and set apex offsets directly
"wait" wavelength of bob in seconds
"delay" phase offset to start at (0 = pos1, 0.5 = pos2, 1.0 = back at pos1 again)
"sounds"
0) none, or, set your own with 'noise' (stop sound) and 'noise1' (move sound)
1) ratchet metal
2) base plat

Spawnflags
START_OFF	start off
CRUSHER		don't reverse when blocked
STOP_*		when triggered off, keep oscillating until reaching the low/high/midpoint and stop there. checking more than one adds eligible stopping places, and the bobber will stop at the first one reached.
*/
/*FGD
@baseclass base(Appearflags, Targetname, TrainSounds, Angle, Func, FuncInvis) = Bob
[
	spawnflags(flags) = [
		1 : "Start off" : 0
		2 : "Crusher (no reverse)" : 0
		4 : "Don't stop until low pos" : 0
		8 : "Don't stop until mid pos" : 0
		16 : "Don't stop until high pos" : 0
	]
	wait(string) : "Period (Wavelength)" : "4"
	distance(integer) : "Length (Amplitude)" : 64
	delay(string) : "Starting offset (0-1) (Phase)" : "0.0"
	dmg(integer) : "Damage when blocked" : 2
	noise(string) : "Override stop sound"
	noise1(string) : "Override move sound"
	pos1(string) : "Override peak position (relative)"
	pos2(string) : "Override trough position (relative)"
]
@SolidClass base(Bob) = func_bobbing : "Bobbing platform.
Moves in a smooth sine wave. Build at the center of motion, specify 'wait' for the wavelength in seconds and 'distance' for the amplitude (distance from end to end) in units. Use 'delay' to set a phase offset (0-1).
Trigger to freeze in place or reactivate. If any 'don't stop until' spawnflags are checked, the bobber will keep oscillating until it reaches one of the designated positions and stop there.

Set both 'pos1' & 'pos2' to override the two apex positions (ends of the bob) to build and light your plat wherever."  []
*/
void() func_bobbing =
{
	//-------------MOD Rev2 29/octubre/2026  port al servidor del Slender
	// SUB_Inhibit es de progs_dump y aca no existe  los flags de skill y
	// deathmatch los filtra el motor al cargar el mapa
	// ORIGINAL: if (SUB_Inhibit()) return;   // dp300/Copper chequeo de inhibicion (skill/dm/coop)

	if (self.mdl != "")
		precache_model(self.mdl);
	//train_sounds();

	SetMovedir();
	if (!self.distance)
		self.distance = 64;
	if (self.wait <= 0)
		self.wait = 4;
	
	if (!self.dmg) self.dmg = 2;   // damage por defecto al bloquear (Alkaline: zeroconvertdefault)

	//  random cada bob con este flag arranca en una fase distinta, para que
	// varios bobbers no queden sincronizados. random() da [0,1) = el rango de delay.
	// Sobreescribe la key "delay" del editor (que fija una fase concreta).
	if (self.spawnflags & SFLAG_BOB_RANDPHASE)
		self.delay = random();

	if (!self.pos1 && !self.pos2)
	{
		//self.pos1 = self.origin + self.distance * 0.5 * self.movedir;
		//self.pos2 = self.origin - self.distance * 0.5 * self.movedir;
		self.pos1 = self.origin;
		self.pos2 = self.origin - self.distance * self.movedir;
	}
	//---- MOD Rev2 29/octubre/2026
	// vuelve el min original  ahora lo trae math.qc
	self.length = min(0.1, self.wait / 6);

	if (self.spawnflags & 128)
		self.use = func_bobbing_spawn;
	else
		func_bobbing_spawn();
}

void() func_bobbing_spawn =
{
	if (!(self.spawnflags & START_OFF))
	{
		self.think = func_bobbing_use;
		self.nextthink = 0.3;	// wait for items and monsters to rest on it
	}
	
	self.use = func_bobbing_use;
	self.blocked = func_bobbing_blocked;
	
	// SOLIDEZ:
	//   brush normal           SOLID_BSP
	//   NONSOLID (o alias .mdl) -> SOLID_NOT visible 
	// En AMBOS casos MOVETYPE_PUSH es lo unico que hace avanzar self.ltime, del que
	// depende el agendado del think Un SOLID_NOT + MOVETYPE_PUSH 
	// el trace de colision ignora SOLID_NOT Antes usaba MOVETYPE_NOCLIP, con lo
	// que ltime no avanzaba y el timing del bob se rompia 
	if (!(self.spawnflags & SFLAG_BOB_NONSOLID) && self.mdl == "")
		self.solid = SOLID_BSP;
	else
		self.solid = SOLID_NOT;

	self.movetype = MOVETYPE_PUSH;

	if (self.mdl != "")
		setmodel (self, self.mdl);
	else
		setmodel (self, self.model);

	setsize (self, self.mins, self.maxs);
	setorigin (self, func_bobbing_pos(self.delay));
}

void() misc_bobbing = {func_bobbing();}