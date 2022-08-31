//
//  CameraFPVViewController.h
//  DJISdkDemo
//
//  Copyright © 2015 DJI. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CameraFPVViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *predictionOutput;
@property (nonatomic) unsigned long resultsCount;
@property (retain, nonatomic) NSArray *results;

@end
