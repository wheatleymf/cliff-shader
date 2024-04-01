//
// Cliff Shader by wheatleymf, 16.02.2024 - 01.04.2024.
// This code is likely huge pile of poo. CC BY-NC 4.0 License.
//

#ifndef CLIFF_UTILS_H
#define CLIFF_UTILS_H

// 
// Triplanar mapping, borrowed from sbox common/utils. The only difference is that it's no longer uses Tex2DS macro, also vC0 orientation has been changed to YZ.
//
#ifndef PIXEL_TRIPLANNAR_H
#define PIXEL_TRIPLANNAR_H

float4 Tex2DTriplanar( in Texture2D texture, in SamplerState samplerState, float3 vPositionWs, float3 vNormalWs, float2 vTile = 512.0f, float flBlend = 1.0f, float2 vTexScale = 1.0f )
{
    // Calculate blending coefficients
    vNormalWs = abs( normalize(vNormalWs) );
    vNormalWs = pow( vNormalWs, flBlend );
    vNormalWs /= dot( vNormalWs, 1.0f ); // (vNormalWs.x + vNormalWs.y + vNormalWs.z);

    // Inches to meters. Since source does everything in inches it makes our texture really small!
    // Lets stretch it out so our values are nicer to play with
    vPositionWs /= 39.3701;

    // Fetch our samples

    vTexScale *= vTile;

    float4 vC0 = texture.Sample( samplerState, vPositionWs.yz * vTexScale );
    float4 vC1 = texture.Sample( samplerState, vPositionWs.xz * vTexScale );
    float4 vC2 = texture.Sample( samplerState, vPositionWs.xy * vTexScale );

    // Blend & Return
    return vC0 * vNormalWs.x + vC1 * vNormalWs.y + vC2 * vNormalWs.z;
}


#ifdef COMMON_PS_INPUT_DEFINED

//
// Sample a texture using tri-plannar mapping using the current world position as an input
//
float4 Tex2DTriplanar( in Texture2D texture, in SamplerState samplerState, PixelInput pixelInput, float2 vTile = 512.0f, float flBlend = 1.0f, float2 vTexScale = 1.0f, bool isLOD = false )
{
    // Leave & return early if shader is in LOD mode (is this ok to do?)
    [flatten]
    if (isLOD) 
    {
        return texture.Sample( samplerState, pixelInput.vTextureCoords.xy * vTexScale );
    }

    float3 vPositionWs = pixelInput.vPositionWithOffsetWs.xyz + g_vHighPrecisionLightingOffsetWs.xyz;
    return Tex2DTriplanar( texture, samplerState, vPositionWs, pixelInput.vNormalWs, vTile, flBlend, vTexScale );
}
#endif
#endif

//
// Contrast & intensity, wrapped into one function. 
// Output float is in [0..1] range because I grab single channel from normal map once and without saturating it can result in freaky lerp.
//
float AdjustMask( float mask, float contrast, float intensity )
{
    return saturate( ( mask * intensity - 0.5f) * max( contrast, 0 ) + 0.5f );
}

//
// Normal blending, both input normals must be unpacked first since this function does not pass output through normalize(). 
//
float3 BlendNormals( float3 NrmA, float3 NrmB ) 
{
    NrmA += float3(  0,  0, 1 );
    NrmB *= float3( -1, -1, 1 );

    return NrmA * dot( NrmA, NrmB ) / NrmA.z - NrmB;
}

//
// Linear dodge blend mode
//
float3 BlendLinearDodge( float3 clr, float mask, float strength )
{
    return min( 1, clr + (mask * strength) );
}

#endif