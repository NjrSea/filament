//
//  DemoViewController.m
//  HelloCocoaPods
//
//  Created by wang ya on 2022/4/4.
//  Copyright © 2022 Google. All rights reserved.
//

#import "DemoViewController.h"
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

using namespace filament;
using namespace utils;

struct Vertex {
    math::float2 position;
    math::float3 color;
};

@interface DemoViewController () <MTKViewDelegate>



@end

@implementation DemoViewController {
    Engine *_engine;
    SwapChain *_swapChain;
    Renderer *_renderer;
    View *_view;
    Scene *_scene;
    Camera *_camera;
    Entity _cameraEntity;
    VertexBuffer *_vertexBuffer;
    IndexBuffer *_indexBuffer;
    Entity _triangle;
    Material *_material;
    MaterialInstance *_materialInstance;
}

- (void)dealloc {
    _engine->destroyCameraComponent(_cameraEntity);
    _engine->destroy(_scene);
    _engine->destroy(_view);
    _engine->destroy(_renderer);
    _engine->destroy(_swapChain);
    _engine->destroy(_triangle);
    _engine->destroy(_indexBuffer);
    _engine->destroy(_vertexBuffer);
    _engine->destroy(_materialInstance);
    _engine->destroy(_material);
    _engine->destroy(&_engine); // the Engine object should always be the the last object we destroy
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _engine = Engine::create(Engine::Backend::METAL);

    MTKView *mtkView = (MTKView *)self.view;
    mtkView.delegate = self;
    _swapChain = _engine->createSwapChain((__bridge  void *)mtkView.layer);

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

    [self resize:mtkView.drawableSize];

    static const Vertex TRIANGLE_VERTICES[3] = {
        { { 0.867, -0.500}, {1.0, 0.0, 0.0} },
        { { 0.000,  1.000}, {0.0, 1.0, 0.0} },
        { {-0.867, -0.500}, {0.0, 0.0, 1.0} },
    };
    static const uint16_t TRIANGLE_INDICES[3] = { 0, 1, 2 };

    VertexBuffer::BufferDescriptor vertices(TRIANGLE_VERTICES, sizeof(Vertex) * 3, nullptr);
    IndexBuffer::BufferDescriptor indices(TRIANGLE_INDICES, sizeof(uint16_t) * 3, nullptr);

    using Type = VertexBuffer::AttributeType;
    const uint8_t stride = sizeof(Vertex);
    _vertexBuffer = VertexBuffer::Builder()
        .vertexCount(3)
        .bufferCount(1)
        .attribute(VertexAttribute::POSITION, 0, Type::FLOAT2, offsetof(Vertex, position), stride)
        .attribute(VertexAttribute::COLOR, 0, Type::FLOAT3, offsetof(Vertex, color), stride)
        .build(*_engine);

    _indexBuffer = IndexBuffer::Builder()
        .indexCount(3)
        .bufferType(IndexBuffer::IndexType::USHORT)
        .build(*_engine);

    _vertexBuffer->setBufferAt(*_engine, 0, std::move(vertices));
    _indexBuffer->setBuffer(*_engine, std::move(indices));


    filamat::MaterialBuilder::init();
    filamat::Package pkg = filamat::MaterialBuilder()
        .name("Triangle material")
        .shading(filamat::MaterialBuilder::Shading::UNLIT)
        .require(VertexAttribute::COLOR)
        .material("void material (inout MaterialInputs material) {"
                  "  prepareMaterial(material);"
                  "  material.baseColor = getColor();"
                  "}")
        .targetApi(filamat::MaterialBuilder::TargetApi::METAL)
        .platform(filamat::MaterialBuilder::Platform::MOBILE)
        .build(_engine->getJobSystem());

    filamat::MaterialBuilder::shutdown();

    _material = Material::Builder()
    .package(pkg.getData(), pkg.getSize())
    .build(*_engine);

    _materialInstance = _material->getDefaultInstance();

    _triangle = utils::EntityManager::get().create();

    using Primitive = RenderableManager::PrimitiveType;

    RenderableManager::Builder(1)
        .geometry(0, Primitive::TRIANGLES, _vertexBuffer, _indexBuffer, 0, 3)
        .material(0, _materialInstance)
        .culling(false)
        .receiveShadows(false)
        .castShadows(false)
        .build(*_engine, _triangle);

    _scene->addEntity(_triangle);

    _engine->getTransformManager().create(_triangle);
}

- (void)resize:(CGSize)size {
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

- (void)update {
    auto& tm = _engine->getTransformManager();
    auto i = tm.getInstance(_triangle);
    const auto time = CACurrentMediaTime();
    tm.setTransform(i, math::mat4f::rotation(time, math::float3 {0.0, 0.0, 1.0}));
}


- (void)drawInMTKView:(nonnull MTKView *)view {
    [self update];
    if (_renderer->beginFrame(_swapChain)) {
        _renderer->render(_view);
        _renderer->endFrame();
    }
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self resize:size];
}

@end
