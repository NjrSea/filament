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
@property (nonatomic, assign)  CGFloat  bearing_y;
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
@property (nonatomic, readonly) NSString *fontName;
@property (nonatomic, readonly) NSString *fontTextureName;

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
        NSString *fontFrame = [NSString stringWithFormat:@"%@.plist", self.fontName];


        [self p_loadFontMetricsWithName:self.fontName];
        [self p_loadFontFramesWithName:fontFrame];
    }

    return self;
}

- (NSString *)fontName {
    //        NSString *fontName = @"OpenSans-Regular";
    NSString *fontName = @"Roboto-Medium";
    return fontName;
}

- (NSString *)fontTextureName {
    return [NSString stringWithFormat:@"%@.png", [self fontName]];
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

    NSString *key = [[NSString stringWithFormat:@"0x%04X", charValue] lowercaseString];

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


    _imageTexture0 = [self p_loadTexture:[SDFFontManager sharedManager].fontTextureName];

    TextureSampler sampler(MinFilter::LINEAR, MagFilter::LINEAR);

    // init must be called before we can build any materials.
    filamat::MaterialBuilder::init();

    // Compile a custom material to use on the triangle.
    filamat::Package pkg = filamat::MaterialBuilder()
    // The material name, only used for debugging purposes.
        .name("Quad material")
        .flipUV(false)
    // Use the unlit shading mode, because we don't have any lights in our scene.
        .shading(filamat::MaterialBuilder::Shading::UNLIT)
        .require(VertexAttribute::POSITION)
        .require(VertexAttribute::UV0)
        .blending(BlendingMode::TRANSPARENT) // 注意这里要设置，不然没有透明效果
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
                  "  float4 distanceVec = texture(materialParams_image0, getUV0());"
                  "float distance = length(distanceVec.rgb);"
                  "float finalColor = smoothstep(materialParams.fontWidth - materialParams.smoothing, materialParams.fontWidth + materialParams.smoothing, distance);"
                  "  material.baseColor = vec4(finalColor);"
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
        .culling(false)
        .receiveShadows(false)
        .castShadows(false)
        .build(*_engine, _renderable);

    NSString *text = @"It is a period of civil war.\n"
    @"Rebel spaceships, striking\n"
    @"from a hidden base, have won\n"
    @"their first victory against\n"
    @"the evil Galactic Empire.\n"
    @"\n"
    @"During the battle, Rebel\n"
    @"spies managed to steal secret\n"
    @"plans to the Empire's\n"
    @"ultimate weapon, the DEATH\n"
    @"STAR, an armored space\n"
    @"station with enough power to\n"
    @"destroy an entire planet.\n"
    @"\n"
    @"Pursued by the Empire's\n"
    @"sinister agents, Princess\n"
    @"Leia races home aboard her\n"
    @"starship, custodian of the\n"
    @"stolen plans that can save\n"
    @"her people and restore\n"
    @"freedom to the galaxy.....";
    [self p_drawCharacter:text];

    _scene->addEntity(_renderable);


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

    double scale = 10;
    const double aspect = size.width / size.height;
    const double left = -scale * aspect;
    const double right = scale * aspect;
    const double bottom = -scale;
    const double top = scale;
    const double near = 0; // why? ortho projection
    const double far = 2.0; // why? ortho projection

    _camera->setProjection(Camera::Projection::ORTHO, left, right, bottom, top, near, far);
}



