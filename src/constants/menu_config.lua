local M = {}

M.SPRING_K = 260
M.SPRING_C = 24

M.FONT_MENU = "src/fonts/SairaExtraCondensed-Regular.ttf"
M.FONT_MENU_BOLD = "src/fonts/SairaExtraCondensed-ExtraBold.ttf"

M.MENU_START_Y = 520
M.MENU_SPACING = 85

M.MENU_OPTIONS_SCALE_MAX = 1.38
M.MENU_OPTIONS_SPACING_ADD = 52
M.MENU_OPTIONS_T_RATE = 2.85
M.MENU_OPTIONS_BANNER_PIVOT_Y = 31.5
-- Options/detail list only: baseline offset before row scale (applied as value/rs). Positive = lower; negative = raise.
M.MENU_OPTIONS_DETAIL_BASELINE_NUDGE_SCREEN_PX = 2
-- Options detail only: label moves up this many screen pixels while row is hovered (animated).
M.MENU_OPTIONS_DETAIL_HOVER_LIFT_SCREEN_PX = 8
M.MENU_OPTIONS_DETAIL_HOVER_LERP_RATE = 14
-- Gap between selection icon and label (screen px; multiplied by UI.scale in draw_ui).
M.MENU_BTN_ICON_TEXT_GAP_SCREEN_PX = 20

M.LOGO_X, M.LOGO_Y = 98, 98
M.LOGO_TARGET_W = 450
M.LOGO_SCALE_MUL = 0.94

M.PREVIEW_W = 930
M.PREVIEW_H = 485
M.SETTINGS_PANEL_W = 1120
M.SETTINGS_PANEL_H = 900
M.PREVIEW_MARGIN_RIGHT = 42
M.PREVIEW_OUTLINE_PX = 2
M.PREVIEW_FOOTER_H = 78
M.PREVIEW_FOOTER_RULE_VIRT = 3
M.PREVIEW_HOVER_LERP_RATE = 1.85
M.PREVIEW_COLOR_MAX = 0.8
M.PREVIEW_SHOT_HOLD = 6
M.PREVIEW_SHOT_CROSSFADE = 1.35

M.IRIS_OUT_DURATION = 2.0
M.GAME_PLACEHOLDER_BLACK_HOLD = 0.9
M.GAME_PLACEHOLDER_TEXT = "Game here lol..."

M.GAME_PLACEHOLDER_TYPE_BASE = 0.068
M.GAME_PLACEHOLDER_TYPE_SPACE_MUL = 1.42
M.GAME_PLACEHOLDER_TYPE_PUNCT_MUL = 1.88

M.GAME_PLACEHOLDER_TYPE_DELAYS = {}
do
    local s = M.GAME_PLACEHOLDER_TEXT
    for i = 1, #s do
        local c = s:sub(i, i)
        local d = M.GAME_PLACEHOLDER_TYPE_BASE
        if c == " " then
            d = d * M.GAME_PLACEHOLDER_TYPE_SPACE_MUL
        elseif c == "." then
            d = d * M.GAME_PLACEHOLDER_TYPE_PUNCT_MUL
        end
        M.GAME_PLACEHOLDER_TYPE_DELAYS[i] = d
    end
end

M.BG_CYCLE_SECONDS = 440
M.BG_CYCLE_COLORS = {
    { 0.78, 0.05, 0.05 },
    { 0.06, 0.70, 0.14 },
    { 0.88, 0.78, 0.10 },
    { 0.10, 0.22, 0.82 },
}

M.MENU_PILL_CENTER_X = 300
-- White pill polygon reaches local x = -270 before row scale; keep scaled shape inside the viewport.
M.MENU_PILL_LOCAL_LEFT = 270
M.MENU_PILL_SCREEN_PAD_VIRT = 20

M.RES_PRESETS = {
    { 3840, 2160 },
    { 2560, 1440 },
    { 1920, 1080 },
    { 1680, 1050 },
    { 1600, 900 },
    { 1366, 768 },
    { 1280, 720 },
    { 1024, 768 },
}
M.SETTINGS_FILE = "menu_settings.txt"
M.WINDOW_FLAGS = { resizable = true, highdpi = true, msaa = 4 }

