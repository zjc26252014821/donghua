#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

// =====================================================================
//  SthenoAddon — stheno 式边缘上滑环形应用切换器 (screencore 附加)
//
//  注入 SpringBoard, 在 screencore 之上叠加:
//    - 屏幕底部上滑手势呼出环形应用切换器 (优先列出 screencore 收藏)
//    - 弹簧过渡动画 (UIViewPropertyAnimator 阻尼 0.8 / 响应 0.5s)
//
//  偏好域 com.susudear.screencoreprefs:
//    sthenoAnimationsEnabled  (默认 YES)
//    sthenoGesturesEnabled    (默认 YES)
//
//  挂钩点选择 SBIconController -viewDidLoad —— 桌面图标控制器加载完毕
//  时才触发, 此时 UIApplication / keyWindow 均已就绪, 不干扰启动早期
//  事件分发链, 避免 SpringBoard 崩溃进安全模式。
// =====================================================================

static NSString *const kSCPrefsDomain      = @"com.susudear.screencoreprefs";
static NSString *const kSCKeyAnimations    = @"sthenoAnimationsEnabled";
static NSString *const kSCKeyGestures      = @"sthenoGesturesEnabled";

// ---- substrate (ellekit) 挂钩 API ----
extern void MSHookMessageEx(Class _class, SEL message, IMP imp, IMP *result);

// ---- 环形切换器外观 ----
static const CGFloat kRingRadius          = 150.0;
static const CGFloat kRingIconSize        = 56.0;

// ---- 弹簧动画参数 (stheno 默认) ----
static const NSTimeInterval kSpringDuration     = 0.5;
static const CGFloat        kSpringDampingRatio = 0.80;
static const CGFloat        kMinScale            = 0.9;
static const CGFloat        kOvershootScale      = 1.04;

// ---- 手势 ----
static const CGFloat kGestureStartThreshold = 30.0;
static const CGFloat kGestureCancelDistance  = 120.0;

static NSArray<NSString *> *kDefaultCandidates(void) {
    return @[
        @"com.apple.mobilesafari",
        @"com.apple.Preferences",
        @"com.apple.mobileslideshow",
        @"com.apple.Maps",
        @"com.apple.mobilemail",
        @"com.apple.mobilenotes",
    ];
}

static NSArray<NSString *> *kRingCandidates(void) {
    NSDictionary *d = [[NSUserDefaults standardUserDefaults]
                          persistentDomainForName:kSCPrefsDomain];
    NSArray *sel = d[@"SelectedApplications"];
    if (sel.count >= 2) return sel;
    return kDefaultCandidates();
}

static BOOL SCReadBool(NSString *key, BOOL def) {
    NSDictionary *d = [[NSUserDefaults standardUserDefaults]
                          persistentDomainForName:kSCPrefsDomain];
    id v = d[key];
    return (v == nil) ? def : [v boolValue];
}

// =====================================================================
//  环形切换器窗口
// =====================================================================
@interface SHRingWindow : UIWindow
- (void)presentAtPoint:(CGPoint)point;
- (void)updateAtPoint:(CGPoint)point;
- (void)dismissWithCommit:(void (^)(void))completion;
@end

@implementation SHRingWindow {
    NSMutableArray<UIImageView *> *_iconViews;
    NSArray<NSString *> *_bundles;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 1;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        _iconViews = [NSMutableArray array];
    }
    return self;
}

