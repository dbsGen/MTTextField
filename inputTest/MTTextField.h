//
//  SPTextField.h
//  inputTest
//
//  Created by zrz on 12-9-27.
//  Copyright (c) 2012年 zrz. All rights reserved.
//

#import "DTAttributedTextContentView.h"
#import "MTTextObject.h"

@protocol MTTextFieldDelegate;

@interface MTTextField : UIView
<UITextInput, MTTextObjectDelegate> {
    DTAttributedTextContentView *_contentView;
    NSMutableArray  *_objects;
}

@property (nonatomic, readonly) DTAttributedTextContentView *contentView;
@property (nonatomic, readonly) UIView      *coverLayer;
@property (nonatomic, strong)   UIFont      *font;
@property (nonatomic, copy)     NSString    *text;
@property (nonatomic, assign)   BOOL        multiLine;
@property (nonatomic, assign)   NSUInteger  selected;

@property (nonatomic, assign)   id<MTTextFieldDelegate> delegate;

- (void)addObject:(MTTextObject *)object;
- (void)insertObject:(MTTextObject *)object atIndex:(NSUInteger)index;

- (void)removeObjectWithPredicate:(NSPredicate*)predicate;
- (void)removeObjectAtIndex:(NSUInteger)index;

@end

@protocol MTTextFieldDelegate <NSObject>

@optional
- (BOOL)textFieldShouldBeginEditing:(MTTextField *)textField;
- (void)textFieldDidBeginEditing:(MTTextField *)textField;  
- (BOOL)textFieldShouldEndEditing:(MTTextField *)textField;
- (void)textFieldDidEndEditing:(MTTextField *)textField;

- (BOOL)textField:(MTTextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string;

- (void)textFieldShouldReturn:(MTTextField *)textField;
- (void)textField:(MTTextField *)textField didObjectDeleted:(MTTextObject *)object;

- (void)textField:(MTTextField *)textField didResetHeight:(CGFloat)height;

@end