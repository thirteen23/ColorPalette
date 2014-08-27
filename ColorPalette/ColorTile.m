//
//  ColorTile.m
//  ColorPalette
//
//  Created by Michael Van Milligan on 3/7/14.
//  Copyright (c) 2014 Michael Van Milligan. All rights reserved.
//

#import "ColorTile.h"

@interface ColorTile ()
@property(nonatomic, strong) UIColor *tileColor;
@end

@implementation ColorTile

- (id)init {
  if (self = [super init]) {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [self setupTile];
  }
  return self;
}

- (id)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [self setupTile];
  }
  return self;
}

- (id)initWithColor:(UIColor *)color {
  if (self = [super init]) {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.tileColor = color;
    [self setupTile];
    self.backgroundColor = color;
  }
  return self;
}

- (void)setupTile {
  self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, 20, 20);
  self.layer.cornerRadius = 10;
  self.layer.masksToBounds = YES;
}

- (void)updateColorWithColor:(UIColor *)color {
  if (color) {
    self.backgroundColor = color;
    [self setNeedsDisplay];
  }
}

@end