- (UIImage *)_iconForBundle:(NSString *)bid {
    Class lsw = NSClassFromString(@"LSApplicationWorkspace");
    if (lsw) {
        SEL wsSel = NSSelectorFromString(@"defaultWorkspace");
        if (![lsw respondsToSelector:wsSel]) wsSel = NSSelectorFromString(@"sharedInstance");
        if ([lsw respondsToSelector:wsSel]) {
            id ws = ((id (*)(id, SEL))objc_msgSend)(lsw, wsSel);
            if (ws) {
                id proxy = ((id (*)(id, SEL, id))objc_msgSend)(
                    ws, @selector(applicationProxyForIdentifier:), bid);
                if (proxy) {
                    id icon = [proxy valueForKey:@"icon"];
                    if ([icon isKindOfClass:[UIImage class]]) return icon;
                    id icons = [proxy valueForKey:@"icons"];
                    if ([icons respondsToSelector:@selector(anyObject)]) {
                        id i0 = [icons anyObject];
                        if ([i0 isKindOfClass:[UIImage class]]) return i0;
                    }
                }
            }
        }
    }
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 0);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (void)_layoutIconsAround:(CGPoint)center animated:(BOOL)animated {
    NSUInteger count = _iconViews.count;
    if (count == 0) return;
    CGFloat startAngle = -M_PI_2;
    CGFloat step = 2 * M_PI / count;
    void (^layout)(void) = ^{
        for (NSUInteger i = 0; i < count; i++) {
            CGFloat angle = startAngle + step * i;
            _iconViews[i].center = CGPointMake(center.x + cos(angle) * kRingRadius,
                                               center.y + sin(angle) * kRingRadius);
        }
    };
    if (animated) {
        [UIView animateWithDuration:kSpringDuration
                              delay:0
             usingSpringWithDamping:kSpringDampingRatio
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:layout completion:nil];
    } else {
        layout();
    }
}

- (void)presentAtPoint:(CGPoint)point {
    _bundles = kRingCandidates();
    for (UIView *v in self.subviews) [v removeFromSuperview];
    [_iconViews removeAllObjects];

    for (NSString *bid in _bundles) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:[self _iconForBundle:bid]];
        iv.frame = CGRectMake(0, 0, kRingIconSize, kRingIconSize);
        iv.layer.cornerRadius = 12;
        iv.layer.masksToBounds = YES;
        iv.layer.borderWidth = 1;
        iv.layer.borderColor = [UIColor systemBlueColor].CGColor;
        iv.center = point;
        [self addSubview:iv];
        [_iconViews addObject:iv];
    }
    self.frame = UIScreen.mainScreen.bounds;
    self.alpha = 0;
    [UIView animateWithDuration:0.2 animations:^{ self.alpha = 1; }];
    [self _layoutIconsAround:point animated:YES];

    self.transform = CGAffineTransformMakeScale(kMinScale, kMinScale);
    [UIView animateWithDuration:kSpringDuration
                          delay:0
         usingSpringWithDamping:kSpringDampingRatio
          initialSpringVelocity:0.8
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = CGAffineTransformMakeScale(kOvershootScale, kOvershootScale);
    } completion:^(BOOL f) {
        [UIView animateWithDuration:0.12 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }];
}

- (void)updateAtPoint:(CGPoint)point {
    CGPoint c = self.center;
    c.x += (point.x - c.x) * 0.2;
    c.y += (point.y - c.y) * 0.2;
    self.center = c;
    [self _layoutIconsAround:c animated:NO];

    UIImageView *nearest = nil; CGFloat best = CGFLOAT_MAX;
    for (UIImageView *iv in _iconViews) {
        CGFloat d = hypot(iv.center.x - point.x, iv.center.y - point.y);
        if (d < best) { best = d; nearest = iv; }
    }
    for (UIImageView *iv in _iconViews)
        iv.transform = (iv == nearest) ? CGAffineTransformMakeScale(1.2, 1.2)
                                      : CGAffineTransformIdentity;
}

- (void)dismissWithCommit:(void (^)(void))completion {
    CGPoint fc = self.center;
    for (UIImageView *iv in _iconViews) {
        [UIView animateWithDuration:kSpringDuration * 0.5
                              delay:0
             usingSpringWithDamping:0.7 initialSpringVelocity:1.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{ iv.center = fc; } completion:nil];
    }
    [UIView animateWithDuration:0.3 animations:^{ self.alpha = 0; }];
    [UIView animateWithDuration:kSpringDuration * 0.6
                          delay:0
         usingSpringWithDamping:kSpringDampingRatio
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{ self.transform = CGAffineTransformMakeScale(0.6, 0.6); }
                     completion:^(BOOL f) {
        if (completion) completion();
        [self removeFromSuperview];
    }];
}

@end

