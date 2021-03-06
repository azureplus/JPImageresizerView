//
//  UIView+JPExtension.m
//  WoTV
//
//  Created by 周健平 on 2018/1/22.
//  Copyright © 2018年 zhanglinan. All rights reserved.
//

#import "UIView+JPExtension.h"
#import <objc/runtime.h>

@implementation UIView (JPExtension)

static const char JPBaseFrameKey = '\0';
- (void)setJp_baseFrame:(CGRect)jp_baseFrame {
    objc_setAssociatedObject(self, &JPBaseFrameKey, [NSValue valueWithCGRect:jp_baseFrame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGRect)jp_baseFrame {
    return [objc_getAssociatedObject(self, &JPBaseFrameKey) CGRectValue];
}

static const char JPMaskLayerKey = '\0';
- (void)setJp_maskLayer:(CAShapeLayer *)jp_maskLayer {
    objc_setAssociatedObject(self, &JPMaskLayerKey, jp_maskLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CAShapeLayer *)jp_maskLayer {
    return objc_getAssociatedObject(self, &JPMaskLayerKey);
}

static const char JPLineLayerKey = '\0';
- (void)setJp_lineLayer:(CAShapeLayer *)jp_lineLayer {
    objc_setAssociatedObject(self, &JPLineLayerKey, jp_lineLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CAShapeLayer *)jp_lineLayer {
    return objc_getAssociatedObject(self, &JPLineLayerKey);
}

- (void)jp_addRoundedCornerWithSize:(CGSize)size radius:(CGFloat)radius maskColor:(UIColor *)maskColor {
    [self jp_addRoundedCornerWithSize:size radius:radius maskColor:maskColor lineWidth:0 lineColor:nil];
}

- (void)jp_addRoundedCornerWithSize:(CGSize)size radius:(CGFloat)radius maskColor:(UIColor *)maskColor lineWidth:(CGFloat)lineWidth lineColor:(UIColor *)lineColor {
    
    self.clipsToBounds = YES;
    
    CGFloat halfLineW = lineWidth * 0.5;
    UIBezierPath *roundedPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(halfLineW, halfLineW, size.width - lineWidth, size.height - lineWidth) cornerRadius:radius];
    
    BOOL isHasLine = lineWidth > 0 && ![lineColor isEqual:[UIColor clearColor]];
    
    if (radius > 0  && ![maskColor isEqual:[UIColor clearColor]]) {
        
        self.layer.borderWidth = 0;
        
        if (!self.jp_maskLayer) {
            self.jp_maskLayer = [CAShapeLayer layer];
            self.jp_maskLayer.fillRule = kCAFillRuleEvenOdd;
            self.jp_maskLayer.fillColor = maskColor.CGColor;
            self.jp_maskLayer.lineWidth = 0;
        }
        
        UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(-1, -1, size.width + 2, size.height + 2)];
        [path appendPath:roundedPath];
        
        self.jp_maskLayer.path = path.CGPath;
        [self.layer addSublayer:self.jp_maskLayer];
        
        if (isHasLine) {
            if (!self.jp_lineLayer) {
                self.jp_lineLayer = [CAShapeLayer layer];
                self.jp_lineLayer.fillColor = [UIColor clearColor].CGColor;
            }
            
            self.jp_lineLayer.strokeColor = lineColor.CGColor;
            self.jp_lineLayer.lineWidth = lineWidth;
            self.jp_lineLayer.path = roundedPath.CGPath;
            
            [self.jp_maskLayer addSublayer:self.jp_lineLayer];
        } else {
            [self.jp_lineLayer removeFromSuperlayer];
            self.jp_lineLayer = nil;
        }
        
    } else {
        [self.jp_maskLayer removeFromSuperlayer];
        self.jp_maskLayer = nil;
        
        [self.jp_lineLayer removeFromSuperlayer];
        self.jp_lineLayer = nil;
        
        if (isHasLine) {
            self.layer.borderColor = lineColor.CGColor;
            self.layer.borderWidth = lineWidth;
        } else {
            self.layer.borderWidth = 0;
        }
    }
    
}

- (UIImage *)jp_convertToImage {
    UIGraphicsBeginImageContextWithOptions(self.jp_size, NO, [UIScreen mainScreen].scale);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (instancetype)jp_viewLoadFromNib {
    return [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:nil options:nil] firstObject];
}

+ (UIWindow *)jp_frontWindow {
    NSEnumerator *frontToBackWindows = [UIApplication.sharedApplication.windows reverseObjectEnumerator];
    for (UIWindow *window in frontToBackWindows) {
        BOOL windowOnMainScreen = window.screen == UIScreen.mainScreen;
        BOOL windowIsVisible = !window.hidden && window.alpha > 0;
//        BOOL windowLevelSupported = (window.windowLevel >= UIWindowLevelNormal && window.windowLevel <= self.maxSupportedWindowLevel);
        BOOL windowKeyWindow = window.isKeyWindow;
        if (windowOnMainScreen && windowIsVisible && windowKeyWindow) {
            return window;
        }
//        if (windowOnMainScreen && windowIsVisible && windowLevelSupported && windowKeyWindow) {
//            return window;
//        }
    }
    return nil;
}

- (BOOL)jp_isShowingOnKeyWindow {
    
    /*
     * 判断该视图是否在主窗口上的条件：
     * 1.没有隐藏
     * 2.透明度大于0.01
     * 3.它的窗口要在主窗口上（就例如tabbarController，切换另一个控制器，上一个控制器的view就看不见了，因为不在keyWindow上了）
     * 4.显示在主窗口的范围之内（即跟主窗口的bounds要有相交）
     */
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    
    //判断子视图是否在主窗口上需要转换坐标系（要在相同坐标系下才可以进行判断，这里是将self的坐标转换为相对于keyWindow上的坐标）
    CGRect onKeyWindowframe = [self.superview convertRect:self.frame toView:keyWindow];
    //参数1：原来坐标系（一般取它的父控件）
    //参数2：要转换的控件
    //参数3：目标坐标系（默认为主窗口，即可以填nil）
    
    return
    // ---- 条件1
    !self.isHidden &&
    // ---- 条件2
    self.alpha > 0.01 &&
    // ---- 条件3
    self.window == keyWindow &&
    // ---- 条件4
    CGRectIntersectsRect(keyWindow.bounds, onKeyWindowframe);
    //CGRectIntersectsRect(rect1,rect2)：判断rect1和rect2是否相交
    
    //严谨一点：添加subview.window == keyWindow条件（防止这种情况：在这里创建个scrollView没有添加到父控件上，其他的条件也能符合）
}

/** 获取顶层控制器 */
- (UIViewController *)jp_topViewController {
    UIViewController *resultVC;
    resultVC = [self _topViewController:[[UIApplication sharedApplication].keyWindow rootViewController]];
    while (resultVC.presentedViewController) {
        resultVC = [self _topViewController:resultVC.presentedViewController];
    }
    return resultVC;
}

- (UIViewController *)_topViewController:(UIViewController *)vc {
    if ([vc isKindOfClass:[UINavigationController class]]) {
        return [self _topViewController:[(UINavigationController *)vc topViewController]];
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        return [self _topViewController:[(UITabBarController *)vc selectedViewController]];
    } else {
        return vc;
    }
    return nil;
}

+ (UIViewController *)jp_getTopViewController {
    UIViewController *resultVC;
    resultVC = [self _getTopViewController:[[UIApplication sharedApplication].keyWindow rootViewController]];
    while (resultVC.presentedViewController) {
        resultVC = [self _getTopViewController:resultVC.presentedViewController];
    }
    if ([resultVC isKindOfClass:[UIAlertController class]])  {
        resultVC = resultVC.presentingViewController;
        if ([resultVC isKindOfClass:[UINavigationController class]]) {
            return [(UINavigationController *)resultVC topViewController];
        } else if ([resultVC isKindOfClass:[UITabBarController class]]) {
            return [(UITabBarController *)resultVC selectedViewController];
        }
    }
    return resultVC;
}

+ (UIViewController *)_getTopViewController:(UIViewController *)vc {
    if ([vc isKindOfClass:[UINavigationController class]]) {
        return [self _getTopViewController:[(UINavigationController *)vc topViewController]];
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        return [self _getTopViewController:[(UITabBarController *)vc selectedViewController]];
    } else {
        return vc;
    }
}

/** 获取顶层导航控制器控制器 */
- (UINavigationController *)jp_topNavigationController {
    UIViewController *topViewController = self.jp_topViewController;
    if (topViewController.navigationController) {
        return topViewController.navigationController;
    } else {
        return nil;
    }
}

- (void)setJp_x:(CGFloat)jp_x {
    CGRect frame = self.frame;
    frame.origin.x = jp_x;
    self.frame = frame;
}
- (CGFloat)jp_x {
    return self.frame.origin.x;
}

- (void)setJp_y:(CGFloat)jp_y {
    CGRect frame = self.frame;
    frame.origin.y = jp_y;
    self.frame = frame;
}
- (CGFloat)jp_y {
    return self.frame.origin.y;
}

- (void)setJp_width:(CGFloat)jp_width {
    CGRect frame = self.frame;
    frame.size.width = jp_width;
    self.frame = frame;
}
- (CGFloat)jp_width {
    return self.frame.size.width;
}

- (void)setJp_height:(CGFloat)jp_height {
    CGRect frame = self.frame;
    frame.size.height = jp_height;
    self.frame = frame;
}
- (CGFloat)jp_height {
    return self.frame.size.height;
}

- (void)setJp_origin:(CGPoint)jp_origin {
    CGRect frame = self.frame;
    frame.origin = jp_origin;
    self.frame = frame;
}
- (CGPoint)jp_origin {
    return self.frame.origin;
}

- (void)setJp_size:(CGSize)jp_size {
    CGRect frame = self.frame;
    frame.size = jp_size;
    self.frame = frame;
}
- (CGSize)jp_size {
    return self.frame.size;
}

- (void)setJp_midX:(CGFloat)jp_midX {
    CGRect frame = self.frame;
    frame.origin.x += (jp_midX - CGRectGetMidX(frame));
    self.frame = frame;
}
- (CGFloat)jp_midX {
    return CGRectGetMidX(self.frame);
}

- (void)setJp_midY:(CGFloat)jp_midY {
    CGRect frame = self.frame;
    frame.origin.y += (jp_midY - CGRectGetMidY(frame));
    self.frame = frame;
}
- (CGFloat)jp_midY {
    return CGRectGetMidY(self.frame);
}

- (void)setJp_maxX:(CGFloat)jp_maxX {
    CGRect frame = self.frame;
    frame.origin.x += (jp_maxX - CGRectGetMaxX(frame));
    self.frame = frame;
}
- (CGFloat)jp_maxX {
    return CGRectGetMaxX(self.frame);
}

- (void)setJp_maxY:(CGFloat)jp_maxY {
    CGRect frame = self.frame;
    frame.origin.y += (jp_maxY - CGRectGetMaxY(frame));
    self.frame = frame;
}
- (CGFloat)jp_maxY {
    return CGRectGetMaxY(self.frame);
}

- (void)setJp_centerX:(CGFloat)jp_centerX {
    CGPoint center = self.center;
    center.x = jp_centerX;
    self.center = center;
}

- (CGFloat)jp_centerX {
    return self.center.x;
}

- (void)setJp_centerY:(CGFloat)jp_centerY {
    CGPoint center = self.center;
    center.y = jp_centerY;
    self.center = center;
}

- (CGFloat)jp_centerY {
    return self.center.y;
}

- (CGFloat)jp_radian {
    CGAffineTransform t = self.transform;
    return atan2f(t.b, t.a);
}

- (CGFloat)jp_angle {
    return (self.jp_radian * 180.0) / M_PI;
}

- (CGFloat)jp_scaleX {
    CGAffineTransform t = self.transform;
    return sqrt(t.a * t.a + t.c * t.c);
}

- (CGFloat)jp_scaleY {
    CGAffineTransform t = self.transform;
    return sqrt(t.b * t.b + t.d * t.d);
}

- (CGPoint)jp_scale {
    return CGPointMake(self.jp_scaleX, self.jp_scaleY);
}

@end

@implementation CALayer (JPExtension)

- (UIImage *)jp_convertToImage {
    UIGraphicsBeginImageContextWithOptions(self.jp_size, NO, [UIScreen mainScreen].scale);
    [self renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)setJp_x:(CGFloat)jp_x {
    CGRect frame = self.frame;
    frame.origin.x = jp_x;
    self.frame = frame;
}
- (CGFloat)jp_x {
    return self.frame.origin.x;
}

- (void)setJp_y:(CGFloat)jp_y {
    CGRect frame = self.frame;
    frame.origin.y = jp_y;
    self.frame = frame;
}
- (CGFloat)jp_y {
    return self.frame.origin.y;
}

- (void)setJp_width:(CGFloat)jp_width {
    CGRect frame = self.frame;
    frame.size.width = jp_width;
    self.frame = frame;
}
- (CGFloat)jp_width {
    return self.frame.size.width;
}

- (void)setJp_height:(CGFloat)jp_height {
    CGRect frame = self.frame;
    frame.size.height = jp_height;
    self.frame = frame;
}
- (CGFloat)jp_height {
    return self.frame.size.height;
}

- (void)setJp_origin:(CGPoint)jp_origin {
    CGRect frame = self.frame;
    frame.origin = jp_origin;
    self.frame = frame;
}
- (CGPoint)jp_origin {
    return self.frame.origin;
}

- (void)setJp_size:(CGSize)jp_size {
    CGRect frame = self.frame;
    frame.size = jp_size;
    self.frame = frame;
}
- (CGSize)jp_size {
    return self.frame.size;
}

- (void)setJp_midX:(CGFloat)jp_midX {
    CGRect frame = self.frame;
    frame.origin.x += (jp_midX - CGRectGetMidX(frame));
    self.frame = frame;
}
- (CGFloat)jp_midX {
    return CGRectGetMidX(self.frame);
}

- (void)setJp_midY:(CGFloat)jp_midY {
    CGRect frame = self.frame;
    frame.origin.y += (jp_midY - CGRectGetMidY(frame));
    self.frame = frame;
}
- (CGFloat)jp_midY {
    return CGRectGetMidY(self.frame);
}

- (void)setJp_maxX:(CGFloat)jp_maxX {
    CGRect frame = self.frame;
    frame.origin.x += (jp_maxX - CGRectGetMaxX(frame));
    self.frame = frame;
}
- (CGFloat)jp_maxX {
    return CGRectGetMaxX(self.frame);
}

- (void)setJp_maxY:(CGFloat)jp_maxY {
    CGRect frame = self.frame;
    frame.origin.y += (jp_maxY - CGRectGetMaxY(frame));
    self.frame = frame;
}
- (CGFloat)jp_maxY {
    return CGRectGetMaxY(self.frame);
}

- (void)setJp_anchorX:(CGFloat)jp_anchorX {
    CGPoint anchorPoint = self.anchorPoint;
    anchorPoint.x = jp_anchorX;
    self.anchorPoint = anchorPoint;
}
- (CGFloat)jp_anchorX {
    return self.anchorPoint.x;
}

- (void)setJp_anchorY:(CGFloat)jp_anchorY {
    CGPoint anchorPoint = self.anchorPoint;
    anchorPoint.y = jp_anchorY;
    self.anchorPoint = anchorPoint;
}
- (CGFloat)jp_anchorY {
    return self.anchorPoint.y;
}

- (void)setJp_positionX:(CGFloat)jp_positionX {
    CGPoint position = self.position;
    position.x = jp_positionX;
    self.position = position;
}
- (CGFloat)jp_positionX {
    return self.position.x;
}

- (void)setJp_positionY:(CGFloat)jp_positionY {
    CGPoint position = self.position;
    position.y = jp_positionY;
    self.position = position;
}
- (CGFloat)jp_positionY {
    return self.position.y;
}

- (CGFloat)jp_radian {
    return [[self valueForKeyPath:@"transform.rotation.z"] doubleValue];
}

- (CGFloat)jp_angle {
    return (self.jp_radian * 180.0) / M_PI;
}

- (CGFloat)jp_scaleX {
    return [[self valueForKeyPath:@"transform.scale.x"] doubleValue];
}

- (CGFloat)jp_scaleY {
    return [[self valueForKeyPath:@"transform.scale.y"] doubleValue];
}

- (CGPoint)jp_scale {
    return CGPointMake(self.jp_scaleX, self.jp_scaleY);
}

@end

