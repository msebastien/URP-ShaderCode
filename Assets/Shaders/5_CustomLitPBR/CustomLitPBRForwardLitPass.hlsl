// This file contains the vertex and fragment functions for the forward lit pass
// This is the shader pass that computes visible colors for a material
// by reading material, light, shadow, ... data
#ifndef SHADER_CUSTOMLITPBR_FORWARDLIT_PASS_INCLUDED
#define SHADER_CUSTOMLITPBR_FORWARDLIT_PASS_INCLUDED

// Pull in URP library functions and our own common functions
#include "CustomLitPBRCommon.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"

// This attributes struct receives data about the mesh we're currently rendering
// Data is automatically placed in fields according to their semantic
struct Attributes
{
    float3 positionOS : POSITION; // Position in object space (equivalent to "local space" in the Unity's scene editor)
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0; // Material texture UVs (texture coordinates set n°0)
};

// For performance reasons, it is important to keep the Interpolators struct as small as possible
// since each variable is more that the rasterizer has to interpolate.
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
#ifdef _NORMALMAP
    float4 tangentWS : TEXCOORD3; // for applying correctly a normal map by converting tangent space to world space
#endif
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
    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    // Pass position and orientation data to the fragment function
    output.positionCS = posnInputs.positionCS; // float4
    output.uv = TRANSFORM_TEX(input.uv, _ColorMap); // Make sure texture tiling/scale&offset is applied correctly
    output.positionWS = posnInputs.positionWS;
    output.normalWS = normalInputs.normalWS;

#ifdef _NORMALMAP
    output.tangentWS = float4(normalInputs.tangentWS, input.tangentOS.w);
#endif

    return output;
}

// The Fragment function. This runs once per fragment, which you can think of as a pixel on the screen
// It must output the final color of this pixel.
// FRONT_FACE_TYPE / FRONT_FACE_SEMANTIC found in Unity.RenderPipelines.Core.ShaderLibrary/API/D3D11.hlsl
float4 Fragment(Interpolators input
#ifdef _DOUBLE_SIDED_NORMALS
    , FRONT_FACE_TYPE frontFace : FRONT_FACE_SEMANTIC
#endif
) : SV_TARGET 
{
    // Normalize normals, and flip them if there are back face normals
    float3 normalWS = input.normalWS;
#ifdef _DOUBLE_SIDED_NORMALS
    normalWS *= IS_FRONT_VFACE(frontFace, 1, -1); // Flip normal for back face to fix lighting
#endif
    
    float3 positionWS = input.positionWS;
    float3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS); // In ShaderVariablesFunctions.hlsl
#ifdef _NORMALMAP
    // GetViewDirectionTangentSpace() needs the vertex normal in an unnormalized state!
    float3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, normalWS, viewDirWS); // In ParallaxOcclusion.hlsl
#endif
    
    // Parallax Occlusion: Calculate new UV 
    // based on the view direction in tangent space
    // since the imaginary surface formed by the heightmap exists in Tangent space
    float2 uv = input.uv;
#ifdef _NORMALMAP
    uv += ParallaxMapping(TEXTURE2D_ARGS(_ParallaxMap, sampler_ParallaxMap), viewDirTS, _ParallaxStrength, uv);
#endif

    float4 colorSample = SAMPLE_TEXTURE2D(_ColorMap, sampler_ColorMap, uv);   
    TestAlphaClip(colorSample);

    // LIGHTING
    
    // Process normal map when it is present
#ifdef _NORMALMAP
    // Decode normal map in tangent space, then convert to world space
    float4 normalSample = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv); // from 0 to 1. Need to be remapped to a range from -1 to 1 (done by UnpackNormal())
    float3 normalTS = UnpackNormalScale(normalSample, _NormalStrength);
    float3x3 tangentToWorld = CreateTangentToWorld(normalWS, input.tangentWS.xyz, input.tangentWS.w); // Tangent space basis
    // multiplies the tangent space Normal vector, from the Normal map, with the "Tangent To World" matrix, producing a world space vector
    // then, normalize to prevent rounding errors
    normalWS = normalize(TransformTangentToWorld(normalTS, tangentToWorld));
