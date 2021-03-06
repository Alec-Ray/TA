#ifndef FOG_COMMON_CGINC
#define FOG_COMMON_CGINC

#include "UnityCG.cginc"

#define UBPA_FOG_COORDS(ID) float4 _fogCoord : TEXCOORD##ID;

float fogBaseColorCtrl;
// WorldSpaceViewDir : vertex to camera
// GetHeightExponentialFog need camera to vertex
#define UBPA_TRANSFER_FOG(v2f, vertex) v2f##._fogCoord = GetExponentialHeightFog(-WorldSpaceViewDir(vertex))

#define UBPA_APPLY_FOG(v2f, pixelColor) pixelColor = fixed4(pixelColor.rgb * pow(v2f._fogCoord.a,fogBaseColorCtrl) + v2f._fogCoord.rgb, pixelColor.a)

// unity not support struct 
//struct Fog {
	// x : FogDensity * exp2(-FogHeightFalloff * (CameraWorldPosition.y - FogHeight))
	// y : FogHeightFalloff
	// [useless] z : CosTerminatorAngle
	// w : StartDistance
	float4 ExponentialFogParameters;

	// FogDensitySecond * exp2(-FogHeightFalloffSecond * (CameraWorldPosition.y - FogHeightSecond))
	// FogHeightFalloffSecond
	// FogDensitySecond
	// FogHeightSecond
	float4 ExponentialFogParameters2;

	// FogDensity in x
	// FogHeight in y
	// [useless] whether to use cubemap fog color in z
	// FogCutoffDistance in w
	float4 ExponentialFogParameters3;

	// xyz : directinal inscattering color
	// w : cosine exponent
	float4 DirectionalInscatteringColor;

	// xyz : directional light's direction. 方向光照射方向的反方向
	// w : direactional inscattering start distance
	float4 InscatteringLightDirection;

	// xyz : fog inscattering color
	// w : min transparency
	float4 ExponentialFogColorParameter;
//};
	float4 fogInscatteringColor2;
	float4 fogInscatteringColor2Top;

static const float FLT_EPSILON2 = 0.01f;

float Pow2(float x) { return x * x; }

// UE 4.22 HeightFogCommon.ush
// Calculate the line integral of the ray from the camera to the receiver position through the fog density function
// The exponential fog density function is d = GlobalDensity * exp(-HeightFalloff * y)
float CalculateLineIntegralShared(float FogHeightFalloff, float RayDirectionY, float RayOriginTerms)
{
	float Falloff = max(-127.0f, FogHeightFalloff * RayDirectionY);    // if it's lower than -127.0, then exp2() goes crazy in OpenGL's GLSL.
	float LineIntegral = (1.0f - exp2(-Falloff)) / Falloff;
	float LineIntegralTaylor = log(2.0) - (0.5 * Pow2(log(2.0))) * Falloff;		// Taylor expansion around 0

	return RayOriginTerms * (abs(Falloff) > FLT_EPSILON2 ? LineIntegral : LineIntegralTaylor);
}

