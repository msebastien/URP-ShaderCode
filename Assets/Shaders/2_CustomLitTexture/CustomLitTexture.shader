Shader "Sebastien/CustomLitTexture" 
{
    // Properties are options set per material, exposed by the material inspector
    // Docs: https://docs.unity3d.com/Manual/SL-PropertiesInPrograms.html
    Properties 
    {
        [Header(Surface options)] // Creates a text header
        // [MainTexture] and [MainColor] allow Material.mainTexture and Material.color to use the correct properties
        [MainTexture] _ColorMap("Color", 2D) = "white" {}
        [MainColor] _ColorTint("Tint", Color) = (1, 1, 1, 1)
    }

    // Subshaders allow for different behaviour and options for different pipelines and platforms
    SubShader 
    {
        // These tags are shared by all passes in this sub shader
        Tags{"RenderPipeline" = "UniversalPipeline"}
        
        // Shaders can have several passes which are used to render different data about the material
        // Each pass has its own vertex and fragment function and shader variant keywords
        Pass 
        {
            Name "ForwardLit" // For debugging
            Tags{"LightMode" = "UniversalForward"} // Pass-specific tags
            // "UniversalForward" tells Unity this is the main lighting pass of this shader
            
            HLSLPROGRAM // Begin HLSL code
            // Register our programmable stage functions
            #pragma vertex Vertex
            #pragma fragment Fragment

            // Include our code file
            #include "CustomLitTextureForwardLitPass.hlsl"
            ENDHLSL
        }
    }
}
