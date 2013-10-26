//
//  SettingsViewController.h
//  Regions
//
//  Created by Jonathan Alter on 10/24/13.
//  Copyright (c) 2013 Apple Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingsViewController : UITableViewController {
@private
    
}

@property (nonatomic, retain) NSMutableArray *tableRows;

@property (nonatomic) BOOL updateServerWithSigChange;

@end
