Shader"Raymarching/Menger"{
	Properties{
		_Radius("Radius", float) = 0.5
		_Color("Color", Color) = (0,1,0,1)
	}
	SubShader{
		Tags{
			"RenderType" = "Transparent"
			"Queue" = "Transparent"
			"LightMode" = "ForwardBase"
		}
		Pass{
			Cull Off
			//ZWrite On
			//ZTest LEqual
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
	
			#include "UnityCG.cginc"
	
			float _Radius;
			float4 _Color;
	
			#define STEPS 128
			#define INF 100000000

			struct appdata {
				float4 vertex : POSITION;
			};

			struct ray {
				float3 org;
				float3 dir;
			};

			struct v2f {
				float4 vertex : SV_POSITION;
				float3 pos : TEXCOORD0;
				float3 wPos : TEXCOORD1; // World Position
			};

			struct frag_out
			{
				fixed4 color : SV_Target;
				float depth : SV_Depth;
			};

			v2f vert(appdata v) {
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.pos = v.vertex.xyz;
				o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
			}

			float max3(float3 p) {
				return max(p.x, max(p.y, p.z));
			}
			float min3(float3 p) {
				return min(p.x, min(p.y, p.z));
			}

			float2 rotate(float2 pos, float rad)
			{
				return float2(cos(rad)*pos.x - sin(rad)*pos.y, sin(rad)*pos.x + cos(rad)*pos.y);
			}

			float cross(float3 pos) {
				float3 cube = max3(abs(pos) - (float3).5);
				float barx = max(abs(pos.y) - 1. / 6., abs(pos.z) - 1. / 6.);
				float bary = max(abs(pos.z) - 1. / 6., abs(pos.x) - 1. / 6.);
				float barz = max(abs(pos.x) - 1. / 6., abs(pos.y) - 1. / 6.);
				//if (max3(abs(pos)) > .6) return cube;
				return min(barx, min(bary, barz));
				//return barx;
			}

			float3 hsv2rgb(float3 c)
			{
				float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
				float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
				return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
			}

			float menger(float3 pos) {
				float d = cross(pos);
				float3 cube = max3(abs(pos) - (float3).5);
				float scale = 1.;
				for (int i = 0; i < 8; i++) {
					pos = frac(3.*pos + (float3).5) - (float3).5;
					scale *= 3.;
					//pos.xy = rotate(pos.xy, _Time.y);
					//pos.yz = rotate(pos.yz, .01*_SinTime.w);
					d = min(d, cross(pos)/scale);
					//d = cross(pos);
				}
				//if (max3(abs(pos)) > .6) return cube;
				//d = max(cube, d);
				d = max(cube, -d);
				return d;
			}

			float sdf(float3 pos)
			{
				pos *= 1.;
				//pos.xy = rotate(pos.xy, _SinTime.y*length(pos.xy));
				//pos.yz = rotate(pos.yz, _CosTime.z*length(pos.yz));
				return menger(pos)/1.;
			}

			float getDepth(float3 rPos) {
				float4 vpPos = UnityObjectToClipPos(float4(rPos,1.0));
				return (vpPos.z / vpPos.w);
			}

			frag_out frag(v2f i)
			{
				frag_out o;
				//float3 worldPosition = i.wPos;
				float3 objPosition = i.pos;
				float3 objSpaceCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
				//float3 cameraPos = _WorldSpaceCameraPos;
				//float3 center = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
				ray r;
				r.dir = normalize(objPosition - objSpaceCameraPos);
				r.org = objSpaceCameraPos;
				float rLen = 0;
				float3 rPos = r.org;
				float dist = INF;
				float steps = 0.;
				for (int ind = 0; ind < STEPS && dist >= .0001; ind++)
				{
					dist = sdf(rPos);
					rLen += dist;
					rPos = r.org + rLen * r.dir;
				}

				float3 col = hsv2rgb(float3(frac((float)ind*2./(float)STEPS+_Time.y*.5), .8, .8));

				o.depth = getDepth(rPos);
				//o.depth = 0;

				float d = .0001;


				float3 normal = normalize(
					mul(
						unity_ObjectToWorld,
						float4(
							sdf(rPos + float3(d, 0, 0)) - sdf(rPos + float3(-d, 0, 0)),
							sdf(rPos + float3(0, d, 0)) - sdf(rPos + float3(0, -d, 0)),
							sdf(rPos + float3(0, 0, d)) - sdf(rPos + float3(0, 0, -d)),
							0
						)
					).xyz
				);

				o.color.w = 1.;
				if (abs(dist)<.0001) {
					o.color.xyz = col*ShadeSH9(half4(normal, 1))+.5*col;
				}
				else{
					//o.color.xyz = float3(1., 0., 0.)*ShadeSH9(half4(normal, 1));
					discard;
				}
				return o;
			}
			ENDCG
		 }
	 }
}