float4 For1FarColor;
// UE 4.22 HeightFogCommon.ush
// @param WorldPositionRelativeToCamera = WorldPosition - InCameraPosition
half4 GetExponentialHeightFog(float3 WorldPositionRelativeToCamera) // camera to vertex
{
	const half MinFogOpacity = ExponentialFogColorParameter.w;//1-fogMaxOpacity雾最不大透明度//

	// Receiver 指着色点
	float3 CameraToReceiver = WorldPositionRelativeToCamera;
	float CameraToReceiverLengthSqr = dot(CameraToReceiver, CameraToReceiver);
	float CameraToReceiverLengthInv = rsqrt(CameraToReceiverLengthSqr); // 平方根的倒数
	float CameraToReceiverLength = CameraToReceiverLengthSqr * CameraToReceiverLengthInv;
	half3 CameraToReceiverNormalized = CameraToReceiver * CameraToReceiverLengthInv;

	// FogDensity * exp2(-FogHeightFalloff * (CameraWorldPosition.y - FogHeight))
	float RayOriginTerms = ExponentialFogParameters.x;
	float RayOriginTermsSecond = ExponentialFogParameters2.x;
	float RayLength = CameraToReceiverLength;
	float RayDirectionY = CameraToReceiver.y;

	// Factor in StartDistance
	// ExponentialFogParameters.w 是 StartDistance
	float ExcludeDistance = ExponentialFogParameters.w;

	if (ExcludeDistance > 0)
	{
		// 到相交点所占时间
		float ExcludeIntersectionTime = ExcludeDistance * CameraToReceiverLengthInv;
		// 相机到相交点的 y 偏移
		float CameraToExclusionIntersectionY = ExcludeIntersectionTime * CameraToReceiver.y;
		// 相交点的 y 坐标
		float ExclusionIntersectionY = _WorldSpaceCameraPos.y + CameraToExclusionIntersectionY;
		// 相交点到着色点的 y 偏移
		float ExclusionIntersectionToReceiverY = CameraToReceiver.y - CameraToExclusionIntersectionY;

		// Calculate fog off of the ray starting from the exclusion distance, instead of starting from the camera
		// 相交点到着色点的距离
		RayLength = (1.0f - ExcludeIntersectionTime) * CameraToReceiverLength;
		// 相交点到着色点的 y 偏移
		RayDirectionY = ExclusionIntersectionToReceiverY;
		// ExponentialFogParameters.y : height falloff
		// ExponentialFogParameters3.y ： fog height
		// height falloff * height
		float Exponent = max(-127.0f, ExponentialFogParameters.y * (ExclusionIntersectionY - ExponentialFogParameters3.y));
		// ExponentialFogParameters3.x : fog density
		RayOriginTerms = ExponentialFogParameters3.x * exp2(-Exponent);

		// ExponentialFogParameters2.y : FogHeightFalloffSecond
		// ExponentialFogParameters2.w : fog height second
		float ExponentSecond = max(-127.0f, ExponentialFogParameters2.y * (ExclusionIntersectionY - ExponentialFogParameters2.w));
		RayOriginTermsSecond = ExponentialFogParameters2.z * exp2(-ExponentSecond);
	}

	// Calculate the "shared" line integral (this term is also used for the directional light inscattering) by adding the two line integrals together (from two different height falloffs and densities)
	// ExponentialFogParameters.y : fog height falloff
	float e0 = CalculateLineIntegralShared(ExponentialFogParameters.y, RayDirectionY, RayOriginTerms);
	float e1 = CalculateLineIntegralShared(ExponentialFogParameters2.y, RayDirectionY, RayOriginTermsSecond);
	float ExponentialHeightLineIntegralShared = e0 + e1;
	float t0 = e1 / (e0 + e1 + 0.00001);
		
	// fog amount，最终的积分值
	float ExponentialHeightLineIntegral = ExponentialHeightLineIntegralShared * RayLength;


	fogInscatteringColor2.xyz = lerp(fogInscatteringColor2Top.xyz, fogInscatteringColor2.xyz, saturate( exp2(-e1* RayLength) ) );

	//ExponentialFogColorParameter.xyz = lerp( ExponentialFogColorParameter.xyz, For1FarColor.xyz, saturate( For1FarColor.a *RayLength));
	//float tt = exp2(-For1FarColor.a *RayLength);
	//ExponentialFogColorParameter.xyz = lerp(ExponentialFogColorParameter.xyz, For1FarColor.xyz, saturate(For1FarColor.a *RayLength));
	ExponentialFogColorParameter.xyz = lerp(For1FarColor.xyz,ExponentialFogColorParameter.xyz, exp2(-For1FarColor.a *RayLength));
	//
	// 雾色
	half3 InscatteringColor = lerp(ExponentialFogColorParameter.xyz, fogInscatteringColor2.xyz , t0);
	//half3 InscatteringColor = ExponentialFogColorParameter.xyz ;
	half3 DirectionalInscattering = 0;

//#if FOG_LIGHT
	// if InscatteringLightDirection.w is negative then it's disabled, otherwise it holds directional inscattering start distance
	if (InscatteringLightDirection.w >= 0)
	{
		float DirectionalInscatteringStartDistance = InscatteringLightDirection.w;
		// Setup a cosine lobe around the light direction to approximate inscattering from the directional light off of the ambient haze;
		half3 DirectionalLightInscattering = DirectionalInscatteringColor.xyz * pow(saturate(dot(CameraToReceiverNormalized, InscatteringLightDirection.xyz)), DirectionalInscatteringColor.w);

		// Calculate the line integral of the eye ray through the haze, using a special starting distance to limit the inscattering to the distance
		float DirExponentialHeightLineIntegral = ExponentialHeightLineIntegralShared * max(RayLength - DirectionalInscatteringStartDistance, 0.0f);
		// Calculate the amount of light that made it through the fog using the transmission equation
		half DirectionalInscatteringFogFactor = saturate(exp2(-DirExponentialHeightLineIntegral));
		// Final inscattering from the light
		DirectionalInscattering = DirectionalLightInscattering * (1 - DirectionalInscatteringFogFactor);
	}
 
	// Calculate the amount of light that made it through the fog using the transmission equation
	// 最终的系数
	half ExpFogFactor = max(saturate(exp2(-ExponentialHeightLineIntegral)), MinFogOpacity);

	// ExponentialFogParameters3.w : FogCutoffDistance
	/*if (ExponentialFogParameters3.w > 0 && CameraToReceiverLength > ExponentialFogParameters3.w)
	{
		ExpFogFactor = 1;
		DirectionalInscattering = 0;
	}*/
	//fogInscatteringColor2
	half3 FogColor = (InscatteringColor) * (1 - ExpFogFactor) + DirectionalInscattering;

	return half4(FogColor, ExpFogFactor);
}

#endif// !FOG_COMMON_CGINC


/*
struct Input
{
	float2 uv_texcoord;
	float4 _fogCoord;//*
};

finalcolor:fogex vertex:vert_fun

void fogex(Input data, SurfaceOutputStandard o, inout fixed4 color)
{
	//UBPA_APPLY_FOG(data,color);
}
void vert_fun(inout appdata_full v, out Input data)
{
	UNITY_INITIALIZE_OUTPUT(Input, data);
	//data._fogCoord = GetExponentialHeightFog(-WorldSpaceViewDir(v.vertex));
}

*/
