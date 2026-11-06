//
//  Tweak.h
//  VideoStarMacroTool
//
//  Created by Senior iOS Reverse Engineer on 2026.
//  Copyright © 2026. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Macro Definitions

#define LOG_TAG @"[VideoStarMacroTool]"
#define MACRO_LOG(fmt, ...) NSLog((LOG_TAG @" " fmt), ##__VA_ARGS__)

#pragma mark - Forward Declarations for Target Classes

@interface MLLayerButtonsCellLayerView : UIView
@property (nonatomic, assign, readonly) NSInteger layerIndex;
@property (nonatomic, strong, nullable) id layerData;
@end

@interface BeatControlsView : UIView
- (void)toggleAction;
- (void)toggleAction:(nullable id)sender;
- (void)nextAction;
- (void)nextAction:(nullable id)sender;
- (void)prevAction;
@end

@interface MultiSplitView : UIView
- (void)setSplitPoint;
- (void)setSplitPoint:(nullable id)sender;
- (void)doSplit;
- (void)doSplit:(nullable id)sender;
@end

@interface CustomPopup : UIView
- (void)dismissAnimated:(BOOL)animated;
@end

@interface CustomUIButton : UIButton
@end

@interface ClipPickerCollectionViewCellImageView : UIView
@end

#pragma mark - Floating Button & Overlay Interface

@interface MacroFloatingButton : UIButton
+ (instancetype)sharedButton;
- (void)attachToKeyWindow;
- (void)showMenu;
@end

#pragma mark - Toast HUD Interface

@interface MacroToastHUD : UIView
+ (void)showMessage:(NSString *)message duration:(NSTimeInterval)duration;
@end

#pragma mark - Macro Automation Engine Interface

@interface VideoStarMacroEngine : NSObject

@property (nonatomic, assign, readonly) BOOL isRunning;

+ (instancetype)sharedEngine;

// Action 1: Auto import media
- (void)startAutoImportMedia;

// Action 2: Auto beat split
- (void)startAutoBeatSplitWithTargetCount:(NSInteger)splitCount interval:(NSTimeInterval)interval;

// Emergency abort
- (void)stopAllMacros;

@end

#pragma mark - Runtime & UI Safety Utilities

UIWindow * _Nullable VSGetActiveKeyWindow(void);
UIViewController * _Nullable VSGetTopViewController(void);
BOOL VSSafeViewIsClass(UIView * _Nullable view, NSString *classNamePart);
UIView * _Nullable VSFindFirstSubviewOfClass(UIView * _Nullable root, NSString *classNamePart);
NSArray<UIView *> *VSFindAllSubviewsOfClass(UIView * _Nullable root, NSString *classNamePart);
void VSSimulateTapOnView(UIView * _Nullable targetView);
void VSSafePerformSelector(id _Nullable target, NSString *selectorName, id _Nullable arg);

NS_ASSUME_NONNULL_END
