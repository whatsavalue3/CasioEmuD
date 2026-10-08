#version 140
in vec2 uv;
uniform mat4 model_matrix;
out vec2 source_uv;

void main()
{
	gl_Position = gl_ModelViewMatrix*vec4(uv, 0.0f, 1);
	source_uv = uv;
}