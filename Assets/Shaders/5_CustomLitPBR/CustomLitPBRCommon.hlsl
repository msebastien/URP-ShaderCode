#ifndef SHADER_CUSTOMLITPBR_COMMON_INCLUDED
// "#ifndef MYSHADER_COMMON_INCLUDED" is equivalent to "#if !defined(MYSHADER_COMMON_INCLUDED)"
#define SHADER_CUSTOMLITPBR_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// Textures
TEXTURE2D(_ColorMap); SAMPLER(sampler_ColorMap); // RGB = albedo, A = Alpha
TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
TEXTURE2D(_MetalnessMask); SAMPLER(sampler_MetalnessMask);
TEXTURE2D(_SpecularMap); SAMPLER(sampler_SpecularMap);
TEXTURE2D(_SmoothnessMask); SAMPLER(sampler_SmoothnessMask);
TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
TEXTURE2D(_ParallaxMap); SAMPLER(sampler_ParallaxMap);
TEXTURE2D(_ClearCoatMask); SAMPLER(sampler_ClearCoatMask);
TEXTURE2D(_ClearCoatSmoothnessMask); SAMPLER(sampler_ClearCoatSmoothnessMask);

// A "uniform" is a global Shader variable. These act as parameters that the user of a shader program can pass to that program. 
// Uniforms are so named because they do not change from one shader invocation to the next within a particular rendering call thus their value is uniform among all invocations. 
// This makes them unlike shader stage inputs and outputs, which are often different for each invocation of a shader stage.
// In HLSL global variables are considered uniform by default.
// Cg/HLSL can also accept uniform keyword, but it is not necessary.
// (Another keyword called "varying" also exists)
// Ex: uniform float4 _ColorTint; (optional)
float4 _ColorMap_ST; // This is automatically set by Unity. Used in TRANSFORM_TEX to apply UV tiling
float4 _ColorTint;
float _NormalStrength;
float _Cutoff; // Alpha cutout threshold
float _Metalness;
float3 _SpecularTint;
float _Smoothness;
float3 _EmissionTint;
float _ParallaxStrength;
float _ClearCoatStrength;
float _ClearCoatSmoothness;

// For transparency using cutout/alpha test
// Discard the current fragment if the value is less or equal to zero
// Discard is a command to the rasterizer causing it to pretend it never invoked a particular fragment function.
// It will short-circuit the fragment function returning immediately after clip() and
// throwing all data pertaining to the fragment. It will neiter write to the depth buffer or the render target. It's as if the fragment function was never called.
void TestAlphaClip(float4 colorSample) 
{
#ifdef _ALPHA_CUTOUT
    clip(colorSample.a * _ColorTint.a - _Cutoff);
#endif
}

#endif