//
// Cliff Shader by wheatleymf, 16.02.2024 - 01.04.2024.
// This code is likely huge pile of poo. CC BY-NC 4.0 License.
//

HEADER
{
	Description = "Cliff Shader";
	Version = 1;
	Description = "Simple triplanar-mapped shader by wheatleymf.";
}

FEATURES 
{
	// Basic stuff
	#include "common/features.hlsl" 

	Feature(F_SECOND_LAYER_TEXTURE, 0..2(0="Disabled", 1="Use 'Direction' map", 2="Dynamic projection"), "Cliff Settings");
	Feature(F_LOD_MODE, 0..1, "Cliff Settings");

}

MODES
{
	VrForward();
	ToolsVis( S_MODE_TOOLS_VIS );
	Depth( S_MODE_DEPTH );
}

//=========================================================================================================================
COMMON
{
	#include "common/shared.hlsl"
}

//=========================================================================================================================

struct VertexInput
{
	#include "common/vertexinput.hlsl"
};

//=========================================================================================================================

struct PixelInput
{
	#include "common/pixelinput.hlsl"
};

//=========================================================================================================================

VS
{
	#include "common/vertex.hlsl"

	//
	// Main
	//
	PixelInput MainVs( VertexInput i )
	{
		PixelInput o = ProcessVertex( i );
		return FinalizeVertex( o );
	}
}

//=========================================================================================================================

