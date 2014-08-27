//
//  ViewController.m
//  ColorPalette
//
//  Created by Michael Van Milligan on 3/4/14.
//  Copyright (c) 2014 Michael Van Milligan. All rights reserved.
//

#import <CoreText/CoreText.h>

#import "ViewController.h"
#import "ColorPaletteGenerator.h"
#import "ColorView.h"
#import "ColorTile.h"
#import "PureLayout.h"

#define _ISA_(X, CLASS) ([X isKindOfClass:[CLASS class]])
#define DEGREES_TO_RADIANS(degrees) ((degrees) * (M_PI / 180.0))
#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))

#define COLOR_BALL_ROOF -1000.0f
#define COLOR_BALL_BASE 150.0f
#define COLOR_BALL_MARGIN 15.0f

#define COLORSPACE_LAB_DISTANCE 200.0f
#define COLORSPACE_LAB_L_CHANGE 100.0f
#define COLORSPACE_LAB_A_CHANGE 100.0f
#define COLORSPACE_LAB_B_CHANGE 100.0f

enum {
  kColorPaletteUndefinedSlider = 0,
  kColorPaletteHueSlider,
  kColorPaletteSaturationSlider,
  kColorPaletteBrightnessSlider,
  kColorPaletteLSlider,
  kColorPaletteASlider,
  kColorPaletteBSlider,
  kColorPaletteDistanceSlider,
  kColorPaletteSliderMax
};

@interface ViewController ()<UIDynamicAnimatorDelegate,
                             UICollisionBehaviorDelegate, ColorViewDelegate>

@property(nonatomic, strong) UIView *knobSlidersView;
@property(nonatomic, strong) UIView *colorSlidersView;
@property(nonatomic, strong) ColorView *colorView;
@property(nonatomic, strong) UILabel *titleLAB;
@property(nonatomic, strong) UILabel *titleHSV;
@property(nonatomic, strong) UISlider *sliderH;
@property(nonatomic, strong) UISlider *sliderS;
@property(nonatomic, strong) UISlider *sliderV;
@property(nonatomic, strong) UISlider *sliderDeltaL;
@property(nonatomic, strong) UISlider *sliderDeltaA;
@property(nonatomic, strong) UISlider *sliderDeltaB;
@property(nonatomic, strong) UISlider *sliderDistance;

@property(nonatomic, strong) dispatch_queue_t iVarQ;
@property(nonatomic, strong) dispatch_source_t collisionTimer;
@property(nonatomic, strong) ColorPaletteGenerator *gen;
@property(nonatomic, copy) dispatch_block_t colorGenerationBlock;

@property(nonatomic, strong) UIDynamicAnimator *animator;
@property(nonatomic, strong) UIDynamicBehavior *customBehavior;

@property(nonatomic, strong) NSMutableArray *seedColorViews;
@property(nonatomic, strong) NSMutableArray *complementColorViews;

@property(nonatomic) NSUInteger numCollisions;

@property(nonatomic, strong) NSMutableDictionary *colorGenerationConfig;
@property(nonatomic) CGFloat genThresh;
@property(nonatomic) CGFloat genSize;
@property(nonatomic) CGFloat genL;
@property(nonatomic) CGFloat genA;
@property(nonatomic) CGFloat genB;

@property(nonatomic) BOOL resetInFlight;

@end

@implementation ViewController

@synthesize iVarQ = _iVarQ, animator = _animator,
            customBehavior = _customBehavior, seedColorViews = _seedColorViews,
            complementColorViews = _complementColorViews,
            colorGenerationConfig = _colorGenerationConfig;

#pragma mark Safe Property Generation

- (UIDynamicAnimator *)animator {
  __block UIDynamicAnimator *animator = nil;
  dispatch_sync(_iVarQ, ^(void) {
      if (!_animator) {
        _animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
        _animator.delegate = self;
      }
      animator = _animator;
  });
  return animator;
}

- (void)setAnimator:(UIDynamicAnimator *)animator {
  dispatch_sync(_iVarQ, ^(void) {
      _animator = nil;
      _animator = animator;
  });
}

- (UIDynamicBehavior *)customBehavior {
  __block UIDynamicBehavior *customBehavior = nil;
  dispatch_sync(_iVarQ, ^(void) {
      if (!_customBehavior) {
        _customBehavior = [[UIDynamicBehavior alloc] init];
      }
      customBehavior = _customBehavior;
  });
  return customBehavior;
}

- (void)setCustomBehavior:(UIDynamicBehavior *)customBehavior {
  dispatch_sync(_iVarQ, ^(void) {
      _customBehavior = nil;
      _customBehavior = customBehavior;
  });
}

- (NSMutableArray *)seedColorViews {
  __block NSMutableArray *seedColorViews = nil;
  dispatch_sync(_iVarQ, ^(void) {
      if (!_seedColorViews) {
        _seedColorViews = [[NSMutableArray alloc] initWithCapacity:20];
      }
      seedColorViews = _seedColorViews;
  });
  return seedColorViews;
}

- (void)setSeedColorViews:(NSMutableArray *)seedColorViews {
  dispatch_sync(_iVarQ, ^(void) { _seedColorViews = seedColorViews; });
}

