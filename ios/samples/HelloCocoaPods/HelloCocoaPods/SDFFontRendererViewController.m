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

@end


@interface SDFFontRendererViewController ()

@end

@implementation SDFFontRendererViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [SDFFontManager sharedManager];
}

@end
