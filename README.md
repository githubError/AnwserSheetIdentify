# AnwserSheetIdentify
iOS OpenCV 答题卡识别

**文章发布在：[http://www.cuipengfei.cn/2018/04/opencv-answer-sheet-identify/](http://www.cuipengfei.cn/2018/04/opencv-answer-sheet-identify/)**

最近计划学习一些图像处理方面的知识，第一时间想到了功能强大的 OpenCV Lib。

早在一年多前出来北京实习的时候，实习公司的一个短视频处理 App 在最初的技术选型的时候就将 OpenCV 作为重要解决方案之一。无奈的是，当初我是一个没毕业的 iOS 小菜鸡，初出茅庐又不懂的 C++，还要肩负起独立开发的大旗，实在是搞不懂也没时间搞这么高精尖的 Lib。在放弃 OpenCV Lib 以及尝试过 AVFoundation 框架后，因此项目最终选用了 GPUImage 来实现，当然这都是后话了。

这次的 OpenCV 的学习，一方面是为了弥补之前的技术空白，另一方面也是为了自己能在图像处理上有所了解，能站在巨人的肩膀上提升一下自身技术的维度。

### 目的及结果
本篇的写作目的是记录学习 OpenCV Lib 以及运用到答题卡识别的相关过程，并且也是对新学习知识点的梳理和重新组织。

本文的实现目的是：利用 OpenCV Lib 识别一张特定的答题卡照片，并且识别出学生填涂的选项。

#### 原图如下：

<img src="http://www.cuipengfei.cn/assets/post_images/2018/opencv_origin.jpg" width = "40%" />

#### 实现结果如下：（红框内为识别结果）
<img src="http://www.cuipengfei.cn/assets/post_images/2018/opencv_result.png" width = "40%" />


### 准备
考虑到 OpenCV 是基于 C/C++ 可跨平台的通用 Lib，为了降低学习成本，便将整个学习和实验集成到 iOS 的开发环境里了。前期要做如下几方面的准备工作：

1. 下载编译 OpenCV Lib，或者直接下载最新的 iOS OpenCV.framework 的 Release 版本；
2. 将自行编译或 Release 版 OpenCV.framework 导入 iOS 项目工程中；
3. 因为 OpenCV 中的 MIN 宏和 UIKit 的 MIN 宏有冲突，所以需要在 .pch 文件中，先定义 OpenCV 的头文件，否则会有编译错误；
4. 将需要混编 C++ 和 Objective-C 的文件后缀改为 **.mm**;
5. 为 UIImage 添加 Category，方便与OpenCV 图象格式的数据 cv::Mat 相互转换。
因这些繁琐的配置问题不是本文写作重点，而且网上不乏一些详细说明，推荐参考 [在MacOS和iOS系统中使用OpenCV](https://blog.devtang.com/2012/10/27/use-opencv-in-ios/) 一文，这里就不再赘述。

### 技术方案
需要说明的是，在学习 OpenCV 的基础知识时，无意间发现唐巧大神几年前写的 [猿题库iOS客户端的技术细节（二）：答题卡扫描算法](http://blog.devtang.com/2013/10/19/the-tech-detail-of-ape-client-2/) 一文。文中提到，在文章发布时相关的识别算法还在进行专利申请，并且在专利申请结束会披露算法细节，但是遗憾的是相关的算法细节并没有公开。

不过万幸的是，唐巧大神提供了一套不错的解决方案，我本人的算法就是按照这个思路展开的，方案如下：

- 图像预处理，压缩图像；
- 将彩色图像转为灰度图像；
- 二值化灰度图像，识别答题卡区域；
- 透视变换，图像纠偏；
- 答案区域 ROI 识别；
- ROI 色值统计，标定答案。

### 具体实现
以下为整个技术方案的分步实现算法及效果图，绝大部分均使用的是 OpenCV Lib 标准 API，具体功能以及参数说明可自行查阅[官方文档](https://opencv.org/)。

- 图像预处理、压缩图像

因 iOS 系统的图片数据为 UIImage 类型，在使用 OpenCV Lib 处理图片是需要预处理成为 cv::Mat 类型，然后将预处理后的 cv::Mat 图像数据作为 inputMat 并对其进行压缩处理，降低 CPU 运算负荷。

``` objc
// 压缩
cv::resize(inputMat, outputMat, cv::Size(inputMat.rows / 1.5, inputMat.cols/ 1.5));

```

<br/>

- 将彩色图像转为灰度图像

将压缩处理后的 cv::Mat 彩色图像数据进行灰度处理，便于接下来的二值化。

``` objc
// 灰度处理
cv::cvtColor(inputMat, outputMat, CV_BGR2GRAY);
```
处理结果：

<img src="http://www.cuipengfei.cn/assets/post_images/2018/opencv_grayMat.png" width="40%"/>


<br/>

- 图像降噪、二值化

在图像进行二值化之前，需要对灰度图像做一次降噪处理，用以消除图像模糊的噪声，提高二值化的清晰度。在对比过均值滤波、高斯滤波、中值滤波后，选择了效果稍明显的均值滤波方式，代码如下：

``` objc
// 滤波 去噪声
cv::blur(inputMat, outputMat, cv::Size(3,3));

// 二值化
cv::threshold(inputMat, outputMat, 100, 255, cv::THRESH_BINARY_INV);
```

处理结果：

<img src="http://www.cuipengfei.cn/assets/post_images/2018/opencv_binary.png" width="40%"/>


<br/>

- 直线检测

对二值化图像进行直线检测，目的是检测出答题卡的方框，为了视觉效果更加明显，这里将检测的直线，直接绘制在压缩的图像上，并且颜色设置为红色。

``` objc
// 直线检测
std::vector<cv::Vec4i> lines;
cv::HoughLinesP(outputMat, lines, 1, CV_PI/180, resizeMat.rows / 4, resizeMat.rows / 2, 5);
for (size_t i = 0; i < lines.size(); i++) {

// 获取直线收尾两点
cv::Vec4i line = lines[i];
cv::Point point_1 = cv::Point(line[0],line[1]);
cv::Point point_2 = cv::Point(line[2],line[3]);

// 绘制直线
cv::line(resizeMat, point_1, point_2, cv::Scalar(255,0,0,1));
}

```

处理结果：

<img src="http://www.cuipengfei.cn/assets/post_images/2018/opencv_line.png" width="40%"/>


<br/>

- 直线过滤

因需要识别答题卡的ROI区域（即每一道题的选项位置），我们需要先识别出答题卡方框区域的四个顶点，以便根据四个顶点进行透视变换。

四个顶点的位置可以根据上、下、左、右四条直线，两两相交的性质分别求出，但是很不幸，如上图所示，进行直线检测时通过设置合理的阈值参数，能检测处在出边框范围内的很多条直线，因此在计算四个交点之前，还需要先合理的过滤出上、下、左、右四条直线。

为方便起见，这里直接在检测出直线的时候进行过滤，过滤的规则很简单，根据直线两个端点分别相对于图像中心点的位置，判断出当前直线属于上下左右的哪一个方位，并且只保留该方位第一条被检测到的直线。

直线检测及过滤的代码如下：

``` objc
// 直线检测
std::vector<cv::Vec4i> lines;
cv::HoughLinesP(outputMat, lines, 1, CV_PI/180, resizeMat.rows / 4, resizeMat.rows / 2, 5);

cv::Vec4i filtLines[4];   // 过滤的线 [上，左，下，右]
int filtLineFlag[4] = {0};

cv::Point originPoint = cv::Point(resizeMat.rows / 2, resizeMat.cols / 2); // 图像中心点

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

```


<br/>

- 计算四个顶点

上面通过简单的过滤算法，得到了不同方位的四条直线，并存放在 cv::Vec4i filtLines[4] 的容器内，容器内的线条和对应方位为：[上，左，下，右]。

接下来变可以分别取出对应位置的两条线段计算交点，计算交点需要使用简单的数学公式，代码如下，不再赘述：

``` objc
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
```

使用容器将计算的交点，按照位置有序存储：

``` objc
std::vector<cv::Point> filtPoints; // 存放计算的焦点

filtPoints.push_back(CrossPointWithLine(filtLines[0], filtLines[1]));
filtPoints.push_back(CrossPointWithLine(filtLines[0], filtLines[3]));
filtPoints.push_back(CrossPointWithLine(filtLines[1], filtLines[2]));
filtPoints.push_back(CrossPointWithLine(filtLines[3], filtLines[2]));

```

已计算的四个交点为圆心画圆，查看效果（四个顶点的圆画的有点小，凑合看吧😂）：

<img src="http://www.cuipengfei.cn/assets/post_images/2018/opencv_crossPoint.png" width="40%"/>


<br/>

- 图像纠偏

根据上述的四个顶点，构造透视变换的变换矩阵，利用 OpenCV Lib 的透视变换，对灰度图像，进行图像纠偏处理。

``` objc 
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
cv::warpPerspective(grayMat, output, transform, cv::Size(resizeMat.rows, resizeMat.cols));
```

效果如下：

<img src="http://www.cuipengfei.cn/assets/post_images/2018/opencv_transform.png" width="40%"/>


<br/>

- 设置选项区域 ROI（感兴趣区域）

观察纠偏后的灰度图像的规律，可以按照每5道题设置一个 ROI，并标定出相应的位置，这里需要特别注意的是，上下左右以及 ROI 间隔的设置需要根据整个纠偏后的图像大小的比例来确定，为了简单起见，这里直接写成固定值。算法如下：

``` objc
// 设置ROI, 使用容器记录ROI
std::vector<cv::Rect> ROIRect;
int leading = 40, trailing = 15, top = 5, bottom = 5, margin_col = 50, margin_row = 10, width = 0, height = 0, row = 8, col = 4;
width = (grayMat.cols - leading - trailing - margin_col * (col - 1)) / col;
height = (grayMat.rows - top - bottom - margin_row * (row - 1)) / row;
for (int i = 0; i < row; i++) {
for (int j = 0; j < col; j++) {
cv::Rect rect = cv::Rect(j * (width + margin_col) + leading, i * (height + margin_row + 0.7) + top, width, height);
ROIRect.push_back(rect);

cv::rectangle(writeMat, rect, cv::Scalar(255,0,0,1));
}
}
```
将划分的 ROI 使用方框标记，效果如下：

<img src="http://www.cuipengfei.cn/assets/post_images/2018/opencv_ROIRect.png" width="40%"/>


<br/>

- 根据选项区域，设置每道题的 ROI

这一步对选项区域进一步拆分，计算出每一道题的 ROI。可以和上面计算区域的方法合并，直接进行每道题的 ROI 拆分，能有效减少循环及计算次数，降低 CPU 负荷，这大概也是最后识别耗时比唐巧大佬多出0.03秒的原因之一，这里不再深究。

``` objc
// 遍历ROI，设置并记录每道题的ROI
std::vector<cv::Rect> ROIItemRect;
for (int i = 0; i < ROIRect.size(); i++) {
cv::Rect rect = ROIRect[i];
int height = 0, margin_height = 0;
height = (rect.height - margin_height * 4) / 5;
for (int k = 0; k < 5; k++) {
cv::Rect itemRect = cv::Rect(rect.x, rect.y + (height + margin_height) * k, rect.width, height);
ROIItemRect.push_back(itemRect);

cv::rectangle(writeMat, itemRect, cv::Scalar(255,0,0,1));
}
}
```

效果如下：

<img src="http://www.cuipengfei.cn/assets/post_images/2018/opencv_ROIItemRect.png" width="40%"/>


<br/>

- 二值化纠偏后的灰度图像，便于接下来的色值统计

这里对纠偏后的灰度图进行二值化操作，其实不是必须的，为了性能提升减少耗时才做，在进行上面的图像纠偏时可以直接对第一次二值化的图像进行纠偏操作。但是在实现的过程中因为要控制每一步的显示效果，这里多做了一次处理，可以忽略。

``` objc
// 二值化 灰度图
cv::Mat binaryMat;
cv::threshold(grayMat, binaryMat, 100, 255, cv::THRESH_BINARY);
```


<br/>

- 分割选项，统计色值，计算有效作答

对纠偏后的二值化图像，按照上述计算的每道题的 ROI，按照选项横向均等划分为 5 个区域，对应答题卡中的 ABCDE 五个选项，分别对每道题的 ROI 的 5 个区域的像素进行色值统计，统计出色值等于 0 的像素点个数，个数超过该选项总像素点的 25% 时即为有效作答，并且 log 出当前的题号和选项值。算法如下：

``` objc
for (int i = 0; i < ROIItemRect.size(); i++) {  // 遍历每道题
cv::Rect rect = ROIItemRect[i];
// 分割选项
int width = rect.width / 5;
for (int k = 0; k < 5; k++) {
cv::Rect itemRect = cv::Rect(rect.x + width * k, rect.y, width, rect.height);
cv::Mat roiMat = binaryMat(itemRect);   // 截取ROI

cv::rectangle(writeMat, itemRect, cv::Scalar(255,0,0,1));

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
```

最终的识别结果如下：

<img src="http://www.cuipengfei.cn/assets/post_images/2018/opencv_result.png" width="40%"/>


<br/><br/>

### 总结

这套解决方案的实现思路来源于唐巧大神的[猿题库iOS客户端的技术细节（二）：答题卡扫描算法](http://blog.devtang.com/2013/10/19/the-tech-detail-of-ape-client-2/) 一文，本文实现的算法没有经过过多的测试，仅能保证这张图片的识别率在95%以上。另外，在 CPU 运算耗时上面，这些计算方式没有进行优化也不是最优解。

唐巧大神没有开源此算法，我这菜鸡代码大家凑合看吧，源代码不包含 opencv2.framework，请自行下载后添加进项目中。答题卡识别 Demo 地址：[https://github.com/githubError/AnwserSheetIdentify](https://github.com/githubError/AnwserSheetIdentify)

如有疑问，请联系我：[http://www.cuipengfei.cn/](http://www.cuipengfei.cn/)


-EOF-

