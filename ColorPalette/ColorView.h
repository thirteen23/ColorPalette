//
//  ColorView.h
//  ColorPalette
//
//  Created by Michael Van Milligan on 4/30/14.
//  Copyright (c) 2014 Michael Van Milligan. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ColorViewDelegate<NSObject>

typedef enum {
  ColorViewTouchBegan,
  ColorViewTouchEnded,
  ColorViewTouchCancelled,
  ColorViewTouchMoved
} ColorViewTouchEvent;

@required
- (void)colorViewTouchEventEnded:(ColorViewTouchEvent)event;
@end

@interface ColorView : UIView

@property(nonatomic, weak) id<ColorViewDelegate> delegate;

@end
