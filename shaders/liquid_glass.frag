#version 460 core
// 液态玻璃（Liquid Glass）—— 移植自 AndroidLiquidGlass / Backdrop v2
//   https://github.com/Kyant0/AndroidLiquidGlass
//
// 数学核心（SDF 距离场 / circleMap 斜面 / 折射位移 / 7-tap 色散 / 边缘高光）
// 全部按原作 AGSL 逐行移植，参数语义与默认值保持一致。
//
// 运行方式：必须配合 ImageFilter.shader + BackdropFilter 使用。
// 该场景下引擎会自动注入 uSize（float 索引 0,1）与 uTexture（sampler 索引 0），
// 这两个不要从 Dart 侧设置；自定义 uniform 从 setFloat(2) 开始。
#include <flutter/runtime_effect.glsl>

out vec4 fragColor;

// ===== 引擎自动注入（不要从 Dart 设置）=====
uniform vec2 uSize;
uniform sampler2D uTexture;

// ===== 自定义 uniform：setFloat 索引从 2 起 =====
uniform float uRefractionHeight;    // 2  斜面宽度（px），建议 [0, radius]
uniform float uRefractionAmount;    // 3  最大位移量（px），传负值=放大
uniform float uDepthEffect;         // 4  0/1，是否混入径向产生 3D 凸起
uniform float uChromatic;           // 5  0/1，是否启用色散
uniform float uRadius;              // 6  圆角半径（px）
uniform float uBlurRadius;          // 7  背景模糊半径（px）
uniform float uHighlightAngle;      // 8  光照角度（弧度）
uniform float uHighlightFalloff;    // 9  高光衰减指数
uniform float uHighlightIntensity;  // 10 高光强度
uniform float uSurfaceAlpha;        // 11 可读性底色透明度
uniform vec4 uSurfaceColor;         // 12..15 可读性底色（unpremultiplied sRGB）
uniform float uSaturation;          // 16 饱和度（1.0=原样，1.5=vibrancy）
uniform float uOpacity;             // 17 整体不透明度

const float PI = 3.141592653589793;

// ---------------------------------------------------------------------------
// 圆角矩形有向距离场
// ---------------------------------------------------------------------------
float sdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    float outside = length(max(cornerCoord, 0.0)) - radius;
    float inside = min(max(cornerCoord.x, cornerCoord.y), 0.0);
    return outside + inside;
}

// SDF 的解析梯度（= 2D 法线），非数值差分。
vec2 gradSdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
        return sign(coord) * normalize(max(cornerCoord, 0.0));
    } else {
        float gradX = step(cornerCoord.y, cornerCoord.x);
        return sign(coord) * vec2(gradX, 1.0 - gradX);
    }
}

// 四分之一圆截面斜面：
// t=0（边缘）→ d 最大；t=H（斜面内端）→ d=0，且该处导数为 0（与平坦区 C¹ 连续）。
float circleMap(float x) {
    return 1.0 - sqrt(1.0 - x * x);
}

// ---------------------------------------------------------------------------
// 背景采样（自动处理 OpenGLES 的 y 翻转）
// ---------------------------------------------------------------------------
vec4 sampleBackdrop(vec2 coord) {
    vec2 uv = coord / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
#endif
    return texture(uTexture, uv);
}

// 泊松盘近似高斯模糊。
// 不用数组字面量（SkSL 不支持），改为两层定长循环按角度/半径生成采样点，
// 兼容 Impeller(SPIR-V) 与 Skia(SkSL) 两个编译后端。
vec4 blurredBackdrop(vec2 coord, float radius) {
    if (radius <= 0.01) {
        return sampleBackdrop(coord);
    }
    vec4 sum = sampleBackdrop(coord);
    float total = 1.0;
    // 外圈：12 点 @ radius，角度均匀分布
    for (int i = 0; i < 12; i++) {
        float a = float(i) * 0.5235987756; // 30°
        sum += sampleBackdrop(coord + vec2(cos(a), sin(a)) * radius);
        total += 1.0;
    }
    // 内圈：6 点 @ radius*0.45，权重 2（更高频的细节）
    for (int i = 0; i < 6; i++) {
        float a = float(i) * 1.047197551 + 0.2617993878; // 60° 起偏 15°
        sum += sampleBackdrop(coord + vec2(cos(a), sin(a)) * radius * 0.45) * 2.0;
        total += 2.0;
    }
    return sum / total;
}

// 饱和度调整（unpremultiply → 矩阵 → repremultiply）
vec4 applySaturation(vec4 c, float saturation) {
    float a = c.a;
    if (a <= 0.0 || abs(saturation - 1.0) < 0.001) return c;
    vec3 rgb = c.rgb / a;
    float luma = dot(rgb, vec3(0.213, 0.715, 0.072));
    rgb = mix(vec3(luma), rgb, saturation);
    return vec4(clamp(rgb, 0.0, 1.0) * a, a);
}

