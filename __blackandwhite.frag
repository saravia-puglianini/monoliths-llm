#version 330
in vec2 texcoord;
uniform sampler2D tex;
uniform float opacity;

vec4 default_post_processing(vec4 c);

vec4 window_shader() {
    // Muestrea el color original
    vec4 color = texture(tex, texcoord);
    
    // Convertir a escala de grises
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Mantener solo blanco y negro sólido (sin transparencia)
    // color.a = 1.0; // ← Descomenta para forzar opacidad total
    
    return vec4(vec3(gray), color.a); // color.a mantiene transparencia original
}