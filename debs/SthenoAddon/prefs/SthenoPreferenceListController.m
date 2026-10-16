#import <UIKit/UIKit.h>

// =====================================================================
//  SthenoPreferenceListController — Stheno 附加设置面板
//
//  真正编译的 PSListController 子类 (《全局开发约定》设置面板规范)。
//  specifier 由 bundle 的 Root.plist 提供 (PSGroupCell + 2×PSSwitchCell),
//  开关读写偏好域 com.susudear.screencoreprefs:
//    sthenoAnimationsEnabled / sthenoGesturesEnabled
//
//  Preferences.framework 由 Settings 进程加载, CI SDK 无链接 stub,
//  通过 -Wl,-undefined,dynamic_lookup 在运行时解析 (约定的方案)。
// =====================================================================

// 最小接口声明 — 与系统 Preferences.framework 的真实类对接
@interface PSListController : UIViewController
@end

@interface SthenoPreferenceListController : PSListController
@end

@implementation SthenoPreferenceListController

// 不重载 -specifiers: PSListController 默认实现加载 bundle 内 Root.plist,
// 保留其内置 group/row/index 数据源缓存 (避免动态临时数组导致的空白问题)。

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = @"Stheno 附加";
    }
    return self;
}

@end