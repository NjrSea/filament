//
//  SDFFontRendererViewController.m
//  HelloCocoaPods
//
//  Created by wang ya on 2022/4/11.
//  Copyright © 2022 Google. All rights reserved.
//

#import "SDFFontRendererViewController.h"
#import <Foundation/Foundation.h>
#import <MJExtension.h>
#include <filament/Engine.h>
#import <MetalKit/MTKView.h>
#include <filament/SwapChain.h>
#include <filament/Renderer.h>
#include <filament/View.h>
#include <filament/Camera.h>
#include <filament/Scene.h>
#include <filament/Viewport.h>

#include <utils/Entity.h>
#include <utils/EntityManager.h>

#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <filament/RenderableManager.h>

#include <filament/Material.h>
#include <filament/MaterialInstance.h>

#include <filamat/MaterialBuilder.h>

#include <filament/TransformManager.h>

#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/VertexBuffer.h>
#include "resources.h"

#include <utils/Path.h>

#include "stb_image.h"

#include <iostream> // for cerr

using namespace filament;
using namespace utils;

using MinFilter = TextureSampler::MinFilter;
using MagFilter = TextureSampler::MagFilter;

using SamplerType = filament::backend::SamplerType;
using SubpassType = filament::backend::SubpassType;
using SamplerFormat = filament::backend::SamplerFormat;
using ParameterPrecision = filament::backend::Precision;
using CullingMode = filament::backend::CullingMode;
using UniformType = filament::backend::UniformType;

struct Vertex {
    math::float2 position;
    math::float2 uv;
};

@interface AtlasFrame : NSObject

@property (nonatomic, assign) CGFloat x;
@property (nonatomic, assign) CGFloat y;
@property (nonatomic, assign) CGFloat w;
@property (nonatomic, assign) CGFloat h;

@end

@implementation AtlasFrame

@end

@interface AtlasMetaData : NSObject

@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, copy)   NSString *image;

@end

@implementation AtlasMetaData

@end

@interface GlyphData : NSObject

@property (nonatomic, assign)  CGFloat advance_x;
@property (nonatomic, assign)  CGFloat bbox_height;
@property (nonatomic, assign)  CGFloat bbox_width;
@property (nonatomic, assign)  CGFloat  bearing_x;
@property (nonatomic, assign)  CGFloat bearing_y;
@property (nonatomic, copy)     NSString *charcode;
@property (nonatomic, copy)     NSDictionary *kernings;
@property (nonatomic, assign)  CGFloat s0;
@property (nonatomic, assign)  CGFloat s1;
@property (nonatomic, assign)  CGFloat t0;
@property (nonatomic, assign)  CGFloat t1;

@end

@implementation GlyphData

@end

@interface AtlasData : NSObject

@property (nonatomic, strong) AtlasMetaData *meta;
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary<NSString *, NSNumber *> *> *frames;

@end

@implementation AtlasData

@end

@interface FontMetrics : NSObject

@property (nonatomic, assign) CGFloat ascender;
@property (nonatomic, assign) CGFloat descender;
@property (nonatomic, assign) NSDictionary *glyph_data;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat max_advance;
@property (nonatomic, assign) CGFloat name;
@property (nonatomic, assign) CGFloat size;
@property (nonatomic, assign) CGFloat space_advance;

@end

@implementation FontMetrics

@end

@interface SDFFontManager ()

@property (nonatomic, strong) FontMetrics *metrics;
@property (nonatomic, strong) AtlasData *atlasData;

@end

@implementation SDFFontManager

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static SDFFontManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[SDFFontManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        [self p_loadFontMetricsWithName:@"OpenSans-Regular"];
        [self p_loadFontFramesWithName:@"OpenSans-Regular.plist"];
    }

    return self;
}

- (void)p_loadFontMetricsWithName:(NSString *)name {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"json"];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]
                                                               options:0
                                                                 error:nil];
    _metrics = [FontMetrics mj_objectWithKeyValues:dictionary];
    NSMutableDictionary *glyphDic = [NSMutableDictionary dictionary];

    [_metrics.glyph_data enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSDictionary * _Nonnull obj, BOOL * _Nonnull stop) {
        glyphDic[key] = [GlyphData mj_objectWithKeyValues:obj];
    }];
    _metrics.glyph_data = glyphDic;
}

- (void)p_loadFontFramesWithName:(NSString *)name {
    _atlasData = [AtlasData mj_objectWithFilename:name];
}

- (GlyphData *)metricsForCharacter:(NSString *)ch {
    return [[self.metrics glyph_data] objectForKey:ch];
}

