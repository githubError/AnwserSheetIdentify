//
//  ViewController.m
//  AnwserSheetIdentify
//
//  Created by JWTHiOS02 on 2018/4/18.
//  Copyright © 2018年 cuipengfei. All rights reserved.
//

#import "ViewController.h"
#import "OpenCVManager.h"

extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@property (weak, nonatomic) IBOutlet UIImageView *resultImageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imageView.image = [UIImage imageNamed:@"123456"];
}


- (IBAction)convert:(id)sender {
    
    uint64_t time = dispatch_benchmark(1, ^{
        self.resultImageView.image = [OpenCVManager correctWithUIImage:[UIImage imageNamed:@"123456"]];
    });
    
    NSLog(@"耗时 ---> %llu ns",time);
}

@end
