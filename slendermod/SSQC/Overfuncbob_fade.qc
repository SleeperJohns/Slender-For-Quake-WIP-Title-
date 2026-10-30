//--------rev 1 septiembre 9 del 2026
//-------- MOD Rev2 29/octubre/2026

/*
==============================================================================
FUNC_BOBBING_FADE  --  BY Rel_71

Variante de func_bobing.qc con ALPHA POR DISTANCIA AL JUGADOR

Nace para volumenes de niebla. Un brush con alpha molesta cuando el jugador ya
esta adentro, asi que aca el alpha se interpola entre dos valores segun que tan
cerca este el jugador mas proximo

Reusa la matematica del bob original sin copiarla: func_bobbing_pos,
func_bobbing_think y func_bobbing_blocked viven en Overfuncbobing.qc
El coseno del flicker sale de cos_deg en math.qc  MOD Rev2 29/octubre/2026
Lo que SI es propio es el ciclo de vida, porque func_bobbing_use cablea
self.think = func_bobbing_think y pisaria el think del fade en cada toggle

DOS COSAS QUE NO SON OBVIAS, documentadas donde importan
  1 la distancia se mide contra la CAJA y no contra el origin
  2 alpha 0 NO es invisible, es opaco
==============================================================================
*/

//-------------MOD Rev2 29/octubre/2026  port al servidor del Slender
// el defs.qc vanilla no declara alpha  Ironwail lo lee por nombre y lo manda
// con el protocolo 666 que es su default  con el 15 vanilla no viaja
//---- MOD Rev2 29/octubre/2026
// va despues de Overfuncbobing.qc que trae el think del bob
// y de math.qc que trae cos_deg y min
.float alpha;

// alpha cuando el jugador esta a dist_near o menos
.float alpha_near;
// alpha cuando esta a dist_far o mas. Entre las dos se interpola lineal
.float alpha_far;
.float dist_near;
.float dist_far;

//--------rev 1 septiembre 9 del 2026
// ALPHA 0 ES UNA TRAMPA En el protocolo Fitz 
// y DEFAULT se renderiza OPACO
// Con 0.001 el byte codificado da 1, que si es invisible
float FADE_ALPHA_MIN = 0.001;

//--------rev 1 septiembre 9 del 2026
// FLICKER. Dos cosenos de frecuencias
//----  29/octubre/2026
// usa cos_deg de math.qc  coseno exacto en grados con el truco de makevectors
// de Alkaline
float FADE_FLICKER_RATIO = 0.37;   // relacion entre las dos frecuencias

.float flicker_amp;    // 0 = apagado. 0.15 = mas menos 15 por ciento
.float flicker_rate;   // ciclos por segundo del componente lento

// Desfase y ajuste de ritmo PROPIOS de cada bob, sorteados al spawn. NO son
// keys del editor. Sin esto todos los volumenes con la misma rate parpadean al
// unisono y se nota muchisimo
.float flicker_phase;
.float flicker_jitter;

//-------- octubre 1 del 2026
// Dormir es basicamente eso
//---- MOD Rev2 29/octubre/2026
// Un bob fuera del PVS del jugador deja de moverse  la distancia no cuenta
// Lo caro de un bob no es el QC, es SV_PushMove, Con velocity en cero sale en la primera
// linea y solo avanza ltime
// La red ya estaba resuelta lo que no esta en el PVS de un cliente no se manda
.float fade_sleep;       // instante en que se durmio, 0 = despierto

float FADE_SLEEP_TICK  = 0.5;   // cada cuanto revisa si despierta
float FADE_VIS_INSET   = 8;     // las esquinas se meten hacia adentro de la caja
const float SFLAG_FADE_SOLID = 4;

// ==============================================================================
// DISTANCIA A LA CAJA
// ==============================================================================
// No sirve medir contra origin. Un brush sin origin brush lo tiene en 0 0 0
float(entity e, vector p) fade_dist_to_box =
{
    local vector c;

    c = p;
    if (c_x < e.absmin_x) c_x = e.absmin_x;
    if (c_x > e.absmax_x) c_x = e.absmax_x;
    if (c_y < e.absmin_y) c_y = e.absmin_y;
    if (c_y > e.absmax_y) c_y = e.absmax_y;
    if (c_z < e.absmin_z) c_z = e.absmin_z;
    if (c_z > e.absmax_z) c_z = e.absmax_z;

    return vlen(p - c);
};

