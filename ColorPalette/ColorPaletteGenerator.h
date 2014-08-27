//
//  ColorPaletteGenerator.h
//  ColorPalette
//
//  Created by Michael Van Milligan on 3/25/14.
//  Copyright (c) 2014 Thirteen23. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "UIColor+T23ColourSpaces.h"

/*
 * Keys for NSDictionary returned in ^ColorPaletteBlock
 */

/* Key where value is an NSArray containing the seed colour neighbours
 *
 * Note:    This key may also be used to set custom options values on the seed
 *          colour to be passed into initWithConfig. In this case it would be a
 *          dictionary with this as its key containing any of the options set.
 */
extern NSString *const ColorPaletteGeneratorSeedColor;

/* Key where value is an NSArray containing the seed colour complement
 *neighbours
 *
 * Note:    This key may also be used to set custom options values on the seed
 *          colour complement to be passed into initWithConfig. In this case it
 *          would be a dictionary with this as its key containing any of the
 *          options set.
 */
extern NSString *const ColorPaletteGeneratorSeedColorComplement;

/*
 * Keys for initWithConfig
 */

/* Distance threshold key where value is an NSNumber > 0; default is 80.0 */
extern NSString *const ColorPaletteGeneratorDistanceThreshold;

/* Ellipsoid *L axis span key where value is an NSNumber -100 <= X <= 100;
 * default is 25.0 */
extern NSString *const ColorPaletteGeneratorEllipsoidStarL;

/* Ellipsoid *a axis span key where value is an NSNumber -100 <= X <= 100;
 * default is 15.0 */
extern NSString *const ColorPaletteGeneratorEllipsoidStarA;

/* Ellipsoid *b axis span key where value is an NSNumber -100 <= X <= 100;
 * default is 15.0 */
extern NSString *const ColorPaletteGeneratorEllipsoidStarB;

/* NSNumber where its value is the number of neighbour colors picked; default is
 * 20 */
extern NSString *const ColorPaletteGeneratorNeighbourSize;

/* Callback block for color generation results. The palette is an NSArray of
 * UIColors. */
typedef void (^ColorPaletteBlock)(NSDictionary *palette, NSError *error);

@interface ColorPaletteGenerator : NSObject

- (ColorPaletteGenerator *)initWithConfig:(NSDictionary *)config;

- (void)getColorPaletteForSeedColor:(UIColor *)seed
           withCallbackOnEachResult:(BOOL)perResult
                withCompletionBlock:(ColorPaletteBlock)block;

@end

/*
 * UIColor category tomfoolery to stash CIE*L*a*b distance from origin
 */
@interface UIColor (LabDistance)
@property(nonatomic, strong) NSNumber *distance;
@end

@implementation UIColor (LabDistance)

- (void)setDistance:(NSNumber *)distance {
  objc_setAssociatedObject(self, @selector(distance), distance,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)distance {
  return objc_getAssociatedObject(self, @selector(distance));
}

@end
