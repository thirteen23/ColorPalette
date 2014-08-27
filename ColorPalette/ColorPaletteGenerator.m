//
//  ColorPaletteGenerator.m
//  ColorPalette
//
//  Created by Michael Van Milligan on 3/25/14.
//  Copyright (c) 2014 Thirteen23. All rights reserved.
//

#define _ISA_(X, CLASS) ([X isKindOfClass:[CLASS class]])
#define DEGREES_TO_RADIANS(degrees) ((degrees) * (M_PI / 180.0))
#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))

/*
 C
 */
#include <CoreFoundation/CFError.h>
/*
 Objective-C
 */
#import "ColorPaletteGenerator.h"

typedef void (^ColorPaletteEllipsoidBlock)(CGFloat *delta, CGFloat *r,
                                           CGFloat *g, CGFloat *b);

NSString *const ColorPaletteGeneratorSeedColor = @"SeedColour";
NSString *const ColorPaletteGeneratorSeedColorComplement = @"ComplementColour";
NSString *const ColorPaletteGeneratorDistanceThreshold = @"CIE*L*a*b Distance";
NSString *const ColorPaletteGeneratorEllipsoidStarL = @"CIE*L";
NSString *const ColorPaletteGeneratorEllipsoidStarA = @"CIE*a";
NSString *const ColorPaletteGeneratorEllipsoidStarB = @"CIE*b";
NSString *const ColorPaletteGeneratorNeighbourSize = @"NeighbourSize";

@interface ColorPaletteGenerator ()

/* Main properties, w/ & w/o ARC */
#if __has_feature(objc_arc)
@property(nonatomic, strong) ColorPaletteBlock paletteBlock;
@property(nonatomic, strong) ColorPaletteEllipsoidBlock seedEllipsoidBlock;
@property(nonatomic, strong)
    ColorPaletteEllipsoidBlock complementEllipsoidBlock;
@property(nonatomic, strong) NSMutableArray *seedResults;
@property(nonatomic, strong) NSMutableArray *complementResults;
@property(nonatomic, strong) dispatch_queue_t colorQ;
#else
@property(nonatomic, copy) ColorPaletteBlock paletteBlock;
@property(nonatomic, copy) ColorPaletteEllipsoidBlock seedEllipsoidBlock;
@property(nonatomic, copy) ColorPaletteEllipsoidBlock complementEllipsoidBlock;
@property(nonatomic, retain) NSMutableArray *seedResults;
@property(nonatomic, retain) NSMutableArray *complementResults;
@property(nonatomic, assign) dispatch_queue_t colorQ;
#endif /* __has_feature(objc_arc) */

/* Seed settings */
@property(nonatomic, assign) CGFloat seedDistanceThreshold;
@property(nonatomic, assign) CGFloat seedStarL;
@property(nonatomic, assign) CGFloat seedStarA;
@property(nonatomic, assign) CGFloat seedStarB;
@property(nonatomic, assign) NSUInteger seedNeighbourSize;

/* Seed complement settings */
@property(nonatomic, assign) CGFloat complementDistanceThreshold;
@property(nonatomic, assign) CGFloat complementStarL;
@property(nonatomic, assign) CGFloat complementStarA;
@property(nonatomic, assign) CGFloat complementStarB;
@property(nonatomic, assign) NSUInteger complementNeighbourSize;

@property(nonatomic, assign) BOOL doPieceMeal;

@end

@implementation ColorPaletteGenerator

@synthesize paletteBlock = _paletteBlock,
            seedEllipsoidBlock = _seedEllipsoidBlock,
            complementEllipsoidBlock = _complementEllipsoidBlock,
            seedResults = _seedResults, complementResults = _complementResults,
            colorQ = _colorQ;

