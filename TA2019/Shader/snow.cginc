fixed _SnowPower;
fixed _SnowNormalPower;
fixed4 _SnowColor;
fixed _SnowEdge;
sampler2D _SnowNoise;
half _SnowNoiseScale;
half _SnowGloss;
half _SnowLocalPower;
half _SnowMeltPower;
half HARD_SNOW;
half MELT_SNOW;

/*
[Toggle]_snow_options("----------ѩѡ��-----------",int) = 0
_SnowNormalPower("  ѩ����ǿ��", Range(0.3, 1)) = 1
//_SnowColor("ѩ��ɫ", Color) = (0.784, 0.843, 1, 1)
_SnowEdge("  ѩ��Ե����", Range(0.01, 0.3)) = 0.2
//_SnowNoise("ѩ���", 2D) = "white" {}
_SnowNoiseScale("  ѩ�������", Range(0.1, 20)) = 1.28
//_SnowGloss("ѩ�߹�", Range(0, 1)) = 1
//_SnowMeltPower("  ѩ_����Ӱ�����", Range(1, 2)) =  1
_SnowLocalPower("  ѩ_����Ӱ�����", Range(-5, 0.3)) = 0
[MaterialToggle] HARD_SNOW("Ӳ��ѩ", Float) = 0
[MaterialToggle] MELT_SNOW("����ѩ", Float) = 0
//[KeywordEnum(ON, OFF)] _IsWeather("�Ƿ��������", Float) = 0
*/
/*
#if _ISWEATHER_ON

	#if SNOW_ENABLE 
		fixed nt;
		CmpSnowNormalAndPower(i.uv0, i.normalDir.xyz, nt, normalDirection);
	#endif
	#endif
*/
/*
#if _ISWEATHER_ON
	#if SNOW_ENABLE
		diffuseColor.rgb = lerp(diffuseColor.rgb, _SnowColor.rgb, nt *_SnowColor.a);
	#endif
#endif
*/

/*
#if _ISWEATHER_ON
	#if RAIN_ENABLE
		gloss = saturate(gloss* get_smoothnessRate());
	#endif
	#if(SNOW_ENABLE)
		gloss = lerp(gloss, _SnowGloss, nt);
	#endif
#endif
*/

void CmpSnowNormalAndPower(in half2 uv,in float3 VertexNormal,out fixed t, inout float3 normalDirection)
{
#if SNOW_ENABLE 
	half snoize = 0;
	half snl = 0;
	if (MELT_SNOW > 0)
	{
		half snoize = tex2D(_SnowNoise, uv*_SnowNoiseScale).r;
		snl = snoize * _SnowMeltPower;
		t = smoothstep(_SnowPower, _SnowPower + _SnowEdge, snl);
		if (HARD_SNOW > 0)
		{
			t = step(snoize, t);
		}
	}
	else
	{
		snl = dot(normalDirection, half3(0, 1, 0));
		snl = (1.0 - _SnowLocalPower)*snl + _SnowLocalPower;
		t = smoothstep(_SnowPower, _SnowPower + _SnowEdge, snl);
		if (HARD_SNOW > 0)
		{
			half snoize = tex2D(_SnowNoise, uv*_SnowNoiseScale).r;
			t = step(snoize, t);
		}
	}
	normalDirection = lerp(VertexNormal.xyz, normalDirection, _SnowNormalPower);

#endif
}



void CmpSnowNormalAndPowerSurFace(in half2 uv, in float3 VertexNormal, out fixed t, inout float3 normalDirection, float3 tUp)//���߿ռ��Ϸ���
{
#if SNOW_ENABLE 
	half snoize = 0;
	half snl = 0;
	if (MELT_SNOW > 0)
	{
		half snoize = tex2D(_SnowNoise, uv*_SnowNoiseScale).r;
		snl = snoize * _SnowMeltPower;
		t = smoothstep(_SnowPower, _SnowPower + _SnowEdge, snl);
		if (HARD_SNOW > 0)
		{
			t = step(snoize, t);
		}
	}
	else
	{
		snl = dot(normalDirection, tUp);
		snl = (1.0 - _SnowLocalPower)*snl + _SnowLocalPower;
		t = smoothstep(_SnowPower, _SnowPower + _SnowEdge, snl);
		if (HARD_SNOW > 0)
		{
			half snoize = tex2D(_SnowNoise, uv*_SnowNoiseScale).r;
			t = step(snoize, t);
		}
	}
	normalDirection = lerp(half3(0, 0, 1), normalDirection, _SnowNormalPower);

#endif
}
 