// Jugador vivo mas cercano Devuelve -1 si no hay ninguno
// find arranca en el edict 1 y los clientes son los primeros, asi que la
// cadena corta enseguida y sale barato aunque corra por volumen y por think
float() fade_nearest_player =
{
    local entity p;
    local float  d, best;

    best = -1;
    p = find(world, classname, "player");
    while (p)
    {
        if (p.health > 0)
        {
            d = fade_dist_to_box(self, p.origin);
            if (best < 0 || d < best) best = d;
        }
        p = find(p, classname, "player");
    }
    return best;
};

// ==============================================================================
// EL FADE
// ==============================================================================
//--------rev octubre 1 del 2026
// Recibe la distancia en vez de buscarla
void(float d) func_bobbing_fade_alpha =
{
    local float f, a;

    if      (d < 0)              f = 1;   // nadie vivo, tratar como lejos
    else if (d <= self.dist_near)  f = 0;
    else if (d >= self.dist_far)   f = 1;
    else f = (d - self.dist_near) / (self.dist_far - self.dist_near);

    a = self.alpha_near + (self.alpha_far - self.alpha_near) * f;

//--------rev 2 septiembre 9 del 2026
    // FLICKER MULTIPLICATIVO, va sobre el resultado del fade
    if (self.flicker_amp > 0)
    {
        local float t, w;
        t = time * self.flicker_rate * self.flicker_jitter * 360;
        //---- MOD  29/octubre/2026
        w = cos_deg(t + self.flicker_phase)
          + cos_deg(t * FADE_FLICKER_RATIO + self.flicker_phase * 2.7);
        a = a * (1 + self.flicker_amp * w * 0.5);   // w va de -2 a 2
    }

    if (a < FADE_ALPHA_MIN) a = FADE_ALPHA_MIN;
    if (a > 1) a = 1;

    self.alpha = a;
};

float(vector p) fade_point_visible =
{
    self.view_ofs = p - self.origin;
    return (checkclient() != world);
};

float() fade_is_visible =
{
    local vector p;

    if (fade_point_visible((self.absmin + self.absmax) * 0.5)) return TRUE;

    p_z = self.absmax_z - FADE_VIS_INSET;

    p_x = self.absmin_x + FADE_VIS_INSET;  p_y = self.absmin_y + FADE_VIS_INSET;
    if (fade_point_visible(p)) return TRUE;
    p_x = self.absmax_x - FADE_VIS_INSET;
    if (fade_point_visible(p)) return TRUE;
    p_y = self.absmax_y - FADE_VIS_INSET;
    if (fade_point_visible(p)) return TRUE;
    p_x = self.absmin_x + FADE_VIS_INSET;
    if (fade_point_visible(p)) return TRUE;

    return FALSE;
};

void() func_bobbing_fade_think =
{
    local float d;

//--------rev 4 octubre 1 del 2026
    // DUERME SOLO POR PVS. Lo que no esta en la vista del jugador se congela a
    // cualquier distancia
    if (!fade_is_visible())
    {
        if (!self.fade_sleep)
        {
            self.fade_sleep = time;
            self.velocity   = '0 0 0';   // SV_PushMove sale en la primera linea
        }
        // nextthink de un pusher va en ltime, y ltime sigue avanzando con la
        // velocidad en cero
        self.nextthink = self.ltime + FADE_SLEEP_TICK;
        return;
    }

    // DESPERTAR SIN SALTO La fase del bob sale de (time - search_time) / wait,
    // desde un tiempo absoluto. Corriendo search_time lo mismo que estuvo
    // dormido, la fase sigue EXACTAMENTE donde se congelo, sin tiron
    if (self.fade_sleep)
    {
        self.search_time = self.search_time + (time - self.fade_sleep);
        self.fade_sleep  = 0;
    }

    // la busqueda del jugador corre recien despierto, dormido no hace falta
    d = fade_nearest_player();
    func_bobbing_fade_alpha(d);

    // el think base sale temprano y SIN reagendar cuando state es 0, y el motor
    // pone nextthink en cero antes de llamar al think. Sin esto el fade dejaria
    // de correr apenas apaguen el bobber
    func_bobbing_think();
    if (!self.nextthink) self.nextthink = self.ltime + self.length;
};

