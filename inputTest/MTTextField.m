//
//  SPTextField.m
//  inputTest
//
//  Created by zrz on 12-9-27.
//  Copyright (c) 2012年 zrz. All rights reserved.
//

#import "MTTextField.h"
#import "DTCoreTextLayoutFrame.h"
#import "DTCoreTextLayoutLine.h"
#import <CoreText/CoreText.h>
#import "MTTextFieldCursor.h"

const NSString *kSPTextMarkIndentifier  = @"SPTextMarkIndentifier";

@interface SPTextPosition : UITextPosition
<NSCopying>

@property (nonatomic)   NSUInteger  index;

+ (SPTextPosition *)positionWithIndex:(NSUInteger)index;

@end

@implementation SPTextPosition

+ (SPTextPosition *)positionWithIndex:(NSUInteger)index
{
    SPTextPosition *position = [[self alloc] init];
    position.index = index;
    return position;
}

- (id)copyWithZone:(NSZone *)zone
{
    SPTextPosition *new = [[[self class] allocWithZone:zone] init];
    new.index = self.index;
    return new;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ index:%d>", NSStringFromClass(self.class), _index];
}

@end

@interface SPTextRange : UITextRange
<NSCopying>

@property (nonatomic)   NSRange range;

+ (SPTextRange *)textRangeWithRange:(NSRange)range;

@end

@implementation SPTextRange

+ (SPTextRange *)textRangeWithRange:(NSRange)range
{
    SPTextRange *textRange = [[self alloc] init];
    textRange.range = range;
    return textRange;
}

- (UITextPosition *)start
{
    return [SPTextPosition positionWithIndex:_range.location];
}

- (UITextPosition *)end
{
    return [SPTextPosition positionWithIndex:_range.location + _range.length];
}

- (BOOL)isEmpty
{
    return self.range.length == 0;
}

- (id)copyWithZone:(NSZone *)zone
{
    SPTextRange *new = [[self.class allocWithZone:zone] init];
    new.range = self.range;
    return new;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ location:%d, length:%d>", NSStringFromClass(self.class), _range.location, _range.length];
}

@end

@interface MTTextField()

@property (nonatomic, readonly) MTTextFieldCursor   *cursor;

- (void)setAttributedString:(NSAttributedString *)string;

@end

@implementation MTTextField {
    SPTextRange *_selectedTextRange,
                *_markedTextRange;
    SPTextPosition  *_beginningOfDocument,
                    *_endOfDocument;
    UITextInputStringTokenizer  *_tokenizer;
    CTFontRef   ct_font;
    NSUInteger  _selected;
    CGFloat     _objectsLeft,
                _objectsTop,
                _objectsHeihgt;
}

@synthesize coverLayer = _coverLayer, cursor = _cursor;
@synthesize contentView = _contentView;
@synthesize returnKeyType = _returnKeyType;
@synthesize autocorrectionType = _autocorrectionType;
@synthesize autocapitalizationType = _autocapitalizationType;
@synthesize secureTextEntry = _secureTextEntry;
@synthesize selected = _selected;

- (void)dealloc
{
    for (MTTextObject *obj in _objects) {
        obj.delegate = nil;
    }
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        _tokenizer = [[UITextInputStringTokenizer alloc] initWithTextInput:self];
        
        _contentView = [[DTAttributedTextContentView alloc] initWithFrame:self.bounds];
        _contentView.backgroundColor = [UIColor clearColor];
        [self addSubview:_contentView];
        static CTFontRef __systemBoldFont;
        if (!__systemBoldFont) {
            __systemBoldFont = CTFontCreateWithName(CFSTR("Helvetica-Bold"), 14, NULL);
        }
        
        self.markedTextStyle = @{(id)kCTFontAttributeName : (__bridge id)__systemBoldFont,
        (id)kCTForegroundColorAttributeName: (__bridge id)[UIColor blueColor].CGColor,
        kSPTextMarkIndentifier : @"1"};
        
        _coverLayer = [[UIView alloc] initWithFrame:self.bounds];
        _coverLayer.userInteractionEnabled = NO;
        _coverLayer.backgroundColor = [UIColor clearColor];
        [self addSubview:_coverLayer];
        
        self.font = [UIFont systemFontOfSize:14];
        self.selectedTextRange = [SPTextRange textRangeWithRange:NSMakeRange(0, 0)];
        
        
        // objects
        
        _objects = [[NSMutableArray alloc] init];
        _selected = NSNotFound;
        
        
        self.returnKeyType = UIReturnKeyDone;
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        self.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }
    return self;
}

