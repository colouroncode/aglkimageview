#define MAX_TEXTURES    1
#define MAX_TEX_COORDS  1

uniform highp mat4      u_mvpMatrix;
uniform highp mat3      u_normalMatrix;
uniform sampler2D       u_units[MAX_TEXTURES];
uniform lowp  vec4      u_globalAmbient;
uniform highp vec3      u_diffuseLightDirection;
uniform highp vec4      u_diffuseLightColor;
uniform bool            u_useConstantColor;
uniform lowp  vec4      u_constantColor;
uniform lowp  vec3      u_colorFilter;

varying highp vec2      v_texCoords[MAX_TEX_COORDS];
varying lowp vec4       v_lightColor;

void main() {
    lowp vec4 color = texture2D(u_units[0], v_texCoords[0]);
    if (color.a < 0.2) {
        if (u_useConstantColor) {
            gl_FragColor = u_constantColor;
        } else {
            gl_FragColor = vec4(0.0);
        }
    } else {
        gl_FragColor = vec4(color.r*u_colorFilter[0], color.g*u_colorFilter[1], color.b*u_colorFilter[2], color.a);
    }
}