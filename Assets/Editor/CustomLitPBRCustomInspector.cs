using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public class CustomLitPBRCustomInspector : ShaderGUI
{
    public enum SurfaceType
    {
        Opaque, TransparentBlend, TransparentCutout
    }

    // Back face culling, No Culling, No Culling with Normal Flipping 
    public enum FaceRenderingMode
    {
        FrontOnly, NoCulling, DoubleSided
    }

    // Support for Extra Transparency modes : Additive, Multiply and Pre-multipled
    // Additive and Multiply modes are very useful for particles
    // While Pre-multiplied mode helps simulate glass
    public enum BlendType
    {
        Alpha, Premultiplied, Additive, Multiply
    }

    public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
    {
        base.AssignNewShaderToMaterial(material, oldShader, newShader);

        if (newShader.name.StartsWith("Sebastien/CustomLitPBR") && 
            (newShader.FindPropertyIndex("_SurfaceType") != -1 || newShader.FindPropertyIndex("_FaceRenderingMode") != -1))
        {
            UpdateSurfaceType(material);
        }
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material material = materialEditor.target as Material;
        var surfaceProp = BaseShaderGUI.FindProperty("_SurfaceType", properties, true);
        var blendProp = BaseShaderGUI.FindProperty("_BlendType", properties, true);
        var faceProp = BaseShaderGUI.FindProperty("_FaceRenderingMode", properties, true);

        EditorGUI.BeginChangeCheck();
        
        surfaceProp.floatValue = (int)(SurfaceType)EditorGUILayout.EnumPopup("Surface type", (SurfaceType)surfaceProp.floatValue);
        blendProp.floatValue = (int)(BlendType)EditorGUILayout.EnumPopup("Blend type", (BlendType)blendProp.floatValue);
        faceProp.floatValue = (int)(FaceRenderingMode)EditorGUILayout.EnumPopup("Face rendering mode", (FaceRenderingMode)faceProp.floatValue);
        base.OnGUI(materialEditor, properties);

        if (EditorGUI.EndChangeCheck())
        {
            UpdateSurfaceType(material);
        }

    }

    private void UpdateSurfaceType(Material material) 
    {
        SurfaceType surface = (SurfaceType)material.GetFloat("_SurfaceType");
        
        switch(surface)
        {
            case SurfaceType.Opaque:
                material.renderQueue = (int)RenderQueue.Geometry;
                material.SetOverrideTag("RenderType", "Opaque");
                break;

            case SurfaceType.TransparentCutout:
                material.renderQueue = (int)RenderQueue.AlphaTest;
                material.SetOverrideTag("RenderType", "TransparentCutout");
                break;

            case SurfaceType.TransparentBlend:
                material.renderQueue = (int)RenderQueue.Transparent;
                material.SetOverrideTag("RenderType", "Transparent");
                break;
        }

        BlendType blend = (BlendType)material.GetFloat("_BlendType");
        switch (surface)
        {
            case SurfaceType.Opaque:
            case SurfaceType.TransparentCutout:
                material.SetInt("_SourceBlend", (int)BlendMode.One);
                material.SetInt("_DestBlend", (int)BlendMode.Zero);
                material.SetInt("_ZWrite", 1); // enable depth map
                break;

            case SurfaceType.TransparentBlend:
                // Blend type
                switch(blend)
                {
                    // Like we're used to, we're blending using the alpha value of the source pixel
                    // source alpha * source color + (1 - source alpha) * destination color
                    case BlendType.Alpha:
                        material.SetInt("_SourceBlend", (int)BlendMode.SrcAlpha);
                        material.SetInt("_DestBlend", (int)BlendMode.OneMinusSrcAlpha);
                        break;
                    // Pre-multiplied mode assumes Alpha has already been multiplied with the color
                    // and stored in a texture RGB values. So the source multiplier should be one so alpha is not applied to the source color.
                    // This gives artists better control on how a transparent object looks.
                    // URP further enhances the pre-multiplied mode by having lighting affect the material's alpha
                    // which is wonderful for glass where specular highlights appear opaque
                    // 1 * source color + (1 - alpha source) * destination color
                    case BlendType.Premultiplied:
                        material.SetInt("_SourceBlend", (int)BlendMode.One);
                        material.SetInt("_DestBlend", (int)BlendMode.OneMinusSrcAlpha);
                        break;
                    // Additive mode is mathematically the inverse of pre-multiplied mode
                    // The source is affected by alpha but the destination is not.
                    // This is great for particle effects like lightning and fire
                    // source alpha * source color + 1 * destination color
                    case BlendType.Additive:
                        material.SetInt("_SourceBlend", (int)BlendMode.SrcAlpha);
                        material.SetInt("_DestBlend", (int)BlendMode.One);
                        break;
                    // Multiply mode is for specialized use.
                    // It completely ignores alpha. It just multiplies the source and destination color together.
                    // It tends to darken the scene, sometimes useful for otherwordly effects and masking
                    // 0 * source color + source color * destination color
                    case BlendType.Multiply:
                        material.SetInt("_SourceBlend", (int)BlendMode.Zero);
                        material.SetInt("_DestBlend", (int)BlendMode.SrcColor);
                        break;
                }
                
                // Disable depth map
                material.SetInt("_ZWrite", 0);
                break;
        }

        // Blend: URP Lighting affect alpha
        if(surface == SurfaceType.TransparentBlend &&  blend == BlendType.Premultiplied)
        {
            material.EnableKeyword("_ALPHAPREMULTIPLY_ON");
        }
        else
        {
            material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
        }

        // Disable shadow pass because partial shadows with transparent objects without cutout and alpha test
        material.SetShaderPassEnabled("ShadowCaster", surface != SurfaceType.TransparentBlend);

        if(surface == SurfaceType.TransparentCutout)
            material.EnableKeyword("_ALPHA_CUTOUT");
        else
            material.DisableKeyword("_ALPHA_CUTOUT");

        // Face Rendering

        FaceRenderingMode faceRenderingMode = (FaceRenderingMode)material.GetFloat("_FaceRenderingMode");
        if(faceRenderingMode == FaceRenderingMode.FrontOnly)
        {
            material.SetInt("_Cull", (int)UnityEngine.Rendering.CullMode.Back); // Render only front face
        } 
        else
        {
            material.SetInt("_Cull", (int)UnityEngine.Rendering.CullMode.Off); // Render front and back face
        }

        if(faceRenderingMode == FaceRenderingMode.DoubleSided)
        {
            material.EnableKeyword("_DOUBLE_SIDED_NORMALS"); // flip normals based on view dir when culling is disabled
        }
        else
        {
            material.DisableKeyword("_DOUBLE_SIDED_NORMALS"); // don't flip normals
        }

        // Enable/Disable Normal mapping
        if(material.GetTexture("_NormalMap") == null)
        {
            material.DisableKeyword("_NORMALMAP");
        } 
        else
        {
            material.EnableKeyword("_NORMALMAP");
        }
    }   
}
