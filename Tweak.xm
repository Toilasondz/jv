//
//  Tweak.xm
//  VideoStarMacroTool
//
//  Created by Senior iOS Reverse Engineer on 2026.
//  Copyright © 2026. All rights reserved.
//

#import "Tweak.h"

#pragma mark - 1. RUNTIME & UI SAFETY UTILITIES

UIWindow * _Nullable VSGetActiveKeyWindow(void) {
    if (![NSThread isMainThread]) {
        __block UIWindow *win = nil;
        dispatch_sync(dispatch_get_main_queue(), ^{
            win = VSGetActiveKeyWindow();
        });
        return win;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow) {
                        return w;
                    }
                }
            }
        }
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (!w.hidden && w.alpha > 0.01) {
                        return w;
                    }
                }
            }
        }
    }

    UIWindow *legacyKeyWindow = [UIApplication sharedApplication].keyWindow;
    if (legacyKeyWindow) {
        return legacyKeyWindow;
    }

    NSArray<UIWindow *> *windows = [UIApplication sharedApplication].windows;
    if (windows.count > 0) {
        return windows.firstObject;
    }

    return nil;
}

UIViewController * _Nullable VSGetTopViewController(void) {
    UIWindow *keyWindow = VSGetActiveKeyWindow();
    if (!keyWindow) return nil;

    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }

    if ([topVC isKindOfClass:[UINavigationController class]]) {
        topVC = [(UINavigationController *)topVC topViewController] ?: topVC;
    } else if ([topVC isKindOfClass:[UITabBarController class]]) {
        topVC = [(UITabBarController *)topVC selectedViewController] ?: topVC;
    }

    return topVC;
}

BOOL VSSafeViewIsClass(UIView * _Nullable view, NSString *classNamePart) {
    if (!view || !classNamePart || classNamePart.length == 0) return NO;
    NSString *clsName = NSStringFromClass([view class]);
    return [clsName rangeOfString:classNamePart options:NSCaseInsensitiveSearch].location != NSNotFound;
}

UIView * _Nullable VSFindFirstSubviewOfClass(UIView * _Nullable root, NSString *classNamePart) {
    if (!root || !classNamePart) return nil;
    if (VSSafeViewIsClass(root, classNamePart)) {
        return root;
    }
    for (UIView *sub in root.subviews) {
        UIView *found = VSFindFirstSubviewOfClass(sub, classNamePart);
        if (found) {
            return found;
        }
    }
    return nil;
}

NSArray<UIView *> *VSFindAllSubviewsOfClass(UIView * _Nullable root, NSString *classNamePart) {
    NSMutableArray<UIView *> *results = [NSMutableArray array];
    if (!root || !classNamePart) return results;

    if (VSSafeViewIsClass(root, classNamePart)) {
        [results addObject:root];
    }
    for (UIView *sub in root.subviews) {
        [results addObjectsFromArray:VSFindAllSubviewsOfClass(sub, classNamePart)];
    }
    return results;
}

void VSSafePerformSelector(id _Nullable target, NSString *selectorName, id _Nullable arg) {
    if (!target || !selectorName || selectorName.length == 0) return;

    SEL sel = NSSelectorFromString(selectorName);
    if ([target respondsToSelector:sel]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        if (arg) {
            [target performSelector:sel withObject:arg];
        } else {
            [target performSelector:sel];
        }
        #pragma clang diagnostic pop
        return;
    }

    NSString *colonSelName = [selectorName stringByAppendingString:@":"];
    SEL colonSel = NSSelectorFromString(colonSelName);
    if ([target respondsToSelector:colonSel]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [target performSelector:colonSel withObject:arg ?: target];
        #pragma clang diagnostic pop
    }
}

