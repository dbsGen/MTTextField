//
//  SPTextFieldCursor.m
//  inputTest
//
//  Created by zrz on 12-9-28.
//  Copyright (c) 2012年 zrz. All rights reserved.
//

#import "MTTextFieldCursor.h"

@implementation MTTextFieldCursor {
    NSTimer *_twinklingTimer;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.alpha = 0;
        
        self.backgroundColor = [UIColor blueColor];
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (void)twinkling
{
    [UIView beginAnimations:@"" context:NULL];
    [UIView setAnimationDuration:1.6];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    if (self.alpha == 0.85f) {
        self.alpha = 0.2f;
    }else self.alpha = 0.85f;
    [UIView commitAnimations];
}

- (void)show
{
    if (_twinklingTimer) {
        return;
    }
    _twinklingTimer = [NSTimer timerWithTimeInterval:1
                                              target:self
                                            selector:@selector(twinkling)
                                            userInfo:nil repeats:YES];
    self.alpha = 0.85f;
    [[NSRunLoop currentRunLoop] addTimer:_twinklingTimer
                                 forMode:NSDefaultRunLoopMode];
}

- (void)miss
{
    [_twinklingTimer invalidate];
    _twinklingTimer = nil;
    [UIView transitionWithView:self
                      duration:0.3
                       options:UIViewAnimationCurveEaseInOut
                    animations:^{
                        self.alpha = 0;
                    } completion:nil];
}

@end