- (NSMutableArray *)complementColorViews {
  __block NSMutableArray *complementColorViews = nil;
  dispatch_sync(_iVarQ, ^(void) {
      if (!_complementColorViews) {
        _complementColorViews = [[NSMutableArray alloc] initWithCapacity:20];
      }
      complementColorViews = _complementColorViews;
  });
  return complementColorViews;
}

- (void)setComplementColorViews:(NSMutableArray *)complementColorViews {
  dispatch_sync(_iVarQ,
                ^(void) { _complementColorViews = complementColorViews; });
}

- (NSMutableDictionary *)colorGenerationConfig {
  __block NSMutableDictionary *colorGenerationConfig = nil;
  dispatch_sync(_iVarQ, ^(void) {
      if (!colorGenerationConfig) {
        _colorGenerationConfig =
            [[NSMutableDictionary alloc] initWithCapacity:2];
      }
      colorGenerationConfig = _colorGenerationConfig;
  });
  return colorGenerationConfig;
}

- (void)setColorGenerationConfig:(NSMutableDictionary *)colorGenerationConfig {
  dispatch_sync(_iVarQ,
                ^(void) { _colorGenerationConfig = colorGenerationConfig; });
}

#pragma mark Overrides

- (instancetype)init {
  if (self = [super init]) {
    _iVarQ = dispatch_queue_create("com.ColorPalette.iVarQ", NULL);
    _genThresh = 80.0f;
    _genSize = 20.0f;
    _genL = 25.0f;
    _genA = 15.0f;
    _genB = 15.0f;
    _resetInFlight = NO;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.seedColor = [UIColor yellowColor];

  self.view.backgroundColor = [UIColor whiteColor];

  [self setupSliders];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}

#pragma mark Initializers

- (void)setupSliders {

  /*
   * Main content view holding the sliders and color view
   */
  _colorSlidersView = [[UIView alloc] init];
  _colorSlidersView.translatesAutoresizingMaskIntoConstraints = NO;
  _colorSlidersView.backgroundColor =
      [self.view.backgroundColor colorWithAlphaComponent:0.90f];

  [self.view addSubview:_colorSlidersView];

  [_colorSlidersView autoPinEdgeToSuperviewEdge:ALEdgeTop
                                      withInset:COLOR_BALL_BASE];
  [_colorSlidersView autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:0.0f];
  [_colorSlidersView autoAlignAxisToSuperviewAxis:ALAxisVertical];
  [_colorSlidersView autoMatchDimension:ALDimensionWidth
                            toDimension:ALDimensionWidth
                                 ofView:self.view];

  /*
   * Color view that presents the currently selected HSV color
   */
  _colorView = [[ColorView alloc] init];
  _colorView.backgroundColor =
      [UIColor colorWithHue:0.5f saturation:0.5f brightness:0.5f alpha:1.0f];
  _colorView.layer.cornerRadius = 12.5f;
  _colorView.layer.masksToBounds = YES;
  _colorView.delegate = self;

  self.seedColor = _colorView.backgroundColor;

  [_colorSlidersView addSubview:_colorView];

  [_colorView autoMatchDimension:ALDimensionWidth
                     toDimension:ALDimensionWidth
                          ofView:_colorSlidersView
                      withOffset:-50.0f];
  [_colorView autoSetDimension:ALDimensionHeight toSize:40.0f];
  [_colorView autoAlignAxisToSuperviewAxis:ALAxisVertical];
  [_colorView autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:25.0f];

  /*
   * "H S V" label
   */
  _titleHSV = [[UILabel alloc] init];
  NSString *titleHSVText = [NSString
      stringWithFormat:@"H = %.0fº, S = %.2f, V = %.2f",
                       RADIANS_TO_DEGREES(0.5f * 2.0f * M_PI), 0.5f, 0.5f];
  _titleHSV.translatesAutoresizingMaskIntoConstraints = NO;

  _titleHSV.text = titleHSVText;
  [_titleHSV sizeToFit];

  _titleHSV.textColor = [UIColor darkGrayColor];
  _titleHSV.backgroundColor = [UIColor clearColor];
  _titleHSV.font = [[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]
      fontWithSize:13.0f];
  _titleHSV.textAlignment = NSTextAlignmentCenter;

  [_colorSlidersView addSubview:_titleHSV];

  [_titleHSV autoAlignAxisToSuperviewAxis:ALAxisVertical];
  [_titleHSV autoPinEdge:ALEdgeTop
                  toEdge:ALEdgeBottom
                  ofView:_colorView
              withOffset:10.0f];

  /*
   * Hue slider
   */
  _sliderH = [[UISlider alloc] init];
  _sliderH.translatesAutoresizingMaskIntoConstraints = NO;
  [_sliderH addTarget:self
                action:@selector(sliderAction:)
      forControlEvents:UIControlEventValueChanged];
  [_sliderH setBackgroundColor:[UIColor clearColor]];
  _sliderH.minimumValue = 0.0f;
  _sliderH.maximumValue = 1000.0;
  _sliderH.continuous = YES;
  _sliderH.value = 500.0f;
  _sliderH.tag = kColorPaletteHueSlider;

  UIImage *hImage = [self addText:@"H"];
  [_sliderH setThumbImage:hImage forState:UIControlStateNormal];
  [_sliderH setThumbImage:hImage forState:UIControlStateHighlighted];
  [_sliderH setThumbImage:hImage forState:UIControlStateSelected];

  [_colorSlidersView addSubview:_sliderH];

  /*
   * Saturation slider
   */
  _sliderS = [[UISlider alloc] init];
  _sliderS.translatesAutoresizingMaskIntoConstraints = NO;
  [_sliderS addTarget:self
                action:@selector(sliderAction:)
      forControlEvents:UIControlEventValueChanged];
  [_sliderS setBackgroundColor:[UIColor clearColor]];
  _sliderS.minimumValue = 0.0f;
  _sliderS.maximumValue = 1000.0;
  _sliderS.continuous = YES;
  _sliderS.value = 500.0f;
  _sliderS.tag = kColorPaletteSaturationSlider;

  UIImage *sImage = [self addText:@"S"];
  [_sliderS setThumbImage:sImage forState:UIControlStateNormal];
  [_sliderS setThumbImage:sImage forState:UIControlStateHighlighted];
  [_sliderS setThumbImage:sImage forState:UIControlStateSelected];

  [_colorSlidersView addSubview:_sliderS];

  /*
   * Brightness slider
   */
  _sliderV = [[UISlider alloc] init];
  _sliderV.translatesAutoresizingMaskIntoConstraints = NO;
  [_sliderV addTarget:self
                action:@selector(sliderAction:)
      forControlEvents:UIControlEventValueChanged];
  [_sliderV setBackgroundColor:[UIColor clearColor]];
  _sliderV.minimumValue = 0.0f;
  _sliderV.maximumValue = 1000.0;
  _sliderV.continuous = YES;
  _sliderV.value = 500.0f;
  _sliderV.tag = kColorPaletteBrightnessSlider;

  UIImage *vImage = [self addText:@"V"];
  [_sliderV setThumbImage:vImage forState:UIControlStateNormal];
  [_sliderV setThumbImage:vImage forState:UIControlStateHighlighted];
  [_sliderV setThumbImage:vImage forState:UIControlStateSelected];

  [_colorSlidersView addSubview:_sliderV];

  NSArray *hsvSliders = @[ _sliderH, _sliderS, _sliderV ];

  [_sliderH autoMatchDimension:ALDimensionWidth
                   toDimension:ALDimensionWidth
                        ofView:_colorSlidersView
                    withOffset:-50.0f];

  [_sliderH autoAlignAxisToSuperviewAxis:ALAxisVertical];
  [_sliderH autoSetDimension:ALDimensionHeight toSize:25.0f];

  [hsvSliders autoMatchViewsDimension:ALDimensionWidth];
  [hsvSliders autoMatchViewsDimension:ALDimensionHeight];
  [hsvSliders autoAlignViewsToAxis:ALAxisVertical];

  [_sliderH autoPinEdge:ALEdgeTop
                 toEdge:ALEdgeBottom
                 ofView:_titleHSV
             withOffset:15.0f];

  [_sliderS autoPinEdge:ALEdgeTop
                 toEdge:ALEdgeBottom
                 ofView:_sliderH
             withOffset:10.0f];

  [_sliderV autoPinEdge:ALEdgeTop
                 toEdge:ALEdgeBottom
                 ofView:_sliderS
             withOffset:10.0f];

  /*
   * LAB knobs title
   */
  _titleLAB = [[UILabel alloc] init];
  NSString *labelText =
      [NSString stringWithFormat:@"L* = %.2f, a* = %.2f, b* = %.2f, ∆ = %.2f",
                                 _genL, _genA, _genB, _genThresh];
  _titleLAB.translatesAutoresizingMaskIntoConstraints = NO;

  _titleLAB.text = labelText;
  [_titleLAB sizeToFit];

  _titleLAB.textColor = [UIColor darkGrayColor];
  _titleLAB.backgroundColor = [UIColor clearColor];
  _titleLAB.font = [[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]
      fontWithSize:13.5f];
  _titleLAB.textAlignment = NSTextAlignmentCenter;

  [_colorSlidersView addSubview:_titleLAB];

  [_titleLAB autoAlignAxisToSuperviewAxis:ALAxisVertical];
  [_titleLAB autoPinEdge:ALEdgeTop
                  toEdge:ALEdgeBottom
                  ofView:_sliderV
              withOffset:25.0f];

  /*
   * L* delta slider
   */
  _sliderDeltaL = [[UISlider alloc] init];
  _sliderDeltaL.translatesAutoresizingMaskIntoConstraints = NO;
  [_sliderDeltaL addTarget:self
                    action:@selector(sliderAction:)
          forControlEvents:UIControlEventValueChanged];
  [_sliderDeltaL setBackgroundColor:[UIColor clearColor]];
  _sliderDeltaL.minimumValue = -COLORSPACE_LAB_L_CHANGE;
  _sliderDeltaL.maximumValue = COLORSPACE_LAB_L_CHANGE;
  _sliderDeltaL.continuous = NO;
  _sliderDeltaL.value = 25.0f;
  _sliderDeltaL.tag = kColorPaletteLSlider;

  UIImage *lImage = [self addText:@"L"];
  [_sliderDeltaL setThumbImage:lImage forState:UIControlStateNormal];
  [_sliderDeltaL setThumbImage:lImage forState:UIControlStateHighlighted];
  [_sliderDeltaL setThumbImage:lImage forState:UIControlStateSelected];

  [_colorSlidersView addSubview:_sliderDeltaL];

  /*
   * A* delta slider
   */
  _sliderDeltaA = [[UISlider alloc] init];
  _sliderDeltaA.translatesAutoresizingMaskIntoConstraints = NO;
  [_sliderDeltaA addTarget:self
                    action:@selector(sliderAction:)
          forControlEvents:UIControlEventValueChanged];
  [_sliderDeltaA setBackgroundColor:[UIColor clearColor]];
  _sliderDeltaA.minimumValue = -COLORSPACE_LAB_A_CHANGE;
  _sliderDeltaA.maximumValue = COLORSPACE_LAB_A_CHANGE;
  _sliderDeltaA.continuous = NO;
  _sliderDeltaA.value = 15.0f;
  _sliderDeltaA.tag = kColorPaletteASlider;

  UIImage *aImage = [self addText:@"A"];
  [_sliderDeltaA setThumbImage:aImage forState:UIControlStateNormal];
  [_sliderDeltaA setThumbImage:aImage forState:UIControlStateHighlighted];
  [_sliderDeltaA setThumbImage:aImage forState:UIControlStateSelected];

  [_colorSlidersView addSubview:_sliderDeltaA];

  /*
   * B* delta slider
   */
  _sliderDeltaB = [[UISlider alloc] init];
  _sliderDeltaB.translatesAutoresizingMaskIntoConstraints = NO;
  [_sliderDeltaB addTarget:self
                    action:@selector(sliderAction:)
          forControlEvents:UIControlEventValueChanged];
  [_sliderDeltaB setBackgroundColor:[UIColor clearColor]];
  _sliderDeltaB.minimumValue = -COLORSPACE_LAB_B_CHANGE;
  _sliderDeltaB.maximumValue = COLORSPACE_LAB_B_CHANGE;
  _sliderDeltaB.continuous = NO;
  _sliderDeltaB.value = 15.0f;
  _sliderDeltaB.tag = kColorPaletteBSlider;

  UIImage *bImage = [self addText:@"B"];
  [_sliderDeltaB setThumbImage:bImage forState:UIControlStateNormal];
  [_sliderDeltaB setThumbImage:bImage forState:UIControlStateHighlighted];
  [_sliderDeltaB setThumbImage:bImage forState:UIControlStateSelected];

  [_colorSlidersView addSubview:_sliderDeltaB];

  /*
   * Distance delta slider
   */
  _sliderDistance = [[UISlider alloc] init];
  _sliderDistance.translatesAutoresizingMaskIntoConstraints = NO;
  [_sliderDistance addTarget:self
                      action:@selector(sliderAction:)
            forControlEvents:UIControlEventValueChanged];
  [_sliderDistance setBackgroundColor:[UIColor clearColor]];
  _sliderDistance.minimumValue = 15.0f;
  _sliderDistance.maximumValue = COLORSPACE_LAB_DISTANCE;
  _sliderDistance.continuous = NO;
  _sliderDistance.value = 80.0f;
  _sliderDistance.tag = kColorPaletteDistanceSlider;

  UIImage *dImage = [self addText:@"∆"];
  [_sliderDistance setThumbImage:dImage forState:UIControlStateNormal];
  [_sliderDistance setThumbImage:dImage forState:UIControlStateHighlighted];
  [_sliderDistance setThumbImage:dImage forState:UIControlStateSelected];

  [_colorSlidersView addSubview:_sliderDistance];

  NSArray *labSliders =
      @[ _sliderDeltaL, _sliderDeltaA, _sliderDeltaB, _sliderDistance ];

  [_sliderDeltaL autoMatchDimension:ALDimensionWidth
                        toDimension:ALDimensionWidth
                             ofView:_colorSlidersView
                         withOffset:-50.0f];

  [_sliderDeltaL autoAlignAxisToSuperviewAxis:ALAxisVertical];
  [_sliderDeltaL autoSetDimension:ALDimensionHeight toSize:25.0f];

  [labSliders autoMatchViewsDimension:ALDimensionWidth];
  [labSliders autoMatchViewsDimension:ALDimensionHeight];
  [labSliders autoAlignViewsToAxis:ALAxisVertical];

  [_sliderDeltaL autoPinEdge:ALEdgeTop
                      toEdge:ALEdgeBottom
                      ofView:_titleLAB
                  withOffset:15.0f];

  [_sliderDeltaA autoPinEdge:ALEdgeTop
                      toEdge:ALEdgeBottom
                      ofView:_sliderDeltaL
                  withOffset:10.0f];

  [_sliderDeltaB autoPinEdge:ALEdgeTop
                      toEdge:ALEdgeBottom
                      ofView:_sliderDeltaA
                  withOffset:10.0f];

  [_sliderDistance autoPinEdge:ALEdgeTop
                        toEdge:ALEdgeBottom
                        ofView:_sliderDeltaB
                    withOffset:10.0f];

  [self.view bringSubviewToFront:_colorSlidersView];
}

- (UIImage *)addText:(NSString *)text {

  // pack it into attributes dictionary
  NSDictionary *attributes = @{
    NSFontAttributeName : [UIFont fontWithName:@"Helvetica" size:20.0f],
    NSForegroundColorAttributeName : [UIColor lightGrayColor]
  };

  // make the attributed string
  NSAttributedString *stringToDraw =
      [[NSAttributedString alloc] initWithString:text attributes:attributes];

  CGRect rect =
      [stringToDraw boundingRectWithSize:CGSizeMake(40.0f, 40.0f)
                                 options:NSStringDrawingUsesFontLeading
                                 context:nil];

  CGSize size = CGSizeMake(40.0f, 40.0f);
  UIGraphicsBeginImageContextWithOptions(size, NO, 0);

  // now for the actual drawing
  CGContextRef context = UIGraphicsGetCurrentContext();

  CGContextSetFillColorWithColor(context, [UIColor blueColor].CGColor);

  CGContextSaveGState(context);
  CGRect rectangle = CGRectMake(5.0f, 5.0f, 30.0f, 30.0f);
  CGContextSetBlendMode(context, kCGBlendModeScreen);
  CGContextAddEllipseInRect(context, rectangle);
  CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 0.25f), 1.5f,
                              [UIColor darkGrayColor].CGColor);
  CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
  CGContextDrawPath(context, kCGPathFill);
  CGContextRestoreGState(context);

  CGAffineTransform trans = CGAffineTransformMakeScale(1, -1);
  CGContextSetTextMatrix(context, trans);

  [stringToDraw drawAtPoint:CGPointMake(20.0f - (rect.size.width / 2.0f),
                                        20.0f - (rect.size.height / 2.0f))];

  UIImage *testImg = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return testImg;
}