PS
{ 
	//
	// Combos
	//
	StaticCombo( S_MODE_DEPTH, 0..1, Sys( ALL ) );						
	StaticCombo( S_SECOND_LAYER, F_SECOND_LAYER_TEXTURE, Sys( PC ) );
	StaticCombo( S_TEXTURE_FILTERING, F_TEXTURE_FILTERING, Sys( PC ) );
	StaticCombo( S_LOD_MODE, F_LOD_MODE, Sys( ALL ) );

	#define CUSTOM_MATERIAL_INPUTS
	//
	// Input boxes for Color map, tint mask and tint color.
	//
	CreateInputTexture2D( Color, 	Srgb, 8, "", "_color", 	"Material,10/10", Default3( 1.0, 1.0, 1.0 ) );		// RGB
	CreateInputTexture2D( ColorTintMask, Linear, 8, "", "_tint", "Material,10/20", Default3( 1.0, 1.0, 1.0 ) );	// A
	float3 g_flColorTint < UiType( Color ); Default3( 1.0, 1.0, 1.0 ); UiGroup( "Material,10/20" ); >;

	//
	// Global model normal map.
	//
	CreateInputTexture2D( GlobalNormal, Linear, 8, "NormalizeNormals", "_glnormal", "Material,10/30", Default3( 0.5, 0.5, 1.0) );
	float GlobalNormalStrength < UiType( Slider ); Default( 1.0f ); Range( 0, 50.0 ); UiGroup( "Material,10/30"); >;

	//
	// Store normal map. Normal strength can be adjusted.
	//
    CreateInputTexture2D( DetailNormal, Linear, 8, "NormalizeNormals", "_normal", "Material,10/40", Default3( 0.5, 0.5, 1.0 ) );
	float NormalStrength < UiType( Slider ); Default( 1.0f ); Range( 0, 50.0 ); UiGroup( "Material,10/40"); >; 

	//
	// Roughness, Metalness and Ambient Occlusion - everything gets packed into a signle RGB texture. AO strength can be adjusted.
	//
	CreateInputTexture2D( Roughness, 		Linear, 8, "", "_rough", 	"Material,10/50", Default( 1 ) );
	CreateInputTexture2D( Metalness, 		Linear, 8, "", "_metal", 	"Material,10/60", Default( 1.0 ) );
	CreateInputTexture2D( GlobalAmbientOcclusion, Linear, 8, "", "_ao", "Material,10/70", Default( 1.0 ) );
	CreateInputTexture2D( DetailAmbientOcclusion, Linear, 8, "", "_ao", "Material,10/80", Default( 1.0 ) );
	float AmbientOcclusionStrength < UiType( Slider ); Default( 1.0f ); Range( 0, 10.0 ); UiGroup( "Material,10/70" ); >;

	//
	// Cliff mesh details - peaks, direction and dirt masks. Dirt mask's black color indicates which areas should be darkened.
	//
	CreateInputTexture2D( CliffPeaks, 	  Linear, 8, "", "_peaks", 	"Cliff Model Data,20/10", Default( 1 ) );	// R
	CreateInputTexture2D( CliffDirection, Linear, 8, "", "_dir", 	"Cliff Model Data,20/20", Default( 0 ) );	// G
	CreateInputTexture2D( CliffDirt,	  Linear, 8, "", "_dirt", 	"Cliff Model Data,20/30", Default( 1 ) );	// B

	//
	// Include sliders to customize influence of CMD maps.
	//
	float PeaksStrength 	< UiType( Slider ); Default( 0.25f ); Range(0, 5); UiGroup("Cliff Model Data,20/30"); >;
	float DirectionStrength < UiType( Slider ); Default( 0.5f  ); Range(0, 5); UiGroup("Cliff Model Data,20/30"); >; 
	float DirtStrength		< UiType( Slider ); Default( 1.0f  ); Range(0, 3); UiGroup("Cliff Model Data,20/30"); >;

	// 
	// Create Texture2Ds
	//
	Texture2D g_tColor 		< Channel( RGB, Box( Color ), Srgb ); Channel( A, Box( ColorTintMask ), Linear ); OutputFormat( BC7 ); SrgbRead( true ); >;
	Texture2D g_tGlNormal 	< Channel( RGB, Box( GlobalNormal ), Linear ); 	OutputFormat( DXT5 ); SrgbRead( false ); >;
	Texture2D g_tNormal 	< Channel( RGB, Box( DetailNormal ), Linear); 	OutputFormat( DXT5 ); SrgbRead( false ); >;
	Texture2D g_tRmo 		< Channel( R, 	Box( Roughness ), Linear ); Channel( G, Box( Metalness ), Linear ); Channel( B, Box( GlobalAmbientOcclusion ), Linear ); Channel( A, Box( DetailAmbientOcclusion ), Linear ); OutputFormat( BC7 ); SrgbRead( false ); >;
	Texture2D g_tCmd 		< Channel( R, 	Box( CliffPeaks), Linear ); Channel( G, Box( CliffDirection ), Linear ); Channel( B, Box( CliffDirt ), Linear ); OutputFormat( BC7 ); SrgbRead( false ); >;

	//
	// Triplanar mapping settings
	//
	float TextureTiling 	< UiType( VectorText ); Default( 2.0f ); Range ( 1.0f, 2048.0f ); UiGroup("Triplanar Settings,40/10"); >;
	float TextureBlending 	< UiType( VectorText ); Default( 1.0f ); Range ( 0.0f,   10.0f ); UiGroup("Triplanar Settings,40/20"); >;
	float TextureScale		< UiType( Slider ); 	Default( 1.0f ); Range ( 0.0f,   20.0f ); UiGroup("Triplanar Settings,40/30"); >;
	
	//
	// Second layer that can be applied with the usage of direction map. (or dynamically, if it's enabled)
	//
	#if (S_SECOND_LAYER)
		CreateInputTexture2D( LayerTwoColor, 			Srgb, 	8, "", 					"_color2", 	"L2 Texture,30/10", Default3( 1.0, 1.0, 1.0 ) );	// Tex1-RGB
		CreateInputTexture2D( LayerTwoNormal, 			Linear, 8, "NormalizeNormals", 	"_normal2", "L2 Texture,30/20", Default3( 1.0, 1.0, 1.0 ) );	// Tex2-RGB
		CreateInputTexture2D( LayerTwoRoughness, 		Linear, 8, "", 					"_rough2", 	"L2 Texture,30/30", Default( 0.5 ) );				// Tex3-R
		CreateInputTexture2D( LayerTwoMetalness, 		Linear, 8, "", 					"_metal2", 	"L2 Texture,30/40", Default( 0 ) );					// Tex3-G
		CreateInputTexture2D( LayerTwoAmbientOcclusion, Linear, 8, "", 					"_ao2", 	"L2 Texture,30/50", Default( 1 ) );					// Tex3-B

		Texture2D g_tColor_L2 	< Channel( RGB, Box( LayerTwoColor ), 		Srgb ); 	OutputFormat( BC7 ); 	SrgbRead( true ); >;
		Texture2D g_tNormal_L2 	< Channel( RGB, Box( LayerTwoNormal ), 		Linear ); 	OutputFormat( DXT5 ); 	SrgbRead( false ); >;
		Texture2D g_tRmo_L2	 	< Channel( R, 	Box( LayerTwoRoughness ), 	Linear ); 	Channel( G, Box( LayerTwoMetalness ), Linear); Channel( B, Box( LayerTwoAmbientOcclusion ), Linear ); OutputFormat( BC7 ); SrgbRead( false ); >;

		float TextureTilingB 	< UiType( VectorText ); Default( 2.0f ); Range ( 1.0f, 2048.0f ); UiGroup("Triplanar Settings,40/10"); >;
		float TextureBlendingB 	< UiType( VectorText ); Default( 1.0f ); Range ( 0.0f,   10.0f ); UiGroup("Triplanar Settings,40/20"); >;
		float TextureScaleB		< UiType( Slider ); 	Default( 1.0f ); Range ( 0.0f,   20.0f ); UiGroup("Triplanar Settings,40/30"); >;

		// Set up sliders to control the generated mask when using dynamic projection
		#if ( S_SECOND_LAYER == 2 )
			float g_flBlendStrength < Default( 2 ); Range( 0.1, 8 ); UiGroup( "L2 Texture,30/60" ); >;	// How much area is covered by layer texture
			float g_flBlendContrast < Default( 1 ); Range( 0.1, 8 ); UiGroup( "L2 Texture,30/60" ); >;	// Lower value = smoother edges of a mask
		#endif
	#endif 

	//
	// Includes
	// 
    #include "sbox_pixel.fxc"	// Probably redundant include, since pixel.hlsl imports sbox_pixel.fxc already :S
    #include "common/pixel.hlsl"
	#include "cliff_utils.hlsl"	// Linear dodge, contrast & brightness, normal blending, slightly customized triplanar functions.

	RenderState( CullMode, F_RENDER_BACKFACES ? NONE : DEFAULT );	// Connect "Render Backfaces" from material editor so it actually works

	#if ( S_MODE_DEPTH )
        #define MainPs Disabled
    #endif

	//
	// Main
	//
	float4 MainPs( PixelInput i ) : SV_Target0
	{
		float2 UV = i.vTextureCoords.xy;	// Used for default texture mapping using mesh UV.
		float fac = 8;						// Used in TextureTiling "math" to make scale control feel less clunky. I probably can implement this in a better way. 

		//
		// Preparing cliff mesh data (peaks, distance & dirt masks) and then color map.
		//
		float3 		l_tCmd = g_tCmd.Sample( TextureFiltering, UV ).rgb;	// R = Peaks, G = Direction, B = Dirt
		float4 l_tColorMap = Tex2DTriplanar( g_tColor, TextureFiltering, i, TextureTiling / fac, TextureBlending, TextureScale, S_LOD_MODE).rgba;

		//
		// Loading up & instantly decoding normal maps. (global & detail)
		//
		float3 l_tGlNormalMap = DecodeNormal( g_tGlNormal.Sample( TextureFiltering, UV ).rgb ); 																							// Model's normal map - regular UV mapping
		float3   l_tNormalMap = DecodeNormal( Tex2DTriplanar( g_tNormal, TextureFiltering, i, TextureTiling / fac, TextureBlending, TextureScale, S_LOD_MODE ).rgb );	

		//
		// Loading up roughness/metalness/ambient occlusion maps. They're used for shading the mesh itself. 
		// Roughness/metalness maps are triplanar mapped and related to detail texture. AO is shading the mesh globally. 
		//
		float4 rm = Tex2DTriplanar( g_tRmo, TextureFiltering, i, TextureTiling / fac, TextureBlending, TextureScale, S_LOD_MODE ).rgba;	// We don't use triplanar mapped global AO, but it's easier to sample all 4 channels than only R, G and A.
		float  ao = g_tRmo.Sample( TextureFiltering, UV ).b;

        Material m = Material::Init();

		//
		// Branch out entirely and return material early if we're in a LOD mode, we don't need too much processing in this case
		//
		#if ( S_LOD_MODE )
			m.Albedo = l_tColorMap.rgb;
			m.Normal = TransformNormal( l_tGlNormalMap, i.vNormalWs, i.vTangentUWs, i.vTangentVWs );
			m.Roughness = rm.r;
			m.Metalness = rm.g;
			m.AmbientOcclusion = ao * rm.a;

			#if( S_SECOND_LAYER )	// Pretty stupid implementation, hopefully this isn't a big deal. 
				m.Albedo = lerp( l_tColorMap.rgb, Tex2DTriplanar( g_tColor_L2, TextureFiltering, i, TextureTilingB / fac, TextureBlendingB, TextureScaleB, S_LOD_MODE ).rgb, l_tCmd.g );
			#endif

			return ShadingModelStandard::Shade( i, m );
		#endif

		//
		// Building final albedo texture
		//
		l_tColorMap.rgb = abs( l_tColorMap.rgb - l_tCmd.b * (DirtStrength / 6) );	// Blend dirt map with "Difference" effect, pretty messy. 
		m.Albedo = BlendLinearDodge( lerp( l_tColorMap.rgb, (l_tColorMap.rgb) * g_flColorTint, l_tColorMap.a), l_tCmd.r, PeaksStrength );	// Blend peaks map with linear dodge

		//
		// Combine two normal maps
		//
		float3 l_tNormalMapBl = BlendNormals( float3( l_tGlNormalMap.rg * GlobalNormalStrength, l_tGlNormalMap.b ), float3( l_tNormalMap.rg * NormalStrength, l_tNormalMap.b) );	// Combined maps

		//
		// Setup the main material. If L2 is not enabled, this is what will be passed into shading model. 
		//
		m.Normal = TransformNormal( l_tNormalMapBl, i.vNormalWs, i.vTangentUWs, i.vTangentVWs );
        m.Roughness = rm.r;	
        m.Metalness = rm.g;
        m.AmbientOcclusion = (ao * rm.a ) / AmbientOcclusionStrength;
        m.TintMask = g_tColor.Sample( TextureFiltering, UV ).a;

		//
		// Prepare L2 textures here, then lerp two materials together. If dynamic projection is off, use given direction map from material editor.
		// If dynamic projection is enabled, use transformed normal (+Z) from 1st layer material as a mask, then correct with contrast/intensity sliders.
		//
		#if ( S_SECOND_LAYER )
			float3 l_tColorMap2 = 	Tex2DTriplanar( g_tColor_L2, TextureFiltering, i, TextureTilingB / fac, TextureBlendingB, TextureScaleB, S_LOD_MODE ).rgb;
			float3 l_tNormalMap2 = 	DecodeNormal( Tex2DTriplanar( g_tNormal_L2, TextureFiltering, i, TextureTilingB / fac, TextureBlendingB, TextureScaleB, S_LOD_MODE).rgb );
			float3 l_tRmo2 = 		Tex2DTriplanar( g_tRmo_L2, TextureFiltering, i, TextureTilingB / fac, TextureBlendingB, TextureScaleB, S_LOD_MODE ).rgb;

			Material layer = Material::Init();

			layer.Albedo 			= l_tColorMap2.rgb;
			layer.Normal 			= TransformNormal( l_tNormalMap2, i.vNormalWs, i.vTangentUWs, i.vTangentVWs );
			layer.Roughness 		= l_tRmo2.r;
			layer.Metalness 		= l_tRmo2.g;
			layer.AmbientOcclusion 	= l_tRmo2.b / AmbientOcclusionStrength;

			#if ( S_SECOND_LAYER == 2 )
				m = Material::lerp( m, layer, AdjustMask( m.Normal.b, g_flBlendContrast, g_flBlendStrength ) );
			#else
			 	m = Material::lerp( m, layer, l_tCmd.g );
			#endif
		#endif

		//
		// Write to shading model & return
		//
		return ShadingModelStandard::Shade( i, m );
	}
}