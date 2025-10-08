Shader "Custom/Shader_10_G"
{
    Properties
    {
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
                Light light = GetMainLight();
                half3 normal = normalize(IN.normal);
                half3 view_direction = normalize(TransformViewToWorld(float3(0,0,0)) - IN.position);
                float3 half_vector = normalize(view_direction + light.direction);
                half VdotN = max(0, dot(view_direction, normal));
                half LdotN = max(0, dot(light.direction, normal));
                half HdotN = max(0, dot(half_vector, normal));
                half LdotH = max(0, dot(light.direction, half_vector));
                half VdotH = max(0, dot(view_direction, half_vector));

                half G = min(1, 2 * min(HdotN * VdotN / VdotH, HdotN * LdotN / LdotH));
                half3 color = G;
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