- (void)initializeColorGenerationConfig {
  [self.colorGenerationConfig removeAllObjects];
  self.colorGenerationConfig = nil;

  NSMutableDictionary *genConfig = [[NSDictionary dictionary] mutableCopy];
  NSMutableDictionary *seedConfig = [[NSDictionary dictionary] mutableCopy];
  NSMutableDictionary *compConfig = [[NSDictionary dictionary] mutableCopy];

  [seedConfig setObject:[NSNumber numberWithFloat:_genThresh]
                 forKey:ColorPaletteGeneratorDistanceThreshold];
  [seedConfig setObject:[NSNumber numberWithFloat:_genSize]
                 forKey:ColorPaletteGeneratorNeighbourSize];
  [seedConfig setObject:[NSNumber numberWithFloat:_genL]
                 forKey:ColorPaletteGeneratorEllipsoidStarL];
  [seedConfig setObject:[NSNumber numberWithFloat:_genA]
                 forKey:ColorPaletteGeneratorEllipsoidStarA];
  [seedConfig setObject:[NSNumber numberWithFloat:_genB]
                 forKey:ColorPaletteGeneratorEllipsoidStarB];

  [compConfig setObject:[NSNumber numberWithFloat:_genThresh]
                 forKey:ColorPaletteGeneratorDistanceThreshold];
  [compConfig setObject:[NSNumber numberWithFloat:_genSize]
                 forKey:ColorPaletteGeneratorNeighbourSize];
  [compConfig setObject:[NSNumber numberWithFloat:_genL]
                 forKey:ColorPaletteGeneratorEllipsoidStarL];
  [compConfig setObject:[NSNumber numberWithFloat:_genA]
                 forKey:ColorPaletteGeneratorEllipsoidStarA];
  [compConfig setObject:[NSNumber numberWithFloat:_genB]
                 forKey:ColorPaletteGeneratorEllipsoidStarB];

  [genConfig setObject:seedConfig forKey:ColorPaletteGeneratorSeedColor];
  [genConfig setObject:compConfig
                forKey:ColorPaletteGeneratorSeedColorComplement];

  self.colorGenerationConfig = genConfig;
}