// Copia del use original con UNA diferencia: cablea el think del fade
// Ademas al apagar deja el think agendado en vez de ponerlo en cero, para que
// el alpha siga respondiendo con el bobber detenido
void() func_bobbing_fade_use =
{
    self.think = func_bobbing_fade_think;

    if (self.state == 2) self.state = 1;
    else                 self.state = !self.state;

    if (self.state)
    {
        // rev 3 oct 1 2026: se borra el sueno ANTES de fijar search_time, si no
        // el think de abajo lo despertaria y correria search_time otra vez
        self.fade_sleep  = 0;
        self.search_time = time - self.delay * self.wait;
        self.think();
        return;
    }

    if (self.spawnflags & SFLAG_BOB_STOP)
    {
        self.state = 2;
        return;
    }

    sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
    self.nextthink = self.ltime + self.length;
};

void() func_bobbing_fade_spawn =
{
    // apagado de entrada igual tiene que correr el think, si no el alpha queda
    // congelado en el valor de spawn
    if (!(self.spawnflags & START_OFF)) self.think = func_bobbing_fade_use;
    else                                self.think = func_bobbing_fade_think;
    self.nextthink = 0.3;   // que items y monstruos se asienten primero

    self.use     = func_bobbing_fade_use;
    self.blocked = func_bobbing_blocked;

    // DEFAULT NO SOLIDO, al reves del bob original. Un alias .mdl nunca puede
    // ser SOLID_BSP, misma condicion que usa func_bobbing_spawn
    if ((self.spawnflags & SFLAG_FADE_SOLID) && self.mdl == "")
        self.solid = SOLID_BSP;
    else
        self.solid = SOLID_NOT;

    // MOVETYPE_PUSH es lo unico que hace avanzar ltime, del que depende el
    // agendado del think. Vale tambien para SOLID_NOT
    self.movetype = MOVETYPE_PUSH;

    if (self.mdl != "") setmodel (self, self.mdl);
    else                setmodel (self, self.model);

    setsize (self, self.mins, self.maxs);
    setorigin (self, func_bobbing_pos(self.delay));
};

