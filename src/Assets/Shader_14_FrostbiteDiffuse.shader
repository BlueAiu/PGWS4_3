Shader "Custom/Shader_14_FrostbiteDiffuse"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _Roughness("Roughness", Range(0.000001, 1)) = 0.4
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normal : NORMAL;
                float3 position : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half _Roughness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.position = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half Fresnel (half f0, half f90, float co)
            {
                return f0 + (f90-f0) * pow(1 - co, 5);
            }

            half3 Fr_DisneyDiffuse (half3 albedo, half LdotN, half VdotN, half LdotH, half linearRoughness)
            {
                half energyBias = lerp(0.0, 0.5, linearRoughness);
                half energyFactor = lerp(1.0, 1.0/1.51, linearRoughness);
                half Fd90 = energyBias + 2.0 * LdotH * LdotH * linearRoughness;
                half FL = Fresnel(1, Fd90, LdotN);
                half FV = Fresnel(1, Fd90, VdotN);
                return (albedo * FL * FV * energyFactor);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                static const half epsilon = 0.000001;

                Light light = GetMainLight();
                half3 normal = normalize(IN.normal);
                half3 view_direction = normalize(TransformViewToWorld(float3(0,0,0)) - IN.position);
                float3 half_vector = normalize(view_direction + light.direction);
                half VdotN = max(epsilon, dot(view_direction, normal));
                half LdotN = max(epsilon, dot(light.direction, normal));
                half HdotN = max(epsilon, dot(half_vector, normal));
                half LdotH = max(0, dot(light.direction, half_vector));
                half VdotH = max(0, dot(view_direction, half_vector));

                
                
                half3 color = light.color * LdotN 
                    * Fr_DisneyDiffuse(_BaseColor, LdotN, VdotN, LdotH, _Roughness * _Roughness) / PI;
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}