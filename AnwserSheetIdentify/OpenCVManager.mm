//
//  OpenCVManager.m
//  OpenCVDemo
//
//  Created by JWTHiOS02 on 2018/4/4.
//  Copyright © 2018年 JWTHiOS02. All rights reserved.
//

#import "OpenCVManager.h"
#import "opencv2/opencv.hpp"
#import "UIImage+OpenCV.h"

@implementation OpenCVManager

+ (UIImage *)correctWithUIImage:(UIImage *)image {
    cv::Mat inputMat;
    cv::Mat outputMat;
    cv::Mat tmp;
    
    inputMat = [image cvMatImage];
    
    // 压缩
    cv::resize(inputMat, tmp, cv::Size(inputMat.rows / 1.5, inputMat.cols/ 1.5));
    outputMat = tmp;
    
    // 记录压缩图像
    cv::Mat resizeMat;
    tmp.copyTo(resizeMat);
    
    // 转灰度图像
    cv::cvtColor(outputMat, tmp, CV_BGR2GRAY);
    outputMat = tmp;
    
    // 记录灰度值
    cv::Mat grayMat;
    tmp.copyTo(grayMat);
    
    // 滤波 去噪声
    cv::blur(outputMat, tmp, cv::Size(3,3));
    outputMat = tmp;
    
    
    // THRESH_BINARY：二值化
    cv::threshold(outputMat, tmp, 100, 255, cv::THRESH_BINARY_INV);
    outputMat = tmp;
    
    // 边缘检测
    cv::Canny(outputMat, tmp, 30, 220);
    outputMat = tmp;
    
    // 边角检测  填充边界内空白色值
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(outputMat, contours, CV_RETR_LIST, CV_CHAIN_APPROX_NONE);
    for (int i = 0; i < contours.size(); i++) {
        for (int j = 0; j < contours[i].size(); j++) {
            // 根据点画圆
            cv::Point point = cv::Point(contours[i][j].x, contours[i][j].y);
            cv::circle(outputMat, point, 1, cv::Scalar(255,0,0,1), 2.5);
        }
    }
    
    // 直线检测
    std::vector<cv::Vec4i> lines;
    cv::HoughLinesP(outputMat, lines, 1, CV_PI/180, resizeMat.rows / 4, resizeMat.rows / 2, 5);
    
    cv::Vec4i filtLines[4];   // 过滤的线 [上，左，下，右]
    int filtLineFlag[4] = {0};
    
    cv::Point originPoint = cv::Point(resizeMat.rows / 2, resizeMat.cols / 2); // 原点
    
    for (size_t i = 0; i < lines.size(); i++) {
        cv::Vec4i line = lines[i];
        cv::Point point_1 = cv::Point(line[0],line[1]);
        cv::Point point_2 = cv::Point(line[2],line[3]);
        
        // 过滤线
        if (point_1.y > originPoint.y && point_2.y > originPoint.y && filtLineFlag[0] == 0) {
            filtLines[0] = line;
            filtLineFlag[0] = 1;
            cv::line(resizeMat, point_1, point_2, cv::Scalar(255,0,0,1));
        }
        
        if (point_1.x < originPoint.x && point_2.x < originPoint.x && filtLineFlag[1] == 0) {
            filtLines[1] = line;
            filtLineFlag[1] = 1;
            cv::line(resizeMat, point_1, point_2, cv::Scalar(255,0,0,1));
        }
        
        if (point_1.y < originPoint.y && point_2.y < originPoint.y && filtLineFlag[2] == 0) {
            filtLines[2] = line;
            filtLineFlag[2] = 1;
            cv::line(resizeMat, point_1, point_2, cv::Scalar(255,0,0,1));
        }
        
        if (point_1.x > originPoint.x && point_2.x > originPoint.x && filtLineFlag[3] == 0) {
            filtLines[3] = line;
            filtLineFlag[3] = 1;
            cv::line(resizeMat, point_1, point_2, cv::Scalar(255,0,0,1));
        }
        cv::line(resizeMat, point_1, point_2, cv::Scalar(255,0,0,1));
    }
    
    // 四个交点
    std::vector<cv::Point> filtPoints; // 存放计算的焦点
    filtPoints.push_back(CrossPointWithLine(filtLines[0], filtLines[1]));
    filtPoints.push_back(CrossPointWithLine(filtLines[0], filtLines[3]));
    filtPoints.push_back(CrossPointWithLine(filtLines[1], filtLines[2]));
    filtPoints.push_back(CrossPointWithLine(filtLines[3], filtLines[2]));
    
    for (int i = 0; i < filtPoints.size(); i++) {
        cv::circle(resizeMat, filtPoints[i], 10, cv::Scalar(255,0,0,1));
    }
    
    // 构造变换矩阵
    cv::Point2f src_vertices[4];
    src_vertices[0] = filtPoints[0];
    src_vertices[1] = filtPoints[1];
    src_vertices[2] = filtPoints[2];
    src_vertices[3] = filtPoints[3];
    
    cv::Point2f dst_vertices[4];
    dst_vertices[0] = cv::Point(0,resizeMat.cols);
    dst_vertices[1] = cv::Point(resizeMat.rows,resizeMat.cols);
    dst_vertices[2] = cv::Point(0, 0);
    dst_vertices[3] = cv::Point(resizeMat.rows,0);
    
    // 透视变换
    cv::Mat transform = cv::getPerspectiveTransform(src_vertices,dst_vertices);
    cv::warpPerspective(grayMat, tmp, transform, cv::Size(resizeMat.rows, resizeMat.cols));
    grayMat = tmp;
    
    
    // 设置ROI, 使用容器记录ROI
    std::vector<cv::Rect> ROIRect;
    int leading = 40, trailing = 15, top = 5, bottom = 5, margin_col = 50, margin_row = 10, width = 0, height = 0, row = 8, col = 4;
    width = (grayMat.cols - leading - trailing - margin_col * (col - 1)) / col;
    height = (grayMat.rows - top - bottom - margin_row * (row - 1)) / row;
    for (int i = 0; i < row; i++) {
        for (int j = 0; j < col; j++) {
            // 此处 +0.7 为特殊校准，不应该有
            cv::Rect rect = cv::Rect(j * (width + margin_col) + leading, i * (height + margin_row + 0.7) + top, width, height);
            ROIRect.push_back(rect);
            
        }
    }

    
    // 遍历ROI，设置并记录每道题的ROI
    std::vector<cv::Rect> ROIItemRect;
    for (int i = 0; i < ROIRect.size(); i++) {
        cv::Rect rect = ROIRect[i];
        int height = 0, margin_height = 0;
        height = (rect.height - margin_height * 4) / 5;
        for (int k = 0; k < 5; k++) {
            cv::Rect itemRect = cv::Rect(rect.x, rect.y + (height + margin_height) * k, rect.width, height);
            ROIItemRect.push_back(itemRect);
        }
    }
    
    // 二值化 灰度图
    cv::Mat binaryMat;
    cv::threshold(grayMat, binaryMat, 100, 255, cv::THRESH_BINARY);
    
    for (int i = 0; i < ROIItemRect.size(); i++) {  // 遍历每道题
        cv::Rect rect = ROIItemRect[i];
        // 分割选项
        int width = rect.width / 5;
        for (int k = 0; k < 5; k++) {
            cv::Rect itemRect = cv::Rect(rect.x + width * k, rect.y, width, rect.height);
            cv::Mat roiMat = binaryMat(itemRect);   // 截取ROI
            
            int count = 0;  // 统计色值
            for (int x = 0; x < roiMat.rows; x++) {
                for (int y = 0; y < roiMat.cols; y++) {
                    
                    if (roiMat.at<uchar>(x,y) == 0) {
                        count ++;
                    }
                }
            }
            
            // 超过 25% 算作有效答案
            if (count > roiMat.rows * roiMat.cols * 0.25) {
                switch (k) {
                    case 0:
                        NSLog(@"第 %d 题：A",i + 1);
                        break;
                    case 1:
                        NSLog(@"第 %d 题：B",i + 1);
                        break;
                    case 2:
                        NSLog(@"第 %d 题：C",i + 1);
                        break;
                    case 3:
                        NSLog(@"第 %d 题：D",i + 1);
                        break;
                    case 4:
                        NSLog(@"第 %d 题：E",i + 1);
                        break;
                        
                    default:
                        break;
                }
                continue;
            }
        }
    }
    
    return [UIImage imageWithCVMat:binaryMat];
}


// 计算直线交点
cv::Point CrossPointWithLine(cv::Vec4i & line1, cv::Vec4i & line2) {
    
    int l1_1_x = line1[0];
    int l1_1_y = line1[1];
    int l1_2_x = line1[2];
    int l1_2_y = line1[3];
    
    float a = (l1_1_y - l1_2_y) / ((l1_1_x - l1_2_x) == 0 ? 1.0 :(l1_1_x - l1_2_x));
    float b = l1_1_y - l1_1_x * a;
    
    int l2_1_x = line2[0];
    int l2_1_y = line2[1];
    int l2_2_x = line2[2];
    int l2_2_y = line2[3];
    
    float c = (l2_1_y - l2_2_y) / ((l2_1_x - l2_2_x) == 0 ? 1.0 : (l2_1_x - l2_2_x));
    float d = l2_1_y - l2_1_x * c;
    
    float x = (d - b) / (a - c);
    float y = (a*d - b*c) / (a - c);
    
    return cv::Point(x,y);
}

@end
