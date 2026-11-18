// ================================================================
// Over_hud_rain.qc  --  LLUVIA DE CLIENTE, by Rel71
// ================================================================
//-------------MOD INI 2/noviembre/2026
/*
 Lluvia dibujada en CSQC_DrawHud, Cada gota es un punto 3D
 alrededor del ojo que se proyecta con los angulos de la vista, asi al girar
 la gota se queda en su direccion del mundo en vez de viajar pegada a la pantalla

 MOD 16/NOV/2026  cada gota guarda su posicion, velocidad y nacimiento en arrays
 Ironwail no actualiza view_angles ni conoce el origin
pitch, yaw y velocidad llegan del server por stat, y cada frame a cada gota se le
resta lo que se movio el jugador, asi queda en el lugar del mundo donde nacio
*/
//------------- MOD 13/NOV/2026
/*
func_rainzone con flag CLIENTE, ahora esto configura cada zona 
las zonas son un sistema de dos partes 
1 son las brushes como tal y 2 son unos rayos que se castean para ver que partes de tu 
pantalla deberdad tienen cielo y por ende deberian de dibujar gotas
esto funciona regulero y la verdad requiere ajustar la cantidad de rayos y la densidad de los 
mismo para mejorar el effecto aunque me preocupa el rendimiento de esto, necesito probarlo en red
*/



// Para portear este archivo antes de quien llame HUD_DrawRain(screensize),
// al principio de CSQC_DrawHud. Usa getstatf, cvar, random, drawfill y drawstring
// ================================================================

// stats
const float STAT_VIEWANG   = 60;    // (pitch+180)*8 + yaw*8*4096, 1/8 de grado
const float STAT_VIEWVEL   = 61;    // 8 bits por eje +128, 16 u/s por paso
const float STAT_RAIN_CFG  = 72;    // config de la zona, 0 = no llueve
//------------- MOD 17/NOV/2026  un stat por anillo, la porcion k es el bit 2^k
const float STAT_RAIN_MASK = 73;    // anillo interno, y el ojo en RAIN_HEAD
const float STAT_RAIN_MID  = 74;    // anillo medio
const float STAT_RAIN_OUT  = 75;    // anillo externo

const float RAIN_TEST_ON = 1;       
const float RAIN_PER_COUNT = 22;    
const float RAIN_TOP     = 260;     // altura de spawn
const float RAIN_BOT     = -120;     // donde muere
const float RAIN_DMIN    = 40;      // distancia horizontal minima
const float RAIN_DMAX    = 520;     // y maxima
const float RAIN_STREAK  = 0.026;   // largo del trazo en segundos de caida
const float RAIN_WIND    = 0.4;     // deriva con wind_rain
const float RAIN_FADE    = 3; 

// bandas de cielo
//------------- MOD 17/NOV/2026  16 porciones x 3 anillos
//estos parametros marcan las distancias donde cambia la medicion de cielo de cada porcion,
//son 4 mediciones: tu propia cabeza y tres anillos, interno, medio y externo
//el server mide cada anillo en el centro de su banda, asi el error maximo es media banda
const float RAIN_CORE_R  = 70;      // mas cerca pide el bit del ojo y el de la porcion interna
const float RAIN_RING1_R = 150;     // interno de RAIN_DMIN hasta aca, el server lo mide a 95
const float RAIN_RING2_R = 300;     // medio hasta aca (server a 225), externo hasta RAIN_DMAX (server a 410)
const float RAIN_HEAD    = 65536;   // cabeza del jugador
const float RAIN_TAN22   = 0.41421; // tan 22.5 grados, el limite entre porciones


const float RAIN_MAXSEG  = 40;      // maximo de segmentos por gota
const float RAIN_DEBUG   = 0;




// ejes de la vista y proyeccion, se recalculan cada frame 
vector rain_fw, rain_rt, rain_up;
float  rain_cx, rain_cy, rain_f;
vector rain_scr;    // salida de rain_project x y z en pantalla, 