// =====================================================================
//  手势处理器
// =====================================================================
@interface SHGestureHandler : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIPanGestureRecognizer *pan;
@property (nonatomic, strong) SHRingWindow *ring;
@property (nonatomic) CGPoint fingerStart;
@property (nonatomic) BOOL presented;
@end

@implementation SHGestureHandler

- (instancetype)init {
    self = [super init];
    if (self) {
        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _pan.delegate = self;
    }
    return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gr {
    if (gr != _pan) return YES;
    CGPoint v = [_pan velocityInView:_pan.view];
    return fabs(v.y) > fabs(v.x) && v.y < -30;
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    CGPoint loc = [g locationInView:v];

    switch (g.state) {
        case UIGestureRecognizerStateBegan:
            _fingerStart = loc;
            break;
        case UIGestureRecognizerStateChanged: {
            CGFloat dy = loc.y - _fingerStart.y;
            if (dy > kGestureCancelDistance) {
                if (_presented) [self _dismiss];
                return;
            }
            if (!_presented && -dy > kGestureStartThreshold) {
                [self _presentAt:loc];
            } else if (_presented) {
                [_ring updateAtPoint:loc];
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            if (_presented) {
                __weak typeof(self) wself = self;
                [_ring dismissWithCommit:^{
                    __strong typeof(wself) sself = wself;
                    if (sself) [sself _launchFirstCandidate];
                }];
                _presented = NO;
                _ring = nil;
            }
            break;
        }
        default: break;
    }
}

- (void)_presentAt:(CGPoint)loc {
    if (_presented) return;
    UIWindow *host = UIApplication.sharedApplication.keyWindow;
    if (!host) return;
    SHRingWindow *ring = [[SHRingWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [host addSubview:ring];
    [ring presentAtPoint:loc];
    _ring = ring;
    _presented = YES;
}

- (void)_dismiss {
    [_ring removeFromSuperview];
    _ring = nil;
    _presented = NO;
}

- (void)_launchFirstCandidate {
    NSString *bundle = kRingCandidates().firstObject;
    if (!bundle.length) return;
    Class lsw = NSClassFromString(@"LSApplicationWorkspace");
    if (lsw) {
        SEL wsSel = NSSelectorFromString(@"defaultWorkspace");
        if (![lsw respondsToSelector:wsSel]) wsSel = NSSelectorFromString(@"sharedInstance");
        if ([lsw respondsToSelector:wsSel] &&
            [lsw instancesRespondToSelector:@selector(openApplicationWithBundleID:)]) {
            id ws = ((id (*)(id, SEL))objc_msgSend)(lsw, wsSel);
            if (ws) {
                ((void (*)(id, SEL, id))objc_msgSend)(
                    ws, @selector(openApplicationWithBundleID:), bundle);
                return;
            }
        }
    }
    NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"%@://", bundle]];
    if (u) [UIApplication.sharedApplication openURL:u options:@{} completionHandler:nil];
}

@end

// =====================================================================
//  挂钩: SBIconController -viewDidLoad (SpringBoard 桌面就绪后)
// =====================================================================
static void (*orig_SBIconController_viewDidLoad)(id, SEL);

static void hook_SBIconController_viewDidLoad(id self, SEL _cmd) {
    if (orig_SBIconController_viewDidLoad) orig_SBIconController_viewDidLoad(self, _cmd);

    // 延迟到主窗口完全出现后再挂手势
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (!SCReadBool(kSCKeyGestures, YES)) return;
        UIWindow *key = UIApplication.sharedApplication.keyWindow;
        if (!key) return;
        static SHGestureHandler *handler = nil;
        if (!handler) handler = [[SHGestureHandler alloc] init];
        if (!handler.pan.view) [key addGestureRecognizer:handler.pan];
    });
}

__attribute__((constructor))
static void SthenoAddonInit(void) {
    Class cls = NSClassFromString(@"SBIconController");
    if (cls) {
        MSHookMessageEx(cls, @selector(viewDidLoad),
                        (IMP)hook_SBIconController_viewDidLoad,
                        (IMP *)&orig_SBIconController_viewDidLoad);
    }
}