/*QUAKED func_bobbing_fade (0 .5 .8) ? START_OFF CRUSHER SOLID STOP_LOW STOP_MID STOP_HIGH RANDPHASE START_INVIS
Igual que func_bobbing pero el alpha se interpola segun la distancia al jugador
mas cercano. Pensado para volumenes de niebla que estorban cuando el jugador ya
esta adentro. Por defecto NO ES SOLIDO

La distancia se mide contra la caja del brush, no contra su centro, asi que
estando adentro vale cero en cualquier punto del volumen

"alpha_near" alpha a dist_near o menos. Default 0.001 o sea invisible
"alpha_far"  alpha a dist_far o mas. Default 1
"dist_near"  donde termina de desvanecerse. Default 96
"dist_far"   donde recupera el alpha lejano. Default dist_near + 256

"flicker_amp"  variacion del alpha. 0 apagado, 0.15 es mas menos 15 por ciento
"flicker_rate" ciclos por segundo. Default 0.4. Arriba de 1 se ve estroboscopico
               porque el think corre como maximo a 10 Hz

Cada volumen sortea su propio desfase Y su propio ritmo al spawnear, asi que
varios con las mismas keys nunca parpadean sincronizados

SUENO automatico, sin key: lo que no esta en el PVS del jugador se congela
a cualquier distancia, y al volver a verse sigue desde la misma fase

Poner alpha_near mayor que alpha_far invierte el efecto y aparece al acercarse

OJO alpha 0 en el protocolo significa DEFAULT y se renderiza OPACO. Por eso el
piso es 0.001 y un 0 escrito en el editor se coerce a ese valor

Las demas keys son las de func_bobbing: wait, distance, delay, pos1, pos2, dmg
*/
/*FGD
@SolidClass base(Bob) = func_bobbing_fade : "Bobbing platform con alpha por distancia al jugador.
Por defecto NO SOLIDO. Pensado para volumenes de niebla."
[
	spawnflags(flags) = [
		1 : "Start off" : 0
		2 : "Crusher (no reverse)" : 0
		4 : "Solid (por defecto NO lo es)" : 0
		8 : "Don't stop until low pos" : 0
		16 : "Don't stop until mid pos" : 0
		32 : "Don't stop until high pos" : 0
		64 : "Fase random del bob" : 0
		128 : "Start invis (spawnea al trigger)" : 0
	]
	alpha_near(string) : "Alpha de cerca (0.001 = invisible)" : "0.001"
	alpha_far(string) : "Alpha de lejos" : "1"
	dist_near(integer) : "Distancia donde termina de desvanecerse" : 96
	dist_far(integer) : "Distancia donde recupera el alpha lejano" : 512
	flicker_amp(string) : "Amplitud del flicker (0 = apagado)" : "0"
	flicker_rate(string) : "Ciclos por segundo del flicker" : "0.4"
]
*/
void() func_bobbing_fade =
{
    //------------- 29/octubre/2026  port al servidor del Slender
    // SUB_Inhibit es de progs_dump y aca no existe  los flags de skill y
    // deathmatch los filtra el motor al cargar el mapa
    // ORIGINAL: if (SUB_Inhibit()) return;

    if (self.mdl != "") precache_model(self.mdl);

    SetMovedir();
    if (!self.distance) self.distance = 64;
    if (self.wait <= 0) self.wait = 4;
    if (!self.dmg) self.dmg = 2;

    if (self.spawnflags & SFLAG_BOB_RANDPHASE) self.delay = random();

    if (!self.pos1 && !self.pos2)
    {
        self.pos1 = self.origin;
        self.pos2 = self.origin - self.distance * self.movedir;
    }
    //---- MOD Rev2 29/octubre/2026
    // vuelve el min original  ahora lo trae math.qc
    self.length = min(0.1, self.wait / 6);

    // defaults del fade. No se puede distinguir una key sin escribir de un cero
    // escrito, asi que se elige el caso comun: invisible cerca, opaco lejos
    if (self.alpha_near <= 0) self.alpha_near = FADE_ALPHA_MIN;
    if (self.alpha_far  <= 0) self.alpha_far  = 1;
    if (self.alpha_near > 1)  self.alpha_near = 1;
    if (self.alpha_far  > 1)  self.alpha_far  = 1;

    if (self.dist_near <= 0) self.dist_near = 96;
    // si quedan iguales la interpolacion dividiria por cero
    if (self.dist_far <= self.dist_near) self.dist_far = self.dist_near + 256;

//--------rev 2 septiembre 9 del 2026
    // FLICKER. El think corre como maximo a 10 Hz, arriba de 1 ciclo por
    // segundo se ve estroboscopico y aliaseado. Para niebla va lento
    if (self.flicker_amp < 0) self.flicker_amp = 0;
    if (self.flicker_amp > 1) self.flicker_amp = 1;
    if (self.flicker_rate <= 0) self.flicker_rate = 0.4;

    // DESINCRONIZADO por entidad en los DOS ejes. Solo con desfase, dos
    // volumenes con la misma rate comparten periodo y con el tiempo se los ve
    // emparentados igual. El jitter de ritmo lo rompe del todo
    self.flicker_phase  = random() * 360;
    self.flicker_jitter = 0.85 + random() * 0.3;

    self.fade_sleep = 0;   // rev 3 oct 1 2026: nace despierto

    // valor de arranque, el primer think lo corrige contra el jugador real
    self.alpha = self.alpha_far;

    if (self.spawnflags & 128)
        self.use = func_bobbing_fade_spawn;
    else
        func_bobbing_fade_spawn();
};