- (AtlasFrame *)atlasFrameForCharacter:(NSString *)ch {
    auto charValue = [ch characterAtIndex:0];

   NSString *key = [NSString stringWithFormat:@"0x%04X", charValue];

    NSDictionary *frameDic = self.atlasData.frames[key];

    return [AtlasFrame mj_objectWithKeyValues:frameDic];
}

@end


@interface SDFFontRendererViewController () <MTKViewDelegate>

@end

@implementation SDFFontRendererViewController {
    struct SDFParams {
        float smoothing;
        float fontWidth;
        float outlineWidth;
        float shadowWidth;
        math::float2 shadowOffset;
        math::float4 shadowColor;
        math::float4 fontColor;
        math::float4 outlineColor;

    } _params;
    Engine *_engine;
    SwapChain *_swapChain;
    Renderer *_renderer;
    View *_view;
    Scene *_scene;
    Camera *_camera;
    Entity _cameraEntity;
    VertexBuffer *_vertexBuffer;
    IndexBuffer *_indexBuffer;
    Material *_material;
    MaterialInstance *_materialInstance;
    Texture *_imageTexture0;
    Entity _renderable;
}

- (void)dealloc {
    _engine->destroy(_renderable);
    _engine->destroy(_materialInstance);
    _engine->destroy(_material);
    _engine->destroy(_imageTexture0);
    _engine->destroy(_indexBuffer);
    _engine->destroy(_vertexBuffer);
    _engine->destroy(_cameraEntity);
    _engine->destroy(_scene);
    _engine->destroy(_view);
    _engine->destroy(_renderer);
    _engine->destroy(_swapChain);
    Engine::destroy(&_engine);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _params.outlineWidth = 0.5;
    _params.fontWidth = 0.9;
    _params.smoothing = 0.1;
    _params.shadowOffset = {0, 0};
    _params.shadowColor = math::float4({0, 0, 0, 1});
    _params.outlineColor = math::float4({0, 0, 0, 1});
    _params.fontColor = math::float4({0, 0, 1, 1});

    [SDFFontManager sharedManager];
    [self p_setupFilament];
}

- (void)p_setupFilament {
    _engine = Engine::create(Engine::Backend::METAL);

    MTKView *mtkView = (MTKView *)self.view;
    mtkView.delegate = self;
    // __bridge 类型转换，不涉及所有权转换
    _swapChain = _engine->createSwapChain((__bridge void *)mtkView.layer);

    _renderer = _engine->createRenderer();
    _view = _engine->createView();
    _scene = _engine->createScene();
    _cameraEntity = EntityManager::get().create();
    _camera = _engine->createCamera(_cameraEntity);

    _renderer->setClearOptions({
        .clearColor = {0.25f, 0.5f, 1.0f, 1.0f},
        .clear = true
    });

    _view->setScene(_scene);
    _view->setCamera(_camera);

    [self p_resize:mtkView.drawableSize];

    static const Vertex QUAD_VERTICES[4] = {
        {{-1, -1}, {0, 0}},
        {{ 1, -1}, {1, 0}},
        {{-1,  1}, {0, 1}},
        {{ 1,  1}, {1, 1}},
    };
    static const uint16_t QUAD_INDICES[6] = { 0, 1, 2, 3, 2, 1 };

    VertexBuffer::BufferDescriptor vertices(QUAD_VERTICES, sizeof(Vertex) * 4, nullptr);
    IndexBuffer::BufferDescriptor indices(QUAD_INDICES, sizeof(uint16_t) * 6, nullptr);

    using Type = VertexBuffer::AttributeType;
    const uint8_t stride = sizeof(Vertex);
    _vertexBuffer = VertexBuffer::Builder()
        .vertexCount(4)
        .bufferCount(1)
        .attribute(VertexAttribute::POSITION, 0, Type::FLOAT2, offsetof(Vertex, position), stride)
        .attribute(VertexAttribute::UV0, 0, Type::FLOAT2, offsetof(Vertex, uv), stride)
        .build(*_engine);

    _indexBuffer = IndexBuffer::Builder()
        .indexCount(6)
        .bufferType(IndexBuffer::IndexType::USHORT)
        .build(*_engine);

    _vertexBuffer->setBufferAt(*_engine, 0, std::move(vertices));
    _indexBuffer->setBuffer(*_engine, std::move(indices));

    _imageTexture0 = [self p_loadTexture:@"OpenSans-Regular.png"];

    TextureSampler sampler(MinFilter::LINEAR, MagFilter::LINEAR);

    // init must be called before we can build any materials.
    filamat::MaterialBuilder::init();

    // Compile a custom material to use on the triangle.
    filamat::Package pkg = filamat::MaterialBuilder()
    // The material name, only used for debugging purposes.
        .name("Quad material")
    // Use the unlit shading mode, because we don't have any lights in our scene.
        .shading(filamat::MaterialBuilder::Shading::UNLIT)
        .require(VertexAttribute::POSITION)
        .require(VertexAttribute::UV0)
        .parameter(SamplerType::SAMPLER_2D, SamplerFormat::FLOAT, "image0")
        .parameter(UniformType::FLOAT,  "smoothing")
        .parameter(UniformType::FLOAT,  "fontWidth")
        .parameter(UniformType::FLOAT,  "outlineWidth")
        .parameter(UniformType::FLOAT2, "shadowOffset")
        .parameter(UniformType::FLOAT4, "shadowColor")
        .parameter(UniformType::FLOAT4, "outlineColor")
        .parameter(UniformType::FLOAT4, "fontColor")
    // Custom GLSL fragment code.
        .material("void material (inout MaterialInputs material) {"
                  "  prepareMaterial(material);"
                  "  float4 imageColor0 = texture(materialParams_image0, getUV0());"
                  "  material.baseColor = imageColor0;"
                  "}")
    // Compile for Metal on mobile platforms.
        .targetApi(filamat::MaterialBuilder::TargetApi::METAL)
        .platform(filamat::MaterialBuilder::Platform::MOBILE)
        .build(_engine->getJobSystem());
    assert(pkg.isValid());

    // We're done building materials.
    filamat::MaterialBuilder::shutdown();

    // Create a Filament material from the Package.
    _material = Material::Builder()
        .package(pkg.getData(), pkg.getSize())
        .build(*_engine);


    _materialInstance = _material->createInstance();
    _materialInstance->setParameter("image0", _imageTexture0, sampler);
    _materialInstance->setParameter("smoothing", _params.smoothing);
    _materialInstance->setParameter("fontWidth", _params.fontWidth);
    _materialInstance->setParameter("shadowOffset", _params.shadowOffset);
    _materialInstance->setParameter("shadowColor", _params.shadowColor);
    _materialInstance->setParameter("outlineWidth", _params.outlineWidth);
    _materialInstance->setParameter("outlineColor", _params.outlineColor);
    _materialInstance->setParameter("fontColor", _params.smoothing);

    _renderable = EntityManager::get().create();
    RenderableManager::Builder(1)
        .boundingBox({{ -1, -1, -1 }, { 1, 1, 1 }})
        .material(0, _materialInstance)
        .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, _vertexBuffer, _indexBuffer, 0, 6)
        .culling(false).receiveShadows(false).castShadows(false).build(*_engine, _renderable);
    _scene->addEntity(_renderable);

    [self p_drawCharacter:@"I"];
}

