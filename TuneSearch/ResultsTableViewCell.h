//
//  ResultsTableViewCell.h
//  TuneSearch
//
//  Created by Dustin Hennessy on 6/15/15.
//  Copyright (c) 2015 DustinHennessy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ResultsTableViewCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *resultsLabel;
@property (nonatomic, strong) IBOutlet UILabel *artistLabel;
@property (nonatomic, strong) IBOutlet UIImageView  *albumImageView;



@end
