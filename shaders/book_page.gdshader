shader_type canvas_item;
render_mode unshaded;
uniform sampler2D page_texture : filter_nearest;
uniform sampler2D backdrop_texture : filter_nearest;
uniform vec2 pixel_grid = vec2(640.0, 360.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float departure : hint_range(0.0, 1.0) = 0.0;

bool inside(vec2 p, vec2 lo, vec2 hi) {
    return all(greaterThanEqual(p, lo)) && all(lessThanEqual(p, hi));
}
vec3 cloth(vec2 p, vec2 cell) {
    float grain = mod(cell.x + cell.y * 3.0, 4.0);
    vec3 green = grain < 1.0 ? vec3(0.13,0.25,0.19) : vec3(0.17,0.31,0.23);
    float border = min(min(p.x,1.0-p.x),min(p.y,1.0-p.y));
    if (border < 0.012) green = vec3(0.15,0.12,0.08);
    else if (border < 0.021) green = vec3(0.64,0.46,0.22);
    if (p.x < 0.08) green *= 0.72;
    float frame = min(min((p.x-0.13)*0.7,(0.89-p.x)*0.7),min(p.y-0.08,0.92-p.y));
    if (frame >= 0.0 && frame < 0.006) green = vec3(0.83,0.68,0.38);
    vec2 corner = min(abs(p-vec2(0.18,0.12)),abs(p-vec2(0.84,0.88)));
    if (corner.x + corner.y < 0.017) green = vec3(0.90,0.76,0.47);
    return green;
}
void fragment() {
    vec2 uv = (floor(UV * pixel_grid) + 0.5) / pixel_grid;
    float turn = smoothstep(0.0,1.0,progress);
    float angle = turn * 3.14159265;
    float center_shift = -0.2075 * smoothstep(0.65,1.0,turn);
    float drop = 1.2 * departure * departure;
    vec2 p = uv - vec2(center_shift,drop);
    // A complete painted room at the same UV: no stretched/repeated tabletop,
    // rectangular patch or stationary copy of the original book underneath.
    vec4 backdrop = texture(backdrop_texture,uv);
    backdrop.a = 1.0 - smoothstep(0.0,0.65,departure);
    vec4 result = backdrop;
    if (inside(p,vec2(0.5,0.07),vec2(0.915,0.93))) {
        result = vec4(texture(page_texture,p).rgb,1.0);
    }
    // LEFT page rotates about the spine onto RIGHT. One crisp current silhouette.
    float width = 0.405 * abs(cos(angle));
    float lift = 0.035 * sin(angle);
    float left = cos(angle) >= 0.0 ? 0.5-width : 0.5;
    float right = cos(angle) >= 0.0 ? 0.5 : 0.5+width+0.01*turn;
    if (inside(p,vec2(left,0.07-lift),vec2(right,0.93-lift))) {
        vec2 q = vec2((p.x-left)/max(right-left,0.001),(p.y-0.07+lift)/0.86);
        vec3 face;
        if (cos(angle) >= 0.0) {
            face = texture(page_texture,vec2(mix(0.095,0.5,q.x),mix(0.07,0.93,q.y))).rgb;
        } else {
            face = cloth(q,floor(uv*pixel_grid));
        }
        float shade = floor(sin(angle)*4.0)/18.0;
        result = vec4(face*(1.0-shade),1.0);
    }
    if (departure >= 0.9999) result = vec4(0.0);
    COLOR = result;
}
