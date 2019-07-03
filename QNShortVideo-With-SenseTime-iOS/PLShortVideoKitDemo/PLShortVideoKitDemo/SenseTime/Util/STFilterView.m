//
//  STFilterView.m
//  SenseMeEffects
//
//  Created by Sunshine on 31/10/2017.
//  Copyright © 2017 SenseTime. All rights reserved.
//

#import "STFilterView.h"

@interface STButton : UIButton

@property (nonatomic, assign) UIEdgeInsets touchEdgeInsets; //扩展后的点击区域
@property (nonatomic, readonly, assign) CGRect touchFrame;  //扩展后的包括点击区域的frame

@end

@implementation STButton


- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (([event type] != UIEventTypeTouches)) {
        return [super pointInside:point withEvent:event];
    }
    CGRect frame = CGRectMake(self.touchEdgeInsets.left,
                              self.touchEdgeInsets.top,
                              self.bounds.size.width - self.touchEdgeInsets.left - self.touchEdgeInsets.right,
                              self.bounds.size.height - self.touchEdgeInsets.top - self.touchEdgeInsets.bottom);
    return CGRectContainsPoint(frame, point);
}

- (CGRect)touchFrame {
    return CGRectMake(CGRectGetMinX(self.frame) + self.touchEdgeInsets.left,
                      CGRectGetMinY(self.frame) + self.touchEdgeInsets.top,
                      CGRectGetWidth(self.frame) - self.touchEdgeInsets.left - self.touchEdgeInsets.right,
                      CGRectGetHeight(self.frame) - self.touchEdgeInsets.top - self.touchEdgeInsets.bottom);
}

@end

@implementation STFilterView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    STButton *backBtn = [[STButton alloc] initWithFrame:CGRectMake(12, 80, 7, 11)];
    backBtn.touchEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -33);
    [backBtn setImage:[UIImage imageNamed:@"filter_back_btn"] forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(onBtnBack:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:backBtn];
    
    STViewButton *leftView = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
    leftView.userInteractionEnabled = NO;
    leftView.backgroundColor = [UIColor clearColor];
    leftView.titleLabel.textColor = [UIColor whiteColor];
    leftView.frame = CGRectMake(24, 58, 33, 60);
    _leftView = leftView;
    [self addSubview:leftView];
    
    STFilterCollectionView *filterCollectionView = [[STFilterCollectionView alloc] initWithFrame:CGRectMake(CGRectGetMaxX(leftView.frame) + 20, 0, self.frame.size.width - 77, 200) withModels:nil andDelegateBlock:nil];
    _filterCollectionView = filterCollectionView;
    [self addSubview:filterCollectionView];
}

- (void)onBtnBack:(UIButton *)sender {
    if (self.block) {
        self.block();
    }
}

@end
