//
//  ColorView.m
//  ColorPalette
//
//  Created by Michael Van Milligan on 4/30/14.
//  Copyright (c) 2014 Michael Van Milligan. All rights reserved.
//

#define _ISA_(X, CLASS) ([X isKindOfClass:[CLASS class]])
#define DEGREES_TO_RADIANS(degrees) ((degrees) * (M_PI / 180.0))
#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))

#import "ColorView.h"
#import "ColorPaletteGenerator.h"

@interface ColorView ()
@property(nonatomic, strong) UIColor *currentColor;
@end

@implementation ColorView

- (id)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = YES;
    [self initBorder];
  }
  return self;
}

- (id)init {
  if (self = [super init]) {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = YES;
    [self initBorder];
  }
  return self;
}

- (void)initBorder {
  self.layer.borderColor = [UIColor darkGrayColor].CGColor;
  self.layer.borderWidth = 1.5f;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  _currentColor = self.backgroundColor;
  self.backgroundColor = [_currentColor getComplement];

  if (_delegate &&
      [_delegate respondsToSelector:@selector(colorViewTouchEventEnded:)]) {
    [_delegate colorViewTouchEventEnded:ColorViewTouchBegan];
  }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
  self.backgroundColor = _currentColor;

  if (_delegate &&
      [_delegate respondsToSelector:@selector(colorViewTouchEventEnded:)]) {
    [_delegate colorViewTouchEventEnded:ColorViewTouchEnded];
  }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
  if (_delegate &&
      [_delegate respondsToSelector:@selector(colorViewTouchEventEnded:)]) {
    [_delegate colorViewTouchEventEnded:ColorViewTouchCancelled];
  }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
  if (_delegate &&
      [_delegate respondsToSelector:@selector(colorViewTouchEventEnded:)]) {
    [_delegate colorViewTouchEventEnded:ColorViewTouchMoved];
  }
}

@end