- (void)enableUI:(BOOL)enable {

  if (enable) {
    [UIView animateWithDuration:0.5f
        delay:0.0f
        options:(UIViewAnimationOptionBeginFromCurrentState)
        animations:^(void) {
            _colorView.backgroundColor =
                [_colorView.backgroundColor colorWithAlphaComponent:1.0f];
            _sliderH.alpha = 1.0f;
            _sliderS.alpha = 1.0f;
            _sliderV.alpha = 1.0f;
            _sliderDeltaL.alpha = 1.0f;
            _sliderDeltaA.alpha = 1.0f;
            _sliderDeltaB.alpha = 1.0f;
            _sliderDistance.alpha = 1.0f;
        }
        completion:^(BOOL finished) {
            if (finished) {
              self.view.userInteractionEnabled = YES;
            }
        }];
  } else if (self.view.userInteractionEnabled) {
    self.view.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.5f
                          delay:0.0f
                        options:(UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
                         _colorView.backgroundColor =
                             [_colorView.backgroundColor
                                 colorWithAlphaComponent:0.0f];
                         _sliderH.alpha = 0.25f;
                         _sliderS.alpha = 0.25f;
                         _sliderV.alpha = 0.25f;
                         _sliderDeltaL.alpha = 0.25f;
                         _sliderDeltaA.alpha = 0.25f;
                         _sliderDeltaB.alpha = 0.25f;
                         _sliderDistance.alpha = 0.25f;
                     }
                     completion:nil];
  }
}

