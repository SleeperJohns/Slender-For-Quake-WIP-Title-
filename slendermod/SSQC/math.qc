/*
 * math.qc
 *
 * Author: Joshua Skelton joshua.skelton@gmail.com
 *
 * A collection of helpful math functions.
 */

// Forward declarations
float(float value, float minValue, float maxValue) clamp;
float(float a, float b) mod;
float(float x) sign;
float(float value, float minValue, float maxValue) wrap;

/*
 * clamp
 *
 * Limits the given value to the given range.
 *
 * value: A number
 *
 * minValue: The minimum value of the range
 *
 * maxValue: The maximum value of the range
 *
 * Returns: A number within the given range.
 */
//---- MOD Rev2 29/octubre/2026
// el cuerpo ya lo define slender/sm_defs.qc con la misma logica
// queda el prototipo de arriba  por eso math.qc va antes de sm_defs.qc

/*
 * mod
 *
 * Returns the remainder after the division of a by n
 *
 * a: The dividend
 *
 * b: The divisor
 *
 * Returns: The remainder of a divided by n
 */
float(float a, float n) mod = {
    return a - (n * floor(a / n));
};

/*
 * sign
 *
 * Returns an indication of the sign of the given number.
 *
 * x: A number
 *
 * Returns: -1 if x < 0, 0 if x == 0, 1 if x > 0.
 */
float(float x) sign = {
    if (x > 0) {
        return 1;
    }
    else if (x < 0) {
        return -1;
    }

    return 0;
};

/*
 * wrap
 *
 * Limits the given value to the given range and will wrap the value to the
 * the other end of the range if exceeded.
 *
 * value: A number
 *
 * minValue: The minimum value of the range
 *
 * maxValue: The maximum value of the range
 *
 * Returns: A number within the given range.
 */
float(float value, float minValue, float maxValue) wrap = {
    local float range = maxValue - minValue;

    return mod(value - minValue, range + 1) + minValue;
};



float(float a, float b, float mix) lerp =
{
    if (mix <= 0) return a;
    if (mix >= 1) return b;
    return (b * mix + a * ( 1 - mix ) );
}

vector(vector a, vector b, float mix) lerpVector =
{
    if (mix <= 0) return a;
    if (mix >= 1) return b;
    return (b * mix + a * ( 1 - mix ) );
}

// for a relaxing lerp: hermite lerp.
float(float a, float b, float mix) lerpHermite =
{
    if (mix <= 0) return a;
    if (mix >= 1) return b;
    
    local float h01;
    
    h01 = mix * mix;
    h01 *= 3 - 2 * mix;
    
    return (b * h01 + a * ( 1 - h01 ) );
}

vector(vector a, vector b, float mix) lerpVectorHermite =
{
    if (mix <= 0) return a;
    if (mix >= 1) return b;

    local float h01;
    
    h01 = mix * mix;
    h01 *= 3 - 2 * mix;
    
    return (b * h01 + a * ( 1 - h01 ) );
}

float(float anga, float angb) angledif =
{
    float dif;
    dif = fabs(anga - angb);
    if (dif > 180)
        dif = 360 - dif;
    return dif;
}

float(vector ang, vector base_ang, vector offset) isInAngle = {
    if (angledif(ang_x, base_ang_x) > offset_x || angledif(ang_y, base_ang_y) > offset_y)
        return FALSE;
    else
        return TRUE;
};


// normalizes an angle vector to the 0/+359 range
vector(vector ang) normalizeAngles = {

    ang_x = ang_x - floor(ang_x/360) * 360;
    ang_y = ang_y - floor(ang_y/360) * 360;
    ang_z = ang_z - floor(ang_z/360) * 360;

    /*
    while (ang_x > 360)
        ang_x = ang_x - 360;

    while (ang_x < 0)
        ang_x = ang_x + 360;

    while (ang_y > 360)
        ang_y = ang_y - 360;

    while (ang_y < 0)
        ang_y = ang_y + 360;

    while (ang_z > 360)
        ang_z = ang_z - 360;

    while (ang_z < 0)
        ang_z = ang_z + 360;
    */
    return ang;
};