- (void)dealloc {
#if !__has_feature(objc_arc)
  [_paletteBlock release];
  [_seedEllipsoidBlock release];
  [_complementEllipsoidBlock release];
  [_seedResults release];
  [_complementResults release];

  if (NULL != _colorQ) {
    dispatch_release(_colorQ);
    _colorQ = NULL;
  }
#endif /* !__has_feature(objc_arc) */
}

- (instancetype)init {
  return [self initWithConfig:nil];
}

- (instancetype)initWithConfig:(NSDictionary *)config {
  if (self = [super init]) {

    _colorQ = dispatch_queue_create("com.ColorPaletteGenerator.colorQ", NULL);

    NSAssert(
        _colorQ,
        @"Cannot allocate resources for ColorPaletteGenerator dispatch queue");

    /* defaults */
    self.seedDistanceThreshold = self.complementDistanceThreshold = 80.0;
    self.seedStarL = self.complementStarL = 25.0;
    self.seedStarA = self.complementStarA = 15.0;
    self.seedStarB = self.complementStarB = 15.0;
    self.seedNeighbourSize = self.complementNeighbourSize = 20;

    [self configureColorPaletteGeneratorWithOptions:config];
  }
  return self;
}

- (NSMutableArray *)seedResults {
  __block NSMutableArray *seedResults = nil;
  dispatch_sync(self.colorQ, ^(void) {
      if (!_seedResults) {
        _seedResults = [[NSMutableArray alloc] initWithCapacity:20];
      }
      seedResults = _seedResults;
  });
  return seedResults;
}

- (void)setSeedResults:(NSMutableArray *)seedResults {
  dispatch_sync(self.colorQ, ^(void) { _seedResults = seedResults; });
}

- (NSMutableArray *)complementResults {
  __block NSMutableArray *complementResults = nil;
  dispatch_sync(self.colorQ, ^(void) {
      if (!_complementResults) {
        _complementResults = [[NSMutableArray alloc] initWithCapacity:20];
      }
      complementResults = _complementResults;
  });
  return complementResults;
}

- (void)setComplementResults:(NSMutableArray *)complementResults {
  dispatch_sync(self.colorQ,
                ^(void) { _complementResults = complementResults; });
}

- (void)getColorPaletteForSeedColor:(UIColor *)seed
           withCallbackOnEachResult:(BOOL)perResult
                withCompletionBlock:(ColorPaletteBlock)block {

  NSAssert(seed && block, @"Need to pass in a: %s %s", (!seed) ? "[seed]" : "",
           (!block) ? "[block]" : "");

  [self.complementResults removeAllObjects];
  self.complementResults = nil;

  [self.seedResults removeAllObjects];
  self.seedResults = nil;

  self.paletteBlock = block;

  self.doPieceMeal = perResult;

  self.seedEllipsoidBlock = [self
      generateEllipsoidBlockForColorAndParameters:seed
                                           xBound:self.seedStarL
                                           yBound:self.seedStarA
                                           zBound:self.seedStarB
                                distanceThreshold:self.seedDistanceThreshold];

  self.complementEllipsoidBlock =
      [self generateEllipsoidBlockForColorAndParameters:[seed getComplement]
                                                 xBound:self.complementStarL
                                                 yBound:self.complementStarA
                                                 zBound:self.complementStarB
                                      distanceThreshold:
                                          self.complementDistanceThreshold];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                 ^(void) {

      NSDictionary *results = nil;

      size_t SN = self.seedNeighbourSize;
      size_t CN = self.complementNeighbourSize;

      while (0 < SN || 0 < CN) {

        BOOL hitFound = NO;
        CGFloat delta = 0.0;
        CGFloat sr = 0, sg = 0, sb = 0, cr = 0, cg = 0, cb = 0;

        if (0 < SN) {
          self.seedEllipsoidBlock(&delta, &sr, &sg, &sb);
          if (0.0 <= delta) {
            UIColor *hit = [UIColor colorWithRed:(CGFloat)sr
                                           green:(CGFloat)sg
                                            blue:(CGFloat)sb
                                           alpha:1.0];
            hit.distance = [NSNumber numberWithFloat:delta];
            [self.seedResults addObject:hit];
            hitFound = YES;
            SN--;
          }
        }

        if (0 < CN) {
          self.complementEllipsoidBlock(&delta, &cr, &cg, &cb);
          if (0.0 <= delta) {
            UIColor *hit = [UIColor colorWithRed:(CGFloat)cr
                                           green:(CGFloat)cg
                                            blue:(CGFloat)cb
                                           alpha:1.0];
            hit.distance = [NSNumber numberWithFloat:delta];
            [self.complementResults addObject:hit];
            hitFound = YES;
            CN--;
          }
        }

        if (hitFound && self.doPieceMeal) {

          NSDictionary *pieceDict = [NSDictionary
              dictionaryWithObjectsAndKeys:
                  self.seedResults, ColorPaletteGeneratorSeedColor,
                  self.complementResults,
                  ColorPaletteGeneratorSeedColorComplement, nil];
          self.paletteBlock(pieceDict, nil);
        }
      }

      NSAssert(0 == CN || 0 == SN,
               @"Missed some neighbour values: Seeds: %lu Complement: %lu", SN,
               CN);

      results = [NSDictionary
          dictionaryWithObjectsAndKeys:self.seedResults,
                                       ColorPaletteGeneratorSeedColor,
                                       self.complementResults,
                                       ColorPaletteGeneratorSeedColorComplement,
                                       nil];

      self.paletteBlock(results, nil);
  });
}