- (BOOL)resignFirstResponder
{
    if ([self.delegate respondsToSelector:@selector(textFieldShouldEndEditing:)])
        [self.delegate textFieldShouldEndEditing:self];
    [self.cursor miss];
    BOOL ret = [super resignFirstResponder];
    if (ret && [self.delegate respondsToSelector:@selector(textFieldDidEndEditing:)]) {
        [self.delegate textFieldDidEndEditing:self];
    }
    return ret;
}

- (BOOL)becomeFirstResponder
{
    BOOL ret = [super becomeFirstResponder];
    if (ret && [self.delegate respondsToSelector:@selector(textFieldDidBeginEditing:)]) {
        [self.delegate textFieldDidBeginEditing:self];
    }
    return ret;
}

- (BOOL)canBecomeFirstResponder
{
    if ([self.delegate respondsToSelector:@selector(textFieldShouldBeginEditing:)]) {
        return [self.delegate textFieldShouldBeginEditing:self];
    }
    return YES;
}

#pragma mark - text range

@synthesize selectedTextRange = _selectedTextRange;

- (NSString *)textInRange:(UITextRange *)range
{
    NSRange r = [(id)range range];
    r = NSMakeRange(MAX(r.location, 0),
                    MIN(r.length, _contentView.attributedString.length - MAX(r.location, 0)));
    return [[_contentView.attributedString string] substringWithRange:r];
}

