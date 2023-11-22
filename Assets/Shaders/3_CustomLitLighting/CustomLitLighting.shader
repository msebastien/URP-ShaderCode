Shader "Sebastien/CustomLitLighting" 
{
    // Properties are options set per material, exposed by the material inspector
    // Docs: https://docs.unity3d.com/Manual/SL-PropertiesInPrograms.html
    Properties 
    {
        [Header(Surface options)] // Creates a text header
        // [MainTexture] and [MainColor] allow Material.mainTexture and Material.color to use the correct properties
        [MainTexture] _ColorMap("Color", 2D) = "white" {}
        [MainColor] _ColorTint("Tint", Color) = (1, 1, 1, 1)
        _Smoothness("Smoothness", Float) = 0
    }

    // Subshaders allow for different behaviour and options for different pipelines and platforms
    SubShader 
    {
        // These tags are shared by all passes in this sub shader
        Tags{"RenderPipeline" = "UniversalPipeline"}
        
        // Shaders can have several passes which are used to render different data about the material
        // Each pass has its own vertex and fragment function and shader variant keywords
        
        // Forward Lit Pass: Calculate the final pixel color
        Pass 
        {
            Name "ForwardLit" // For debugging
            Tags{"LightMode" = "UniversalForward"} // Pass-specific tags
            // "UniversalForward" tells Unity this is the main lighting pass of this shader
            
            HLSLPROGRAM // Begin HLSL code
            
            // enable specular lighting
            #define _SPECULAR_COLOR 

            // Compile variants of the current render pass (ForwardLit) WITH and WITHOUT main light shadows enabled.
            // Avoids the need to create a different shader with a render pass that disables them.
            // #pragma multi_compile _ KEYWORD_A KEYWORD_B
            // It will compile a variant for each enabled keyword.
            // By specifying an underscore in front of keywords, it will also compile a variant with all of the keywords disabled.
#if UNITY_VERSION >= 202120
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
#else
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#endif
            // Save a bit of compile time by signaling that the "_SHADOWS_SOFT" keyword is only used in the fragment stage
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            
            // Register our programmable stage functions
            #pragma vertex Vertex
            #pragma fragment Fragment

            // Include our code file
            #include "CustomLitLightingForwardLitPass.hlsl"
            ENDHLSL
        }

        // ShadowCaster Pass: Calculates data for the shadow map in order to cast shadows on other objects
        Pass 
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            // Optimization : Since the ShadowCaster only uses the Depth Buffer,
            // we can turn off color using the ColorMask command
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "CustomLitLightingShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}