//------------- MOD 13/NOV/2026
// config de la zona 
float  rain_on, rain_n, rain_speed, rain_alpha, rain_wx, rain_wy, rain_mask;
float  rain_mask_mid, rain_mask_out;   // MOD 17/NOV/2026  anillos medio y externo
float  rain_vis, rain_vis_t;
vector rain_color;

//------------- MOD 16/NOV/2026  gotas con memoria, reemplaza al historial de fotos
// velocidad del jugador (stat 61) y tiempo del frame
vector rain_vel;
float  rain_last, rain_dt;

// estado de cada gota, 375 lugares = count 15 x RAIN_PER_COUNT 25
// si se sube RAIN_PER_COUNT hay que agrandar los arrays y RAIN_MAXDROP con ellos
const float RAIN_MAXDROP = 375;
vector rain_pos[375];    // relativa al jugador: x y horizontal, z altura
float  rain_spd[375];    // velocidad de caida, 0 = todavia no existe
float  rain_born[375];   // time en que nacio, para el fundido de entrada

// seno en grados por Bhaskara, el mismo de bob_cos del server
// no uso sin cos ni makevectors porque nadie probo que anden en este cliente
float(float d) rain_sin =
{
	d = d - floor(d / 360) * 360;
	if (d <= 180)
		return 4 * d * (180 - d) / (40500 - d * (180 - d));
	d = d - 180;
	return -4 * d * (180 - d) / (40500 - d * (180 - d));
};

float(float d) rain_cos = { return rain_sin(d + 90); };

// punto relativo al ojo a pantalla, FALSE si queda detras de la camara
float(vector p) rain_project =
{
	local float z;

	z = p * rain_fw;
	if (z < 8) return FALSE;
	rain_scr_x = rain_cx + (p * rain_rt) / z * rain_f;
	rain_scr_y = rain_cy - (p * rain_up) / z * rain_f;
	rain_scr_z = z;
	return TRUE;
};

//-------------MOD  2/noviembre/2026
/*
 drawfill solo hace rectangulos derechos, un trazo inclinado se arma en
 SECTORES sobre su eje dominante, un escalon por cada ancho
 asi no quedan huecos 
Mirando abajo las gotas convergen hacia arriba
 los trazos se inclinan mucho, por eso tambien hay escalones horizontales

*/

void(vector p0, vector p1, float w, float alpha) rain_streak =
{
	local vector tmp;
	local float segs, j, dx, dy, adx, ady;

	
	//primero descartamos lo que este fuera de la pantalla
	if (p0_y < 0 && p1_y < 0) return;
	if (p0_y > rain_cy * 2 && p1_y > rain_cy * 2) return;
	if (p0_x < 0 && p1_x < 0) return;
	if (p0_x > rain_cx * 2 && p1_x > rain_cx * 2) return;

	// cuanto recorre el trazo en pantalla, el eje mayor decide el tipo de barra
	adx = fabs(p1_x - p0_x);
	ady = fabs(p1_y - p0_y);

		/*
	aqui la logica es que el lado dominante marca la dirreccion en la que vamos a dibujar
	se SUPONE que asi ahorramos trazos y llamadas al drawfill que no es tan eficiente como parece
	*/
	//--------------------------- Y dominante------------
	if (ady >= adx)
	{
		// mas vertical barras verticales, p0 arriba
		if (p1_y < p0_y) { tmp = p0; p0 = p1; p1 = tmp; }
		dx = p1_x - p0_x;
		// una barra por cada ancho w que se corre en x, derecho queda en una sola
		segs = floor(adx / w) + 1;
		if (segs > RAIN_MAXSEG) segs = RAIN_MAXSEG;

		// ENTONCES la barra (j) cubre su tramo xy, y tratamos de dejarla centrada
		// el +0.5 de alto tapa la junta con la siguiente
		j = 0;
		while (j < segs)
		{
			drawfill([p0_x + dx * (j + 0.5) / segs - w * 0.5, p0_y + ady * j / segs],
			         [w, ady / segs + 0.5], rain_color, alpha, 0);
			j = j + 1;
		}
		return;
	}

	//--------------------------- X dominante---------------
	if (p1_x < p0_x) { tmp = p0; p0 = p1; p1 = tmp; }
	dy = p1_y - p0_y;
	segs = floor(ady / w) + 1;
	if (segs > RAIN_MAXSEG) segs = RAIN_MAXSEG;
	j = 0;
	while (j < segs)
	{
		drawfill([p0_x + adx * j / segs, p0_y + dy * (j + 0.5) / segs - w * 0.5],
		         [adx / segs + 0.5, w], rain_color, alpha, 0);
		j = j + 1;
	}
};

