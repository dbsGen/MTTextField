//
//  PCTextObject.h
//  inputTest
//
//  Created by zrz on 12-9-28.
//  Copyright (c) 2012年 zrz. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MTTextObjectDelegate;

@interface MTTextObject : UIButton

@property (nonatomic, readonly) UILabel     *textLabel;
@property (nonatomic, assign)   UIEdgeInsets    contentInset;
@property (nonatomic, strong)   id  indentifier;
@property (nonatomic, assign)   id<MTTextObjectDelegate>  delegate;

@end

@protocol MTTextObjectDelegate <NSObject>

@optional
- (void)textObjectDidChange:(MTTextObject *)textObject;

- (BOOL)textObjectWillSelected:(MTTextObject *)textObject;
- (void)textObjectDidSelected:(MTTextObject *)textObject;

@end