// Đã tối ưu hóa hàm giả lập chạm an toàn tuyệt đối, loại bỏ hoàn toàn UITouch thủ công gây crash iOS 14+
void VSSimulateTapOnView(UIView * _Nullable targetView) {
    if (!targetView) return;

    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            VSSimulateTapOnView(targetView);
        });
        return;
    }

    // 1. Nếu là UIControl (UIButton, Switch,...), kích hoạt sự kiện TouchUpInside trực tiếp
    if ([targetView isKindOfClass:[UIControl class]]) {
        UIControl *control = (UIControl *)targetView;
        [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        return;
    }

    // 2. Kích hoạt gesture recognizer hợp lệ thông qua Runtime target/action
    for (UIGestureRecognizer *gesture in targetView.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]] && gesture.isEnabled) {
            UITapGestureRecognizer *tap = (UITapGestureRecognizer *)gesture;
            id target = nil;
            SEL action = NULL;
            
            @try {
                NSArray *targets = [tap valueForKey:@"_targets"];
                id targetContainer = targets.firstObject;
                if (targetContainer) {
                    target = [targetContainer valueForKey:@"_target"];
                    NSValue *actionValue = [targetContainer valueForKey:@"_action"];
                    if (actionValue) {
                        action = (SEL)[actionValue pointerValue];
                    }
                }
            } @catch (NSException *e) {
                MACRO_LOG(@"Lỗi đọc Gesture Target: %@", e);
            }

            if (target && action && [target respondsToSelector:action]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [target performSelector:action withObject:tap];
                #pragma clang diagnostic pop
                return;
            }
        }
    }

    // 3. Fallback an toàn cho Custom View
    if ([targetView respondsToSelector:@selector(touchesBegan:withEvent:)]) {
        [targetView touchesBegan:[NSSet set] withEvent:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([targetView respondsToSelector:@selector(touchesEnded:withEvent:)]) {
                [targetView touchesEnded:[NSSet set] withEvent:nil];
            }
        });
    }
}

#pragma mark - 2. TOAST HUD IMPLEMENTATION

@implementation MacroToastHUD

+ (void)showMessage:(NSString *)message duration:(NSTimeInterval)duration {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showMessage:message duration:duration];
        });
        return;
    }

    UIWindow *window = VSGetActiveKeyWindow();
    if (!window) return;

    UIView *oldToast = [window viewWithTag:998877];
    if (oldToast) {
        [oldToast removeFromSuperview];
    }

    CGFloat screenWidth = window.bounds.size.width;
    CGFloat toastWidth = MIN(screenWidth - 40.0, 320.0);
    CGFloat toastHeight = 44.0;
    CGFloat topPadding = 50.0;
    if (@available(iOS 11.0, *)) {
        topPadding = window.safeAreaInsets.top + 10.0;
    }

    UIView *toastView = [[UIView alloc] initWithFrame:CGRectMake((screenWidth - toastWidth) / 2.0, topPadding, toastWidth, toastHeight)];
    toastView.tag = 998877;
    toastView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    toastView.layer.cornerRadius = 22.0;
    toastView.layer.masksToBounds = YES;
    toastView.layer.borderWidth = 1.0;
    toastView.layer.borderColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.6].CGColor;
    toastView.alpha = 0.0;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, toastWidth - 24, toastHeight)];
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightMedium];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    [toastView addSubview:label];

    [window addSubview:toastView];
    [window bringSubviewToFront:toastView];

    [UIView animateWithDuration:0.25 animations:^{
        toastView.alpha = 1.0;
        toastView.transform = CGAffineTransformMakeScale(1.05, 1.05);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 animations:^{
            toastView.transform = CGAffineTransformIdentity;
        }];
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            toastView.alpha = 0.0;
            toastView.transform = CGAffineTransformMakeTranslation(0, -15);
        } completion:^(BOOL finished) {
            [toastView removeFromSuperview];
        }];
    });
}

@end

#pragma mark - 3. FLOATING BUTTON IMPLEMENTATION

@interface MacroFloatingButton ()
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, assign) CGPoint startTouchPoint;
@end

@implementation MacroFloatingButton

+ (instancetype)sharedButton {
    static MacroFloatingButton *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [MacroFloatingButton buttonWithType:UIButtonTypeCustom];
        [instance setupUI];
    });
    return instance;
}

