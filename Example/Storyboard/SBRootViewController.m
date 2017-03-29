//
//  SBRootViewController.m
//  RRNavigationBar
//
//  Created by Moch Xiao on 3/29/17.
//  Copyright © 2017 RedRain. All rights reserved.
//

#import "SBRootViewController.h"
#import "RRNavigationBar.h"

@interface SBRootViewController ()

@end

@implementation SBRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.rr_navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.rr_navigationBar.shadowImage = [UIImage new];
}

- (IBAction)handleClickDimsiss:(UIBarButtonItem *)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.navigationController pushViewController:[UIViewController new] animated:YES];
}

@end
