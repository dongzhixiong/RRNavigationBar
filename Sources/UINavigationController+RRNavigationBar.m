//
//  UINavigationController+RRNavigationBar.m
//  RRNavigationBar
//
//  Created by Moch Xiao on 3/25/17.
//  Copyright © 2017 RedRain. All rights reserved.
//

#import "UINavigationController+RRNavigationBar.h"
#import "UIViewController+RRNavigationBar.h"
#import "RRUtils.h"
#import <objc/runtime.h>
#import "UINavigationBar+RRAddition_Internal.h"
#import "_RRWeakAssociatedObjectWrapper.h"
#import "UINavigationBar+RRAddition.h"

#ifndef RRRecoverObject
#   define RRRecoverObject(this, bar, info, property) (bar.property = info[@#property] ?: this.property)
#endif

#ifndef RRRecoverBoolean
#   define RRRecoverBoolean(this, bar, info, property) (bar.property = info[@#property] ? [info[@#property] boolValue] : this.property)
#endif

#ifndef RRRecoverInteger
#   define RRRecoverInteger(this, bar, info, property) (bar.property = info[@#property] ? [info[@#property] integerValue] : this.property)
#endif

#ifndef RRRecoverDobule
#   define RRRecoverDobule(this, bar, info, property) (bar.property = info[@#property] ? [info[@#property] doubleValue] : this.property)
#endif

#ifndef RRExcludeImagePicker
#   define RRExcludeImagePicker(instance) if ([instance isKindOfClass:UIImagePickerController.class]) { return; }
#endif

@interface UINavigationController ()<UINavigationControllerDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, weak, nullable) UIViewController *_visibleTopViewController;
@property (nonatomic, assign) BOOL _navigationBarInitialized;
@end

@implementation UINavigationController (RRNavigationBar)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (self.class == UINavigationController.class) {
            RRSwizzleInstanceMethod(self.class, @selector(viewDidLoad), @selector(_rr_nvc_viewDidLoad));
            RRSwizzleInstanceMethod(self.class, @selector(viewWillLayoutSubviews), @selector(_rr_nvc_viewWillLayoutSubviews));
            RRSwizzleInstanceMethod(self.class, @selector(preferredStatusBarStyle), @selector(_rr_nvc_preferredStatusBarStyle));
        }
    });
}

#pragma mark - Swizzle

- (void)_rr_nvc_viewDidLoad {
    [self _rr_nvc_viewDidLoad];
    RRExcludeImagePicker(self);
    self.delegate = self;
    self.interactivePopGestureRecognizer.delegate = self;
}

