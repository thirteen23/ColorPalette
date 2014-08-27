//
//  ColorTile.h
//  ColorPalette
//
//  Created by Michael Van Milligan on 3/7/14.
//  Copyright (c) 2014 Michael Van Milligan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "ColorPaletteGenerator.h"

@interface ColorTile : UIView
@property(nonatomic, readonly) UIColor *tileColor;
- (id)initWithColor:(UIColor *)color;
- (void)updateColorWithColor:(UIColor *)color;
@end
