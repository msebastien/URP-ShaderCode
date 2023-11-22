// This file contains the vertex and fragment functions for the ShadowCaster pass
// This is the shader pass that computes the shadow map
#ifndef SHADER_CUSTOMLITTRANSPARENCY_SHADOWCASTER_PASS
#define SHADER_CUSTOMLITTRANSPARENCY_SHADOWCASTER_PASS

// Pull in URP library functions and our own common functions
#include "CustomLitTransparencyCommon.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// This attributes struct receives data about the mesh we're currently rendering
// Data is automatically placed in fields according to their semantic
struct Attributes
{
    float3 positionOS : POSITION; // Position in object space (equivalent to "local space" in the Unity's scene editor)
    float3 normalOS : NORMAL;
#ifdef _ALPHA_CUTOUT
    float2 uv : TEXCOORD0; // Material texture UVs (texture coordinates set n°0)
#endif
};

struct Interpolators 
{
    // This value should contain the position in clip space (which is similar to a position on screen)
    // when output from the vertex function. It will be transformed into pixel position of the current
    // fragment on the current when read from the fragment function
    float4 positionCS : SV_POSITION;
#ifdef _ALPHA_CUTOUT
    float2 uv : TEXCOORD0; // Material texture UVs
#endif
};

// Flip normal vector if the angle between the view direction and the normal vector
// is greater than 90 degrees (which means the cosine/dot product is less than zero)
// Otherwise, if it is less than 90 degress (cosine/dot product is greater than zero), don't flip it.
float3 FlipNormalBasedOnViewDir(float3 normalWS, float3 positionWS) 
{
    float3 viewDirWS = GetWorldSpaceNormalizeViewDir(positionWS);
    return normalWS * (dot(normalWS, viewDirWS) < 0 ? -1 : 1);
}

// /!\ Shadow Acne artifact            
// We need to apply a bias or an offset to the shadowcaster vertex positions
// When calculating clip space positions, there's no rule that they must exactly match the mesh.
// We can offset the positions away from the light AND also along the mesh's normals
// Both of these biases should help avoid shadow acne.
float3 _LightDirection;

float4 GetShadowCasterPositionCS(float3 positionWS, float3 normalWS) 
{
    float3 lightDirectionWS = _LightDirection;

#ifdef _DOUBLE_SIDED_NORMALS
    // Flip normal to prevent shadow acne for back face lighting
    normalWS = FlipNormalBasedOnViewDir(normalWS, positionWS);
#endif

    // Apply bias in world space position. Then, transform to clip space.
    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

    // Clip space has depth boundaries. 
    // If we accidentally overstep them when applying a bias, the shadow could disappear or flicker.
    // The boundary to depth is defined by "light near clip plane".
    // Clamp the clip space z coordinate by the near plane value defined by this constant.
#if UNITY_REVERSED_Z // Certain graphics API reverse the clip space Z axis
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE); // Minimum 
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE); // Maximum
#endif
    
    return positionCS;
}


Interpolators Vertex(Attributes input)
{
    Interpolators output;

    VertexPositionInputs posnInputs = GetVertexPositionInputs(input.positionOS);
    VertexNormalInputs normInputs = GetVertexNormalInputs(input.normalOS);
    
    // Pass position data in clip space to the fragment function
    output.positionCS = GetShadowCasterPositionCS(posnInputs.positionWS, normInputs.normalWS); // float4
#ifdef _ALPHA_CUTOUT
    output.uv = TRANSFORM_TEX(input.uv, _ColorMap); // Make sure texture tiling/scale&offset is applied correctly
#endif
    return output;
}

// - The shadow map encode distance from the light camera, but the renderer handles it automatically.
// So, we have to do nothing here. The renderer just needs the position of fragments in the clip space.
// - Clip Space positions encode "Depth", which is related to distance from the camera.
// - When interpolating, the rasterizer stores the depth of each fragment 
// in a data structure called the "Depth Buffer".
// - Unity uses the Depth Buffer to reduce "Overdraw". It happens when
// 2 or more fragments with the same pixel position are rendered during the same frame.
// When everything is opaque, only the closer fragment is ultimately displayed.
// Any other fragments are discarded leading to wasted work. The rasterizer can
// avoid callling a fragment function if its depth is greater than the stored value in the depth buffer.

// URP reuses the Depth Buffer resulting from the ShadowCaster pass as the "Shadow Map".
// But most of the passes have a depth buffer of their own as well.

float4 Fragment(Interpolators input) : SV_TARGET 
{
    // Clip shadow
#ifdef _ALPHA_CUTOUT
    float2 uv = input.uv;
    float4 colorSample = SAMPLE_TEXTURE2D(_ColorMap, sampler_ColorMap, uv);   
    TestAlphaClip(colorSample);
#endif

    return 0;
}

#endif