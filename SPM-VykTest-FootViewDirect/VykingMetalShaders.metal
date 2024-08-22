//
//  VykingMetalShaders.metal
//  VykingTrackerSDKTester
//
//  Created by Chris on 18/06/2019.
//  Copyright © 2019 vyking. All rights reserved.
//

#define USE_DEBUG_PROJECTIVE_WITH_ALPHA 0

#include <metal_stdlib>
using namespace metal;

#include <SceneKit/scn_metal>
typedef struct {
  float3 position  [[ attribute(SCNVertexSemanticPosition)  ]];
  float3 normal    [[ attribute(SCNVertexSemanticNormal)    ]];
  float2 texCoords [[ attribute(SCNVertexSemanticTexcoord0) ]];
} MyVertexInput;

// scene buffer data type see 
//struct SCNSceneBuffer {
//  float4x4    viewTransform;
//  float4x4    inverseViewTransform; // view space to world space
//  float4x4    projectionTransform;
//  float4x4    viewProjectionTransform;
//  float4x4    viewToCubeTransform; // view space to cube texture space (right-handed, y-axis-up)
//  float4      ambientLightingColor;
//  float4      fogColor;
//  float3      fogParameters; // x: -1/(end-start) y: 1-start*x z: exponent
//  float       time;     // system time elapsed since first render with this shader
//  float       sinTime;  // precalculated sin(time)
//  float       cosTime;  // precalculated cos(time)
//  float       random01; // random value between 0.0 and 1.0
//};

struct MyNodeBuffer {
  float4x4 modelTransform;
  float4x4 modelViewProjectionTransform;
  
  // l;ist of available per node data see https://developer.apple.com/documentation/scenekit/scnprogram?language=objc
  //  float4x4 modelTransform;
  //  float4x4 inverseModelTransform;
  //  float4x4 modelViewTransform;
  //  float4x4 inverseModelViewTransform;
  //  float4x4 normalTransform; // Inverse transpose of modelViewTransform
  //  float4x4 modelViewProjectionTransform;
  //  float4x4 inverseModelViewProjectionTransform;
  //  float2x3 boundingBox;
  //  float2x3 worldBoundingBox;
};

struct MyVertexOutput {
  float4 position [[position]];
  float4 rawPosition;
  float2 textureCoordinate;
  float  redValue ;
};
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
vertex MyVertexOutput SCNcameraVertexShader(MyVertexInput in [[ stage_in ]],
                                             constant SCNSceneBuffer& scn_frame [[ buffer(0) ]],
                                             constant MyNodeBuffer& scn_node    [[ buffer(1) ]],
                                             const device float4x4 & uvMatrix   [[ buffer(2) ]]
                                             ) {
  MyVertexOutput vert;
  // it seems that for scenekit we have to use the modelViewProjectionTransform matrix, even if we dont use the output in the
  // vertex shader. If we dont reference the modelViewProjectionTransform then the shader will not be run if the camera node is the only live node
  // otherwise the shader will not be run if the camera node is the onlyy active node
  // what a bad feature. This is really poor!
  // if we place a dummy call to use the modelViewProjectionTransform then the optimised removes it
  vert.rawPosition = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
  vert.position    = float4(in.position, 1.0);  // this is the position the fragment shade will use
  
  float4 newUV =  uvMatrix * float4( in.position.x ,
                                   -in.position.y ,  // turns y upside down
                                   0, 1 );
  
  vert.textureCoordinate.x = newUV.x ;
  vert.textureCoordinate.y = newUV.y ;
  
  return vert;
  
}
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
fragment float4 SCNcameraFragmentShader(MyVertexOutput in [[stage_in]],
                                       texture2d<float, access::sample> lumaTexture  [[texture(0)]],
                                       texture2d<float, access::sample> chromaTexture [[texture(1)]]
                                       ) {
  constexpr sampler textureSampler (coord::normalized,
                                    address::clamp_to_edge,
                                    filter::linear);
  
  const float4 lumaSample     = lumaTexture.sample(textureSampler, in.textureCoordinate);
  const float4 chromaSample   = chromaTexture.sample(textureSampler, in.textureCoordinate);
  
  const float4x4 ycbcrToRGBTransform = float4x4(
                                                float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                                float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                                float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                                float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
                                                );

  // if (is_null_texture(chromaTexture)) {
  //  return float4(lumaSample.r,0.0,0.0,1.0);
  // }
  
  return pow(ycbcrToRGBTransform * float4(lumaSample.r,chromaSample.rg,1.0),2.2);
}
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
struct MyNodeBufferOccluder {
  float4x4 modelTransform;
  float4x4 modelViewProjectionTransform;
  float4x4 modelViewTransform;
  