#else
    float3 normalTS = float3(0, 0, 1);
    normalWS = normalize(normalWS);
#endif

    // Initialize all struct's fields to 0.
    // Found in URP/ShaderLib/Input.hlsl & URP/ShaderLib/SurfaceData.hlsl
    InputData lightingInput = (InputData)0; 
    SurfaceData surfaceInput = (SurfaceData)0;

    // Define Lighting data (vertex pos + normal)
    lightingInput.positionWS = positionWS;
    lightingInput.normalWS = normalWS;

    // Computes the World Space View normalized direction (pointing towards the viewer) for specular lighting
    lightingInput.viewDirectionWS = viewDirWS;
    lightingInput.shadowCoord = TransformWorldToShadowCoord(positionWS); // In Shadows.hlsl
    
    // Debug: To support additional views in Unity's Rendering Debugger
#if UNITY_VERSION >= 202120
    lightingInput.positionCS = input.positionCS;
#ifdef _NORMALMAP
    lightingInput.tangentToWorld = tangentToWorld;
#endif
#endif
    
    // SURFACE
    // Define surface data struct, which contains data from the material structures
    surfaceInput.albedo = colorSample.rgb * _ColorTint.rgb;
    surfaceInput.alpha = colorSample.a * _ColorTint.a;

    // 2 workflows -> Metallic or Specular
    // In Specular workflow mode, UniversalFragmentPBR actually ignores the metallic value
#ifdef _SPECULAR_SETUP
    float4 specularMapSample = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, uv);
    surfaceInput.specular = specularMapSample.rgb * _SpecularTint;
    surfaceInput.metallic = 0;
#else
    surfaceInput.specular = 1; // white
    // Make the meterial look more or less metallic and shiny, using a mask for determining
    // which part of the texture should look metallic
    float4 metalnessMaskSample = SAMPLE_TEXTURE2D(_MetalnessMask, sampler_MetalnessMask, uv);
    surfaceInput.metallic = metalnessMaskSample.r * _Metalness;
#endif

    // Smoothness/Roughness: To reduce highlight effect of the specular lighting
    // smooth = 1.0 - rough / rough = 1.0 - smooth
    float4 smoothnessMaskSample = SAMPLE_TEXTURE2D(_SmoothnessMask, sampler_SmoothnessMask, uv);
#ifdef _ROUGHNESS_SETUP
    smoothnessMaskSample = 1 - smoothnessMaskSample;
#endif
    surfaceInput.smoothness = smoothnessMaskSample.r * _Smoothness;

    // Normal vector in Tangent Space
    surfaceInput.normalTS = normalTS;

    // Emission: Make some part of the material glowing
    // It works by ignoring shadows and overexposing affected areas
    // It doesn't actually light the scene unfortunately
    // We can sort of fix this by tying it into baked lighting
    float4 emissionMapSample = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv);
    surfaceInput.emission = emissionMapSample.rgb * _EmissionTint;

    // Clear coat
    // Clear coat emulates a transparent coat of paint on top of a surface.
    // It can have its own independant smoothness value
    float4 clearCoatMaskSample = SAMPLE_TEXTURE2D(_ClearCoatMask, sampler_ClearCoatMask, uv);
    surfaceInput.clearCoatMask = clearCoatMaskSample.r * _ClearCoatStrength;
    float4 clearCoatSmoothnessMaskSample = SAMPLE_TEXTURE2D(_ClearCoatSmoothnessMask, sampler_ClearCoatSmoothnessMask, uv);
    surfaceInput.clearCoatSmoothness = clearCoatSmoothnessMaskSample.r * _ClearCoatSmoothness;

    // Debug view (use Unity's Rendering Debugger instead)
    //return float4((normalWS + 1) * 0.5, 1); // normal -> -1 to 1. We remap to a range of 0 to 1.
    
    // Calculate PBR Lighting (supports Rendring Debugger)
    return UniversalFragmentPBR(lightingInput, surfaceInput);
}

#endif