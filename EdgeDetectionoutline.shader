Shader "URPCustom/OutlineDetection"
{
    Properties
    {
        _BaseMap("Base Texture",2D) = "white"{}
        _OutlineThickness("Thickness",Range(0,1)) = 1
        _DepthSensitivity("DepthSensitiviy",Range(0,100)) = 0.3
        _NormalsSensitivity("NormalsSensitivity",Range(0,100)) = 0.3
        _ColorSensitivity("ColorSensitivity",Range(0,100)) = 0.3
        _OutlineColor("OutlineColor",Color) = (0,0,0,1)
    }
        SubShader
        {
            Tags
            {
                "RenderPipeline" = "UniversalPipeline"//这是一个URP Shader！
                "Queue" = "Geometry"
                "RenderType" = "Opaque"
            }
            HLSLINCLUDE
            //CG中核心代码库 #include "UnityCG.cginc"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

           //除了贴图外，要暴露在Inspector面板上的变量都需要缓存到CBUFFER中
           CBUFFER_START(UnityPerMaterial)
          float4 _BaseMap_ST;
        float _OutlineThickness;
        float _DepthSensitivity;
        float _NormalsSensitivity;
        float _ColorSensitivity;
        float _OutlineColor;
        float4 _CameraColorTexture_TexelSize;

        CBUFFER_END

        TEXTURE2D(_CameraColorTexture);//Camera的主图
        SAMPLER(sampler_CameraColorTexture);
        //像素大小


         TEXTURE2D(_CameraDepthTexture);
         SAMPLER(sampler_CameraDepthTexture);

         TEXTURE2D(_CameraDepthNormalsTexture);
         SAMPLER(sampler_CameraDepthNormalsTexture);
         float3 DecodeNormal(float4 enc) {
             float kScale = 1.777;
             float3 nn = enc.xyz * float3(2 * kScale, 2 * kScale, 0) + float3(-kScale, -kScale, 1);
             float g = 2.0 / dot(nn.xyz, nn.xyz);
             float3 n;
             n.xy = g * nn.xy;
             n.z = g - 1;
             return n;
         }


         void Outline_float(float2 UV, float OutlineThickness, float DepthSensitivity, float NormalsSensitivity, float ColorSensitivity, float4 OutlineColor, out float4 Out) {
             float halfScaleFloor = floor(OutlineThickness * 0.5);
             float halfScaleCeil = ceil(OutlineThickness * 0.5);
             float2 Texel = (1.0) / float2(_CameraColorTexture_TexelSize.z, _CameraColorTexture_TexelSize.w);
             float2 uvSamples[4];
             float depthSamples[4];
             float3 normalSamples[4], colorSamples[4];

             //根据像素大小缩放偏移的UV量
             uvSamples[0] = UV - float2(Texel.x, Texel.y) * halfScaleFloor;
             uvSamples[1] = UV + float2(Texel.x, Texel.y) * halfScaleCeil;
             uvSamples[2] = UV + float2(Texel.x * halfScaleCeil, -Texel.y * halfScaleFloor);
             uvSamples[3] = UV + float2(-Texel.x * halfScaleFloor, Texel.y * halfScaleCeil);


        

             for (int i = 0; i < 4; i++) {
                 depthSamples[i] = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[i]).r;
                 normalSamples[i] = DecodeNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uvSamples[i]));
                 colorSamples[i] = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[i]);

             }


             //DEPTH
             float depthFiniteDifference0 = depthSamples[1] - depthSamples[0];
             float depthFiniteDifference1 = depthSamples[3] - depthSamples[2];
             float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2)) * 100;
             float depthThreshold = (1 / DepthSensitivity) * depthSamples[0];
             edgeDepth = edgeDepth > depthThreshold ? 1 : 0;


             //Normals
             float3 normalFiniteDifference0 = normalSamples[1] - normalSamples[0];
             float3 normalFiniteDifference1 = normalSamples[3] - normalSamples[2];
             float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
             edgeNormal = edgeNormal > (1 / NormalsSensitivity) ? 1 : 0;

             //Color
             float3 colorFiniteDifference0 = colorSamples[1] - colorSamples[0];
             float3 colorFiniteDifference1 = colorSamples[3] - colorSamples[2];
             float edgeColor = sqrt(dot(colorFiniteDifference0, colorFiniteDifference0) + dot(colorFiniteDifference1, colorFiniteDifference1));
             edgeColor = edgeColor > (1 / ColorSensitivity) ? 1 : 0;

             float edge = max(edgeDepth, max(edgeNormal, edgeColor));

             float4 original = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[0]);

             Out = float4(edge, edge, edge,1);
             
             Out = ((1 - edge) * original) + edge *OutlineColor;



         }

             ENDHLSL






            Pass
            {
                Tags{"LightMode" = "UniversalForward"}
                HLSLPROGRAM //CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                struct Attributes//这就是a2v
                {
                    float4 positionOS : POSITION;
                    float2 uv : TEXCOORD;
                };
                struct Varings//这就是v2f
                {
                    float4 positionCS : SV_POSITION;
                    float2 uv : TEXCOORD;
                };



                Varings vert(Attributes IN)
                {
                    Varings OUT;
                    VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                    OUT.positionCS = positionInputs.positionCS;

                    OUT.uv = IN.uv;
                    return OUT;
                }

                float4 frag(Varings IN) :SV_Target
                {
                    float4 Out;
                   Outline_float(IN.uv,_OutlineThickness,_DepthSensitivity,_NormalsSensitivity,_ColorSensitivity,_OutlineColor,Out);
                   return Out;
                }
                ENDHLSL  //ENDCG          
            }
        }
}
