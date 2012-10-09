//
//  ViewController.h
//  inputTest
//
//  Created by zrz on 12-9-27.
//  Copyright (c) 2012年 zrz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MTTextField.h"

@interface ViewController : UIViewController
<UITableViewDataSource, UITableViewDelegate,
MTTextFieldDelegate> {
    IBOutlet    UITableView *_tableView;
}

@end