- (Texture *)p_loadTexture:(NSString *)name {

    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:nil];
    int w, h, n;
    unsigned char* data = stbi_load(path.cString, &w, &h, &n, 4);

    if (data == nullptr) {
        std::cerr << "The texture " << path << " could not be loaded" << std::endl;
        exit(1);
    }

    Texture::PixelBufferDescriptor buffer(data, size_t(h * w * 4),
                                          Texture::Format::RGBA,
                                          Texture::Type::UBYTE,
                                          (Texture::PixelBufferDescriptor::Callback) &stbi_image_free);

    auto* texture = Texture::Builder()
        .width(w)
        .height(h)
        .levels(1)
        .sampler(Texture::Sampler::SAMPLER_2D)
        .format(Texture::InternalFormat::RGBA8)
        .build(*_engine);

    texture->setImage(*_engine, 0, std::move(buffer));
    return texture;
}

- (void)p_resize:(CGSize)size {
    _view->setViewport({0, 0, (uint32_t)size.width, (uint32_t)size.height});

    const double aspect = size.width / size.height;
    const double left = -2.0 * aspect;
    const double right = 2 * aspect;
    const double bottom = -2.0;
    const double top = 2.0;
    const double near = 0; // why? ortho projection
    const double far = 1.0; // why? ortho projection

    _camera->setProjection(Camera::Projection::ORTHO, left, right, bottom, top, near, far);
}



- (void)p_drawCharacter:(NSString *)ch {

    [[SDFFontManager sharedManager] atlasFrameForCharacter:ch];
    NSLog(@"");
}


#pragma mark - MTKViewDelegate

- (void)update {
    //    auto& tm = _engine->getTransformManager();
    //    auto i = tm.getInstance(_triangle);
    //    const auto time = CACurrentMediaTime();
    //    tm.setTransform(i, math::mat4f::rotation(time, math::float3 {0.0, 0.0, 1.0}));
}


- (void)drawInMTKView:(nonnull MTKView *)view {
    [self update];
    if (_renderer->beginFrame(_swapChain)) {
        _renderer->render(_view);
        _renderer->endFrame();
    }
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self p_resize:size];
}

@end
