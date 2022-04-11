//
//  SDFFontRendererViewController.m
//  HelloCocoaPods
//
//  Created by wang ya on 2022/4/11.
//  Copyright © 2022 Google. All rights reserved.
//

#import "SDFFontRendererViewController.h"
#import <Foundation/Foundation.h>

@interface GlyphData : NSObject

@property (nonatomic, assign)  CGFloat advanceX;
@property (nonatomic, assign)  CGFloat bboxHeight;
@property (nonatomic, assign)  CGFloat bboxWidth;
@property (nonatomic, assign)  CGFloat  bearingX;
@property (nonatomic, assign)  CGFloat bearingY;
@property (nonatomic, copy)     NSString *charcode;
@property (nonatomic, copy)     NSDictionary *kernings;
@property (nonatomic, assign)  CGFloat s0;
@property (nonatomic, assign)  CGFloat s1;
@property (nonatomic, assign)  CGFloat t0;
@property (nonatomic, assign)  CGFloat t1;

@end

@implementation GlyphData

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {

    }
    return self;
}

@end

@interface FontMetrics : NSObject

@property (nonatomic, assign) CGFloat ascender;
@property (nonatomic, assign) CGFloat descender;
@property (nonatomic, assign) NSDictionary *glyphData;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat maxAdvance;
@property (nonatomic, assign) CGFloat name;
@property (nonatomic, assign) CGFloat size;
@property (nonatomic, assign) CGFloat spaceAdvance;

//case  = "glyph_data"
//case
//case  = "max_advance"
//case
//case
//case  = "space_advance"

@end

@implementation FontMetrics

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        
    }
    return self;
}

@end

@interface SDFFontManager ()

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
        [self p_load];
    }

    return self;
}

- (void)p_load {

}


@end


@interface SDFFontRendererViewController ()

@end

@implementation SDFFontRendererViewController

- (void)viewDidLoad {
    [super viewDidLoad];

}

@end