- (void)setupUI {
    self.frame = CGRectMake(20, 180, 56, 56);
    self.layer.cornerRadius = 28;
    self.layer.masksToBounds = NO;
    self.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.15 alpha:0.88];
    self.layer.borderWidth = 1.8;
    self.layer.borderColor = [UIColor colorWithRed:0.20 green:0.75 blue:1.00 alpha:0.85].CGColor;
    
    self.layer.shadowColor = [UIColor colorWithRed:0.20 green:0.75 blue:1.00 alpha:0.6].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 3);
    self.layer.shadowOpacity = 0.7;
    self.layer.shadowRadius = 8;

    [self setTitle:@"⭐" forState:UIControlStateNormal];
    self.titleLabel.font = [UIFont systemFontOfSize:26];

    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:self.panGesture];

    [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
}

- (void)attachToKeyWindow {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self attachToKeyWindow];
        });
        return;
    }

    UIWindow *window = VSGetActiveKeyWindow();
    if (!window) return;

    if (self.superview != window) {
        [self removeFromSuperview];
        [window addSubview:self];
        [window bringSubviewToFront:self];
        MACRO_LOG(@"Floating button successfully attached to window: %@", window);
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *superView = self.superview;
    if (!superView) return;

    CGPoint translation = [pan translationInView:superView];
    CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);

    UIEdgeInsets safeInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeInsets = superView.safeAreaInsets;
    }

    CGFloat minX = safeInsets.left + self.frame.size.width / 2.0;
    CGFloat maxX = superView.bounds.size.width - safeInsets.right - self.frame.size.width / 2.0;
    CGFloat minY = safeInsets.top + self.frame.size.height / 2.0 + 10;
    CGFloat maxY = superView.bounds.size.height - safeInsets.bottom - self.frame.size.height / 2.0 - 10;

    newCenter.x = MAX(minX, MIN(newCenter.x, maxX));
    newCenter.y = MAX(minY, MIN(newCenter.y, maxY));

    self.center = newCenter;
    [pan setTranslation:CGPointZero inView:superView];

    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat midX = superView.bounds.size.width / 2.0;
        CGFloat targetX = (self.center.x < midX) ? minX : maxX;

        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.center = CGPointMake(targetX, self.center.y);
        } completion:nil];
    }
}

- (void)handleTap {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    [self showMenu];
}

- (void)showMenu {
    UIViewController *topVC = VSGetTopViewController();
    if (!topVC) {
        [MacroToastHUD showMessage:@"Không tìm thấy màn hình giao diện!" duration:2.0];
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"🎬 VideoStar Macro Tool"
                                                                   message:@"Chọn chức năng tự động hóa cần thực hiện:"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *actionImport = [UIAlertAction actionWithTitle:@"🖼️ [Auto Nhập Ảnh/Video vào Lớp]"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [[VideoStarMacroEngine sharedEngine] startAutoImportMedia];
    }];

    UIAlertAction *actionBeat = [UIAlertAction actionWithTitle:@"🎵 [Auto Chia Đoạn Theo Beat]"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        [self showBeatSplitOptionsDialog];
    }];

    UIAlertAction *actionStop = [UIAlertAction actionWithTitle:@"⏹️ [Dừng Macro Đang Chạy]"
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction * _Nonnull action) {
        [[VideoStarMacroEngine sharedEngine] stopAllMacros];
    }];

    UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:@"❌ Đóng"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [sheet addAction:actionImport];
    [sheet addAction:actionBeat];
    if ([VideoStarMacroEngine sharedEngine].isRunning) {
        [sheet addAction:actionStop];
    }
    [sheet addAction:actionCancel];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self;
        sheet.popoverPresentationController.sourceRect = self.bounds;
        sheet.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [topVC presentViewController:sheet animated:YES completion:nil];
}