- (void)resetTimerWithBlock:(dispatch_block_t)block {

  if (NULL != _collisionTimer) {
    dispatch_source_cancel(_collisionTimer);
  }

  _collisionTimer = NULL;
  _collisionTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                           dispatch_get_main_queue());
  if (_collisionTimer) {
    dispatch_source_set_timer(
        _collisionTimer, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
        DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(_collisionTimer, ^(void) {
        dispatch_source_cancel(_collisionTimer);
        block();
    });
    dispatch_resume(_collisionTimer);
  }
}

#pragma mark Delegates and Callbacks

- (void)sliderAction:(id)sender {

  CGFloat H, S, V, A;

  if (!_ISA_(sender, UISlider)) return;

  UISlider *slide = (UISlider *)sender;
  CGFloat value;

  [_colorView.backgroundColor getHue:&H saturation:&S brightness:&V alpha:&A];

  switch (slide.tag) {
    case kColorPaletteHueSlider: {
      value = slide.value / 1000.0f;
      _colorView.backgroundColor =
          [UIColor colorWithHue:value saturation:S brightness:V alpha:A];
      _titleHSV.text = [NSString
          stringWithFormat:@"H = %.0fº, S = %.2f, V = %.2f",
                           RADIANS_TO_DEGREES(value * 2.0f * M_PI), S, V];
      break;
    }
    case kColorPaletteSaturationSlider: {
      value = slide.value / 1000.0f;
      _colorView.backgroundColor =
          [UIColor colorWithHue:H saturation:value brightness:V alpha:A];
      _titleHSV.text = [NSString
          stringWithFormat:@"H = %.0fº, S = %.2f, V = %.2f",
                           RADIANS_TO_DEGREES(H * 2.0f * M_PI), value, V];
      break;
    }
    case kColorPaletteBrightnessSlider: {
      value = slide.value / 1000.0f;
      _colorView.backgroundColor =
          [UIColor colorWithHue:H saturation:S brightness:value alpha:A];
      _titleHSV.text = [NSString
          stringWithFormat:@"H = %.0fº, S = %.2f, V = %.2f",
                           RADIANS_TO_DEGREES(H * 2.0f * M_PI), S, value];
      break;
    }
    case kColorPaletteLSlider: {
      _genL = slide.value;
      _titleLAB.text = [NSString
          stringWithFormat:@"L* = %.2f, a* = %.2f, b* = %.2f, ∆ = %.2f", _genL,
                           _genA, _genB, _genThresh];
      break;
    }
    case kColorPaletteASlider: {
      _genA = slide.value;
      _titleLAB.text = [NSString
          stringWithFormat:@"L* = %.2f, a* = %.2f, b* = %.2f, ∆ = %.2f", _genL,
                           _genA, _genB, _genThresh];
      break;
    }
    case kColorPaletteBSlider: {
      _genB = slide.value;
      _titleLAB.text = [NSString
          stringWithFormat:@"L* = %.2f, a* = %.2f, b* = %.2f, ∆ = %.2f", _genL,
                           _genA, _genB, _genThresh];
      break;
    }
    case kColorPaletteDistanceSlider: {
      _genThresh = slide.value;
      _titleLAB.text = [NSString
          stringWithFormat:@"L* = %.2f, a* = %.2f, b* = %.2f, ∆ = %.2f", _genL,
                           _genA, _genB, _genThresh];
      break;
    }
    default:
      break;
  }

  self.seedColor = _colorView.backgroundColor;
}

