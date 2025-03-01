//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
#define NUM_LIGHTS (1)
#define NEAR_PLANE (0.01f)
#define FAR_PLANE (1000.0f)

Texture2D shadowMapTexture : register(t2);
SamplerState shadowMapSampler : register(s2);
TextureCube g_txCubeMap : register(t3);
struct CBPointLight
{
    float4 Position;
    float4 Color;
    float4 AttenuationDistance;
    matrix LightViews;
    matrix LightProjections;
};

cbuffer cbLights : register(b3)
{
    CBPointLight PointLights[NUM_LIGHTS];

};

Texture2D txDiffuse[2] : register(t0);
SamplerState samLinear[2] : register(s0);



cbuffer cbChangeOnCameraMovement : register(b2)
{

	matrix View;
    float4 CameraPosition;

};

cbuffer CBChangeOnResize : register(b1)
{

	matrix Projection;
};
cbuffer  cbChangesEveryFrame : register(b0)
{
	matrix World;
    float4 OutputColor;
    bool HasNormalMap;
};


struct VS_PHONG_INPUT
{
	float4 Position : POSITION;
    float2 TexCoord :TEXCOORD0;
    float3 Normal : NORMAL;
    
        
    //Apply Tangent Data
    float3 Tangent : TANGENT;
    float3 Bitangent : BITANGENT;
    

};
struct PS_PHONG_INPUT
{
    float4 Position : SV_POSITION;
    float2 TexCoord : TEXCOORD0;
    float3 Normal : NORMAL;
    float3 WorldPosition : WORLDPOS;
    float3 Tangent : TANGENT;
    float3 Bitangent : BITANGENT;
    float4 LightViewPosition : TEXCOORD1;
    //float4 LightViewPositionSecond : TEXCOORD1;
};

struct PS_LIGHT_CUBE_INPUT
{
    float4 Position : SV_POSITION;
};


float LinearizeDepth(float depth)
{
    float z = depth * 2.0 - 1.0;
    return ((2.0 * NEAR_PLANE * FAR_PLANE) / (FAR_PLANE + NEAR_PLANE - z * (FAR_PLANE - NEAR_PLANE))) / FAR_PLANE;
};

PS_PHONG_INPUT VSEnvironmentMap(VS_PHONG_INPUT input)
{
    PS_PHONG_INPUT output = (PS_PHONG_INPUT) 0;
    output.Position = mul(input.Position, World);
    output.Position = mul(output.Position, View);
    output.Position = mul(output.Position, Projection);
    output.TexCoord = input.TexCoord;
    
    output.Normal = normalize(mul(float4(input.Normal, 0), World).xyz);
    
    return output;
};


PS_PHONG_INPUT VSPhong(VS_PHONG_INPUT input)
{
    PS_PHONG_INPUT output = (PS_PHONG_INPUT )0;
    output.Position = mul(input.Position, World);
    output.Position = mul(output.Position, View);
    output.Position = mul(output.Position, Projection);
    output.TexCoord = input.TexCoord;
    

    if (HasNormalMap)
    {
        output.Tangent = normalize(mul(float4(input.Tangent, 0.0f), World).xyz);
        output.Bitangent = normalize(mul(float4(input.Bitangent, 0.0f), World).xyz);
    }
    
    output.Normal = normalize(mul(float4(input.Normal,0),World).xyz);

    output.WorldPosition = mul( input.Position, World );
    
    //LAB10//
    output.LightViewPosition = mul(input.Position, World);
    output.LightViewPosition = mul(output.LightViewPosition, PointLights[0].LightViews );
    output.LightViewPosition = mul(output.LightViewPosition, PointLights[0].LightProjections );
    
    //output.LightViewPositionSecond = mul(input.Position, World);
    //output.LightViewPositionSecond = mul(output.LightViewPositionSecond, PointLights[1].LightViews);
    //output.LightViewPositionSecond = mul(output.LightViewPositionSecond, PointLights[1].LightProjections);

    //output.LightViewPosition = normalize(output.LightViewPosition);
    return output;
};