- (void)replaceRange:(UITextRange *)range withText:(NSString *)text
{
    NSRange ra = [(id)range range];
    if ([self.delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
        if (![self.delegate textField:self
        shouldChangeCharactersInRange:ra
                    replacementString:text])
            return;
    }
    NSMutableAttributedString *string = [self mutableAttributedString];
    if (ra.length) {
        NSDictionary *attributed = nil;
        if (ra.location < string.length) {
            attributed =[string attributesAtIndex:ra.location
                                   effectiveRange:NULL];
        }
        NSAttributedString *stringWillInsert = [[NSAttributedString alloc] initWithString:text
                                                                               attributes:attributed];
        
        
        [string beginEditing];
        [string deleteCharactersInRange:ra];
        [string insertAttributedString:stringWillInsert
                               atIndex:ra.location];
        [string endEditing];
        [self setAttributedString:string];
        if (_selectedTextRange.range.location > ra.location) {
            self.selectedTextRange = [SPTextRange textRangeWithRange:NSMakeRange(_selectedTextRange.range.location - ra.length + stringWillInsert.length, _selectedTextRange.range.length)];
        }
    }else {
        NSDictionary *attributed = nil;
        if (ra.location < string.length) {
            attributed =[string attributesAtIndex:ra.location
                                   effectiveRange:NULL];
        }
        NSAttributedString *stringWillInsert = [[NSAttributedString alloc] initWithString:text
                                                                               attributes:attributed];
        [string beginEditing];
        [string insertAttributedString:stringWillInsert
                               atIndex:ra.location];
        [string endEditing];
        [self setAttributedString:string];
        if (_selectedTextRange.range.location > ra.location) {
            self.selectedTextRange = [SPTextRange textRangeWithRange:NSMakeRange(_selectedTextRange.range.location + stringWillInsert.length, _selectedTextRange.range.length)];
        }
    }
}

#pragma mark - text mark

@synthesize markedTextRange = _markedTextRange;
@synthesize markedTextStyle;

- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange
{
    [self missSelectObject];
    NSRange thisSelection = _selectedTextRange.range;
    NSRange range = _markedTextRange.range;
    _markedTextRange = [SPTextRange textRangeWithRange:NSMakeRange(thisSelection.location + selectedRange.location - markedText.length,
                                                                   markedText.length)];
    if (markedText) {
        NSMutableAttributedString *string = [self mutableAttributedString];
        
        [string beginEditing];
        if (range.length) [string deleteCharactersInRange:range];
        [string insertAttributedString:[[NSAttributedString alloc] initWithString:markedText
                                                                       attributes:self.markedTextStyle]
                               atIndex:thisSelection.location];
        [string endEditing];
        [self setAttributedString:string];
    }
}

- (void)unmarkText
{
    [self missSelectObject];
    NSMutableAttributedString *string = [self mutableAttributedString];
    
    __block NSString *tempString = nil;
    __block NSRange tempRange;
    [string enumerateAttribute:(id)kSPTextMarkIndentifier
                       inRange:NSMakeRange(0, string.length)
                       options:NSAttributedStringEnumerationReverse
                    usingBlock:^(id value, NSRange range, BOOL *stop) {
                        if (value) {
                            tempString = [[string string] substringWithRange:range];
                            tempRange = range;
                            *stop = YES;
                        }
                    }];
    
    if (tempString) {
        [string beginEditing];
        [string deleteCharactersInRange:tempRange];
        if ([self.delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
            if ([self.delegate textField:self
            shouldChangeCharactersInRange:_selectedTextRange.range
                        replacementString:tempString])
                [string insertAttributedString:[[NSAttributedString alloc] initWithString:tempString
                                                                               attributes:[self selectAttribute]]
                                       atIndex:_selectedTextRange.range.location];
        }else
            [string insertAttributedString:[[NSAttributedString alloc] initWithString:tempString
                                                                           attributes:[self selectAttribute]]
                                   atIndex:_selectedTextRange.range.location];
        [string removeAttribute:(id)kSPTextMarkIndentifier
                          range:NSMakeRange(0, string.length)];
        [string endEditing];
    }
    [self setAttributedString:string];
    self.selectedTextRange = [SPTextRange textRangeWithRange:NSMakeRange(_markedTextRange.range.location + _markedTextRange.range.length, 0)];
    _markedTextRange = nil;
}

#pragma mark - document

@synthesize beginningOfDocument = _beginningOfDocument;
@synthesize endOfDocument = _endOfDocument;

#pragma mark - creating ranges and positions

- (UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition
{
    SPTextPosition *from = (id)fromPosition, *to = (id)toPosition;
    NSRange range = NSMakeRange(MIN(from.index, to.index), ABS(to.index - from.index));
    return [SPTextRange textRangeWithRange:range];
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset
{
    SPTextPosition *p = (id)position;
    NSInteger ret = p.index + offset;
    if (ret > _contentView.attributedString.length) {
        ret = _contentView.attributedString.length;
    }
    if (ret < 0) {
        ret = 0;
    }
    return [SPTextPosition positionWithIndex:ret];
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction offset:(NSInteger)offset
{
    SPTextPosition *p = (id)position;
    NSInteger ret = p.index;
    switch (direction) {
        case UITextLayoutDirectionRight:
            ret += offset;
            break;
        case UITextLayoutDirectionLeft:
            ret -= offset;
            break;
        default:
            break;
    }
    
    if (ret < 0) {
        ret = 0;
    }
    if (ret > _contentView.attributedString.length) {
        ret = _contentView.attributedString.length;
    }
    return [SPTextPosition positionWithIndex:ret];
}

#pragma mark - compare

- (NSComparisonResult)comparePosition:(UITextPosition *)position toPosition:(UITextPosition *)other
{
    SPTextPosition *p = (id)position, *o = (id)other;
    
    if (p.index == o.index) {
        return NSOrderedSame;
    } if (p.index < o.index) {
        return NSOrderedAscending;
    } else {
        return NSOrderedDescending;
    }
}

- (NSInteger)offsetFromPosition:(UITextPosition *)from toPosition:(UITextPosition *)toPosition
{
    SPTextPosition *f = (id)from, *t = (id)toPosition;
    return t.index - f.index;
}

#pragma mark - some delegate

@synthesize inputDelegate, tokenizer = _tokenizer;

- (UITextPosition *)positionWithinRange:(UITextRange *)range farthestInDirection:(UITextLayoutDirection)direction {
    
    SPTextRange *r = (id)range;
    NSInteger pos = r.range.location;
    
    switch (direction) {
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionLeft:
            pos = r.range.location;
            break;
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionDown:
            pos = r.range.location + r.range.length;
            break;
    }
    
    return [SPTextPosition positionWithIndex:pos];
}

- (UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction {
    
    SPTextPosition *pos = (id)position;
    NSRange result = NSMakeRange(pos.index, 1);
    
    switch (direction) {
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionLeft:
            result = NSMakeRange(pos.index - 1, 1);
            break;
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionDown:
            result = NSMakeRange(pos.index, 1);
            break;
    }
    
    return [SPTextRange textRangeWithRange:result];
}

- (UITextWritingDirection)baseWritingDirectionForPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction {
    return UITextWritingDirectionLeftToRight;
}

- (void)setBaseWritingDirection:(UITextWritingDirection)writingDirection forRange:(UITextRange *)range
{
}

#pragma mark - Geometry

- (CGRect)firstRectForRange:(UITextRange *)range
{
    SPTextRange *r = (id)range;
    NSRange nrange = r.range;
    NSArray *lines = _contentView.layoutFrame.lines;
    for (DTCoreTextLayoutLine *line in lines) {
        NSRange lineRange = line.stringRange;
        NSInteger local = nrange.location - lineRange.location;
        
        if (local >= 0 && local < lineRange.length) {
            NSUInteger length = MIN(nrange.location + nrange.length, lineRange.location + lineRange.length);
            return [line frameOfGlyphsWithRange:NSMakeRange(nrange.location, length)];
        }
    }
    return CGRectZero;
}

- (CGRect)caretRectForPosition:(UITextPosition *)position
{
    SPTextPosition *p = (id)position;
    
    if (_contentView.attributedString.length == 0 || p.index == 0) {
        return CGRectMake(0, 0, 3, 15);
    }
    
    if (p.index == _contentView.attributedString.length && [_contentView.attributedString.string characterAtIndex:(p.index - 1)] == '\n' ) {
        DTCoreTextLayoutLine *line = [_contentView.layoutFrame.lines lastObject];
        CGRect frame = [line frame];
        
        return CGRectMake(0, frame.origin.y + frame.size.height,
                          3, ceilf((line.descent*2) + line.ascent));
    }
    
    int index = p.index;
    index = MIN(_contentView.attributedString.string.length - 1, index);
    index = MAX(index, 0);
    
    NSArray *lines = _contentView.layoutFrame.lines;
    for (DTCoreTextLayoutLine *line in lines) {
        
        if (index >= line.stringRange.location &&
            index <= line.stringRange.length + line.stringRange.location)
        {
            CGRect rect = [line frameOfGlyphAtIndex:index];
            return CGRectMake(rect.origin.x + rect.size.width,
                              rect.origin.y, 3, rect.size.height);
        }
    }
    return CGRectZero;
}

- (NSArray *)selectionRectsForRange:(UITextRange *)range
{
    return nil;
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point
{
    for (DTCoreTextLayoutLine *line in _contentView.layoutFrame.lines) {
        if (CGRectContainsPoint(line.frame, point)) {
            return [SPTextPosition positionWithIndex:[line stringIndexForPosition:point]];
        }
    }
    return nil;
}
- (UITextPosition *)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange *)range
{
    SPTextRange *r = (id)range;
    for (DTCoreTextLayoutLine *line in _contentView.layoutFrame.lines) {
        if (CGRectContainsPoint(line.frame, point)) {
            int index = [line stringIndexForPosition:point];
            if (index >= [(id)r.start index] && index <= [(id)r.end index]) {
                return [SPTextPosition positionWithIndex:[line stringIndexForPosition:point]];
            }
        }
    }
    return nil;
}
- (UITextRange *)characterRangeAtPoint:(CGPoint)point
{
    for (DTCoreTextLayoutLine *line in _contentView.layoutFrame.lines) {
        if (point.y - line.frame.origin.y < line.frame.size.height) {
            int index = [line stringIndexForPosition:point];
            return [SPTextRange textRangeWithRange:NSMakeRange(index, 0)];
        }
    }
    return nil;
}

#pragma mark - keyboard input

- (void)insertText:(NSString *)text
{
    if (!self.multiLine && [text isEqualToString:@"\n"]) {
        if ([self.delegate respondsToSelector:@selector(textFieldShouldReturn:)]) 
            [self.delegate textFieldShouldReturn:self];
        return;
    }
    [self missSelectObject];
    if ([self.delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
        if (![self.delegate textField:self shouldChangeCharactersInRange:_selectedTextRange.range
                    replacementString:text])
            return;
    }
    NSMutableAttributedString *string = [self mutableAttributedString];
    if (_selectedTextRange.range.length) {
        NSRange range = _selectedTextRange.range;
        NSDictionary *attributed = [self selectAttribute];
        NSAttributedString *stringWillInsert = [[NSAttributedString alloc] initWithString:text
                                                                               attributes:attributed];
        
        
        [string beginEditing];
        [string deleteCharactersInRange:_selectedTextRange.range];
        [string insertAttributedString:stringWillInsert
                               atIndex:range.location];
        [string endEditing];
        [self setAttributedString:string];
        self.selectedTextRange = [SPTextRange textRangeWithRange:NSMakeRange(range.location + stringWillInsert.length, 0)];
    }else {
        NSRange range = _selectedTextRange.range;
        NSDictionary *attributed = [self selectAttribute];
        NSAttributedString *stringWillInsert = [[NSAttributedString alloc] initWithString:text
                                                                               attributes:attributed];
        [string beginEditing];
        [string insertAttributedString:stringWillInsert
                               atIndex:range.location];
        [string endEditing];
        [self setAttributedString:string];
        self.selectedTextRange = [SPTextRange textRangeWithRange:NSMakeRange(range.location + stringWillInsert.length, 0)];
    }
}

- (BOOL)hasText
{
    return _contentView.attributedString.length != 0;
}

- (void)deleteBackward
{
    if (_selected != NSNotFound) {
        MTTextObject *obj = [_objects objectAtIndex:_selected];
        [self removeObjectAtIndex:_selected];
        if ([self.delegate respondsToSelector:@selector(textField:didObjectDeleted:)]) {
            [self.delegate textField:self
                    didObjectDeleted:obj];
        }
        return;
    }
    NSMutableAttributedString *string = [self mutableAttributedString];
    if (_selectedTextRange.range.length) {
        [string beginEditing];
        if ([self.delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
            if ([self.delegate textField:self
       shouldChangeCharactersInRange:_selectedTextRange.range
                   replacementString:@""])
            {
                [string deleteCharactersInRange:_selectedTextRange.range];
            }
        }
        [string endEditing];
        if (!string.length) {
            string = nil;
        }
        [self setAttributedString:string];
        self.selectedTextRange = [SPTextRange textRangeWithRange:NSMakeRange(_selectedTextRange.range.location, 0)];
    }else if (_selectedTextRange.range.location > 0){
        [string beginEditing];
        if ([self.delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
            if ([self.delegate textField:self
           shouldChangeCharactersInRange:NSMakeRange(_selectedTextRange.range.location - 1, 1)
                       replacementString:@""])
            {
                [string deleteCharactersInRange:NSMakeRange(_selectedTextRange.range.location - 1, 1)];
            }
        }
        [string endEditing];
        if (!string.length) {
            string = nil;
        }
        [self setAttributedString:string];
        self.selectedTextRange = [SPTextRange textRangeWithRange:NSMakeRange(_selectedTextRange.range.location - 1, 0)];
    }else {
        self.selected = _objects.count - 1;
    }
}

- (UIView*)textInputView
{
    return _contentView;
}

#pragma mark - touch 

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self becomeFirstResponder];
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:_contentView];
    self.selectedTextRange = [self characterRangeAtPoint:p];
    [self missSelectObject];
    _selected = NSNotFound;
}

#pragma mark - private method

- (NSMutableAttributedString *)mutableAttributedString
{
    NSMutableAttributedString *string = [_contentView.attributedString mutableCopy];
    if (!string) {
        string = [[NSMutableAttributedString alloc] init];
    }
    return string;
}

- (NSDictionary *)selectAttribute {
    NSInteger local = _selectedTextRange.range.location;
    local = local ? local-1:local;
    if (local >= _markedTextRange.range.location &&
        local <= _markedTextRange.range.length) {
        return @{(id)kCTFontAttributeName: (__bridge id)ct_font};
    }
    if (local < _contentView.attributedString.length) {
        return [_contentView.attributedString attributesAtIndex:local
                                  effectiveRange:NULL];
    }else if (_contentView.attributedString.length) {
        return [_contentView.attributedString attributesAtIndex:_contentView.attributedString.length - 1
                                         effectiveRange:NULL];
    }
    return @{(id)kCTFontAttributeName: (__bridge id)ct_font};
}

#pragma mark - setters and getters

- (void)setFont:(UIFont *)font
{
    _font = font;
    if (ct_font)CFRelease(ct_font);
    ct_font = CTFontCreateWithName((__bridge CFStringRef)(font.fontName),
                                   font.pointSize,
                                   NULL);
}

- (void)setText:(NSString *)text
{
    if (text.length) {
        [self setAttributedString:[[NSAttributedString alloc] initWithString:text
                                                                  attributes:[self selectAttribute]]];
    }else {
        [self setAttributedString:nil];
    }
    self.selectedTextRange = [SPTextRange textRangeWithRange:NSMakeRange(MIN(_contentView.attributedString.length, _selectedTextRange.range.location), 0)];
}

- (NSString *)text
{
    return _contentView.attributedString.string;
}

- (void)setSelectedTextRange:(UITextRange *)selectedTextRange
{
    _selectedTextRange = [(id)selectedTextRange copy];
    NSRange selectRange = _selectedTextRange.range;
    if (selectRange.length) {
        [self.cursor miss];
    }else {
        CGRect result = CGRectZero;
        BOOL nextLine = NO;
        
        
        if (_contentView.attributedString.length &&
            selectRange.location >= _contentView.attributedString.length) {
            //最后一个
            if (selectRange.location && [_contentView.attributedString.string characterAtIndex:selectRange.location - 1] == '\n' ) {
                nextLine = YES;
            }
            DTCoreTextLayoutLine *line = [_contentView.layoutFrame.lines lastObject];
            if (nextLine) {
                result = CGRectMake(line.frame.origin.x,
                                    line.frame.origin.y + line.frame.size.height,
                                    2, self.font.lineHeight);
            }else {
                result = CGRectMake(line.frame.origin.x + line.frame.size.width,
                                    line.frame.origin.y, 2,
                                    line.frame.size.height);
            }
        }else {
            if (selectRange.location &&
                selectRange.location < _contentView.attributedString.length &&
                [_contentView.attributedString.string characterAtIndex:selectRange.location] == '\n' ) {
                nextLine = YES;
            }
            for (DTCoreTextLayoutLine *line in _contentView.layoutFrame.lines) {
                NSRange lineRange = line.stringRange;
                if (selectRange.location >= lineRange.location &&
                    selectRange.location < lineRange.location + lineRange.length)
                {
                    if (nextLine) {
                        result = CGRectMake(line.frame.origin.x,
                                            line.frame.origin.y + line.frame.size.height,
                                            2, self.font.lineHeight);
                    }else {
                        CGRect frame = [line frameOfGlyphAtIndex:selectRange.location-line.stringRange.location];
                        if (frame.size.width) {
                            result = CGRectMake(frame.origin.x,
                                                line.frame.origin.y, 2,
                                                frame.size.height);
                        }else {
                            result = CGRectMake(frame.origin.x + line.frame.size.width,
                                                line.frame.origin.y, 2,
                                                frame.size.height);
                        }
                    }
                    break;
                }
            }
        }
        if (!result.size.height) {
            result.size.height = self.font.lineHeight;
        }
        if (!result.size.width) {
            result.size.width = 2;
        }
        
        CGRect frame = _contentView.frame;
        
        if ([self isFirstResponder]) [self.cursor show];
        self.cursor.frame = CGRectMake(frame.origin.x + result.origin.x,
                                       frame.origin.y + result.origin.y,
                                       result.size.width, result.size.height);
    }
}

- (void)setSelected:(NSUInteger)selected
{
    if (_objects.count == 0 ||
        selected > _objects.count - 1) {
        return;
    }
    [self missSelectObject];
    _selected = selected;
    MTTextObject *obj = [_objects objectAtIndex:selected];
    obj.selected = YES;
    [self.cursor miss];
}

- (void)setAttributedString:(NSAttributedString *)string
{
    _contentView.attributedString = string;
    [self resetPositionOfInputView];
}

- (MTTextFieldCursor *)cursor
{
    if (!_cursor) {
        _cursor = [[MTTextFieldCursor alloc] init];
        [self.coverLayer addSubview:_cursor];
    }
    return _cursor;
}

#pragma mark - text objects

#define kObjectsHorizontalInterva   3
#define kObjectsVerticalInterval    3

- (void)addObject:(MTTextObject *)object
{
    [_objects addObject:object];
    
    object.delegate = self;
    [self rebuildObjects];
}

- (void)insertObject:(MTTextObject *)object atIndex:(NSUInteger)index
{
    [_objects insertObject:object atIndex:index];
    if (_selected != NSNotFound &&
        index < _selected) {
        _selected ++;
    }
    [self rebuildObjects];
}

- (void)removeObjectWithPredicate:(NSPredicate*)predicate
{
    MTTextObject *selectedObject = nil;
    if (_selected < _objects.count){
        selectedObject = [_objects objectAtIndex:_selected];
    }
    
    NSArray *objectWillBeRemoved = [_objects filteredArrayUsingPredicate:predicate];
    for (MTTextObject *obj in objectWillBeRemoved) {
        [obj removeFromSuperview];
    }
    [_objects removeObjectsInArray:objectWillBeRemoved];
    
    if (selectedObject) {
        _selected = [_objects indexOfObject:selectedObject];
    }
    
    [self rebuildObjects];
}

- (void)removeObjectAtIndex:(NSUInteger)index
{
    MTTextObject *obj = [_objects objectAtIndex:index];
    [_objects removeObjectAtIndex:index];
    [obj removeFromSuperview];
    
    if (index == _selected) {
        _selected = NSNotFound;
    }else if (index < _selected) {
        _selected -= 1;
    }
    [self rebuildObjects];
}

- (void)rebuildObjects
{
    _objectsLeft = 0, _objectsTop = 0, _objectsHeihgt = 0;
    for (int n = 0, t = _objects.count; n < t; n++) {
        MTTextObject *object = [_objects objectAtIndex:n];
        CGRect frame = object.frame;
        
        if (self.frame.size.width < _objectsLeft + frame.size.width) {
            _objectsLeft = 0;
            _objectsTop += kObjectsVerticalInterval + _objectsHeihgt;
            _objectsHeihgt = 0;
        }
        object.frame = CGRectMake(_objectsLeft + kObjectsVerticalInterval,
                                  _objectsTop,
                                  frame.size.width,
                                  frame.size.height);
        [self addSubview:object];
        _objectsLeft += kObjectsHorizontalInterva + frame.size.width;
        _objectsHeihgt = MAX(_objectsHeihgt, frame.size.height);
    }
    
    [self resetPositionOfInputView];
    self.selectedTextRange = self.selectedTextRange;
}

- (void)resetPositionOfInputView
{
    CGSize size = [_contentView attributedStringSizeThatFits:self.bounds.size.width];
    CGFloat left = _objectsLeft, top = _objectsTop, height = _objectsHeihgt;
    if (self.frame.size.width < _objectsLeft + size.width) {
        left = 0;
        top += kObjectsVerticalInterval + height;
        height = 0;
    }
    
    CGRect frame = _contentView.frame;
    
    //调整 输入框的位置
    if (height) {
        top = top + (height - self.font.lineHeight) / 2;
    }
    
    
    _contentView.frame = CGRectMake(left + kObjectsVerticalInterval,
                                    top,
                                    frame.size.width,
                                    frame.size.height);
    
    if ([self.delegate respondsToSelector:@selector(textField:didResetHeight:)]) {
        [self.delegate textField:self didResetHeight:top + (height ? height : frame.size.height)];
    }
}

- (void)missSelectObject
{
    if (_selected < _objects.count) {
        MTTextObject *object = [_objects objectAtIndex:_selected];
        object.selected = NO;
        _selected = NSNotFound;
    }
}

#pragma mark - text object delegate

- (void)textObjectDidChange:(MTTextObject *)textObject
{
    [self rebuildObjects];
}

- (BOOL)textObjectWillSelected:(MTTextObject *)textObject
{
    [self missSelectObject];
    if (![self isFirstResponder]) {
        [self becomeFirstResponder];
    }
    [self.cursor miss];
    return YES;
}

- (void)textObjectDidSelected:(MTTextObject *)textObject
{
    _selected = [_objects indexOfObject:textObject];
}

@end