- (void)colorViewTouchEventEnded:(ColorViewTouchEvent)event {
  if (ColorViewTouchEnded == event) {
    [self doColorGeneration];
  }
}

- (void)collisionBehavior:(UICollisionBehavior *)behavior
       beganContactForItem:(id<UIDynamicItem>)item
    withBoundaryIdentifier:(id<NSCopying>)identifier
                   atPoint:(CGPoint)p {

  dispatch_async(dispatch_get_main_queue(), ^(void) {
      if ([(NSString *)identifier isEqualToString:@"long_bottom"]) {
        if (_ISA_(item, UIView)) {
          UIView *ball = (UIView *)item;
          if (-1 != ball.tag) {
            ball.tag = -1;
            _numCollisions--;
            if (0 == _numCollisions) {

              [_animator removeAllBehaviors];
              _customBehavior = nil;
              _animator = nil;

              [_seedColorViews
                  enumerateObjectsUsingBlock:^(id obj, NSUInteger idx,
                                               BOOL *stop) {
                      if (_ISA_(obj, UIView)) {
                        UIView *subview = (UIView *)obj;
                        [subview removeFromSuperview];
                      }
                  }];

              [_complementColorViews
                  enumerateObjectsUsingBlock:^(id obj, NSUInteger idx,
                                               BOOL *stop) {
                      if (_ISA_(obj, UIView)) {
                        UIView *subview = (UIView *)obj;
                        [subview removeFromSuperview];
                      }
                  }];

              [_seedColorViews removeAllObjects];
              _seedColorViews = nil;

              [_complementColorViews removeAllObjects];
              _complementColorViews = nil;

              self.colorGenerationBlock();
            }
          }
        }
      }
  });
}