PS_LIGHT_CUBE_INPUT VSLightCube(VS_PHONG_INPUT input)
{
    PS_LIGHT_CUBE_INPUT output = (PS_LIGHT_CUBE_INPUT) 0;
    output.Position = mul(input.Position, World);
    output.Position = mul(output.Position, View);
    output.Position = mul(output.Position, Projection);
    

    return output;
};

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PSPhong(PS_PHONG_INPUT input) : SV_TARGET
{
    float4 color = txDiffuse[0].Sample(samLinear[0], input.TexCoord);
    float3 ambient = float3(0.1f, 0.1f, 0.1f) * color.rgb;    

    float2 projectedTexCoord;
    projectedTexCoord.x = input.LightViewPosition.x / input.LightViewPosition.w / 2.0f + 0.5f;
    projectedTexCoord.y = -input.LightViewPosition.y / input.LightViewPosition.w / 2.0f + 0.5f;
    

        float closestDepth = shadowMapTexture.Sample(shadowMapSampler, projectedTexCoord).r;
        float currentDepth = input.LightViewPosition.z / input.LightViewPosition.w;
        closestDepth = LinearizeDepth(closestDepth);
        currentDepth = LinearizeDepth(currentDepth);
        // Subtract the bias from the lightDepthValue.
        //lightDepthValue = lightDepthValue - bias;
        if (currentDepth > closestDepth + 0.001f)
        {
            
            return (ambient, 0.0f);
    }
    else
    {
        float3 diffuse = float3(0.0f, 0.0f, 0.0f);
        float3 ambience = float3(0.1f, 0.1f, 0.1f);
        float3 ambienceTerm = float3(0.0f, 0.0f, 0.0f);
        float3 specular = float3(0.0f, 0.0f, 0.0f);
        float3 viewDirection = normalize(input.WorldPosition - CameraPosition.xyz);
        float3 normal = normalize(input.Normal);
        
        if (HasNormalMap)
        {
        // Sample the pixel in the normal map.
            float4 bumpMap = txDiffuse[1].Sample(samLinear[1], input.TexCoord);
        // Expand the range of the normal value from (0, +1) to (-1, +1).
            bumpMap = (bumpMap * 2.0f) - 1.0f;
        // Calculate the normal from the data in the normal map.
            float3 bumpNormal = (bumpMap.x * input.Tangent) + (bumpMap.y * input.Bitangent) +
(bumpMap.z * normal);
        // Normalize the resulting bump normal and replace existing normal
            normal = normalize(bumpNormal);
        }
        for (uint i = 0; i < NUM_LIGHTS; ++i)
        {
            float3 distanceToLight = input.WorldPosition - PointLights[i].Position.xyz;
            float Ep = 0.000001f;
            float lightAttenuation = saturate((PointLights[i].AttenuationDistance.x * PointLights[i].AttenuationDistance.y) 
            / (dot(distanceToLight, distanceToLight) + Ep));

            ambienceTerm += (ambience * txDiffuse[0].Sample(samLinear[0], input.TexCoord).rgb) * PointLights[i].Color.xyz
            * lightAttenuation;
        
            float3 lightDirection = normalize(input.WorldPosition - PointLights[i].Position.xyz);
            float lambertianTerm = dot(normalize(input.Normal), -lightDirection);
            diffuse += max(lambertianTerm, 0.0f) * txDiffuse[0].Sample(samLinear[0], input.TexCoord).rgb * PointLights[i].Color.xyz
            * lightAttenuation;
        
            float3 reflectDirection = normalize(reflect(lightDirection, input.Normal));
            specular += pow(max(dot(-viewDirection, reflectDirection), 0.0f), 15.0f) *
            PointLights[i].Color.xyz * txDiffuse[0].Sample(samLinear[0], input.TexCoord).rgb
            * lightAttenuation;
        }


        float4 final = float4(saturate(diffuse + specular + ambient), 1);

        return final;
    }
    

    
};

