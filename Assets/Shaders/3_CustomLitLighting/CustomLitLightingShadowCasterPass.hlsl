// This file contains the vertex and fragment functions for the ShadowCaster pass
// This is the shader pass that computes the shadow map
#ifndef SHADER_CUSTOMLITLIGHTING_SHADOWCASTER_PASS
#define SHADER_CUSTOMLITLIGHTING_SHADOWCASTER_PASS

// Pull in URP library functions and our own common functions
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// This attributes struct receives data about the mesh we're currently rendering
// Data is automatically placed in fields according to their semantic
struct Attributes
{
    float3 positionOS : POSITION; // Position in object space (equivalent to "local space" in the Unity's scene editor)
    float3 normalOS : NORMAL;
};

struct Interpolators 
{
    // This value should contain the position in clip space (which is similar to a position on screen)
    // when output from the vertex function. It will be transformed into pixel position of the current
    // fragment on the current when read from the fragment function
    float4 positionCS : SV_POSITION;
};

// /!\ Shadow Acne artifact            
// We need to apply a bias or an offset to the shadowcaster vertex positions
// When calculating clip space positions, there's no rule that they must exactly match the mesh.
// We can offset the positions away from the light AND also along the mesh's normals
// Both of these biases should help avoid shadow acne.
float3 _LightDirection;

float4 GetShadowCasterPositionCS(float3 positionWS, float3 normalWS) 
{
    float3 lightDirectionWS = _LightDirection;
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
    return output;
}


float4 Fragment(Interpolators input) : SV_TARGET 
{
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
    return 0;
}

#endif