- (void)collisionBehavior:(UICollisionBehavior *)behavior
       endedContactForItem:(id<UIDynamicItem>)item
    withBoundaryIdentifier:(id<NSCopying>)identifier {

  dispatch_async(dispatch_get_main_queue(), ^(void) {
      if (![(NSString *)identifier isEqualToString:@"long_bottom"]) {
        [self resetTimerWithBlock:^(void) {
            _resetInFlight = NO;
            [self enableUI:YES];
        }];
      }
  });
}

#pragma mark Actions

- (NSString *)hexStringForColor:(UIColor *)color {
  // Grab the components
  CGFloat red, green, blue, alpha;
  [color getRed:&red green:&green blue:&blue alpha:&alpha];

  NSInteger integerRed = red * 255;
  NSInteger integerGreen = green * 255;
  NSInteger integerBlue = blue * 255;
  NSInteger integerAlpha = alpha * 255;

  NSString *value =
      [NSString stringWithFormat:@"#%lx%lx%lx", (long)integerRed,
                                 (long)integerGreen, (long)integerBlue];
  if (integerAlpha != 255)
    value = [value stringByAppendingFormat:@"%lx", (long)integerAlpha];

  return value;
}

- (void)doColorGeneration {

  [self enableUI:NO];

  [self initializeColorGenerationConfig];

  self.gen = nil;
  self.gen =
      [[ColorPaletteGenerator alloc] initWithConfig:_colorGenerationConfig];
  [self.gen
      getColorPaletteForSeedColor:self.seedColor
         withCallbackOnEachResult:NO
              withCompletionBlock:^(NSDictionary *palette, NSError *error) {
                  dispatch_async(dispatch_get_main_queue(), ^(void) {
                      [self resetColorBalls:palette];
#if DEBUG
                      [self logPalette:palette];
#endif
                  });
              }];
}

- (void)logPalette:(NSDictionary *)palette {

  NSArray *seedColors = [palette objectForKey:ColorPaletteGeneratorSeedColor];
  NSArray *compColors =
      [palette objectForKey:ColorPaletteGeneratorSeedColorComplement];
  NSMutableArray *seedHexValues = [[NSMutableArray alloc] initWithCapacity:20];
  NSMutableArray *compHexValues = [[NSMutableArray alloc] initWithCapacity:20];

  [seedColors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

      if (_ISA_(obj, UIColor)) {
        UIColor *returnColor = (UIColor *)obj;
        NSString *hexColor = [self hexStringForColor:returnColor];
        [seedHexValues addObject:hexColor];
      }
  }];

  [compColors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

      if (_ISA_(obj, UIColor)) {
        UIColor *returnColor = (UIColor *)obj;
        NSString *hexColor = [self hexStringForColor:returnColor];
        [compHexValues addObject:hexColor];
      }
  }];

  //  NSLog(@"SEED COLORS: %@", seedHexValues);
  //  NSLog(@"COMPLEMENTARY COLORS: %@", compHexValues);
}

- (void)resetColorBalls:(NSDictionary *)palette {

  if (_customBehavior) {
    NSMutableArray *cutSet = [[NSMutableArray alloc] init];
    [_customBehavior.childBehaviors
        enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if (_ISA_(obj, UICollisionBehavior)) {
              [cutSet addObject:obj];
            }

            if (_ISA_(obj, UIDynamicItemBehavior)) {
              UIDynamicItemBehavior *changeElasticity =
                  (UIDynamicItemBehavior *)obj;
              changeElasticity.elasticity = 0.0f;
            }
        }];

    [cutSet enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [_customBehavior removeChildBehavior:obj];
    }];

    NSMutableArray *allViews =
        [[NSMutableArray alloc] initWithArray:self.seedColorViews];
    [allViews addObjectsFromArray:self.complementColorViews];

    UICollisionBehavior *bottomCollision =
        [[UICollisionBehavior alloc] initWithItems:allViews];

    [bottomCollision
        addBoundaryWithIdentifier:@"long_bottom"
                        fromPoint:CGPointMake(
                                      -self.view.frame.size.width * 2.0f,
                                      self.view.frame.size.height + 250.0f)
                          toPoint:CGPointMake(
                                      self.view.frame.size.width * 2.0f,
                                      self.view.frame.size.height + 250.0f)];

    _resetInFlight = YES;
    bottomCollision.collisionMode = UICollisionBehaviorModeBoundaries;
    bottomCollision.collisionDelegate = self;
    [self.customBehavior addChildBehavior:bottomCollision];

    __typeof__(self) __weak weakSelf = self;
    self.colorGenerationBlock = ^(void) {
      [weakSelf generateColorBalls:palette];
    };

  } else {
    [self generateColorBalls:palette];
  }
}