- (ColorPaletteEllipsoidBlock)
    generateEllipsoidBlockForColorAndParameters:(UIColor *)color
                                         xBound:(CGFloat)aX
                                         yBound:(CGFloat)aY
                                         zBound:(CGFloat)bZ
                              distanceThreshold:(CGFloat)D {
  CGFloat L, A, B, ALPHA;
  [color getLStar:&L aStar:&A bStar:&B alpha:&ALPHA];

  ColorPaletteEllipsoidBlock ellipsoidBlock =
      ^void(CGFloat *delta, CGFloat *r, CGFloat *g, CGFloat *b) {

    if (NULL == delta || NULL == r || NULL == g || NULL == b) return;

    CGFloat x = 0.0f, y = 0.0f, z = 0.0f, DELTA = 0.0f;

    CGFloat lambda_neg = (0 == arc4random() % 2) ? 1.0f : -1.0f;
    CGFloat beta_neg = (0 == arc4random() % 2) ? 1.0f : -1.0f;
    CGFloat lambda =
        ((CGFloat)arc4random() / (CGFloat)RAND_MAX) * M_PI * lambda_neg;
    CGFloat beta =
        ((CGFloat)arc4random() / (CGFloat)RAND_MAX) * M_PI_2 * beta_neg;

    x = aX * cos(beta) * cos(lambda);
    y = aY * cos(beta) * sin(lambda);
    z = bZ * sin(beta);

    x = (-0.0f == x) ? 0.0f : x;
    y = (-0.0f == y) ? 0.0f : y;
    z = (-0.0f == z) ? 0.0f : z;

    /*
     * A little private API never hurt anyone...
     */
    colour_t new_lab = {0.0f}, rgb = {0.0f};

    new_lab.LAB_B = B + x;
    new_lab.LAB_A = A + y;
    new_lab.LAB_L = L + z;

    LAB_2_RGB(new_lab.LAB, &(rgb.RGB), colourspace_rgb_profile_srgb_d65);

    UIColor *newColor = [UIColor colorWithRed:rgb.RGB_R
                                        green:rgb.RGB_G
                                         blue:rgb.RGB_B
                                        alpha:ALPHA];
    DELTA =
        [color getDistanceMetricBetweenUIColor:newColor
                                   withOptions:T23UIColourDistanceFormulaCEI76];

    if (D >= DELTA) {
      *r = rgb.RGB_R;
      *g = rgb.RGB_G;
      *b = rgb.RGB_B;

      *delta = DELTA;
    } else {
      *delta = -1.0f * DELTA;
    }
  };

  return ellipsoidBlock;
}

