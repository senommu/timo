#import "ExtensionResourceBridge.h"

@interface WKWebExtension (TimoResourceInitialization)
- (instancetype)initWithResources:(NSDictionary<NSString *, id> *)resources;
- (BOOL)_hasServiceWorkerBackgroundContent;
@end

BOOL TimoExtensionUsesServiceWorker(WKWebExtension *extension)
{
    return [extension respondsToSelector:@selector(_hasServiceWorkerBackgroundContent)]
        && [extension _hasServiceWorkerBackgroundContent];
}

WKWebExtension *TimoCreateResourceExtension(NSDictionary<NSString *, NSData *> *resources, NSError **error)
{
    if ([WKWebExtension instancesRespondToSelector:@selector(initWithResources:)]) {
        WKWebExtension *extension = [[WKWebExtension alloc] initWithResources:resources];
        if (extension) {
#if __has_feature(objc_arc)
            return extension;
#else
            return [extension autorelease];
#endif
        }
    }
    if (error) *error = [NSError errorWithDomain:@"TimoExtensionIdentity" code:1
                                      userInfo:@{NSLocalizedDescriptionKey: @"This WebKit version cannot initialize the extension worker identity. The extension has not been started."}];
    return nil;
}

#import <objc/runtime.h>

// macOS 26 can retire a pool with stale extension IPC receivers. The public
// lifetime owner remains necessary there; cache invalidation uses the public
// website-data API independently. Newer runtimes never instantiate these owners.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface TimoWebProcessPoolOwner () {
    WKProcessPool *_pool;
}
@end

@implementation TimoWebProcessPoolOwner
- (instancetype)init
{
    self = [super init];
    if (self) _pool = [[WKProcessPool alloc] init];
    return self;
}
- (void)configure:(WKWebViewConfiguration *)configuration { configuration.processPool = _pool; }
- (BOOL)matches:(WKWebViewConfiguration *)configuration { return configuration.processPool == _pool; }
#if !__has_feature(objc_arc)
- (void)dealloc
{
    [_pool release];
    [super dealloc];
}
#endif
@end
#pragma clang diagnostic pop

BOOL TimoSetBooleanPreference(id target, SEL setter, BOOL enabled)
{
    if (![target respondsToSelector:setter]) return NO;
    Method method = class_getInstanceMethod(object_getClass(target), setter);
    if (!method) return NO;
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    if (signature.numberOfArguments != 3
        || strcmp(signature.methodReturnType, @encode(void)) != 0
        || strcmp([signature getArgumentTypeAtIndex:2], @encode(BOOL)) != 0) return NO;
    void (*setBoolean)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))method_getImplementation(method);
    setBoolean(target, setter, enabled);
    return YES;
}
