//
//  iOSOrderFile.m
//  iOSOrderFile
//
//  Created by xiongzenghui on 2020/6/11.
//

#import "iOSOrderFile.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sanitizer/coverage_interface.h>
#include <dlfcn.h>
#include <libkern/OSAtomic.h>
#include <pthread.h>

typedef struct SymbolNode {
  void *pc;
  void *next;
} SymbolNode;

static NSMutableSet* set;
static OSQueueHead head = OS_ATOMIC_QUEUE_INIT;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static BOOL finish = NO;

/**
 * 设置 传入的 [start, stop) 区间内每一个符号的【*guard 值】
 * - 1) 0 == *guard 条件时, return
 * - 2) 0 != *guard 条件时,  顺序【递增】设置 *guard
 */
void __sanitizer_cov_trace_pc_guard_init(uint32_t *start, uint32_t *stop)
{
  static uint32_t N; // 符号的总个数

  if (start == stop || *start)
    return;

  for (uint32_t *x = start; x < stop; x++)
    *x = ++N;
}

void __sanitizer_cov_trace_pc_guard(uint32_t *guard)
{
  void* pc = NULL;

#if 0
  /**
   * 不能写如下这句代码, 否则 会导致【无法获取】到所有【0 == *guard】类型的符号
   *
   * guard: 0, pc: 0x10ff61adf, dli_sname: +[_AFURLSessionTaskSwizzling load]
   * guard: 0, pc: 0x10ff61d53, dli_sname: +[_AFURLSessionTaskSwizzling swizzleResumeAndSuspendMethodForClass:]
   * guard: 0, pc: 0x10ff61e73, dli_sname: af_addMethod
   * ...................
   */
  if (!*guard) return;
#endif

#if 0
  // If you set *guard to 0 this code will not be called again for this edge.
  // Now you can get the PC and do whatever you want:
  // store it somewhere or symbolize it and print right away.
  *guard = 0;
#endif

  if (finish) return;
  pc = __builtin_return_address(0);

  pthread_mutex_lock(&lock);

  if (!set) set = [[NSMutableSet alloc] init];
  if ([set containsObject:@(*guard)] && (0 != *guard))
  {
    pthread_mutex_unlock(&lock);
    return;
  }

#if 0
  Dl_info info;
  dladdr(pc, &info);
  printf("guard: %d, pc: %p, dli_sname: %s\n", *guard, pc, info.dli_sname);
#endif

  SymbolNode *node = malloc(sizeof(SymbolNode));
  if (!node)
  {
    pthread_mutex_unlock(&lock);
    return;
  }

  node->pc = pc;
  node->next = NULL;
  [set addObject:@(*guard)];
  pthread_mutex_unlock(&lock);

  OSAtomicEnqueue(&head, node, offsetof(SymbolNode, next));
}

void generate_order_file()
{
  finish = YES;
#if 0
  dispatch_async(dispatch_get_global_queue(0, 0), ^{
#endif
  NSMutableArray <NSString *>* symbolNames = [NSMutableArray array];

  while (YES)
  {
    // 依次取出 symbolList[i] 当前正在执行的 函数 所在的内存地址
    SymbolNode* node = OSAtomicDequeue(&head, offsetof(SymbolNode, next));
    if (!node)
      break;

    // 解析得到 当前执行的函数 对应的符号信息
    Dl_info info;
    dladdr(node->pc, &info);
#if 0
    printf("fname:%s \nfbase:%p \nsname:%s \nsaddr:%p\n",
            info.dli_fname,
            info.dli_fbase,
            info.dli_sname,
            info.dli_saddr);
#endif

    // 删除 当前 函数符号
    if (0 == strcmp(__FUNCTION__, info.dli_sname))
    {
      free(node);
      continue;
    }

    // symbol name
    NSString* sname = (0 == strncmp("-[", info.dli_sname, 2) || 0 == strncmp("+[", info.dli_sname, 2)) ? \
      @(info.dli_sname) : \
      [NSString stringWithFormat:@"_%s", info.dli_sname];

    // 去重
    if ([symbolNames containsObject:sname])
    {
      free(node);
      continue;
    }

    // 顺序取反
    [symbolNames insertObject:sname atIndex:0];
    free(node);
  }
#if 1
  NSLog(@"symbolNames: %@", symbolNames);
#endif

  // 写入 磁盘文件
  NSString* funcStr = [symbolNames componentsJoinedByString:@"\n"];
  NSString* filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"trace.order"];
  NSLog(@"filePath: %@", filePath);
  NSData* fileContents = [funcStr dataUsingEncoding:NSUTF8StringEncoding];
  [[NSFileManager defaultManager] createFileAtPath:filePath contents:fileContents attributes:nil];
#if 0
  });
#endif
}
