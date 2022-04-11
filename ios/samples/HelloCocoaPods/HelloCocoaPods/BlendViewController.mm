//
//  BlendViewController.m
//  HelloCocoaPods
//
//  Created by wang ya on 2022/4/5.
//  Copyright © 2022 Google. All rights reserved.
//

#import "BlendViewController.h"
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

struct Vertex {
    math::float2 position;
    math::float2 uv;
};

@interface BlendViewController () <MTKViewDelegate>

@end

@implementation BlendViewController
{
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
    Texture *_imageTexture1;
    Entity _renderable;
}

- (void)dealloc {
    _engine->destroy(_renderable);
    _engine->destroy(_materialInstance);
    _engine->destroy(_material);
    _engine->destroy(_imageTexture1);
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

    _imageTexture0 = [self p_loadTexture:@"bImage0"];
    _imageTexture1 = [self p_loadTexture:@"bImage1"];

    TextureSampler sampler(MinFilter::LINEAR, MagFilter::LINEAR);

    // init must be called before we can build any materials.
    filamat::MaterialBuilder::init();

    // Compile a custom material to use on the triangle.
    filamat::Package pkg = filamat::MaterialBuilder()
    // The material name, only used for debugging purposes.
        .name("Quad material")
    // Use the unlit shading mode, because we don't have any lights in our scene.
        .shading(filamat::MaterialBuilder::Shading::UNLIT)
        .require(VertexAttribute::UV0)
        .require(VertexAttribute::UV1)
        .parameter(SamplerType::SAMPLER_2D, SamplerFormat::FLOAT, "image0")
        .parameter(SamplerType::SAMPLER_2D, SamplerFormat::FLOAT, "image1")
        .parameter(filament::backend::UniformType::FLOAT, "cAlpha")
    // Custom GLSL fragment code.
        .material("void material (inout MaterialInputs material) {"
                  "  prepareMaterial(material);"
                  "  float4 imageColor0 = texture(materialParams_image0, getUV0());"
                  "  float4 imageColor1 = texture(materialParams_image1, getUV0());"
                  "  material.baseColor =  (imageColor1 * materialParams.cAlpha) + ((1.0f - materialParams.cAlpha) * imageColor0);"
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
    _materialInstance->setParameter("image1", _imageTexture1, sampler);
    _materialInstance->setParameter("cAlpha", 0.8f);

    _renderable = EntityManager::get().create();
    RenderableManager::Builder(1)
        .boundingBox({{ -1, -1, -1 }, { 1, 1, 1 }})
        .material(0, _materialInstance)
        .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, _vertexBuffer, _indexBuffer, 0, 6)
        .culling(false).receiveShadows(false).castShadows(false).build(*_engine, _renderable);
    _scene->addEntity(_renderable);
}

- (Texture *)p_loadTexture:(NSString *)name {

    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"jpg"];
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
