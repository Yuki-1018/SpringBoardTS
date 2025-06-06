#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include <assert.h>
#include <stdbool.h>
#include <unistd.h>
#include <xpc/xpc.h>
#include <dispatch/dispatch.h>
#import <objc/runtime.h>

@interface LCSharedUtils : NSObject
+ (NSURL *)appGroupPath;
@end

@interface FBScene : NSObject
- (NSString *)identifier;
@end

@interface FBSScene : NSObject
- (NSString *)identifier;
- (id)identity;
- (id)identityToken;
@end

@interface UIMutableApplicationSceneSettings : NSObject
- (void)setLevel:(CGFloat)level;
@end

@interface UIApplicationSceneSettings : NSObject
- (instancetype)initWithSettings:(id)s;
- (UIMutableApplicationSceneSettings *)mutableCopy;
- (CGFloat)level;
@end

@interface UIWindowScene(private)
- (FBSScene *)_scene;
@end

%hook BKSSystemShellService
- (instancetype)initWithConfigurator:(id)configurator {
    // skip init to avoid calling exit() and watchdog
    return nil;
}
%end

%hook SpringBoard
// skip initializing Notification Center
- (void)_startBulletinBoardServer {}

- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    if (connectingSceneSession.role == UIWindowSceneSessionRoleApplication) {
        static NSUInteger numRoleApps = 0;
        if (numRoleApps++ != 1) {
            return %orig;
        } else {
            // If we reach here, it means that this is the second UIWindowSceneSessionRoleApplication being created
            // init a scene to display SpringBoard's programmatically created scenes
            UISceneConfiguration *config = [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
            config.delegateClass = NSClassFromString(@"SBLCSceneDelegate");
            return config;
        }
    }
    return %orig;
}

// iOS 18
- (void)_prepareBacklightServices {
    // do nothing
}
%end

// Optional if process name = SpringBoard
%hook TLAlert
+ (void)_stopAllAlerts {}
%end

// SB's implementation recursively calls this for some reason, so use UIKit's implementation instead
%hook UISApplicationInitializationContext
+ (id)sb_embeddedDisplayDefaultContext {
    return [self performSelector:@selector(defaultContext)];
}
%end

%hook SWSystemSleepMonitorProvider
- (void)registerForSystemPowerOnQueue:(id)queue withDelegate:(id)delegate {
    // do nothing
}
%end

%hook _UIEventDeferringManager
+ (void)setSystemShellBehaviorDelegate:(id)delegate {
    // do nothing
}
%end

%hook PBUIPosterViewController
- (instancetype)init {
    return nil;
}
%end

// FIXME
/*
%hook SBApplicationController
- (void)_loadApplications:(id)apps remove:(id)remove {
    // do nothing for now
}
%end
*/

%hook BKSTouchDeliveryObservationService
- (void)_connectToTouchDeliveryService {
    // do nothing
}
%end

%hook _UIEventDeferringManager
- (void)setNeedsRemoteEventDeferringRuleComparisonInEnvironments:(id)environments forBehaviorDelegate:(id)delegate withReason:(NSString *)reason {
    // do nothing
}
%end

%hook SASPresentationConnectionListener
+ (instancetype)listener {
    return nil;
}
%end

%hook SASSignalConnectionListener
+ (instancetype)listener {
    return nil;
}
%end

%hook FBSystemShellInitializationOptions
- (id)independentWatchdogPortName {
    // Skip watchdog init
    return nil;
}
%end

%hook SBUIBiometricResource
- (void)_reevaluateFaceDetection {
    // do nothing
}
%end

%hook FBSystemShell
- (void)_setSystemIdleSleepDisabled:(BOOL)disabled forReason:(id)reason {
    // do nothing
}
%end

%hook BiometricKitXPCClient
- (int)initializeConnection {
    return 0;
}
%end

%hook SBSetupManager
- (BOOL)_setSetupRequiredReason:(NSUInteger)reason {
    // skip setup
    return NO;
}
%end