M.MENU_MUSIC_DIR = "src/audio/music"
M.MENU_MUSIC_EXT = { [".mp3"] = true, [".ogg"] = true, [".wav"] = true, [".flac"] = true }

M.SETTINGS_INNER_PAD_X = 72
M.SETTINGS_INNER_PAD_Y = 48
M.SETTINGS_PCT_COL = 96

local optionsPillMaxCenterX = math.max(
    M.MENU_PILL_CENTER_X,
    M.MENU_PILL_LOCAL_LEFT * M.MENU_OPTIONS_SCALE_MAX + M.MENU_PILL_SCREEN_PAD_VIRT
)
M.SETTINGS_PANEL_MIN_LEFT_X = optionsPillMaxCenterX + math.ceil(290 * M.MENU_OPTIONS_SCALE_MAX) + 72

M.PARTICLE_RADIAL_EXCL_PAD = 72
M.PARTICLE_COUNT = 119

M.BG_SHADER = [[
extern number time;
extern vec2 screenSize;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 base = Texel(tex, texture_coords) * color;
    vec2 uv = screen_coords / screenSize;
    vec2 d = uv - vec2(0.5);
    float vig = 1.0 - dot(d, d) * 0.38;
    vig = smoothstep(0.35, 1.0, clamp(vig, 0.0, 1.0));

    float g = fract(sin(dot(screen_coords.xy * 0.71 + time * 12.0, vec2(12.9898, 78.233))) * 43758.5453);
    float grain = mix(1.0, g, 0.035);

    return vec4(base.rgb * vig * grain, base.a);
}
]]

M.BG_WATERCOLOR_SHADER = [[
extern number time;
extern vec2 screenSize;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 uv = texture_coords;
    vec2 p = screen_coords / screenSize;
    float t = time * 0.11;

    vec2 flow = vec2(
        sin(uv.y * 9.0 + t * 1.3) * cos(uv.x * 5.0 - t * 0.6),
        cos(uv.x * 8.0 - t * 1.0) * sin(uv.y * 4.5 + t * 0.75)
    ) * 0.014;
    vec2 suv = clamp(uv + flow, vec2(0.002), vec2(0.998));
    vec4 scene = Texel(tex, suv) * color;

    float y = dot(scene.rgb, vec3(0.299, 0.587, 0.114));
    scene.rgb = mix(scene.rgb, vec3(y), 0.28);

    float wash = sin(p.x * 3.2 + t * 0.35) * sin(p.y * 2.8 - t * 0.28);
    wash = wash * 0.04 + 0.97;
    scene.rgb *= wash;

    vec2 d = p - vec2(0.5);
    float edge = 1.0 - dot(d, d) * 0.42;
    edge = mix(0.88, 1.0, smoothstep(0.15, 1.0, clamp(edge, 0.0, 1.0)));
    scene.rgb *= edge;

    scene.rgb = scene.rgb * 0.84 + vec3(0.035);

    float g = fract(sin(dot(screen_coords.xy * 0.63 + time * 2.0, vec2(12.9898, 78.233))) * 43758.5453);
    float grain = mix(0.97, 1.0, g);
    scene.rgb *= grain;

    return vec4(clamp(scene.rgb, 0.0, 1.0), scene.a);
}
]]

M.UI_SHADER = [[
extern number time;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texel = Texel(tex, texture_coords);
    float sheen = sin(screen_coords.x * 0.018 + time * 1.9) * 0.018;
    float rim = sin(screen_coords.y * 0.012 - time * 1.4) * 0.012;
    float pulse = sin(time * 2.4) * 0.008;
    float lum = 1.0 + sheen + rim + pulse;
    return texel * vec4(color.rgb * lum, color.a);
}
]]

M.PREVIEW_GRAYSCALE_SHADER = [[
extern number colorBlend;
extern number colorMax;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texel = Texel(tex, texture_coords) * color;
    float y = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
    vec3 gray = vec3(y);
    float t = clamp(colorBlend, 0.0, 1.0) * colorMax;
    vec3 outRgb = mix(gray, texel.rgb, t);
    return vec4(outRgb, texel.a);
}
]]

return M
