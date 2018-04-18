//
//  UIImage+OpenCV.h
//  OpenCVDemo
//
//  Created by JWTHiOS02 on 2018/4/4.
//  Copyright © 2018年 JWTHiOS02. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (OpenCV)

+ (UIImage *)imageWithCVMat:(const cv::Mat&)cvMat;

- (id)initWithCVMat:(const cv::Mat&)cvMat;

- (cv::Mat)cvMatImage;

@property(nonatomic, readonly) cv::Mat CVMat;
@property(nonatomic, readonly) cv::Mat CVGrayscaleMat;

@end
