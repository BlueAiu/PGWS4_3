Shader "Custom/Shader_16_MyShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
        _Emission("Emission", Color) = (0, 0, 0, 0)
        _Fresnel0("Fresnel0", Color) = (1, 1, 1, 1)
        _RoughnessX("Roughness X", Range(0, 1)) = 0.8
        _RoughnessY("Roughness Y", Range(0, 1)) = 0.2
        _Metallic("Metallic", Range(0, 1)) = 0.6
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
                float4 tangent : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float3 position : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _SpecularColor;
                half4 _Emission;
                half4 _Fresnel0;
                half _RoughnessX;
                half _RoughnessY;
                half _Metallic;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.tangent = float4(TransformObjectToWorldNormal(float3(IN.tangent.xyz)).xyz, IN.tangent.w);
                OUT.position = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half FresnelReflecttanceAverageDielectric(float co, float f0, float f90)
            {
                co = min(0.9999, max(0.000001, co));

                float root_f0 = sqrt(f0);
                float root_f90 = sqrt(f90);
                float n = (root_f90 + root_f0) / (root_f90 - root_f0);
                float n2 = n * n;

                float si2 = 1 - co * co;
                float nb = sqrt(n2 - si2);
                float bn = nb / si2;

                float r_s = (co - nb) / (co + nb);
                float r_p = (co - bn) / (co + bn);
                return 0.5 * f90 * (r_s * r_s + r_p * r_p);
            }

            half4 Fresnel (half4 f0, half f90, float co)
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

            float V_SnithGGXCorrelated(float NdotL, float NdotV, float alphaG2)
            {
                // hogehoge

                float Lambda_GGXV = NdotL * sqrt((-NdotV * alphaG2 + NdotV) * NdotV + alphaG2);
                float Lambda_GGXL = NdotV * sqrt((-NdotL * alphaG2 + NdotL) * NdotL + alphaG2);
                return 0.5f / (Lambda_GGXV + Lambda_GGXL);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                static const half epsilon = 0.000001;

                Light light = GetMainLight();
                half3 normal = normalize(IN.normal);
                half3 binormal = normalize(cross(normal, IN.tangent.xyz) * IN.tangent.w);
                half3 tangent = cross(binormal, normal) * IN.tangent.w;
                half3 view_direction = normalize(TransformViewToWorld(float3(0,0,0)) - IN.position);
                float3 half_vector = normalize(view_direction + light.direction);
                half VdotN = max(epsilon, dot(view_direction, normal));
                half LdotN = max(epsilon, dot(light.direction, normal));
                half HdotN = max(epsilon, dot(half_vector, normal));
                half LdotH = max(0, dot(light.direction, half_vector));
                half VdotH = max(0, dot(view_direction, half_vector));
                
                half alphaX = _RoughnessX * _RoughnessX;
                half alphaY = _RoughnessY * _RoughnessY;
                half XdotH = dot(tangent, half_vector);
                half YdotH = dot(binormal, half_vector);
                half c = (XdotH*XdotH / (alphaX*alphaX) + YdotH*YdotH / (alphaY+alphaY)) / (HdotN*HdotN);

                half alpha = alphaX * alphaY;
                half3 diffuse = Fr_DisneyDiffuse(_BaseColor, LdotN, VdotN, LdotH, alpha) / PI;

                half alpha2 = alpha * alpha;
                float D = exp(-c) / sqrt(LdotN * VdotN) / (4 * PI * alphaX * alphaY); // alpha2 / (PI * pow(HdotN * HdotN * (alpha2 - 1.0) + 1.0, 2.0)); // ハイライト
                half G = V_SnithGGXCorrelated(LdotN, VdotN, alpha2); // 幾何減衰
                half4 F = Fresnel(_Fresnel0, 1, VdotH); // 反射光
                half3 specular = saturate(_SpecularColor * D * G * F / (4 * LdotN * VdotN));
                
                half3 color = light.color * LdotN * lerp(diffuse, specular, _Metallic);
                color += _Emission;
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}