- (void)_rr_nvc_viewWillLayoutSubviews {
    [self _rr_nvc_viewWillLayoutSubviews];
    RRExcludeImagePicker(self);
    if (!self._navigationBarInitialized && self.navigationBar) {
        self.rr_navigationBar = RRUINavigationBarDuplicate(self.navigationBar);
        [self.rr_navigationBar _apply];
        self._navigationBarInitialized = YES;
        RRLog(@"nvc's rr_navigationBar initialized");
    }
    
    // Workaround for present nvc.
    // Normally call order nvc:viewWillLayoutSubviews -> vc:viewDidLoad,
    // when present a nvc, vc:viewDidLoad -> nvc:viewWillLayoutSubviews.
    // So, in vc:viewDidLoad vc.rr_navigationBar isn't the correct styles,
    // therefore recored setups, recover when nvc.rr_navigationBar initialized.
    UINavigationBar *this = self.rr_navigationBar;
    UINavigationBar *bar = self.topViewController.rr_navigationBar;
    NSDictionary *info = bar._tmpInfo;
    if (this && info) {
        RRRecoverInteger(this, bar, info, barStyle);
        RRRecoverBoolean(this, bar, info, translucent);
        RRRecoverDobule(this, bar, info, alpha);
        RRRecoverObject(this, bar, info, tintColor);
        RRRecoverObject(this, bar, info, barTintColor);
        RRRecoverObject(this, bar, info, backgroundColor);
        RRRecoverObject(this, bar, info, shadowImage);
        [bar setBackgroundImage:info[@"backgroundImage"] ?: [this backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
        RRRecoverObject(this, bar, info, backIndicatorImage);
        RRRecoverObject(this, bar, info, backIndicatorTransitionMaskImage);
        RRRecoverBoolean(this, bar, info, rr_forceShadowImageHidden);
        bar._tmpInfo = nil;
    }
}

- (UIStatusBarStyle)_rr_nvc_preferredStatusBarStyle {
    if (self.topViewController) {
        return self.topViewController.preferredStatusBarStyle;
    }
    return self._rr_nvc_preferredStatusBarStyle;
}

#pragma mark - Private

- (nullable UIViewController *)_visibleTopViewController {
    return ((_RRWeakAssociatedObjectWrapper *)objc_getAssociatedObject(self, _cmd)).object;
}

- (void)set_visibleTopViewController:(nullable UIViewController *)_visibleTopViewController {
    _RRWeakAssociatedObjectWrapper *wrapper = [[_RRWeakAssociatedObjectWrapper alloc] initWithObject:_visibleTopViewController];
    objc_setAssociatedObject(self, @selector(_visibleTopViewController), wrapper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)_navigationBarInitialized {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)set_navigationBarInitialized:(BOOL)_navigationBarInitialized {
    objc_setAssociatedObject(self, @selector(_navigationBarInitialized), @(_navigationBarInitialized), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)_makeNavigationBarVisible:(BOOL)visible {
    RRTRY([[self.navigationBar valueForKey:@"_backgroundView"] setHidden:!visible]);
}

- (void)_handleDidShowViewController:(UIViewController *)viewController {
    [viewController.rr_navigationBar _apply];
    [self _makeNavigationBarVisible:YES];
    
    viewController.rr_navigationBar._rr_transiting = NO;
    viewController.rr_navigationBar._rr_equalOtherNavigationBarInTransiting = NO;
    viewController.rr_navigationBar.hidden = YES;
    viewController.view.clipsToBounds = YES;
    self._visibleTopViewController.rr_navigationBar._rr_transiting = NO;
    self._visibleTopViewController.rr_navigationBar._rr_equalOtherNavigationBarInTransiting = NO;
    self._visibleTopViewController.rr_navigationBar.hidden = YES;
    self._visibleTopViewController.view.clipsToBounds = YES;
    
    self._visibleTopViewController = viewController;
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    RRLog(@"WILL SHOW VC %@", viewController.navigationItem.title);
    
    RRExcludeImagePicker(navigationController);
    
    // If these two navigationBar `equal`, use system transition behavior.
    if (RRIsUINavigationBarEqual(viewController.rr_navigationBar, self._visibleTopViewController.rr_navigationBar)) {
        viewController.rr_navigationBar._rr_transiting = YES;
        viewController.rr_navigationBar._rr_equalOtherNavigationBarInTransiting = YES;
        self._visibleTopViewController.rr_navigationBar._rr_transiting = YES;
        self._visibleTopViewController.rr_navigationBar._rr_equalOtherNavigationBarInTransiting = YES;
        if (!viewController.view.backgroundColor) {
            viewController.view.backgroundColor = self._visibleTopViewController.view.backgroundColor;
        }
        return;
    }
    
    // If cancel pop, needs recover.
    static dispatch_once_t onceToken;
    static BOOL iOSVersionGreaterThanOrEqualTo10 = NO;
    dispatch_once(&onceToken, ^{
        iOSVersionGreaterThanOrEqualTo10 = UIDevice.currentDevice.systemVersion.floatValue >= 10;
    });
    id <UIViewControllerTransitionCoordinator> transitionCoordinator = self._visibleTopViewController.transitionCoordinator;
    __weak typeof(self) weak_self = self;
    void (^handleCancel)(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) = ^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        if (context.isCancelled) {
            RRLog(@"Canceled");
            __strong typeof(weak_self) strong_self = weak_self;
            [strong_self _handleDidShowViewController:strong_self._visibleTopViewController];
        }
    };
    if (iOSVersionGreaterThanOrEqualTo10) {
        [transitionCoordinator notifyWhenInteractionChangesUsingBlock:handleCancel];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [transitionCoordinator notifyWhenInteractionEndsUsingBlock:handleCancel];
#pragma clang diagnostic pop
    }
    
    viewController.rr_navigationBar._rr_transiting = YES;
    viewController.rr_navigationBar._rr_equalOtherNavigationBarInTransiting = NO;
    viewController.rr_navigationBar.hidden = NO;
    viewController.view.clipsToBounds = NO;
    self._visibleTopViewController.rr_navigationBar._rr_transiting = YES;
    self._visibleTopViewController.rr_navigationBar._rr_equalOtherNavigationBarInTransiting = NO;
    self._visibleTopViewController.rr_navigationBar.hidden = NO;
    self._visibleTopViewController.view.clipsToBounds = NO;

    [viewController viewWillLayoutSubviews];
    [self._visibleTopViewController viewWillLayoutSubviews];
    
    if (!viewController.view.backgroundColor) {
        viewController.view.backgroundColor = self._visibleTopViewController.view.backgroundColor;
    }

    [self _makeNavigationBarVisible:NO];
    
#if INRR
    NSUInteger currentIndex = [navigationController.viewControllers indexOfObject:self._visibleTopViewController];
    if (!self._visibleTopViewController) {
        currentIndex = 0;
    }
    NSUInteger toIndex = [navigationController.viewControllers indexOfObject:viewController];
    if (currentIndex > toIndex) {
        RRLog(@"POPING TO VC %@", viewController.navigationItem.title);
    } else {
        RRLog(@"PUSHING TO VC %@", viewController.navigationItem.title);
    }
#endif
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    RRExcludeImagePicker(navigationController);
    [self _handleDidShowViewController:viewController];
    RRLog(@"DID SHOW VC %@", viewController.navigationItem.title);
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    RRTRY(
        if ([[self valueForKey:@"_isTransitioning"] boolValue]) {
          return NO;
        }
    );
    if (self.viewControllers.count <= 1) {
        return NO;
    }
    if (self.topViewController.rr_interactivePopGestureRecognizerDisabled) {
        return NO;
    }
    return YES;
}

@end
