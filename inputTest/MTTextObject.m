//
//  PCTextObject.m
//  inputTest
//
//  Created by zrz on 12-9-28.
//  Copyright (c) 2012年 zrz. All rights reserved.
//

#import "MTTextObject.h"

@implementation MTTextObject {
}

@synthesize textLabel = _textLabel;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        _textLabel = [[UILabel alloc] initWithFrame:self.bounds];
        _textLabel.backgroundColor = [UIColor clearColor];
        _textLabel.font = [UIFont boldSystemFontOfSize:14];
        [self addSubview:_textLabel];
        
        self.contentInset = UIEdgeInsetsMake(3, 5, 3, 5);
        
        [_textLabel addObserver:self
                     forKeyPath:@"text"
                        options:NSKeyValueObservingOptionNew
                        context:NULL];
        
        [self addTarget:self
                 action:@selector(selectClick)
       forControlEvents:UIControlEventTouchUpInside];
        
        [self setBackgroundImage:[UIImage imageNamed:@"btn_person_item"]
                        forState:UIControlStateNormal];
        [self setBackgroundImage:[UIImage imageNamed:@"btn_person_item_on"]
                        forState:UIControlStateSelected];
    }
    return self;
}

- (void)dealloc
{
    [_textLabel removeObserver:self
                    forKeyPath:@"text"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _textLabel && [keyPath isEqualToString:@"text"]) {
        NSString *text = [change objectForKey:NSKeyValueChangeNewKey];
        CGSize size = [text sizeWithFont:_textLabel.font
                       constrainedToSize:CGSizeMake(MAXFLOAT, MAXFLOAT)
                           lineBreakMode:_textLabel.lineBreakMode];
        
        CGRect frame = self.frame;
        frame.size.width = size.width + self.contentInset.left + self.contentInset.right;
        frame.size.height = size.height + self.contentInset.top + self.contentInset.bottom;
        self.frame = frame;
        
        _textLabel.frame = CGRectMake(self.contentInset.left,
                                      self.contentInset.top,
                                      size.width, size.height);
        
        if ([self.delegate respondsToSelector:@selector(textObjectDidChange:)]) {
            [self.delegate textObjectDidChange:self];
        }
    }
}

#pragma mark - action

- (void)selectClick
{
    BOOL ret = YES;
    if ([self.delegate respondsToSelector:@selector(textObjectWillSelected:)]) {
        ret = [self.delegate textObjectWillSelected:self];
    }
    if (ret) {
        //允许选中
        self.selected = YES;
        if ([self.delegate respondsToSelector:@selector(textObjectDidSelected:)]) {
            [self.delegate textObjectDidSelected:self];
        }
    }
}

@end
