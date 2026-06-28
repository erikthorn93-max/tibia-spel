shader_type canvas_item;
// Levande vatten: mjuka ljusvågor och ett vandrande highlight-band ovanpå
// vattentexturen. Animationen drivs av världsposition (inte tile-UV) så vågorna
// löper sömlöst över rutgränserna utan synligt rutnät.

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	// Två osammanhängande vågor → oregelbundet glitter utan tydlig periodicitet.
	float w = sin(wpos.x * 0.045 + TIME * 1.25)
			+ sin(wpos.y * 0.060 - TIME * 0.85);
	col.rgb += w * 0.035;
	// Långsamt vandrande ljusband (solreflex på ytan).
	float band = sin(wpos.x * 0.035 + wpos.y * 0.028 + TIME * 0.7);
	float hl = smoothstep(0.72, 1.0, band);
	col.rgb += hl * vec3(0.10, 0.14, 0.18);
	COLOR = col;
}
