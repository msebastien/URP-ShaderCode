#ifndef SHADER_CUSTOMLITTRANSPARENCY_COMMON
// "#ifndef MYSHADER_COMMON_INCLUDED" is equivalent to "#if !defined(MYSHADER_COMMON_INCLUDED)"
#define SHADER_CUSTOMLITTRANSPARENCY_COMMON

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// Textures
TEXTURE2D(_ColorMap); SAMPLER(sampler_ColorMap); // RGB = albedo, A = Alpha
float4 _ColorMap_ST; // This is automatically set by Unity. Used in TRANSFORM_TEX to apply UV tiling

// A "uniform" is a global Shader variable. These act as parameters that the user of a shader program can pass to that program. 
// Uniforms are so named because they do not change from one shader invocation to the next within a particular rendering call thus their value is uniform among all invocations. 
// This makes them unlike shader stage inputs and outputs, which are often different for each invocation of a shader stage.
// In HLSL global variables are considered uniform by default.
// Cg/HLSL can also accept uniform keyword, but it is not necessary.
// (Another keyword called "varying" also exists)
uniform float4 _ColorTint;

float _Cutoff; // Alpha cutout threshold
float _Smoothness;

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