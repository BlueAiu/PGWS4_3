Shader "Custom/Shader_12_CookTorrance"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _Fresnel0("Fresnel0", Color) = (0.8, 0.8, 0.8, 1)
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
                half4 _Fresnel0;
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

                half alpha2 = _Roughness * _Roughness * _Roughness * _Roughness;
                float D = exp(-(1 - HdotN * HdotN)/(HdotN * HdotN * alpha2))
                    / (4 * alpha2 * HdotN * HdotN * HdotN * HdotN);
                    
                half G = min(1, 2 * min(HdotN * VdotN / VdotH, HdotN * LdotN / LdotH));
                half4 F = _Fresnel0 + (1-_Fresnel0) * exp(-6 * VdotH); // FarCry3 approximation
                half3 brdf = _BaseColor * D * G * F / (4 * LdotN * VdotH);
                
                half3 color = light.color * LdotN * brdf;
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}