//------------- MOD 16/NOV/2026
// borra las gotas desde n hasta el final, en el bucle renacen solas fundiendo
void(float n) rain_kill =
{
	while (n < RAIN_MAXDROP)
	{
		rain_spd[n] = 0;
		n = n + 1;
	}
};

// lee la velocidad del jugador y el tiempo del frame, una vez por frame
// el stat empaca 8 bits por eje con +128 y 16 u/s por paso
void() rain_motion =
{
	local float pv, vx, vy, vz;

	pv = getstatf(STAT_VIEWVEL);
	if (pv)
	{
		vz = floor(pv / 65536);
		pv = pv - vz * 65536;
		vy = floor(pv / 256);
		vx = pv - vy * 256;
		rain_vel = ([vx, vy, vz] - '128 128 128') * 16;
	}
	else
		rain_vel = '0 0 0';   // el stat todavia no llego

	// tiempo hacia atras o salto grande = mapa nuevo, carga o pausa: todas renacen
	rain_dt = time - rain_last;
	rain_last = time;
	if (rain_dt < 0 || rain_dt > 0.25)
	{
		rain_dt = 0;
		rain_kill(0);
	}
};


// config de la zona
void() rain_read_cfg =
{
	local float c, col, n;

	rain_mask     = getstatf(STAT_RAIN_MASK);
	rain_mask_mid = getstatf(STAT_RAIN_MID);   // MOD 17/NOV/2026
	rain_mask_out = getstatf(STAT_RAIN_OUT);
	c = getstatf(STAT_RAIN_CFG);
	rain_on = (c != 0);
	if (!rain_on) return;

	//------------- MOD 16/NOV/2026  tope de los arrays, y si baja el count las
	// que sobran se borran para que al volver renazcan fundiendo
	n = (c - floor(c / 16) * 16) * RAIN_PER_COUNT;
	if (n > RAIN_MAXDROP) n = RAIN_MAXDROP;
	if (n != rain_n) rain_kill(n);
	rain_n = n;
	c = floor(c / 16);
	rain_speed = (c - floor(c / 32) * 32) * 50;
	c = floor(c / 32);
	rain_alpha = (c - floor(c / 16) * 16) / 15;
	c = floor(c / 16);
	col = c - floor(c / 4) * 4;
	c = floor(c / 4);

	// viento como la server: deriva en -y
	rain_wx = 0;
	rain_wy = 0;
	if (c) rain_wy = -RAIN_WIND * rain_speed;

	if (col == 2)      rain_color = '0.6 0.9 0.6';     // verde
	else if (col == 3) rain_color = '0.8 0.65 0.95';   // morado
	else               rain_color = '0.75 0.82 0.9';   // azul
};
	
