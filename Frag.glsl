#version 140

uniform usampler2D planes;
in vec2 source_uv;
out vec4 frag_color;

vec3 palette[4] = vec3[4](
vec3(255,255,255),/*
vec3(148,148,148),
vec3(54,54,54),*/
/*
vec3(222,115,3),
vec3(84,0,109),
*/
vec3(255,0,0),
vec3(0,0,255),
vec3(0,0,0)
);

void main() {
	vec2 uv = floor(source_uv/2);
	ivec2 charpos = ivec2(floor(uv/vec2(8,1)));
	int bitpos = int(floor(uv.x))&0x7;
	int hirow = int(texelFetch(planes,charpos+ivec2(0,64),0).x);
	int lorow = int(texelFetch(planes,charpos,0).x);
	int hi = int((hirow&(0x80>>bitpos)) != 0);
	int lo = int((lorow&(0x80>>bitpos)) != 0);
	int index = (hi*2 + lo);
	
	frag_color = vec4(palette[index]/255,1);
	//frag_color = vec4(row,0,1,1);
	//frag_color = vec4(source_uv,1,1);
}