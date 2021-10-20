Shader "URP/Toon/ToonShader"

{

	Properties

	{
		 [KeywordEnum(ON,OFF)] _IS_FACE("isFace",float) = 0 
		_MainTex("MainTex",2D) = "White"{}

		_BaseColor("BaseColor",Color) = (1,1,1,1)
		_ShadowColor("ShadowColor",Color) = (0.7,0.7,0.8,1)
		_ShadowRange("ShadowRange",Range(0,1)) = 0.5
		_ShadowSmooth("ShadowSmooth",Range(0,1)) = 0.05

		_OutLineWidth("OutLineWidth",Range(0.01,2)) = 0.24
		_OutLineColor("OutLineColor",Color) = (0.5,0.5,0.5,1)
		_Glossiness("Glossiness",Range(0,10) )=2
	    _SpecularColor("SpecularColor",Color) = (0.5,0.5,0.2)
	     _rampTex("rampTex",2D)= "white"{}

		//Rim
		_RimColor("RimColor",Color) = (1,0.9,1)
		_RimMin("RimMin",Range(0,1)) = 0.1
		_RimMax("RimMax",Range(0,1)) = 0.9
	   _RimBloomExp("RimBloomExp",Range(0,5)) = 0.9
	  _RimBloomMulti("RimBloomMulti",Range(0,2)) = 0.9
	   _FaceShadow("FaceShadowMap",2D) = "white"{}
		_shadowControl("ShadowControl",Range(0,2)) = 1.5

			//specular 


		_Roughness("Roughness",Range(0.001,1)) = 0.01
		_DividLineSpec("DividLineSpec",Range(0.001,1)) = 0.01

	   _BoundSharp("BoundSharp",Range(0.001,1)) = 0.01
			_speColor("speColor",Color) = (1,1,1)
			_speStrength("speStrength",Range(0,1)) = 0.4
	}

		SubShader

		{

			Tags{

			"RenderPipeline" = "UniversalRenderPipeline"

			"RenderType" = "Opaque"

			}

			HLSLINCLUDE

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			CBUFFER_START(UnityPerMaterial)

			float4 _MainTex_ST;
			half4 _BaseColor;
			half4 _ShadowColor;
			float _ShadowRange;
			float _ShadowSmooth;
			float _OutLineWidth;
			half4 _OutLineColor;
			float _Glossiness;
			half4 _SpecularColor;
			float4 _RimColor;
			float _RimMin;
			float _RimMax;
			float _RimSmooth;
			float _RimBloomExp;
			float _RimBloomMulti;
			float _shadowControll;
			float _Roughness;
			float _DividLineSpec;
			float _BoundSharp;
			half3 _speColor;
			float _speStrength;
			CBUFFER_END

			TEXTURE2D(_MainTex);
			TEXTURE2D(_rampTex);
			SAMPLER(sampler_rampTex);
			SAMPLER(sampler_MainTex);
			TEXTURE2D(_FaceShadow);
			SAMPLER(sampler_FaceShadow);

			 struct a2v

			 {

				 float4 positionOS:POSITION;

				 float4 normalOS:NORMAL;

				 float2 texcoord:TEXCOORD;

			 };

			 struct v2f

			 {

				 float4 positionCS:SV_POSITION;

				 float2 texcoord:TEXCOORD;
				 float3 normalWS:TEXCOORD1;
				 float3 positionWS:TEXCOORD2;
				 float3 headrightWS:TEXCOORD3;

			 };
			 real3 SH_IndirectionDiff(float3 normalWS)//漫反射

			 {

				 real4 SHCoefficients[7];

				 SHCoefficients[0] = unity_SHAr;

				 SHCoefficients[1] = unity_SHAg;

				 SHCoefficients[2] = unity_SHAb;

				 SHCoefficients[3] = unity_SHBr;

				 SHCoefficients[4] = unity_SHBg;

				 SHCoefficients[5] = unity_SHBb;

				 SHCoefficients[6] = unity_SHC;

				 float3 Color = SampleSH9(SHCoefficients, normalWS);

				 return max(0, Color);

			 }

			 float D_GGX_DIY(float a2, float NoH) {
				 float d = (NoH * a2 - NoH) * NoH + 1;
				 return a2 / (3.14159 * d * d);
			 }

			 float sigmoid(float x, float center, float sharp) {
				 float s;
				 s = 1 / (1 + pow(100000, (-3 * sharp * (x - center))));
				 return s;
			 }
			ENDHLSL
				
				
				
				pass
			{


				HLSLPROGRAM
				#pragma vertex VERT
				#pragma fragment FRAG

                #pragma shader_feature _IS_FACE_ON _IS_FACE_OFF

				#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
				#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
				#pragma multi_compile _ _SHADOWS_SOFT//  
			


				v2f VERT(a2v i)

				{
					v2f o;
					o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
					o.texcoord = TRANSFORM_TEX(i.texcoord,_MainTex);
					o.normalWS = TransformObjectToWorldNormal(i.normalOS);
					o.positionWS = TransformObjectToWorld(i.positionOS);
					o.headrightWS = TransformObjectToWorld(float3(1, 0, 0));
					return o;

				}

				half4 FRAG(v2f i) :SV_TARGET

				{
					half4 col = 1;
					
					half4 tex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord) * _BaseColor;
					
					half3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);
					half3 normalWS = normalize(i.normalWS);
					Light mainLight = GetMainLight();
					float3 mainLightDir = normalize(mainLight.direction);

#if _IS_FACE_OFF
					half halfLambert =(dot(normalWS, mainLightDir) * 0.5 + 0.5);
					
					
					half3 ramp2 = SAMPLE_TEXTURE2D(_rampTex, sampler_rampTex,float2(saturate(halfLambert - _ShadowRange),0.5));
					half ramp = smoothstep(0, _ShadowSmooth, halfLambert - _ShadowRange);
					//half3 diffuse = step(halfLambert, _ShadowRange) * _ShadowColor + step(_ShadowRange, halfLambert) * halfLambert;
					half3 diffuse = lerp( _ShadowColor, _BaseColor, ramp);
					diffuse *= tex;
					diffuse *= mainLight.color;

#endif
			       //边缘光
					half NdotL = max(0,dot(normalWS, mainLightDir));

					half f = 1.0 - saturate(dot(viewDirWS, normalWS));
					half rimBloom = pow(f, _RimBloomExp) * _RimBloomMulti * NdotL;
					half3 rimColor = f * _RimColor.rgb * _RimColor.a*mainLight.color* rimBloom;
					
			
					half rim = smoothstep(_RimMin, _RimMax, f);
					rim = smoothstep(0, _RimSmooth, rim);
					
					



#if _IS_FACE_ON
			     //face shadow
					
					half faceshadow = SAMPLE_TEXTURE2D(_FaceShadow, sampler_FaceShadow, i.texcoord);
					half faceshadowL = SAMPLE_TEXTURE2D(_FaceShadow, sampler_FaceShadow, float2(1 - i.texcoord.x, i.texcoord.y));
					float3 headRight = i.headrightWS;
					
					float RdotL = dot(headRight, mainLightDir);

					float angle = acos(RdotL);
					angle = angle / PI * 2;
					//angle = pow(angle, _shadowControll);

					if (RdotL <= 0 && 1 < angle <= 2) {
						 angle = angle - 1;
						//faceshadow = smoothstep(0, _ShadowSmooth, faceshadow - angle);

						faceshadow = faceshadowL > angle ? 1 : 0;
						
					}

				
					else if (RdotL > 0 && 0 < angle <= 1) {
						 angle = 1 - angle;
						faceshadow = faceshadow > angle ? 1 : 0;
						 
					}

					else {

					
						faceshadow = 0;
						
					}
			
					//half rampf = smoothstep(0, _ShadowSmooth, faceshadow-angle);
					//faceshadow = lerp(0, 1, rampf);
					half3 diffuse =lerp(_ShadowColor, _BaseColor, faceshadow);
					diffuse *= tex;
					diffuse *= mainLight.color;

#endif

					//specular
					half3 H = normalize(mainLightDir + viewDirWS);
					half NoH = dot(normalWS, H);
					half NDF0 = D_GGX_DIY(_Roughness * _Roughness, 1);
					half NDF_HBound = NDF0 * _DividLineSpec;
					half NDF = D_GGX_DIY(_Roughness * _Roughness, clamp(0, 1, NoH));

					half specularWin = sigmoid(NDF, NDF_HBound, _BoundSharp);

					half specular = specularWin * (NDF0 + NDF_HBound) / 2*_speStrength*_speColor;


					float4 finalColor = float4(rimColor + diffuse + specular,1);
			        return  finalColor;
			//return  float4(diffuse,1);

				}

				ENDHLSL

			}

			UsePass "Universal Render Pipeline/Lit/ShadowCaster" 

		}





}

