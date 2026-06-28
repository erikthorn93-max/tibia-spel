shader_type canvas_item;
// Tunn kontur runt en sprites silhuett: målar konturfärg i de genomskinliga
// pixlarna precis utanför figuren (där en granne är ogenomskinlig). Ger
// varelser "pop" mot marken utan att rita om någon sprite. Förutsätter lite
// marginal i texturen så konturen inte klipps mot kanten.

uniform vec4 outline_color : source_color = vec4(0.04, 0.03, 0.06, 0.6);
uniform float thickness : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 ps = TEXTURE_PIXEL_SIZE * thickness;
	// Största grann-alpha (4-grannskap räcker för en mjuk 1px-kontur).
	float a = texture(TEXTURE, UV + vec2(0.0, -ps.y)).a;
	a = max(a, texture(TEXTURE, UV + vec2(0.0,  ps.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2( ps.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a);
	// Bara där den egna pixeln är tom men en granne fylld → kant utanför figuren.
	float edge = a * (1.0 - col.a);
	COLOR = mix(col, outline_color, edge);
}