- (void)showBeatSplitOptionsDialog {
    UIViewController *topVC = VSGetTopViewController();
    if (!topVC) return;

    UIAlertController *dialog = [UIAlertController alertControllerWithTitle:@"🎵 Thiết lập số điểm cắt Beat"
                                                                    message:@"Chọn số lượng phân cảnh hoặc số lần chia beat mong muốn:"
                                                             preferredStyle:UIAlertControllerStyleAlert];

    [dialog addAction:[UIAlertAction actionWithTitle:@"Cắt 10 Beats (Nhanh)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[VideoStarMacroEngine sharedEngine] startAutoBeatSplitWithTargetCount:10 interval:0.28];
    }]];

    [dialog addAction:[UIAlertAction actionWithTitle:@"Cắt 20 Beats (Chuẩn)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[VideoStarMacroEngine sharedEngine] startAutoBeatSplitWithTargetCount:20 interval:0.28];
    }]];

    [dialog addAction:[UIAlertAction actionWithTitle:@"Cắt 35 Beats (Dài)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[VideoStarMacroEngine sharedEngine] startAutoBeatSplitWithTargetCount:35 interval:0.28];
    }]];

    [dialog addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];

    [topVC presentViewController:dialog animated:YES completion:nil];
}

@end

#pragma mark - 4. AUTOMATION MACRO ENGINE IMPLEMENTATION

@interface VideoStarMacroEngine ()
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, assign) BOOL shouldCancel;
@end

@implementation VideoStarMacroEngine

+ (instancetype)sharedEngine {
    static VideoStarMacroEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VideoStarMacroEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isRunning = NO;
        _shouldCancel = NO;
    }
    return self;
}

- (void)stopAllMacros {
    if (!self.isRunning) {
        [MacroToastHUD showMessage:@"Không có macro nào đang chạy." duration:1.5];
        return;
    }
    self.shouldCancel = YES;
    self.isRunning = NO;
    [MacroToastHUD showMessage:@"🛑 Đã dừng macro khẩn cấp!" duration:2.0];
}

#pragma mark - Feature 1: Tự động nhập ảnh / video vào lớp

- (BOOL)isLayerEligibleForMediaImport:(UIView *)layerCellView {
    if (!layerCellView) return NO;

    NSMutableString *info = [NSMutableString string];
    if (layerCellView.accessibilityLabel) [info appendFormat:@"%@ ", layerCellView.accessibilityLabel];
    if (layerCellView.accessibilityIdentifier) [info appendFormat:@"%@ ", layerCellView.accessibilityIdentifier];
    [info appendFormat:@"%@ ", NSStringFromClass([layerCellView class])];

    for (UIView *sub in layerCellView.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *lbl = (UILabel *)sub;
            if (lbl.text) [info appendFormat:@"%@ ", lbl.text];
        }
    }

    NSString *lowercased = info.lowercaseString;

    NSArray<NSString *> *forbiddenKeywords = @[
        @"empty", @"rỗng", @"trống",
        @"zap", @"zaps",
        @"color", @"màu",
        @"overlay", @"lớp phủ",
        @"text", @"chữ",
        @"mask", @"mặt nạ"
    ];

    for (NSString *forbidden in forbiddenKeywords) {
        if ([lowercased containsString:forbidden]) {
            return NO;
        }
    }

    return YES;
}

