Shader "Sebastien/CustomLitTransparency" 
{
    // Properties are options set per material, exposed by the material inspector
    // Docs: https://docs.unity3d.com/Manual/SL-PropertiesInPrograms.html
    Properties 
    {
        [Header(Surface options)] // Creates a text header
        // [MainTexture] and [MainColor] allow Material.mainTexture and Material.color to use the correct properties
        [MainTexture] _ColorMap("Color", 2D) = "white" {}
        [MainColor] _ColorTint("Tint", Color) = (1, 1, 1, 1)
        _Cutoff("Alpha Cutout threshold", Range(0, 1)) = 0.5
        _Smoothness("Smoothness", Float) = 0

        // Shader Metadata
        //[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull mode", Float) = 2
        [HideInInspector] _Cull("Cull mode", Float) = 2

        [HideInInspector] _SourceBlend("Source blend", Float) = 0
        [HideInInspector] _DestBlend("Destination Blend", Float) = 0
        [HideInInspector] _ZWrite("ZWrite", Float) = 0
        
        [HideInInspector] _SurfaceType("Surface type", Float) = 0
        [HideInInspector] _FaceRenderingMode("Face rendering mode", Float) = 0
    }

    // Subshaders allow for different behaviour and options for different pipelines and platforms
    SubShader 
    {
        // These tags are shared by all passes in this sub shader
        Tags{
                "RenderPipeline" = "UniversalPipeline"
                "RenderType" = "Opaque"
                //"RenderType" = "Transparent"
                //"Queue" = "Transparent"
            }
        
        // Shaders can have several passes which are used to render different data about the material
        // Each pass has its own vertex and fragment function and shader variant keywords
        
        // Forward Lit Pass: Calculate the final pixel color
        Pass 
        {
            Name "ForwardLit" // For debugging
            Tags{"LightMode" = "UniversalForward"} // Pass-specific tags
            // "UniversalForward" tells Unity this is the main lighting pass of this shader
            
            // Transparency
            // This Blend command determines how the rasterizer combines fragment function outputs with colors already present on the screen.
            // The color returned by the fragment function is called the "Source color" while the color stored on the render target is called the "Destination color".
            // The rasterizer multiplies each color by some numbers and adds the products together storing the result in the render target overriding what was already there.
            // Command: Blend {Source color multiplier} {Destination color multiplier}
            // Source * Destination = Result
            // Source=1, Destination=0 => Result=0 (Fully Opaque, by default)
            // For transparency, we need to linearly interpolate between the source and destination colors based on the source colors alpha
            ///Blend SrcAlpha OneMinusSrcAlpha
            Blend[_SourceBlend][_DestBlend]

            // Transparent objects don't always blend with objects behind them
            // The rasterizer stores transparent object positions in the depth buffer preventing fragments behind them from ever running.
            // We can't blend colors with a material that was never drawn.
            // We need a way to prevent transparent surfaces from being stored in the depth buffer.
            // This command prevents the rasterizer from storing any of the pass data in the depth buffer.
            ///ZWrite Off
            ZWrite[_ZWrite]

            // Face Culling (Off, Front, Back)
            Cull[_Cull]

            HLSLPROGRAM // Begin HLSL code
            
            // enable specular lighting
            #define _SPECULAR_COLOR
            
            // Specify a shader variant with alpha cutout enabled
            // Shader features are just like multi-compiles in that they generate shader variants
            // based on a list of keywords. The difference comes in game builds.
            // When we build a game or create a distributable, Unity must determine which compiled shader variants to include in the build.
            // It gathers all shaders used by the game and starts filtering shader variants.
            // Unity includes all variants generated by multi-compile commands 
            // but before including a shader feature variant, it checks to make sure that some material in the game has the required keywords enabled
            // ==> Example : shader_feature _ _ALPHA_CUTOUT _ALPHA_SUPER
            // - variant with no keyword ? Included! Opaque materials
            // - variant with _ALPHA_CUTOUT ? Included! Alpha test materials
            // - variant with _ALPHA_SUPER ? Not Included! No material use this.
            // /!\ Since this check happens at build time, keywords that change dynamically at runtime,
            // like the URP lighting keywords, should use "multi-compile". Shader variants are not cheap to compile and shader features help to optimize build time.
            // Also, Shader features always have an implicit underscore in their keywords list! 
            // In other words, they always trigger a variant with none of the listed keywords enabled.
            // Finally, the "local" suffix indicates that the keyword is unique to this shader and will not be set globally.
            // We set alpha cutout on a material by material basis so it can use local variants.
            #pragma shader_feature_local _ALPHA_CUTOUT

            // Enable Normal flipping based on view dir when culling is disabled to fix lighting
            #pragma shader_feature_local _DOUBLE_SIDED_NORMALS 

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
            #include "CustomLitTransparencyForwardLitPass.hlsl"
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

            // Face Culling (Off, Front, Back)
            Cull[_Cull]

            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment

            // Enable clipping shadows when using transparent objects with alpha cutout
            #pragma shader_feature_local _ALPHA_CUTOUT

            // Enable Normal flipping based on view dir when culling is disabled to fix shadow acne
            #pragma shader_feature_local _DOUBLE_SIDED_NORMALS 

            #include "CustomLitTransparencyShadowCasterPass.hlsl"
            ENDHLSL
        }
    }

    CustomEditor "CustomLitTransparencyCustomInspector"
}
