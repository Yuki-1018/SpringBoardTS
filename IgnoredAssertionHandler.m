//
//  IgnoredAssertionHandler.m
//
//
//  Created by Duy Tran on 1/6/25.
//
#import "IgnoredAssertionHandler.h"

@implementation IgnoredAssertionHandler
- (void)handleFailureInFunction:(NSString *)functionName file:(NSString *)fileName lineNumber:(NSInteger)line description:(NSString *)format, ... {
    // Format message
    va_list vl;
    va_start(vl, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:vl];
    va_end(vl);
    NSLog(@"Ignoring: *** Assertion failure in %@, %@:%lld: %@", functionName, fileName, (long long)line, msg);
}

- (void)handleFailureInMethod:(SEL)selector object:(id)object file:(NSString *)fileName lineNumber:(NSInteger)line description:(NSString *)format, ... {
    // Format message
    va_list vl;
    va_start(vl, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:vl];
    va_end(vl);
    NSLog(@"Ignoring: *** Assertion failure in [%s %s], %@:%lld: %@", object_getClassName(object), sel_getName(selector), fileName, (long long)line, msg);
}
@end