- (void)startAutoImportMedia {
    if (self.isRunning) {
        [MacroToastHUD showMessage:@"⚠️ Macro khác đang thực thi!" duration:2.0];
        return;
    }

    UIWindow *window = VSGetActiveKeyWindow();
    if (!window) {
        [MacroToastHUD showMessage:@"Lỗi: Không tìm thấy KeyWindow!" duration:2.0];
        return;
    }

    NSArray<UIView *> *allLayerCells = VSFindAllSubviewsOfClass(window, @"MLLayerButtonsCellLayerView");
    if (allLayerCells.count == 0) {
        allLayerCells = VSFindAllSubviewsOfClass(window, @"LayerButtonsCell");
    }

    if (allLayerCells.count == 0) {
        [MacroToastHUD showMessage:@"Vui lòng mở giao diện Multi-Layer trước!" duration:2.5];
        return;
    }

    NSMutableArray<UIView *> *validLayers = [NSMutableArray array];
    for (UIView *cell in allLayerCells) {
        if ([self isLayerEligibleForMediaImport:cell]) {
            [validLayers addObject:cell];
        }
    }

    if (validLayers.count == 0) {
        [MacroToastHUD showMessage:@"Không tìm thấy lớp hình ảnh/video hợp lệ nào!" duration:2.5];
        return;
    }

    [validLayers sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
        CGPoint p1 = [v1 convertPoint:CGPointZero toView:nil];
        CGPoint p2 = [v2 convertPoint:CGPointZero toView:nil];
        if (p1.y < p2.y) return NSOrderedAscending;
        if (p1.y > p2.y) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    self.isRunning = YES;
    self.shouldCancel = NO;

    NSString *startMsg = [NSString stringWithFormat:@"Bắt đầu nạp %lu lớp media...", (unsigned long)validLayers.count];
    [MacroToastHUD showMessage:startMsg duration:2.0];

    [self processImportStepForLayerIndex:0 inList:validLayers];
}

- (void)processImportStepForLayerIndex:(NSInteger)index inList:(NSArray<UIView *> *)layerList {
    if (self.shouldCancel || !self.isRunning) {
        self.isRunning = NO;
        return;
    }

    if (index >= (NSInteger)layerList.count) {
        self.isRunning = NO;
        [MacroToastHUD showMessage:@"✅ Đã hoàn tất nhập toàn bộ ảnh/video!" duration:2.5];
        AudioServicesPlaySystemSound(1519);
        return;
    }

    UIView *currentLayerCell = layerList[index];
    NSString *status = [NSString stringWithFormat:@"Đang xử lý lớp %ld/%lu...", (long)(index + 1), (unsigned long)layerList.count];
    [MacroToastHUD showMessage:status duration:1.8];

    VSSimulateTapOnView(currentLayerCell);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.shouldCancel) { self.isRunning = NO; return; }

        UIWindow *win = VSGetActiveKeyWindow();
        UIView *replaceButton = nil;

        NSArray<UIView *> *customButtons = VSFindAllSubviewsOfClass(win, @"CustomUIButton");
        for (UIView *btnView in customButtons) {
            if ([btnView isKindOfClass:[UIButton class]]) {
                UIButton *b = (UIButton *)btnView;
                NSString *title = [b titleForState:UIControlStateNormal].lowercaseString;
                NSString *acc = b.accessibilityLabel.lowercaseString ?: @"";
                if ([title containsString:@"replace"] || [title containsString:@"thay"] ||
                    [acc containsString:@"replace"] || [acc containsString:@"thay"] ||
                    [title containsString:@"choose"] || [title containsString:@"chọn"]) {
                    replaceButton = b;
                    break;
                }
            }
        }

        if (!replaceButton) {
            UIView *popup = VSFindFirstSubviewOfClass(win, @"CustomPopup");
            if (popup) {
                replaceButton = VSFindFirstSubviewOfClass(popup, @"UIButton") ?: popup;
            }
        }

        if (replaceButton) {
            VSSimulateTapOnView(replaceButton);
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.40 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.shouldCancel) { self.isRunning = NO; return; }

            UIWindow *w = VSGetActiveKeyWindow();
            NSArray<UIView *> *pickerCells = VSFindAllSubviewsOfClass(w, @"ClipPickerCollectionViewCellImageView");
            if (pickerCells.count == 0) {
                pickerCells = VSFindAllSubviewsOfClass(w, @"ClipPicker");
            }

            if (pickerCells.count > 0) {
                NSInteger itemIdx = MIN((NSInteger)pickerCells.count - 1, index);
                UIView *targetMediaCell = pickerCells[itemIdx];
                VSSimulateTapOnView(targetMediaCell);
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self processImportStepForLayerIndex:index + 1 inList:layerList];
            });
        });
    });
}

#pragma mark - Feature 2: Tự động chia Beat & cắt phân cảnh