/*
reverse engineering options

 id a0 = (id)[[[LSApplicationRecord enumeratorWithOptions:0b0] allObjects] mutableCopy]; id a1 = (id)[[LSApplicationRecord enumeratorWithOptions:0b1] allObjects]; (void)[a0 removeObjectsInArray:a1]; (id)[a0 description]
 -> user installed apps
 
 so options:
 0: all apps
 1<<0: system apps only
 1<<1: unknown
 1<<2: unknown
 1<<3: unknown
 1<<4: unknown
 1<<5: unknown
 1<<6: empty array
 1<<7: unknown
 
enumerate all bundles: (~*(_DWORD *)(a1 + 96) & 0xD0LL) == 0;
0b11010000
 
*/

@interface LSApplicationRecord : NSObject
+ (id)vs_applicationRecordWithBundleURL:(NSURL *)bundleURL;
@end

/*
%hook LSApplicationRecord
+ (NSEnumerator *)enumeratorWithOptions:(NSUInteger)options {
    static NSMutableArray *installedApps = nil;
    if (!installedApps) {
        installedApps = [NSMutableArray array];
        NSURL *docPath = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%s/Documents/Applications", getenv("LC_HOME_PATH")]];
        NSURL *appGroupPath = [[NSClassFromString(@"LCSharedUtils") appGroupPath] URLByAppendingPathComponent:@"LiveContainer/Applications"];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSMutableArray *apps = [fileManager contentsOfDirectoryAtURL:docPath includingPropertiesForKeys:@[NSURLIsDirectoryKey]
            options:NSDirectoryEnumerationSkipsHiddenFiles error:nil].mutableCopy;
        [apps addObjectsFromArray:[fileManager contentsOfDirectoryAtURL:appGroupPath includingPropertiesForKeys:@[NSURLIsDirectoryKey]
            options:NSDirectoryEnumerationSkipsHiddenFiles error:nil]];
        for (NSURL *url in apps) {
            if ([url.pathExtension isEqualToString:@"app"]) {
                // TODO: handle hidden apps?
                LSApplicationRecord *appRecord = [LSApplicationRecord vs_applicationRecordWithBundleURL:url];
                if (appRecord) {
                    [installedApps addObject:appRecord];
                }
            }
        }
    }
    // TODO: handle the options
    return installedApps.objectEnumerator;
}
%end
*/

/*
// low-level hook of querying installed apps
%hook _LSXPCQueryResolver
- (void)_enumerateResolvedResultsOfQuery:(id)query XPCConnection:(id)connection withBlock:(id)block {

}
%end
*/

/*
typedef void (^LSBundleProxyHandler)(LSBundleProxy *proxy, BOOL *stop);
%hook LSApplicationWorkspace
- (void)enumerateBundlesOfType:(NSUInteger)type legacySPI:(BOOL)legacySPI block:(LSBundleProxyHandler)block {
    
}
%end
*/

%hook HKSPSleepStore
- (instancetype)init {
    // skip init sleep stuff
    return nil;
}
%end

@interface BSServicesConfiguration : NSObject
- (id)domainForIdentifier:(NSString *)identifier;
@end
%hook BSServicesConfiguration
- (id)domainForMachName:(NSString *)machName {
    if([machName isEqualToString:@"com.apple.frontboard.systemappservices"] || [machName isEqualToString:@"com.troll.frontboard.systemappservices"]) {
        return [self domainForIdentifier:@"com.apple.frontboard"];
    }
    return %orig;
}
%end

// iOS 18
%hook SBBacklightController
+ (instancetype)_sharedInstanceCreateIfNeeded:(BOOL)arg1 {
    return nil;
}
%end

%hook SBInputUISceneController
- (id)_createInputUIScene {
    // skip init
    return nil;
}
%end

//////////

%hook BLSHService
+ (instancetype)sharedService {
    NSLog(@"[Hook] BLSHService -sharedService called");
    return nil;
}
%end

%ctor {
    //MSImageRef image = MSGetImageByName("/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore");
    //%init(_UIApplicationProcessIsSpringBoard = MSFindSymbol(image, "__UIApplicationProcessIsSpringBoard"));
}
