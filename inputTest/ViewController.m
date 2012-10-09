//
//  ViewController.m
//  inputTest
//
//  Created by zrz on 12-9-27.
//  Copyright (c) 2012年 zrz. All rights reserved.
//

#import "ViewController.h"
#import "MTTextField.h"

@interface ViewController ()

@end

@implementation ViewController {
    NSArray     *_source,
                *_showing;
    NSMutableArray  *_selected;
    MTTextField *_textField;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    _source = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"items" ofType:@"plist"]];
    _showing = [_source copy];
    
    
    _textField = [[MTTextField alloc] initWithFrame:CGRectMake(0, 0, 320, 43)];
    [self.view addSubview:_textField];
    _textField.delegate = self;
    
    _selected = [[NSMutableArray alloc] init];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - table view delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _showing.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *indentifier = @"indentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:indentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:indentifier];
    }
    NSString *string =  [_showing objectAtIndex:indexPath.row];
    cell.textLabel.text = string;
    NSLog(@"%@, %@", string, _selected);
    if ([_selected containsObject:string]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *string =  [_showing objectAtIndex:indexPath.row];
    if ([_selected containsObject:string]) {
        [_selected removeObject:string];
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        [_textField removeObjectWithPredicate:[NSPredicate predicateWithFormat:@"indentifier == %@", string]];
    }else {
        [_selected addObject:string];
        
        MTTextObject *object = [[MTTextObject alloc] init];
        object.textLabel.text = string;
        object.indentifier = string;
        [_textField addObject:object];
        _textField.text = @"";
        [self textFieldreSet];
    }
}

#pragma mark - text field delegate

- (BOOL)textField:(MTTextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    [self performSelector:@selector(textFieldreSet)
               withObject:nil
               afterDelay:0];
    return YES;
}

- (void)textFieldreSet
{
    NSString *text = _textField.text;
    if (!text) {
        text = @"";
    }
    _showing = [_source filteredArrayUsingPredicate:
                [NSPredicate predicateWithFormat:@"SELF LIKE[cd] %@",
                 [NSString stringWithFormat:@"*%@*", text]]];
    [_tableView reloadData];
}

- (void)textField:(MTTextField *)textField didObjectDeleted:(MTTextObject *)object
{
    [_selected removeObjectsInArray:[_selected filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == %@", object.indentifier]]];
    [_tableView reloadData];
}

- (void)textField:(MTTextField *)textField didResetHeight:(CGFloat)height
{
    CGRect frame = textField.frame;
    frame.size.height = height;
    textField.frame = frame;
    
    CGRect bounds = [UIScreen mainScreen].bounds;
    _tableView.frame = CGRectMake(0, height, bounds.size.width, bounds.size.height - height - 20);
}

@end