// fundido de toda la lluvia: sube con alguna celda con cielo, si no baja
// devuelve FALSE cuando ya no hay nada que dibujar
float() rain_fade =
{
	local float dt;

	dt = time - rain_vis_t;
	rain_vis_t = time;
	if (dt < 0 || dt > 0.25) dt = 0;

	if (rain_on && (rain_mask || rain_mask_mid || rain_mask_out))   // MOD 17/NOV/2026  los tres anillos
	{
		rain_vis = rain_vis + dt * RAIN_FADE;
		if (rain_vis > 1) rain_vis = 1;
		return TRUE;
	}
	rain_vis = rain_vis - dt * RAIN_FADE;
	if (rain_vis > 0) return TRUE;
	rain_vis = 0;
	return FALSE;
};


/*
 decide si una gota se dibuja o no
La idea 
El server no puede revisar cada gota
 Lo que hace es dividir el area alrededor del jugador en celdas y revisar solo las celdas
10 veces por segundo Para cada celda manda un bit en los stats 73, 74 y 75: 1 si tiene cielo y se ve desde el ojo, 0 si no
 El cliente, por cada gota, busca en que celda cae y mira ese bit

//------------- MOD 17/NOV/2026  16 porciones x 3 anillos
Las celdas: una rosa de 16 porciones de 22.5°, vista desde arriba,
numeradas desde +x en sentido antihorario. La porcion k es el bit 2^k
                    +y
             5   4  |  3   2
          6         |         1
        7           |           0
 -x  ------------- PJ ------------- +x
        8           |           15
          9         |         14
            10  11  |  12  13
                    -y
Estan fijas en el mundo, no giran con la camara, la 0 siempre empieza en +x del mapa

Cada anillo tiene su stat con los mismos 16 bits:
   73  interno  de 40 a 150, mas el ojo en 65536    el server mide a 95
   74  medio    de 150 a 300                        a 225
   75  externo  de 300 a 520                        a 410
Bajo RAIN_CORE_R (70) pide el bit del ojo y el de la porcion interna
*/
float(vector p) rain_cell_open =
{
	local float r2, u, v, bit;

	// cuadrante: bit de su primera porcion, u mide sobre el eje donde
	// empieza y v sobre el eje donde termina, los dos positivos
	if (p_y >= 0)
	{
		if (p_x >= 0) { bit = 1;    u = p_x;  v = p_y;  }   // 0 a 90
		else          { bit = 16;   u = p_y;  v = -p_x; }   // 90 a 180
	}
	else
	{
		if (p_x < 0)  { bit = 256;  u = -p_x; v = -p_y; }   // 180 a 270
		else          { bit = 4096; u = -p_y; v = p_x;  }   // 270 a 360
	}

	// cada limite de 22.5 grados que pasa sube el bit a la porcion siguiente
	if (v >= u * RAIN_TAN22) bit = bit * 2;   // paso 22.5
	if (v >= u)              bit = bit * 2;   // paso 45
	if (v * RAIN_TAN22 >= u) bit = bit * 2;   // paso 67.5

	// la distancia elige el anillo
	r2 = p_x * p_x + p_y * p_y;
	if (r2 >= RAIN_RING2_R * RAIN_RING2_R) return (rain_mask_out & bit) != 0;
	if (r2 >= RAIN_RING1_R * RAIN_RING1_R) return (rain_mask_mid & bit) != 0;
	if (r2 < RAIN_CORE_R * RAIN_CORE_R) bit = bit | RAIN_HEAD;
	return (rain_mask & bit) == bit;
};


/*
HUD_DrawRain

0. interruptor        

1. config y fundido   (una vez por frame)
    rain_read_cfg   stats 72 y 73: cuantas gotas, caida, alpha, color, viento, mascara
     rain_fade       sube o baja rain_vis

  2. movimiento del jugador
    rain_motion     velocidad del stat 61 y rain_dt, el tiempo del frame

    3. camara
     angulos del stat 60 
     ejes fw / rt / up, el roll se ignora
     focal desde el fov y centro de pantalla  -> deja listo rain_project

	 4. debug              texto de angulos y velocidad si RAIN_DEBUG

   -- 5. bucle de gotas, i = 0 .. rain_n-1
      a. mover         cae, el viento la empuja y se le resta lo que se movio el jugador
      b. renacer       no existia, llego abajo o quedo lejos -> rain_spawn
      c. cola          q = cabeza + velocidad relativa x RAIN_STREAK
      d. filtros       celda con cielo? -> cabeza delante de la camara? -> cola tambien?
      e. aspecto       ancho por distancia, transparencia, fundido al nacer
      f. dibujar       rain_streak de la cola a la cabeza




*/

