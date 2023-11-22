// This file contains the vertex and fragment functions for the forward lit pass
// This is the shader pass that computes visible colors for a material
// by reading material, light, shadow, ... data
#ifndef SHADER_CUSTOMLITLIGHTING_FORWARDLIT_PASS
#define SHADER_CUSTOMLITLIGHTING_FORWARDLIT_PASS

// Pull in URP library functions and our own common functions
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// A "uniform" is a global Shader variable. These act as parameters that the user of a shader program can pass to that program. 
// Uniforms are so named because they do not change from one shader invocation to the next within a particular rendering call thus their value is uniform among all invocations. 
// This makes them unlike shader stage inputs and outputs, which are often different for each invocation of a shader stage.
// In HLSL global variables are considered uniform by default.
// Cg/HLSL can also accept uniform keyword, but it is not necessary.
// (Another keyword called ""varying" also exists)
uniform float4 _ColorTint;

// Textures
TEXTURE2D(_ColorMap); SAMPLER(sampler_ColorMap); // RGB = albedo, A = Alpha
float4 _ColorMap_ST; // This is automatically set by Unity. Used in TRANSFORM_TEX to apply UV tiling

float _Smoothness;

// This attributes struct receives data about the mesh we're currently rendering
// Data is automatically placed in fields according to their semantic
struct Attributes
{
    float3 positionOS : POSITION; // Position in object space (equivalent to "local space" in the Unity's scene editor)
    float2 uv : TEXCOORD0; // Material texture UVs (texture coordinates set n°0)
    float3 normalOS : NORMAL;
};

struct Interpolators 
{
    // This value should contain the position in clip space (which is similar to a position on screen)
    // when output from the vertex function. It will be transformed into pixel position of the current
    // fragment on the current when read from the fragment function
    float4 positionCS : SV_POSITION;

    // The following variables will retain their values from the vertex stage, 
    // except the rasterizer will interpolate them between vertices
    float2 uv : TEXCOORD0; // Material texture UVs
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2; // For Lighting, will be interpolated
};
            
// - The primary objective of the Vertex shader stage is to compute where
// mesh vertices appear on the screen
// - This function is called multiple times (once for each vertex).
// - It runs in parallel on the GPU
// - Each vertex function call is effectively isolated from all the others.
// - Each call can only depend on the data in the input struct as well as other global data
// - Each Vertex function call only knows data of a SINGLE vertex 
//   => (for efficiency, the GPU doesn't want to load the entire mesh at once)
// A vertex's position on screen is described using a space called "clip space".
Interpolators Vertex(Attributes input)
{
    Interpolators output;

    // These helper functions, found in URP/ShaderLibrary/ShaderVariablesFunctions.hlsl
    // transform object space values into world and clip space
    VertexPositionInputs posnInputs = GetVertexPositionInputs(input.positionOS);
    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);

    // Pass position and orientation data to the fragment function
    output.positionCS = posnInputs.positionCS; // float4
    output.uv = TRANSFORM_TEX(input.uv, _ColorMap); // Make sure texture tiling/scale&offset is applied correctly
    output.positionWS = posnInputs.positionWS;
    output.normalWS = normalInputs.normalWS;

    return output;
}

// The Fragment function. This runs once per fragment, which you can think of as a pixel on the screen
// It must output the final color of this pixel.
float4 Fragment(Interpolators input) : SV_TARGET 
{
    float2 uv = input.uv;
    float4 colorSample = SAMPLE_TEXTURE2D(_ColorMap, sampler_ColorMap, uv);

    // Initialize all struct's fields to 0.
    // Found in URP/ShaderLib/Input.hlsl & URP/ShaderLib/SurfaceData.hlsl
    InputData lightingInput = (InputData)0; 
    SurfaceData surfaceInput = (SurfaceData)0;

    // Define Lighting data (vertex pos + normal)
    lightingInput.positionWS = input.positionWS;
    lightingInput.normalWS = normalize(input.normalWS);
    // Computes the World Space View normalized direction (pointing towards the viewer) for specular lighting
    lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS); // In ShaderVariablesFunctions.hlsl
    lightingInput.shadowCoord = TransformWorldToShadowCoord(input.positionWS); // In Shadows.hlsl

    // Define surface data struct, which contains data from the material structures
    surfaceInput.albedo = colorSample.rgb * _ColorTint.rgb;
    surfaceInput.alpha = colorSample.a * _ColorTint.a;
    surfaceInput.specular = 1; // white
    surfaceInput.smoothness = _Smoothness; // To reduce highlight effect of the specular lighting
    
    // Calculate Lighting using Blinn-Phong
#if UNITY_VERSION >= 202120
    return UniversalFragmentBlinnPhong(lightingInput, surfaceInput);
#else
    return UniversalFragmentBlinnPhong
    (
        lightingInput, 
        surfaceInput.albedo, 
        float4(surfaceInput.specular, 1), 
        surfaceInput.smoothness,
        0,
        surfaceInput.alpha,
        surfaceInput.normalTS
    );
#endif

}

#endif