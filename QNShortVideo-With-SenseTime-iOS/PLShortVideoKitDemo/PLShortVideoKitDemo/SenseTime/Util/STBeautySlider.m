//
//  STBeautySlider.m
//  SenseMeEffects
//
//  Created by Sunshine on 2019/2/11.
//  Copyright © 2019 SenseTime. All rights reserved.
//

#import "STBeautySlider.h"

@interface STBeautySlider ()

@property (nonatomic, strong) UILabel *valueLabel;

@end

@implementation STBeautySlider

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _valueLabel.text = @"";
        _valueLabel.textColor = [UIColor whiteColor];
        _valueLabel.textAlignment = NSTextAlignmentCenter;
        _valueLabel.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_valueLabel];
    }
    return self;
}

- (CGRect)trackRectForBounds:(CGRect)bounds {
    CGRect trackRect = [super trackRectForBounds:bounds];
    return CGRectMake(trackRect.origin.x, bounds.size.height * 3.0 / 4.0 - 1.0, trackRect.size.width, trackRect.size.height);
}

- (CGRect)thumbRectForBounds:(CGRect)bounds trackRect:(CGRect)rect value:(float)value {
    CGRect thumbRect = [super thumbRectForBounds:bounds trackRect:rect value:value];
    
    if ([self.delegate respondsToSelector:@selector(currentSliderValue:slider:)]) {
        value = [self.delegate currentSliderValue:value slider:self];
    }
    
    _valueLabel.text = [NSString stringWithFormat:@"%d", (int)(value * 100)];
    _valueLabel.frame = CGRectMake(thumbRect.origin.x, 0, thumbRect.size.width, thumbRect.origin.y);
    return thumbRect;
}

@end
