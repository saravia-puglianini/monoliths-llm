#version 330
in vec2 texcoord;
uniform sampler2D tex;
uniform float opacity;

vec4 default_post_processing(vec4 c);

vec4 window_shader() {
    vec2 texsize = textureSize(tex, 0);
    vec4 color = texture(tex, texcoord / texsize);
    // Convertir a escala de grises (fórmula estándar)
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    color = vec4(vec3(gray), color.a);
    return default_post_processing(color);
}