- (void)generateColorBalls:(NSDictionary *)palette {

  NSArray *seedColors = [palette objectForKey:ColorPaletteGeneratorSeedColor];
  NSArray *compColors =
      [palette objectForKey:ColorPaletteGeneratorSeedColorComplement];

  CGFloat midway = self.view.frame.size.width / 2.0f;

  // Just in case
  _numCollisions = 0;

  [seedColors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

      if (_ISA_(obj, UIColor)) {
        UIColor *returnColor = (UIColor *)obj;
        ColorTile *tile = [[ColorTile alloc] initWithColor:returnColor];
        CGFloat startingPlace =
            (arc4random() % 200) + (idx * (tile.frame.size.height + 5.0f));
        tile.frame = CGRectMake(tile.frame.origin.x + 25.0f +
                                    (arc4random() % (int)(midway - 50.0f)),
                                tile.frame.origin.y - startingPlace,
                                tile.frame.size.width, tile.frame.size.height);
        tile.tag = idx;

        [self.seedColorViews addObject:tile];
        [self.view addSubview:tile];
        [self.view sendSubviewToBack:tile];

        _numCollisions++;
      }
  }];

  [compColors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

      if (_ISA_(obj, UIColor)) {
        UIColor *returnColor = (UIColor *)obj;
        ColorTile *tile = [[ColorTile alloc] initWithColor:returnColor];
        CGFloat startingPlace =
            (arc4random() % 200) + (idx * (tile.frame.size.height + 5.0f));
        tile.frame = CGRectMake(tile.frame.origin.x + (midway + 25.0f) +
                                    (arc4random() % (int)(midway - 50.0f)),
                                tile.frame.origin.y - startingPlace,
                                tile.frame.size.width, tile.frame.size.height);
        tile.tag = idx;

        [self.complementColorViews addObject:tile];
        [self.view addSubview:tile];
        [self.view sendSubviewToBack:tile];

        _numCollisions++;
      }
  }];

  [self doGravity];
  [self doCollision];
  [self.animator addBehavior:self.customBehavior];
}

- (void)doGravity {

  NSMutableArray *colorViews =
      [[NSMutableArray alloc] initWithArray:self.seedColorViews];
  [colorViews addObjectsFromArray:self.complementColorViews];

  UIGravityBehavior *gravity =
      [[UIGravityBehavior alloc] initWithItems:colorViews];
  gravity.magnitude = 1.0f;
  gravity.angle = M_PI_2;
  [self.customBehavior addChildBehavior:gravity];

  UIDynamicItemBehavior *dynamics =
      [[UIDynamicItemBehavior alloc] initWithItems:colorViews];
  dynamics.elasticity = 0.85f;
  dynamics.density = 1.0f;
  dynamics.allowsRotation = YES;

  [self.customBehavior addChildBehavior:dynamics];
}

- (void)doCollision {

  CGFloat midway = self.view.frame.size.width / 2.0f;

  UICollisionBehavior *seedCollision =
      [[UICollisionBehavior alloc] initWithItems:self.seedColorViews];
  seedCollision.translatesReferenceBoundsIntoBoundary = NO;
  seedCollision.collisionMode = UICollisionBehaviorModeEverything;
  seedCollision.collisionDelegate = self;

  [seedCollision
      addBoundaryWithIdentifier:@"bottom"
                      fromPoint:CGPointMake(COLOR_BALL_MARGIN, COLOR_BALL_BASE)
                        toPoint:CGPointMake(midway, COLOR_BALL_BASE)];

  [seedCollision
      addBoundaryWithIdentifier:@"left"
                      fromPoint:CGPointMake(COLOR_BALL_MARGIN, COLOR_BALL_ROOF)
                        toPoint:CGPointMake(COLOR_BALL_MARGIN,
                                            COLOR_BALL_BASE)];

  [seedCollision
      addBoundaryWithIdentifier:@"right"
                      fromPoint:CGPointMake(midway, COLOR_BALL_ROOF)
                        toPoint:CGPointMake(midway, COLOR_BALL_BASE)];

  [self.customBehavior addChildBehavior:seedCollision];

  UICollisionBehavior *complementCollision =
      [[UICollisionBehavior alloc] initWithItems:self.complementColorViews];
  complementCollision.translatesReferenceBoundsIntoBoundary = NO;
  complementCollision.collisionMode = UICollisionBehaviorModeEverything;
  complementCollision.collisionDelegate = self;

  [complementCollision
      addBoundaryWithIdentifier:@"bottom"
                      fromPoint:CGPointMake(midway, COLOR_BALL_BASE)
                        toPoint:CGPointMake(self.view.frame.size.width -
                                                COLOR_BALL_MARGIN,
                                            COLOR_BALL_BASE)];

  [complementCollision
      addBoundaryWithIdentifier:@"left"
                      fromPoint:CGPointMake(midway, COLOR_BALL_ROOF)
                        toPoint:CGPointMake(midway, COLOR_BALL_BASE)];

  [complementCollision
      addBoundaryWithIdentifier:@"right"
                      fromPoint:CGPointMake(self.view.frame.size.width -
                                                COLOR_BALL_MARGIN,
                                            COLOR_BALL_ROOF)
                        toPoint:CGPointMake(self.view.frame.size.width -
                                                COLOR_BALL_MARGIN,
                                            COLOR_BALL_BASE)];

  [self.customBehavior addChildBehavior:complementCollision];
}

@end
