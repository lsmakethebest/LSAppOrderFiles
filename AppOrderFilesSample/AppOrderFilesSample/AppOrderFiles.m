//
//  AppOrderFiles.m
//  AppOrderFiles
//
//  Created by liusong on 2019/9/19.
//  Copyright © 2019 liusong All rights reserved.
//

#import <dlfcn.h>
#import <libkern/OSAtomicQueue.h>
#import <pthread.h>
#import <Foundation/Foundation.h>

 NSString * const APP_LAUNCH_FINISH_NOTIFICATION = @"app_launch_finish";

static OSQueueHead queue = OS_ATOMIC_QUEUE_INIT;

static BOOL collectFinished = NO;

typedef struct {
    void *pc;
    void *next;
} PCNode;

// The guards are [start, stop).
// This function will be called at least once per DSO and may be called
// more than once with the same values of start/stop.
void __sanitizer_cov_trace_pc_guard_init(uint32_t *start,
                                         uint32_t *stop) {
    static uint32_t N;  // Counter for the guards.
    if (start == stop || *start) return;  // Initialize only once.
    printf("INIT: %p %p\n", start, stop);
    for (uint32_t *x = start; x < stop; x++)
    *x = ++N;  // Guards should start from 1.
}

// This callback is inserted by the compiler on every edge in the
// control flow (some optimizations apply).
// Typically, the compiler will emit the code like this:
//    if(*guard)
//      __sanitizer_cov_trace_pc_guard(guard);
// But for large functions it will emit a simple call:
//    __sanitizer_cov_trace_pc_guard(guard);
void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
    if (!*guard) return;  // Duplicate the guard check.
    if (collectFinished) {
        return;
    }
    // If you set *guard to 0 this code will not be called again for this edge.
    // Now you can get the PC and do whatever you want:
    //   store it somewhere or symbolize it and print right away.
    // The values of `*guard` are as you set them in
    // __sanitizer_cov_trace_pc_guard_init and so you can make them consecutive
    // and use them to dereference an array or a bit vector.
    *guard = 0;
    void *PC = __builtin_return_address(0);
    PCNode *node = malloc(sizeof(PCNode));
    *node = (PCNode){PC, NULL};
    OSAtomicEnqueue(&queue, node, offsetof(PCNode, next));
}

extern void AppOrderFiles(void(^completion)(NSString *orderFilePath)) {
    collectFinished = YES;
    __sync_synchronize();
    NSString *functionExclude = [NSString stringWithFormat:@"_%s", __FUNCTION__];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray <NSString *> *functions = [NSMutableArray array];
        while (YES) {
            PCNode *node = OSAtomicDequeue(&queue, offsetof(PCNode, next));
            if (node == NULL) {
                break;
            }
            Dl_info info = {0};
            dladdr(node->pc, &info);
            NSString *name = @(info.dli_sname);
            BOOL isObjc = [name hasPrefix:@"+["] || [name hasPrefix:@"-["];
            NSString *symbolName = isObjc ? name : [@"_" stringByAppendingString:name];
            if ([symbolName rangeOfString:@"+[AppOrderFile load]"].length<=0) {
                [functions addObject:symbolName];
            }
        }
        if (functions.count == 0) {
            if (completion) {
                completion(nil);
            }
            return;
        }
        NSMutableArray<NSString *> *calls = [NSMutableArray arrayWithCapacity:functions.count];
        NSEnumerator *enumerator = [functions reverseObjectEnumerator];
        NSString *obj;
        while (obj = [enumerator nextObject]) {
            if (![calls containsObject:obj]) {
                [calls addObject:obj];
            }
        }
        [calls removeObject:functionExclude]; //remove  _AppOrderFiles
        NSString *result = [calls componentsJoinedByString:@"\n"];
        NSLog(@"Order:\n%@", result);
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *filePath = [documentsPath stringByAppendingPathComponent:@"order.txt"];
        NSError *error;
        BOOL success = [result writeToURL:[NSURL fileURLWithPath:filePath] atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (completion) {
            completion(success ? filePath : nil);
        }
    });
}


@interface AppOrderFile : NSObject

@end

@implementation AppOrderFile

+ (void)load
{
    // 此处通知标识 app启动已完成,获取函数调用栈
    NSNotificationCenter *center =[NSNotificationCenter defaultCenter];
    [center addObserverForName:APP_LAUNCH_FINISH_NOTIFICATION
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification * _Nonnull note)
     {
         AppOrderFiles(^(NSString *orderFilePath) {
             NSLog(@"OrderFilePath:%@", orderFilePath);
         });
     }];

}

@end