// normalizes an angle vector to the -180/+179 range
vector(vector ang) normalizeAngles180 = {
    ang_x = ((ang_x+180) - floor((ang_x+180)/360) * 360) - 180;
    ang_y = ((ang_y+180) - floor((ang_y+180)/360) * 360) - 180;
    ang_z = ((ang_z+180) - floor((ang_z+180)/360) * 360) - 180;

    /*
    while (ang_x > 180)
        ang_x = ang_x - 360;

    while (ang_x < -180)
        ang_x = ang_x + 360;

    while (ang_y > 180)
        ang_y = ang_y - 360;

    while (ang_y < -180)
        ang_y = ang_y + 360;

    while (ang_z > 180)
        ang_z = ang_z - 360;

    while (ang_z < -180)
        ang_z = ang_z + 360;
    */
    return ang;
};
float mathlib_accuracy; //accuracy of sqrt & pow


//----------------math ported from copper by Rel_71
// mathlib_sqrt
float(float num) sqrt =
{
	local float apr;

	if(mathlib_accuracy <= 0)
		mathlib_accuracy = 0.001;   //this sets a level of accuracy, it's a global float

	if (num < mathlib_accuracy)
		return 0;
	if (num>1)
		apr = num;
	else
		apr = 1;
	do
	{
		apr = (num + (apr * apr)) / (2 * apr);
	}
	while (fabs((apr * apr) - num) > (num * mathlib_accuracy));
	return apr;
}

vector(vector a, vector b) CrossProduct =
{
	vector c;

	c_x = a_y * b_z - a_z * b_y;
	c_y = a_z * b_x - a_x * b_z;
	c_z = a_x * b_y - a_y * b_x;

	return c;
}


// =========================================================================
// AGREGADOS PARA LA LIBRERIA DE VEHICULOS (vehicle/)
// Funciones y constantes que no existian en math.qc pero son requeridas
// por func_vehicle y el sistema de fisica soft-body. El resto de utilidades
// matematicas las provee math.qc existente (lerp, clamp, mod, sqrt, etc.).
// =========================================================================

// Constante PI usada por func_vehicle para calcular la circunferencia de
// las ruedas (linear velocity / (PI * radius) = angular velocity).
const float PI = 3.1415926535897932384626433832795028841971693993751058209749445923;

// min/max basicos. La libreria de vehiculos los usa intensivamente.
// Ironwail puede tenerlos como builtins, pero proveerlos en QC es portable.
float(float a, float b) min = { if (a <= b) return a; return b; }
float(float a, float b) max = { if (a >= b) return a; return b; }

// Longitud cuadrada de un vector. Evita el sqrt cuando solo se necesita
// comparar magnitudes (mucho mas barato que vlen).
float(vector v) vlensqr =
{
	return v_x * v_x + v_y * v_y + v_z * v_z;
}

// not(a, b) ya esta definido en subs.qc:714 (Copper). Se omite aqui.

//-------------MOD Rev3 29/octubre/2026
// SENO Y COSENO EN GRADOS  la solucion de Alkaline  su math.qc
// makevectors con el angulo en el yaw deja v_forward = cos sin 0  exacto
// porque la trigonometria la hace el motor  guarda y restaura v_forward
// v_up y v_right asi no le pisa nada a quien lo llama
// NO se llaman sin y cos porque este archivo tambien compila en csprogs y
// ahi esos nombres son los builtins 60 y 61 que trabajan en radianes
vector(float deg) SinCos =
{
	local vector vf, vu, vr, r;

	vf = v_forward;
	vu = v_up;
	vr = v_right;

	// a 0 360 antes del motor  con un time grande el float pierde precision
	deg = deg - floor(deg / 360) * 360;
	makevectors('0 1 0' * deg);
	r_x = v_forward_y;   // seno
	r_y = v_forward_x;   // coseno
	r_z = 0;

	v_forward = vf;
	v_up = vu;
	v_right = vr;
	return r;
}

float(float deg) sin_deg =
{
	local vector r;
	r = SinCos(deg);
	return r_x;
}

float(float deg) cos_deg =
{
	local vector r;
	r = SinCos(deg);
	return r_y;
}

