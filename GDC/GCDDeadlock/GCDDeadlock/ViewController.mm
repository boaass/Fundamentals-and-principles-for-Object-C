//
//  ViewController.m
//  GCDDeadlock
//
//  Created by cm_zhaichunlin on 2019/3/18.
//  Copyright © 2019 cmcm. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic, strong) NSThread *thread;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _thread = [[NSThread alloc] initWithBlock:^{
        @autoreleasepool {
            NSRunLoop *runloop = [NSRunLoop currentRunLoop];
            [runloop addPort:[NSMachPort port] forMode:NSRunLoopCommonModes];
            [runloop run];
        }
    }];
    [_thread start];
    
    // 死锁
//    [self deadLockTest1];
//    [self desdLockTest2];
    [self desdLockTest3];
    
    // 不会死锁
//    [self noDeadLockTest1];
    [self noDeadLockTest2];
}

#pragma marm - deadlock demo
/**
 *  首先执行任务1，这是肯定没问题的，只是接下来，程序遇到了同步线程，那么它会进入等待，等待任务2执行完，然后执行任务3。但这是队列，有任务来，当然会将任务加到队尾，然后遵循FIFO原则执行任务。那么，现在任务2就会被加到最后，任务3排在了任务2前面，问题来了：
 *  任务3要等任务2执行完才能执行，任务2由排在任务3后面，意味着任务2要在任务3执行完才能执行，所以他们进入了互相等待的局面。
 */
- (void)deadLockTest1
{
    NSLog(@"task 1");
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"task 2");
    });
    NSLog(@"task 3");
}

/**
 * 执行任务1；
 遇到异步线程，将【任务2、同步线程、任务4】加入串行队列中。因为是异步线程，所以在主线程中的任务5不必等待异步线程中的所有任务完成；
 因为任务5不必等待，所以2和5的输出顺序不能确定；
 任务2执行完以后，遇到同步线程，这时，将任务3加入串行队列；
 又因为任务4比任务3早加入串行队列，所以，任务3要等待任务4完成以后，才能执行。但是任务3所在的同步线程会阻塞，所以任务4必须等任务3执行完以后再执行。这就又陷入了无限的等待中，造成死锁。
 */
- (void)desdLockTest2
{
    NSLog(@"task 1");
    dispatch_queue_t queue = dispatch_queue_create("com.zcl.serialQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        NSLog(@"task 2");
        dispatch_sync(queue, ^{
            NSLog(@"task 3");
        });
        NSLog(@"task 4");
    });
    NSLog(@"task 5");
}

/**
 *  在加入到Global Queue异步线程中的任务有：【任务1、同步线程、任务3】。
 第一个就是异步线程，任务4不用等待，所以结果任务1和任务4顺序不一定。
 任务4完成后，程序进入死循环，Main Queue阻塞。但是加入到Global Queue的异步线程不受影响，继续执行任务1后面的同步线程。
 同步线程中，将任务2加入到了主线程，并且，任务3等待任务2完成以后才能执行。这时的主线程，已经被死循环阻塞了。所以任务2无法执行，当然任务3也无法执行，在死循环后的任务5也不会执行。
 最终，只能得到1和4顺序不定的结果
 */
- (void)desdLockTest3
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"task 1");
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"task 2");
        });
        NSLog(@"task 3");
    });
    NSLog(@"task 4");
    while (1);
    NSLog(@"task 5");
}

#pragma mark - no deadload
- (void)noDeadLockTest1
{
    NSLog(@"task 1");
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self performSelector:@selector(test) onThread:self.thread withObject:nil waitUntilDone:NO modes:@[NSDefaultRunLoopMode, NSRunLoopCommonModes]];
//        [self performSelector:@selector(test) onThread:self.thread withObject:nil waitUntilDone:YES modes:@[NSDefaultRunLoopMode, NSRunLoopCommonModes]];
//        [self test];
    });
    NSLog(@"task 3");
}

- (void)test
{
    for (int index = 0; index < 100000000; index++);
    NSLog(@"task 2 ----- %@", [NSThread currentThread]);
}

/**
 *  首先，将【任务1、异步线程、任务5】加入Main Queue中，异步线程中的任务是：【任务2、同步线程、任务4】。
 所以，先执行任务1，然后将异步线程中的任务加入到Global Queue中，因为异步线程，所以任务5不用等待，结果就是2和5的输出顺序不一定。
 然后再看异步线程中的任务执行顺序。任务2执行完以后，遇到同步线程。将同步线程中的任务加入到Main Queue中，这时加入的任务3在任务5的后面。
 当任务3执行完以后，没有了阻塞，程序继续执行任务4。
 从以上的分析来看，得到的几个结果：1最先执行；2和5顺序不一定；4一定在3后面。
 */
- (void)noDeadLockTest2
{
    NSLog(@"task 1");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"task 2 ----- %@", [NSThread currentThread]);
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"task 3");
        });
        NSLog(@"task 4");
    });
    NSLog(@"task 5");
}


@end