//------------- MOD 16/NOV/2026  ajustes de las gotas, todos se pueden tocar
// las semillas irracionales se fueron con el metodo viejo (sigue en OverHorde)
const float RAIN_SPD_LO  = 0.9;    // velocidad entre 0.9 y 0.9 + RAIN_SPD_RNG de height
const float RAIN_SPD_RNG = 0.2;
const float RAIN_THICK   = 1.2;    // grosor de la gota en unidades
const float RAIN_W_MIN   = 0.6;    // topes del grosor en pixeles
const float RAIN_W_MAX   = 3;
const float RAIN_FAR_DIM = 0.6;    // a RAIN_DMAX de profundidad la gota es 60% mas tenue
const float RAIN_BORN    = 0.05;   // segundos de fundido al nacer
//------------- MOD 17/NOV/2026  reparto de las gotas por anillo, el resto va al externo
const float RAIN_PART_IN  = 0.2;   // 20% en el interno (RAIN_DMIN a RAIN_RING1_R), pareja real 0.08
const float RAIN_PART_MID = 0.3;   // 30% en el medio (RAIN_RING1_R a RAIN_RING2_R), pareja real 0.25

// gota nueva al azar alrededor del jugador: guarda posicion, velocidad y nacimiento
// arriba TRUE nace en el tope (llego abajo), FALSE a cualquier altura
// (relleno al empezar, count que sube o gota que quedo lejos)
void(float i, float arriba) rain_spawn =
{
	local float d, yaw, h, s, f, r0, r1;

	//------------- MOD 17/NOV/2026  el indice elige el anillo y adentro va pareja por area
	// las primeras RAIN_PART_IN del total al interno, las siguientes RAIN_PART_MID
	// al medio y el resto al externo, asi cada anillo tiene siempre su cantidad
	f = i / rain_n;
	if (f < RAIN_PART_IN)                      { r0 = RAIN_DMIN;    r1 = RAIN_RING1_R; }
	else if (f < RAIN_PART_IN + RAIN_PART_MID) { r0 = RAIN_RING1_R; r1 = RAIN_RING2_R; }
	else                                       { r0 = RAIN_RING2_R; r1 = RAIN_DMAX;    }
	d   = sqrt(r0 * r0 + random() * (r1 * r1 - r0 * r0));   // pareja por area, como la lluvia real
	yaw = random() * 360;
	h   = RAIN_TOP;
	if (!arriba) h = RAIN_BOT + random() * (RAIN_TOP - RAIN_BOT);
	s   = rain_speed * (RAIN_SPD_LO + RAIN_SPD_RNG * random());

	// nace corrida contra el viento la mitad de lo que le queda de caida,
	// asi en promedio la lluvia queda centrada en el jugador
	rain_pos[i]  = [d * rain_cos(yaw), d * rain_sin(yaw), h]
	             - [rain_wx, rain_wy, 0] * (0.5 * (h - RAIN_BOT) / s);
	rain_spd[i]  = s;
	rain_born[i] = time;
};