float4 PSEnvironmentMap(PS_PHONG_INPUT input) : SV_TARGET
{
    float4 color = txDiffuse[0].Sample(samLinear[0], input.TexCoord);
    float3 ambient = float3(0.1f, 0.1f, 0.1f) * color.rgb;

    float2 projectedTexCoord;
    projectedTexCoord.x = input.LightViewPosition.x / input.LightViewPosition.w / 2.0f + 0.5f;
    projectedTexCoord.y = -input.LightViewPosition.y / input.LightViewPosition.w / 2.0f + 0.5f;
    

    float closestDepth = shadowMapTexture.Sample(shadowMapSampler, projectedTexCoord).r;
    float currentDepth = input.LightViewPosition.z / input.LightViewPosition.w;
    closestDepth = LinearizeDepth(closestDepth);
    currentDepth = LinearizeDepth(currentDepth);
        // Subtract the bias from the lightDepthValue.
        //lightDepthValue = lightDepthValue - bias;
    if (currentDepth > closestDepth + 0.001f)
    {
            
        return (ambient, 0.0f);
    }
    else
    {
        float3 diffuse = float3(0.0f, 0.0f, 0.0f);
        float3 ambience = float3(0.1f, 0.1f, 0.1f);
        float3 ambienceTerm = float3(0.0f, 0.0f, 0.0f);
        float3 specular = float3(0.0f, 0.0f, 0.0f);
        float3 viewDirection = normalize(input.WorldPosition - CameraPosition.xyz);
        float3 normal = normalize(input.Normal);
        
        if (HasNormalMap)
        {
        // Sample the pixel in the normal map.
            float4 bumpMap = txDiffuse[1].Sample(samLinear[1], input.TexCoord);
        // Expand the range of the normal value from (0, +1) to (-1, +1).
            bumpMap = (bumpMap * 2.0f) - 1.0f;
        // Calculate the normal from the data in the normal map.
            float3 bumpNormal = (bumpMap.x * input.Tangent) + (bumpMap.y * input.Bitangent) +
(bumpMap.z * normal);
        // Normalize the resulting bump normal and replace existing normal
            normal = normalize(bumpNormal);
        }
        for (uint i = 0; i < NUM_LIGHTS; ++i)
        {
            float3 distanceToLight = input.WorldPosition - PointLights[i].Position.xyz;
            float Ep = 0.000001f;
            float lightAttenuation = saturate((PointLights[i].AttenuationDistance.x * PointLights[i].AttenuationDistance.y)
            / (dot(distanceToLight, distanceToLight) + Ep));
            
            ambienceTerm += (ambience * txDiffuse[0].Sample(samLinear[0], input.TexCoord).rgb) * PointLights[i].Color.xyz * lightAttenuation;
        
            float3 lightDirection = normalize(input.WorldPosition - PointLights[i].Position.xyz);
            float lambertianTerm = dot(normalize(input.Normal), -lightDirection);
            diffuse += max(lambertianTerm, 0.0f) * txDiffuse[0].Sample(samLinear[0], input.TexCoord).rgb * PointLights[i].Color.xyz * lightAttenuation;
        
            float3 reflectDirection = normalize(reflect(lightDirection, input.Normal));
            specular += pow(max(dot(-viewDirection, reflectDirection), 0.0f), 8.0f) * PointLights[i].Color.xyz * txDiffuse[0].Sample(samLinear[0], input.TexCoord).rgb * lightAttenuation;
        }
        float3 env_coord = reflect(viewDirection, normal); //ȯ�� ������ ���� �ؽ�ó �ּ� �ݻ纤��
        float4 env = g_txCubeMap.Sample(samLinear[0], env_coord);
        //env ���� ��� ���̸� ������������
        float4 final = float4(ambient + diffuse + specular + (env * 0.10f), 1);

        return final;
    }
};

float4 PSLightCube(PS_LIGHT_CUBE_INPUT input) : SV_Target
{
    return OutputColor;
};
