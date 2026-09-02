// Copyright (c) 2026 Adam Brauns (@AdamBrauns)

// Cursor trail in the style of cursor-warp: a quad stretched between the
// previous and current cursor cells. Each corner eases toward the new cell at
// its own speed, so the corners leading the move jump ahead while the trailing
// corners lag behind, producing a smear that collapses onto the new cursor.
// Ghostty only exposes the previous and current cursor, so there is one smear.

// --- Configuration ---------------------------------------------------------
const float DURATION = 0.2;                // total animation time in seconds
const float TRAIL_SIZE = 0.8;              // 0 = corners move together, 1 = max smear
const float THRESHOLD_MIN_DISTANCE = 1.5;  // min move (in cursor heights) to show trail
const float BLUR = 1.0;                    // antialias width in pixels (diagonal moves only)
const float TRAIL_THICKNESS = 1.0;         // trail height relative to the cursor
const float TRAIL_THICKNESS_X = 0.9;       // trail width relative to the cursor
const float FADE_ENABLED = 0.0;            // 1 = fade the tail, 0 = solid trail
const float FADE_EXPONENT = 5.0;           // steepness of the tail fade

// Ghostty passes the cursor color as sRGB; the shader pipeline is linear.
vec3 sRGBToLinear(vec3 c) {
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// EaseOutCirc: fast start, gentle settle
float ease(float x) {
    return sqrt(1.0 - pow(x - 1.0, 2.0));
}

// --- Geometry --------------------------------------------------------------
float getSdfRectangle(vec2 p, vec2 xy, vec2 b) {
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// One edge of the polygon SDF, branchless (after Inigo Quilez's distfunctions2d)
float seg(vec2 p, vec2 a, vec2 b, inout float s, float d) {
    vec2 e = b - a;
    vec2 w = p - a;
    vec2 proj = a + e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
    d = min(d, dot(p - proj, p - proj));

    float c0 = step(0.0, p.y - a.y);
    float c1 = 1.0 - step(0.0, p.y - b.y);
    float c2 = 1.0 - step(0.0, e.x * w.y - e.y * w.x);
    float allCond = c0 * c1 * c2;
    float noneCond = (1.0 - c0) * (1.0 - c1) * (1.0 - c2);
    s *= mix(1.0, -1.0, step(0.5, allCond + noneCond));
    return d;
}

float getSdfConvexQuad(vec2 p, vec2 v1, vec2 v2, vec2 v3, vec2 v4) {
    float s = 1.0;
    float d = dot(p - v1, p - v1);
    d = seg(p, v1, v2, s, d);
    d = seg(p, v2, v3, s, d);
    d = seg(p, v3, v4, s, d);
    d = seg(p, v4, v1, s, d);
    return s * sqrt(d);
}

// Pixel coords -> [-1, 1] space with a square aspect (isPosition = 1 for
// positions, 0 for sizes so they are only scaled, not shifted)
vec2 toNdc(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float antialias(float dist, float blurPx) {
    return 1.0 - smoothstep(0.0, toNdc(vec2(blurPx), 0.0).x, dist);
}

// Corner duration from its alignment with the move direction.
// dotVal in [-2, 2]: > 0.5 leading, > -0.5 side, otherwise trailing.
float getDurationFromDot(float dotVal, float lead, float side, float trail) {
    float isLead = step(0.5, dotVal);
    float isSide = step(-0.5, dotVal) * (1.0 - isLead);
    return mix(mix(trail, side, isSide), lead, isLead);
}

// Corners of a cursor rect (xy = top-left in y-up space, zw = size), shrunk
// about its center by the thickness factors: returns tl, tr, bl, br.
void cursorCorners(vec4 c, out vec2 tl, out vec2 tr, out vec2 bl, out vec2 br) {
    vec2 center = c.xy + vec2(c.z, -c.w) * 0.5;
    vec2 halfSize = c.zw * 0.5 * vec2(TRAIL_THICKNESS_X, TRAIL_THICKNESS);
    tl = center + vec2(-halfSize.x,  halfSize.y);
    tr = center + vec2( halfSize.x,  halfSize.y);
    bl = center + vec2(-halfSize.x, -halfSize.y);
    br = center + vec2( halfSize.x, -halfSize.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Always start from the rendered terminal; alpha is preserved throughout
    // so background-opacity keeps working.
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    vec2 vu = toNdc(fragCoord, 1.0);
    vec4 currentCursor  = vec4(toNdc(iCurrentCursor.xy, 1.0),  toNdc(iCurrentCursor.zw, 0.0));
    vec4 previousCursor = vec4(toNdc(iPreviousCursor.xy, 1.0), toNdc(iPreviousCursor.zw, 0.0));

    vec2 centerCC = currentCursor.xy + vec2(currentCursor.z, -currentCursor.w) * 0.5;
    vec2 centerCP = previousCursor.xy + vec2(previousCursor.z, -previousCursor.w) * 0.5;

    float progress = iTime - iTimeCursorChange;
    float minDist = currentCursor.w * THRESHOLD_MIN_DISTANCE;
    if (distance(centerCC, centerCP) <= minDist || progress >= DURATION - 0.001) return;

    vec2 cc_tl, cc_tr, cc_bl, cc_br;
    vec2 cp_tl, cp_tr, cp_bl, cp_br;
    cursorCorners(currentCursor,  cc_tl, cc_tr, cc_bl, cc_br);
    cursorCorners(previousCursor, cp_tl, cp_tr, cp_bl, cp_br);

    // Per-corner durations: leading corners finish first, trailing last
    const float DURATION_TRAIL = DURATION;
    const float DURATION_LEAD  = DURATION * (1.0 - TRAIL_SIZE);
    const float DURATION_SIDE  = (DURATION_LEAD + DURATION_TRAIL) * 0.5;

    vec2 moveVec = centerCC - centerCP;
    vec2 s = sign(moveVec);

    float dot_tl = dot(vec2(-1.0,  1.0), s);
    float dot_tr = dot(vec2( 1.0,  1.0), s);
    float dot_bl = dot(vec2(-1.0, -1.0), s);
    float dot_br = dot(vec2( 1.0, -1.0), s);

    float dur_tl = getDurationFromDot(dot_tl, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);
    float dur_tr = getDurationFromDot(dot_tr, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);
    float dur_bl = getDurationFromDot(dot_bl, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);
    float dur_br = getDurationFromDot(dot_br, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);

    // On horizontal moves, keep each vertical edge rigid so the leading edge
    // arrives as one piece instead of shearing.
    float isMovingRight = step(0.5,  s.x);
    float isMovingLeft  = step(0.5, -s.x);
    float dur_right_rail = getDurationFromDot((dot_tr + dot_br) * 0.5, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);
    float dur_left_rail  = getDurationFromDot((dot_tl + dot_bl) * 0.5, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);

    dur_tl = mix(dur_tl, dur_left_rail,  isMovingLeft);
    dur_bl = mix(dur_bl, dur_left_rail,  isMovingLeft);
    dur_tr = mix(dur_tr, dur_right_rail, isMovingRight);
    dur_br = mix(dur_br, dur_right_rail, isMovingRight);

    vec2 v_tl = mix(cp_tl, cc_tl, ease(clamp(progress / dur_tl, 0.0, 1.0)));
    vec2 v_tr = mix(cp_tr, cc_tr, ease(clamp(progress / dur_tr, 0.0, 1.0)));
    vec2 v_br = mix(cp_br, cc_br, ease(clamp(progress / dur_br, 0.0, 1.0)));
    vec2 v_bl = mix(cp_bl, cc_bl, ease(clamp(progress / dur_bl, 0.0, 1.0)));

    float sdfTrail = getSdfConvexQuad(vu, v_tl, v_tr, v_br, v_bl);

    // Only antialias diagonal moves; on pure H/V moves the edges are already
    // pixel-aligned and blurring them makes the arriving cursor pulse.
    float isDiagonal = abs(s.x) * abs(s.y);
    float effectiveBlur = mix(0.0, BLUR, isDiagonal);
    float shapeAlpha = antialias(sdfTrail, effectiveBlur);

    vec4 trail = vec4(sRGBToLinear(iCurrentCursorColor.rgb), iCurrentCursorColor.a);
    if (FADE_ENABLED > 0.5) {
        // 0 at the tail (previous cell), 1 at the head (current cell)
        float fadeProgress = clamp(dot(vu - centerCP, moveVec) / (dot(moveVec, moveVec) + 1e-6), 0.0, 1.0);
        trail.a *= pow(fadeProgress, FADE_EXPONENT);
    }

    vec4 color = mix(fragColor, vec4(trail.rgb, fragColor.a), trail.a * shapeAlpha);

    // Punch a hole where the current cursor sits so it renders on top
    float sdfCurrentCursor = getSdfRectangle(vu, centerCC, currentCursor.zw * 0.5);
    fragColor = mix(color, fragColor, step(sdfCurrentCursor, 0.0));
}