- (void)startAutoBeatSplitWithTargetCount:(NSInteger)splitCount interval:(NSTimeInterval)interval {
    if (self.isRunning) {
        [MacroToastHUD showMessage:@"⚠️ Macro khác đang thực thi!" duration:2.0];
        return;
    }

    UIWindow *window = VSGetActiveKeyWindow();
    if (!window) return;

    UIView *beatControls = VSFindFirstSubviewOfClass(window, @"BeatControlsView");
    UIView *multiSplitView = VSFindFirstSubviewOfClass(window, @"MultiSplitView");

    if (!multiSplitView) {
        [MacroToastHUD showMessage:@"Vui lòng mở giao diện MultiSplit trước!" duration:2.5];
        return;
    }

    self.isRunning = YES;
    self.shouldCancel = NO;

    [MacroToastHUD showMessage:@"Khởi động bảng điều khiển Beat..." duration:1.5];

    if (beatControls) {
        VSSafePerformSelector(beatControls, @"toggleAction", nil);
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.shouldCancel) { self.isRunning = NO; return; }
        [self performBeatSplitIteration:1 total:splitCount interval:interval];
    });
}

- (void)performBeatSplitIteration:(NSInteger)currentStep total:(NSInteger)totalSteps interval:(NSTimeInterval)interval {
    if (self.shouldCancel || !self.isRunning) {
        self.isRunning = NO;
        return;
    }

    UIWindow *window = VSGetActiveKeyWindow();
    UIView *beatControls = VSFindFirstSubviewOfClass(window, @"BeatControlsView");
    UIView *multiSplitView = VSFindFirstSubviewOfClass(window, @"MultiSplitView");

    if (!multiSplitView) {
        self.isRunning = NO;
        [MacroToastHUD showMessage:@"Mất liên kết với MultiSplitView!" duration:2.0];
        return;
    }

    if (currentStep > totalSteps) {
        [MacroToastHUD showMessage:@"Đang thực hiện cắt phân cảnh (doSplit)..." duration:1.5];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            VSSafePerformSelector(multiSplitView, @"doSplit", nil);
            self.isRunning = NO;
            [MacroToastHUD showMessage:@"🎉 Hoàn thành chia beat & cắt phân cảnh!" duration:2.5];
            AudioServicesPlaySystemSound(1519);
        });
        return;
    }

    NSString *msg = [NSString stringWithFormat:@"🎵 Đang chia Beat: %ld/%ld", (long)currentStep, (long)totalSteps];
    [MacroToastHUD showMessage:msg duration:interval + 0.1];

    if (beatControls) {
        VSSafePerformSelector(beatControls, @"nextAction", nil);
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.shouldCancel) { self.isRunning = NO; return; }

        VSSafePerformSelector(multiSplitView, @"setSplitPoint", nil);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self performBeatSplitIteration:currentStep + 1 total:totalSteps interval:interval];
        });
    });
}

@end

#pragma mark - 5. APPLICATION LIFECYCLE HOOKS

static void InitializeMacroToolUI(void) {
    static BOOL initialized = NO;
    if (initialized) return;
    initialized = YES;

    MACRO_LOG(@"Bắt đầu nạp Floating Button vào UI...");
    [[MacroFloatingButton sharedButton] attachToKeyWindow];
    [MacroToastHUD showMessage:@"⚡ VideoStar Macro Tool đã sẵn sàng!" duration:2.5];
}

%hook UIApplication

- (void)setDelegate:(id<UIApplicationDelegate>)delegate {
    %orig;

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            InitializeMacroToolUI();
        });
    }];
}

%end

#pragma mark - 6. WINDOW ROOT CONTROLLER HOOK (FAILSAFE RE-ATTACH)

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (![self viewWithTag:998877]) {
            [[MacroFloatingButton sharedButton] attachToKeyWindow];
        }
    });
}

%end

#pragma mark - 7. CONSTRUCTOR

%ctor {
    @autoreleasepool {
        MACRO_LOG(@"=== VideoStarMacroTool Tweak Injected Successfully ===");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            InitializeMacroToolUI();
        });
    }
}