- (void)p_drawCharacter:(NSString *)string {
    auto& rm = _engine->getRenderableManager();
    auto instance = rm.getInstance(_renderable);

    auto atlasData = [[SDFFontManager sharedManager] atlasData];
    auto metrics = [[SDFFontManager sharedManager] metrics];

    auto lines = [string componentsSeparatedByString:@"\n"];

    static std::vector<Vertex> font_vertices; // 这里需要把顶点数据交给filament，在 buffer descriptor的callback里销毁数据 或者不变的情况下用static数据
    static std::vector<uint16_t> font_indices;

    CGFloat cursorX = 0;
    CGFloat cursorY = 0;
    uint16_t linesVerticesCount = 0;

    for (NSString *line in lines) {
        for(int i = 0; i < line.length; i++){
            NSRange range = [line rangeOfComposedCharacterSequenceAtIndex:i];
            NSString *ch = [line substringWithRange:range];

            AtlasFrame *frameOfChar = [[SDFFontManager sharedManager] atlasFrameForCharacter:ch];
            GlyphData *glyphOfChar = [[SDFFontManager sharedManager] metricsForCharacter:ch];

            CGFloat atlasWidth = atlasData.meta.width;
            CGFloat atlasHeight = atlasData.meta.height;

            float w = frameOfChar.w / atlasWidth;
            float h = frameOfChar.h / atlasHeight;
            float s0 = frameOfChar.x / atlasWidth;
            float t0 = frameOfChar.y / atlasHeight;
            float s1 = s0 + w;
            float t1 = t0 + h;

            float glyphWidth = glyphOfChar.bbox_width;
            float glyphHeight = glyphOfChar.bbox_height;
            float glyphBearingX = glyphOfChar.bearing_x;
            float glyphBearingY = glyphOfChar.bearing_y;
            float glyphAdvanceX = glyphOfChar.advance_x;

            float x = cursorX + glyphBearingX;
            float y = cursorY + glyphBearingY;

            Vertex v1 = {{x, y - glyphHeight}, {s0, t1}};
            Vertex v2 = {{x + glyphWidth, y - glyphHeight}, {s1, t1}};
            Vertex v3 = {{x, y}, {s0, t0}};
            Vertex v4 = {{x + glyphWidth, y}, {s1, t0}};

            cursorX += glyphAdvanceX;

            font_vertices.push_back(v1);
            font_vertices.push_back(v2);
            font_vertices.push_back(v3);
            font_vertices.push_back(v4);

            uint16_t curIndex = linesVerticesCount + i * 4;
            font_indices.push_back(curIndex + 0);
            font_indices.push_back(curIndex + 1);
            font_indices.push_back(curIndex + 2);
            font_indices.push_back(curIndex + 1);
            font_indices.push_back(curIndex + 3);
            font_indices.push_back(curIndex + 2);

        }
        cursorX = 0;
        cursorY -= metrics.height;
        linesVerticesCount += font_vertices.size();
    }



    VertexBuffer::BufferDescriptor vertices(font_vertices.data(), sizeof(Vertex) * font_vertices.size(), [](void* buffer, size_t size, void* user) {

    });
    IndexBuffer::BufferDescriptor indices(font_indices.data(), sizeof(uint16_t) * font_indices.size(), nullptr);

    using Type = VertexBuffer::AttributeType;
    const uint8_t stride = sizeof(Vertex);
    _vertexBuffer = VertexBuffer::Builder()
        .vertexCount((uint32_t)(font_vertices.size()))
        .bufferCount(1)
        .attribute(VertexAttribute::POSITION, 0, Type::FLOAT2, offsetof(Vertex, position), stride)
        .attribute(VertexAttribute::UV0, 0, Type::FLOAT2, offsetof(Vertex, uv), stride)
        .build(*_engine);

    _indexBuffer = IndexBuffer::Builder()
        .indexCount((uint32_t)font_indices.size())
        .bufferType(IndexBuffer::IndexType::USHORT)
        .build(*_engine);

    _vertexBuffer->setBufferAt(*_engine, 0, std::move(vertices));
    _indexBuffer->setBuffer(*_engine, std::move(indices));

    rm.setGeometryAt(instance, 0, RenderableManager::PrimitiveType::TRIANGLES, _vertexBuffer, _indexBuffer, 0, (uint32_t)font_indices.size());
    rm.setMaterialInstanceAt(instance, 0, _materialInstance);


    auto& tm = _engine->getTransformManager();
    auto transformInstance = tm.getInstance(_renderable);
    math::mat4f transform = math::mat4f::translation(math::float3{-4.5, 4.5, 0}) * math::mat4f::scaling(0.4);
    tm.setTransform(transformInstance, transform);

}



#pragma mark - MTKViewDelegate

- (void)update {
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