void main() {
    vec2 coord = FlutterFragCoord().xy;
    vec2 halfSize = uSize * 0.5;
    vec2 centeredCoord = coord - halfSize;
    float radius = min(uRadius, min(halfSize.x, halfSize.y));

    float sd = sdRoundedRect(centeredCoord, halfSize, radius);

    // 形状外：保持透明，露出下层原始背景（BackdropFilter 是叠加而非擦除）
    float aa = 1.0;
    float shapeAlpha = 1.0 - smoothstep(-aa, aa, sd);
    if (shapeAlpha <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    // 斜面内端以远不做折射，直接采样（原作的早退优化）
    if (-sd < uRefractionHeight) {
        float d = circleMap(1.0 - (-sd) / uRefractionHeight) * uRefractionAmount;
        // 梯度用"放胖 1.5 倍"的圆角，让转角处法线过渡更柔和
        float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));
        vec2 grad = normalize(
            gradSdRoundedRect(centeredCoord, halfSize, gradRadius)
            + uDepthEffect * normalize(centeredCoord + vec2(0.0001))
        );
        vec2 refractedCoord = coord + d * grad;

        vec4 color;
        if (uChromatic > 0.5) {
            // 7-tap 光谱重建，采样沿 dispersedCoord 从 +1 → -1（红→紫）
            float dispIntensity =
                (centeredCoord.x * centeredCoord.y) / (halfSize.x * halfSize.y);
            vec2 dispersed = d * grad * dispIntensity;

            color = vec4(0.0);
            vec4 c;

            c = blurredBackdrop(refractedCoord + dispersed, uBlurRadius);
            color.r += c.r / 3.5;
            color.a += c.a / 7.0;

            c = blurredBackdrop(refractedCoord + dispersed * (2.0 / 3.0), uBlurRadius);
            color.r += c.r / 3.5;
            color.g += c.g / 7.0;
            color.a += c.a / 7.0;

            c = blurredBackdrop(refractedCoord + dispersed * (1.0 / 3.0), uBlurRadius);
            color.r += c.r / 3.5;
            color.g += c.g / 3.5;
            color.a += c.a / 7.0;

            c = blurredBackdrop(refractedCoord, uBlurRadius);
            color.g += c.g / 3.5;
            color.a += c.a / 7.0;

            c = blurredBackdrop(refractedCoord - dispersed * (1.0 / 3.0), uBlurRadius);
            color.g += c.g / 3.5;
            color.b += c.b / 3.0;
            color.a += c.a / 7.0;

            c = blurredBackdrop(refractedCoord - dispersed * (2.0 / 3.0), uBlurRadius);
            color.b += c.b / 3.0;
            color.a += c.a / 7.0;

            c = blurredBackdrop(refractedCoord - dispersed, uBlurRadius);
            color.r += c.r / 7.0;
            color.b += c.b / 3.0;
            color.a += c.a / 7.0;
        } else {
            color = blurredBackdrop(refractedCoord, uBlurRadius);
        }

        color = applySaturation(color, uSaturation);

        // 可读性底色（对应原作 onDrawSurface）—— 导航条上文字可读的关键
        float sa = uSurfaceAlpha * uSurfaceColor.a;
        color.rgb = mix(color.rgb, uSurfaceColor.rgb * uSurfaceAlpha, sa);
        color.a = max(color.a, sa);

        // 边缘高光：dot(SDF 梯度, 光照方向)，用 abs 让迎光/背光侧都亮
        float gradRadiusH = min(radius * 1.5, min(halfSize.x, halfSize.y));
        vec2 gradH = gradSdRoundedRect(centeredCoord, halfSize, gradRadiusH);
        vec2 lightDir = vec2(cos(uHighlightAngle), sin(uHighlightAngle));
        float hl = pow(abs(dot(gradH, lightDir)), uHighlightFalloff);
        // 只在靠近边缘的一圈生效，中心不受影响
        float edgeMask = 1.0 - smoothstep(0.0, max(uRefractionHeight, 1.0), -sd);
        color.rgb += vec3(hl * uHighlightIntensity * edgeMask);

        fragColor = vec4(
            clamp(color.rgb, 0.0, 1.0) * color.a * shapeAlpha * uOpacity,
            color.a * shapeAlpha * uOpacity
        );
    } else {
        // 中心平坦区：只做模糊 + 底色，不做折射
        vec4 color = blurredBackdrop(coord, uBlurRadius);
        color = applySaturation(color, uSaturation);
        float sa = uSurfaceAlpha * uSurfaceColor.a;
        color.rgb = mix(color.rgb, uSurfaceColor.rgb * uSurfaceAlpha, sa);
        color.a = max(color.a, sa);
        fragColor = vec4(
            clamp(color.rgb, 0.0, 1.0) * color.a * shapeAlpha * uOpacity,
            color.a * shapeAlpha * uOpacity
        );
    }
}