- (void)configureColorPaletteGeneratorWithOptions:(NSDictionary *)config {

  NSDictionary *seedDict = nil, *compDict = nil;
  id seedColorSettings, complementColorSettings;
  id seedThreshold = nil, seedL = nil, seedA = nil, seedB = nil,
     seedNeighbourSize = nil;
  id compThreshold = nil, compL = nil, compA = nil, compB = nil,
     compNeighbourSize = nil;

  if (config) {
    seedColorSettings = [config objectForKey:ColorPaletteGeneratorSeedColor];
    complementColorSettings =
        [config objectForKey:ColorPaletteGeneratorSeedColorComplement];

    seedDict = (_ISA_(seedColorSettings, NSDictionary))
                   ? (NSDictionary *)seedColorSettings
                   : config;
    seedThreshold =
        [seedDict objectForKey:ColorPaletteGeneratorDistanceThreshold];
    seedL = [seedDict objectForKey:ColorPaletteGeneratorEllipsoidStarL];
    seedA = [seedDict objectForKey:ColorPaletteGeneratorEllipsoidStarA];
    seedB = [seedDict objectForKey:ColorPaletteGeneratorEllipsoidStarB];
    seedNeighbourSize =
        [seedDict objectForKey:ColorPaletteGeneratorNeighbourSize];

    compDict = (_ISA_(complementColorSettings, NSDictionary))
                   ? (NSDictionary *)complementColorSettings
                   : config;
    compThreshold =
        [compDict objectForKey:ColorPaletteGeneratorDistanceThreshold];
    compL = [compDict objectForKey:ColorPaletteGeneratorEllipsoidStarL];
    compA = [compDict objectForKey:ColorPaletteGeneratorEllipsoidStarA];
    compB = [compDict objectForKey:ColorPaletteGeneratorEllipsoidStarB];
    compNeighbourSize =
        [compDict objectForKey:ColorPaletteGeneratorNeighbourSize];

    self.seedDistanceThreshold = (_ISA_(seedThreshold, NSNumber))
                                     ? [(NSNumber *)seedThreshold floatValue]
                                     : self.seedDistanceThreshold;

    self.seedStarL = (_ISA_(seedL, NSNumber)) ? [(NSNumber *)seedL floatValue]
                                              : self.seedStarL;
    self.seedStarA = (_ISA_(seedA, NSNumber)) ? [(NSNumber *)seedA floatValue]
                                              : self.seedStarA;
    self.seedStarB = (_ISA_(seedB, NSNumber)) ? [(NSNumber *)seedB floatValue]
                                              : self.seedStarB;
    self.seedNeighbourSize =
        (_ISA_(seedNeighbourSize, NSNumber))
            ? ceilf([(NSNumber *)seedNeighbourSize floatValue])
            : self.seedNeighbourSize;

    self.complementDistanceThreshold =
        (_ISA_(compThreshold, NSNumber))
            ? [(NSNumber *)compThreshold floatValue]
            : self.complementDistanceThreshold;

    self.complementStarL = (_ISA_(compL, NSNumber))
                               ? [(NSNumber *)compL floatValue]
                               : self.complementStarL;
    self.complementStarA = (_ISA_(compA, NSNumber))
                               ? [(NSNumber *)compA floatValue]
                               : self.complementStarA;
    self.complementStarB = (_ISA_(compB, NSNumber))
                               ? [(NSNumber *)compB floatValue]
                               : self.complementStarB;
    self.complementNeighbourSize =
        (_ISA_(compNeighbourSize, NSNumber))
            ? ceilf([(NSNumber *)compNeighbourSize floatValue])
            : self.complementNeighbourSize;
  }
}

@end