  // list of available per node data see https://developer.apple.com/documentation/scenekit/scnprogram?language=objc
  //  float4x4 modelTransform;
  //  float4x4 inverseModelTransform;
  //  float4x4 modelViewTransform;
  //  float4x4 inverseModelViewTransform;
  //  float4x4 normalTransform; // Inverse transpose of modelViewTransform
  //  float4x4 modelViewProjectionTransform;
  //  float4x4 inverseModelViewProjectionTransform;
  //  float2x3 boundingBox;
  //  float2x3 worldBoundingBox;
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
struct MyNoPerspectiveVertexOutput {
  float4 position         [[ position              ]];
  float3 normal           [[ center_no_perspective ]];
  float2 textureCoordinate[[ center_no_perspective ]];
  
  float3 EyeDirection_cameraspace;
  float3 Normal_cameraspace;

};
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
vertex MyNoPerspectiveVertexOutput SCNoccluderVertexShader(MyVertexInput in [[ stage_in ]],
                                              constant SCNSceneBuffer& scn_frame [[ buffer(0) ]],
                                              constant MyNodeBufferOccluder& scn_node    [[ buffer(1) ]],
                                              const device float4x4 & uvMatrix   [[ buffer(2) ]]
                                              ) {
  MyNoPerspectiveVertexOutput vert;
  
  vert.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
  
  float4 newUV = uvMatrix * float4( vert.position.x / vert.position.w,
                                   -vert.position.y / vert.position.w ,  // turns y upside down
                                   0, 1 );
  
  vert.textureCoordinate = newUV.xy / newUV.w ;
  
  float3 vetextPosition_cameraspace = (scn_node.modelViewTransform * float4(in.position, 1.0)).xyz ;
  vert.EyeDirection_cameraspace   = float3(0.0,0.0,0.0) - vetextPosition_cameraspace ;
  vert.Normal_cameraspace          = (scn_node.modelViewTransform * float4(in.normal,0.0)).xyz;

  return vert;
  
}
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
fragment float4 SCNoccluderFragmentShader(MyNoPerspectiveVertexOutput in [[stage_in]],
                                          texture2d<float, access::sample> lumaTexture   [[texture(0)]],
                                          texture2d<float, access::sample> chromaTexture [[texture(1)]],
                                          texture2d<float, access::sample> alphaTexture  [[texture(2)]],
                                          const device int & alphaChannelSelector        [[ buffer(2) ]]
                                              ) {
  constexpr sampler textureSampler (coord::normalized,
                                    address::clamp_to_edge,
                                    filter::linear);
  
  const float4 lumaSample   = lumaTexture.sample(textureSampler, in.textureCoordinate);
  const float4 chromaSample = chromaTexture.sample(textureSampler, in.textureCoordinate);
  const float4 alphaSample  = alphaTexture.sample(textureSampler, in.textureCoordinate);
  
  float alphaValue = alphaSample[ alphaChannelSelector];
  
  // if alpha too small discard the fragment
  if( alphaValue < 0.1 ) {
    #if USE_DEBUG_PROJECTIVE_WITH_ALPHA
    float premultipledAlphaValue = 0.5;
    
    return (float4( 1.0,1.0,1.0,1.0 ) * premultipledAlphaValue) ;
    #endif
    
    discard_fragment();
  }
  
 // return float4(1.0,1.0,0.0,1.0); // Uncomment this to see the segmentation mask
  #if !USE_DEBUG_PROJECTIVE_WITH_ALPHA
  const float4x4 ycbcrToRGBTransform = float4x4(
                                                float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                                float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                                float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                                float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
                                                );
  
  return pow(ycbcrToRGBTransform * float4(lumaSample.r,chromaSample.rg,1.0),2.2);
  #else
  // return alphaSample;
  return lumaSample;
  #endif
}


// Vertex shader outputs and per-fragment inputs. Includes clip-space position and vertex outputs
//  interpolated by rasterizer and fed to each fragment generated by clip-space primitives.
typedef struct
{
  // The [[position]] attribute qualifier of this member indicates this value is the clip space
  //   position of the vertex wen this structure is returned from the vertex shader
  float4 clipSpacePosition [[position]];
  
  // Since this member does not have a special attribute qualifier, the rasterizer will
  //   interpolate its value with values of other vertices making up the triangle and
  //   pass that interpolated value to the fragment shader for each fragment in that triangle;
  float2 textureCoordinate;
  
} RasterizerData;

// Vertex Function
vertex RasterizerData
XXXXRGBA_CSR_vertexShader_V1(uint                        vertexID     [[ vertex_id ]],
                         const device packed_float3* vertex_array [[ buffer(0) ]],
                         const device float4x4     & uvMatrix     [[ buffer(1) ]] )

{
  
  RasterizerData out;
  
  // Index into our array of positions to get the current vertex
  //   Our positions are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from
  //   the origin)
  float2 pixelSpacePosition;
  pixelSpacePosition.x = vertex_array[vertexID][0];
  pixelSpacePosition.y = vertex_array[vertexID][1];
  
  // In order to convert from positions in pixel space to positions in clip space we divide the
  //   pixel coordinates by half the size of the viewport.
  out.clipSpacePosition.xy = pixelSpacePosition;
  
  // Set the z component of our clip space position 0 (since we're only rendering in
  //   2-Dimensions for this sample)
  out.clipSpacePosition.z = 0.0;
  
  // Set the w component to 1.0 since we don't need a perspective divide, which is also not
  //   necessary when rendering in 2-Dimensions
  out.clipSpacePosition.w = 1.0;
  
  // scale the texture coords to be matched to the vertex array (-1..1) -> (0..1)
  // the operation transforms the (-1,-1) to (+1,+1) coords to (0,0) to (1,1)
  // float4 newUV = uvMatrix * float4( (pixelSpacePosition.x + 1 ) / 2.0,
  //                                  (-pixelSpacePosition.y + 1 ) / 2.0,
  //                                 0, 1 );
  float4 newUV = uvMatrix * float4( pixelSpacePosition.x ,
                                   -pixelSpacePosition.y ,  // turns y upside down
                                   0, 1 );
  
  out.textureCoordinate.x = newUV.x ;
  out.textureCoordinate.y = newUV.y ;
  
  // out.textureCoordinate.x = (pixelSpacePosition.x + 1 ) / 2.0 ;
  // out.textureCoordinate.y = (-pixelSpacePosition.y + 1 ) / 2.0 ;
  return out;
}

// Fragment function
fragment float4
XXXXRGBA_CSR_fragmentShader_V1(RasterizerData in [[stage_in]],
                           texture2d<half> lumaTexture  [[ texture(0) ]],
                           texture2d<half> chromaTexture [[ texture(1) ]])
{
  // constexpr sampler textureSampler (mag_filter::linear,
  //                                   min_filter::linear);
  //
  // The coord value may either be normalized or pixel.
  // possible values for address are clamp_to_zero, clamp_to_edge, repeat, mirrored_repeat
  // possible values for filter are nearest and linear, to select between nearest-neighbor and linear filtering.
  // http://metalbyexample.com/textures-and-samplers/
  constexpr sampler textureSampler (coord::normalized,
                                    address::clamp_to_edge,
                                    filter::linear);
  
  // Sample the texture to obtain a color
  const half4 lumaSample   = lumaTexture.sample(textureSampler, in.textureCoordinate);
  
  // #if __METAL_VERSION__ >= 100   // added by CK 2020-01-14
  if (is_null_texture(chromaTexture)) {
    return float4(lumaSample.r,lumaSample.g,lumaSample.b,1.0);
  }
  // #endif
  
  const half4 chromaSample = chromaTexture.sample(textureSampler, in.textureCoordinate);
  
  #if 1
  const half4x4 ycbcrToRGBTransform = half4x4(
                                                half4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                                half4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                                half4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                                half4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
                                                );

  half4 val = half4(lumaSample.r,chromaSample.rg,1.0);
  val = ycbcrToRGBTransform * val;
  
  half4 fval = pow(val,2.2 );
  
  return float4( fval );
  #else
  // We return the color of the texture
  // return float4(1.0);
  // if( in.textureCoordinate.y < 0.1 ) return float4(1.0);
  // if( in.textureCoordinate.x < 0.1 ) return float4(0.75);
  
  return float4(lumaSample);
  #endif
}
// ------------------------------------------------------------------------------------------------------------------------

// Vertex Function
vertex RasterizerData XXXXCSR_vertexShader_V1(uint  vertexID[[ vertex_id ]],
                                          const device packed_float3 *vertex_array[[ buffer(0) ]],
                                          const device float4x4      &uvMatrix[[ buffer(1) ]]) {
  RasterizerData out;
  
  // Index into our array of positions to get the current vertex
  //   Our positions are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from
  //   the origin)
  float2 pixelSpacePosition;
  pixelSpacePosition.x = vertex_array[vertexID][0];
  pixelSpacePosition.y = vertex_array[vertexID][1];
  
  // In order to convert from positions in pixel space to positions in clip space we divide the
  //   pixel coordinates by half the size of the viewport.
  out.clipSpacePosition.xy = pixelSpacePosition;
  
  // Set the z component of our clip space position 0 (since we're only rendering in
  //   2-Dimensions for this sample)
  out.clipSpacePosition.z = 0.0;
  
  // Set the w component to 1.0 since we don't need a perspective divide, which is also not
  //   necessary when rendering in 2-Dimensions
  out.clipSpacePosition.w = 1.0;
  
  // scale the texture coords to be matched to the vertex array (-1..1) -> (0..1)
  // the operation transforms the (-1,-1) to (+1,+1) coords to (0,0) to (1,1)
  // float4 newUV = uvMatrix * float4( (pixelSpacePosition.x + 1 ) / 2.0,
  //                                  (-pixelSpacePosition.y + 1 ) / 2.0,
  //                                 0, 1 );
  float4 newUV = uvMatrix * float4( pixelSpacePosition.x ,
                                   -pixelSpacePosition.y ,  // turns y upside down
                                   0, 1 );
  
  out.textureCoordinate.x = newUV.x ;
  out.textureCoordinate.y = newUV.y ;
  
  // out.textureCoordinate.x = (pixelSpacePosition.x + 1 ) / 2.0 ;
  // out.textureCoordinate.y = (-pixelSpacePosition.y + 1 ) / 2.0 ;
  return out;
}

// Fragment function
fragment float4 XXXXCSR_fragmentShader_V1(RasterizerData in [[stage_in]],texture2d<half> colorTexture [[ texture(0) ]]) {
  // constexpr sampler textureSampler (mag_filter::linear,
  //                                   min_filter::linear);
  //
  // The coord value may either be normalized or pixel.
  // possible values for address are clamp_to_zero, clamp_to_edge, repeat, mirrored_repeat
  // possible values for filter are nearest and linear, to select between nearest-neighbor and linear filtering.
  // http://metalbyexample.com/textures-and-samplers/
  constexpr sampler textureSampler (coord::normalized,
                                    address::clamp_to_edge,
                                    filter::linear);
  
  // Sample the texture to obtain a color
  const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
  
  // We return the color of the texture
  // return float4(1.0);
  // return float4(0.2,0.4,0.6,1.0);
  // if( in.textureCoordinate.y < 0.1 ) return float4(1.0);
  // if( in.textureCoordinate.x < 0.1 ) return float4(0.75);
  
  return float4(colorSample);
}

// --------------------------------------------------------------------------------------
// Fragment function
fragment float4
XXXX_SEG_fragmentShader_V2_Vaverage(RasterizerData in [[stage_in]],
                               texture2d<half> colorTexture     [[ texture(0) ]],
                               texture2d<half> fusionTexture    [[ texture(1) ]],
                               const device int &halfReach      [[ buffer(1)  ]],
                               const device float &fusionFactor [[ buffer(2) ]]
                               )
{
  // #define HALF_Y_REACH 5
  uint txW = colorTexture.get_width();
  uint txH = colorTexture.get_height();
  
  uint xCoord = uint( in.textureCoordinate.x * txW );
  uint yCoord = uint( in.textureCoordinate.y * txH );
  
  //  int startY = int( yCoord ) - HALF_Y_REACH;
  //  int endY   = int( yCoord ) + HALF_Y_REACH;

  int startY = int( yCoord ) - halfReach;
  int endY   = int( yCoord ) + halfReach;

  if( startY < 0          ) startY = 0;
  if( endY   > int( txH ) ) endY   = int( txH );
  
  half4 sum = { 0.0,0.0,0.0,0.0 } ;
  
  for(uint i=uint( startY );i<= uint( endY );i++) {
    half4 cValue = colorTexture.read( { xCoord,    i } );
    sum = sum + cValue;
  }
  
  half4 fusionValue = fusionTexture.read( { xCoord, yCoord } );
  half4 vcolour     = sum / half( endY - startY + 1 );
  
  float4 colourValue = float4( (fusionFactor * vcolour) + ((1.0 - fusionFactor) * fusionValue) );
  // float4 colourValue = float4( (fusionFactor * vcolour) );
  // float4 colourValue = float4( fusionValue );
  
  // return float4( 1.0,1.0,1.0,1.0 );
  // float4 colourValue = float4( (sum / half( endY - startY + 1 )) + fusionValue);
  
  //  if( colourValue.r > 0.5 ) { colourValue.r = 1.0 ; } else { colourValue.r = 0.0 ; }
  //  if( colourValue.g > 0.5 ) { colourValue.g = 1.0 ; } else { colourValue.g = 0.0 ; }
  //  if( colourValue.b > 0.5 ) { colourValue.b = 1.0 ; } else { colourValue.b = 0.0 ; }
  // return float4( 0.0,0.0,0.0,1.0 );
  
  return colourValue;
  
  // loop and average // CK WAS HERE
  
  //  for(int i=)
  //  half4 Up    = colorTexture.read( {xCoord,    yCoord + 1} );
  //  half4 Down  = colorTexture.read( {xCoord,    yCoord - 1} );
  //  half4 Right = colorTexture.read( {xCoord + 1,yCoord    } );
  //  half4 Left  = colorTexture.read( {xCoord - 1,yCoord    } );
  //
  //  return float4( Right.r - Left.r ,Up.r - Down.r, 0.0, 0.0 );
}
// --------------------------------------------------------------------------------------
// Fragment function
fragment float4
XXXX_SEG_fragmentShader_V2_Theshold(RasterizerData in [[stage_in]],
                               texture2d<half> colorTexture [[ texture(0) ]]
                                )
{
  uint txW = colorTexture.get_width();
  uint txH = colorTexture.get_height();
  
  uint xCoord = uint( in.textureCoordinate.x * txW );
  uint yCoord = uint( in.textureCoordinate.y * txH );
  
  // return float4( 1.0,1.0,1.0,1.0 );
  
  float4 colourValue = float4( colorTexture.read( { xCoord, yCoord } ));
  
  if( colourValue.r > 0.5 ) { colourValue.r = 1.0 ; } else { colourValue.r = 0.0 ; }
  if( colourValue.g > 0.5 ) { colourValue.g = 1.0 ; } else { colourValue.g = 0.0 ; }
  if( colourValue.b > 0.5 ) { colourValue.b = 1.0 ; } else { colourValue.b = 0.0 ; }
  
  return colourValue;
}

vertex RasterizerData
SEG_vertexShader_V2(uint                        vertexID     [[ vertex_id ]],
                    const device packed_float3* vertex_array [[ buffer(0) ]],
                    const device float4x4      &uvMatrix     [[ buffer(1) ]])
{
  
  RasterizerData out;
  
  // Index into our array of positions to get the current vertex
  //   Our positions are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from
  //   the origin)
  float2 pixelSpacePosition;
  pixelSpacePosition.x = vertex_array[vertexID][0];
  pixelSpacePosition.y = vertex_array[vertexID][1];
  
  // In order to convert from positions in pixel space to positions in clip space we divide the
  //   pixel coordinates by half the size of the viewport.
  out.clipSpacePosition.xy = pixelSpacePosition;
  
  // Set the z component of our clip space position 0 (since we're only rendering in
  //   2-Dimensions for this sample)
  out.clipSpacePosition.z = 0.0;
  
  // Set the w component to 1.0 since we don't need a perspective divide, which is also not
  //   necessary when rendering in 2-Dimensions
  out.clipSpacePosition.w = 1.0;
  
  
  #if 0
  out.textureCoordinate.x = (pixelSpacePosition.x + 1 ) / 2.0 ;
  out.textureCoordinate.y = (-pixelSpacePosition.y + 1 ) / 2.0 ;
  #else
  float4 newUV = uvMatrix * float4( pixelSpacePosition.x ,
                                   -pixelSpacePosition.y ,  // turns y upside down
                                   0, 1 );
  
  out.textureCoordinate.x = newUV.x ;
  out.textureCoordinate.y = newUV.y ;
  #endif
  
  return out;
}

// Fragment function
fragment float4
SEG_fragmentShader_V2_ScaleUp(RasterizerData in [[stage_in]],
                              texture2d<half> colorTexture [[ texture(0) ]])
{
  // constexpr sampler textureSampler (mag_filter::linear,
  //                                   min_filter::linear);
  //
  // The coord value may either be normalized or pixel.
  // possible values for address are clamp_to_zero, clamp_to_edge, repeat, mirrored_repeat
  // possible values for filter are nearest and linear, to select between nearest-neighbor and linear filtering.
  // http://metalbyexample.com/textures-and-samplers/
  constexpr sampler textureSampler (coord::normalized,
                                    address::clamp_to_edge,
                                    filter::linear);
  
  // Sample the texture to obtain a color
  const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
  
  // We return the color of the texture
  // return float4(1.0);
  // if( in.textureCoordinate.y < 0.1 ) return float4(1.0);
  // if( in.textureCoordinate.x < 0.1 ) return float4(0.75);
  
  return float4(colorSample);
}