void(vector vs) HUD_DrawRain =
{
	local float sp, cp, sy, cy, fov, t, i, pitch, vyaw, ps, yq;
	local float s, w, alpha, age;
	local vector p, q, head;

	if (!RAIN_TEST_ON) return;

	//--1
	rain_read_cfg();
	if (!rain_fade()) return;
	//-------2
	rain_motion();   

   //------------------------------------------3
	pitch = view_angles_x;
	vyaw  = view_angles_y;
	ps = getstatf(STAT_VIEWANG);
	if (ps)
	{
		yq = floor(ps / 4096);
		pitch = (ps - yq * 4096) / 8 - 180;
		vyaw  = yq / 8;
	}

	// ejes de la vista, el roll se ignora
	sp = rain_sin(pitch);
	cp = rain_cos(pitch);
	sy = rain_sin(vyaw);
	cy = rain_cos(vyaw);

	rain_fw = [cp * cy, cp * sy, -sp];
	rain_rt = [sy, -cy, 0];
	rain_up = [sp * cy, sp * sy, cp];

	// focal desde el fov horizontal de 4:3 que usa quake, con fallback a 90
	fov = cvar("fov");
	if (fov < 10) fov = 90;
	t = rain_sin(fov * 0.5) / rain_cos(fov * 0.5) * 0.75;
	rain_f  = vs_y * 0.5 / t;
	rain_cx = vs_x * 0.5;
	rain_cy = vs_y * 0.5;
//----------------------------------------------------------------4
	// angulos y la velocidad del stat
	if (RAIN_DEBUG)
		drawstring([rain_cx - 200, 4], strcat("rain pitch ", ftos(pitch), " yaw ", ftos(vyaw),
		           "  motor ", ftos(view_angles_x), " ", ftos(view_angles_y),
		           "  vel ", ftos(rain_vel_x), " ", ftos(rain_vel_y), " ", ftos(rain_vel_z)),
		           '8 8 0', '1 1 1', 1, 0);
//------------------------------------------------------------
//--------------------------------------------------------5
	//------------- MOD 16/NOV/2026  gotas con memoria, antes salian del indice y del reloj
	// el metodo viejo (semillas, vidas e historial de fotos) sigue en la copia de OverHorde
	i = 0;
	while (i < rain_n)
	{
		// a. mover: cae, el viento la empuja y se le resta lo que se movio
		// el jugador en este frame, asi queda fija en el mundo
		s = rain_spd[i];
		p = rain_pos[i] + ([rain_wx, rain_wy, -s] - rain_vel) * rain_dt;

		// b. renacer
		if (!s)                  rain_spawn(i, FALSE);   // todavia no existia
		else if (p_z < RAIN_BOT) rain_spawn(i, TRUE);    // llego abajo, vuelve al tope
		else if (p_x * p_x + p_y * p_y > RAIN_DMAX * RAIN_DMAX)
		                         rain_spawn(i, FALSE);   // quedo lejos, aparece en otro lado
		else                     rain_pos[i] = p;
		p = rain_pos[i];
		s = rain_spd[i];

		// c. cola: donde estaba hace RAIN_STREAK segundos vista desde el jugador,
		// corriendo la lluvia viene de frente
		q = p + [rain_vel_x - rain_wx, rain_vel_y - rain_wy, s + rain_vel_z] * RAIN_STREAK;

		// d. filtros: celda con cielo, cabeza y cola delante de la camara
		if (rain_cell_open(p))
		if (rain_project(p))
		{
			head = rain_scr;
			if (rain_project(q))
			{
				// e. aspecto: grosor por perspectiva, mas tenue lejos y fundido al nacer
				w = RAIN_THICK * rain_f / head_z;
				if (w < RAIN_W_MIN) w = RAIN_W_MIN;
				if (w > RAIN_W_MAX) w = RAIN_W_MAX;

				alpha = rain_alpha * (1 - RAIN_FAR_DIM * head_z / RAIN_DMAX) * rain_vis;
				age = time - rain_born[i];
				if (age < RAIN_BORN) alpha = alpha * age / RAIN_BORN;

				// f. dibujar de la cola a la cabeza
				rain_streak(rain_scr, head, w, alpha);
			}
		}
		i = i + 1;
	}
};
