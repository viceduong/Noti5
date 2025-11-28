//
//  main.m
//  NotifyFilter Root Helper
//
//  Background daemon that monitors notification database
//

#import <Foundation/Foundation.h>
#import <notify.h>
#import <sys/event.h>
#import <sys/stat.h>
#import <signal.h>
#import "SEGBParser.h"
#import "NotificationMonitor.h"
#import "RuleMatcher.h"

// Shared paths
static NSString *const kSharedDataPath = @"/var/mobile/Library/NotifyFilter";
static NSString *const kRulesFilePath = @"/var/mobile/Library/NotifyFilter/rules.json";
static NSString *const kMatchedFilePath = @"/var/mobile/Library/NotifyFilter/matched.json";
static NSString *const kProcessedFilePath = @"/var/mobile/Library/NotifyFilter/processed.json";
static NSString *const kPidFilePath = @"/var/tmp/notifyfilter.pid";
static NSString *const kHeartbeatFilePath = @"/var/tmp/notifyfilter.heartbeat";

// Darwin notification names
static NSString *const kNotifyMatched = @"com.notifyfilter.matched";
static NSString *const kNotifyRulesUpdated = @"com.notifyfilter.rules.updated";
static NSString *const kNotifyStart = @"com.notifyfilter.start";
static NSString *const kNotifyStop = @"com.notifyfilter.stop";
static NSString *const kNotifyHeartbeat = @"com.notifyfilter.heartbeat";

// Global state
static BOOL shouldRun = YES;
static NotificationMonitor *monitor = nil;
static RuleMatcher *ruleMatcher = nil;

#pragma mark - Signal Handlers

void handleSignal(int signal) {
    NSLog(@"NotifyFilter Helper: Received signal %d, shutting down...", signal);
    shouldRun = NO;

    // Clean up PID file
    [[NSFileManager defaultManager] removeItemAtPath:kPidFilePath error:nil];

    exit(0);
}

#pragma mark - Setup

void setupSignalHandlers(void) {
    signal(SIGTERM, handleSignal);
    signal(SIGINT, handleSignal);
    signal(SIGHUP, SIG_IGN);  // Ignore hangup
}

void writePidFile(void) {
    NSString *pidString = [NSString stringWithFormat:@"%d", getpid()];
    [pidString writeToFile:kPidFilePath
                atomically:YES
                  encoding:NSUTF8StringEncoding
                     error:nil];
}

void setupSharedDirectory(void) {
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:kSharedDataPath]) {
        [fm createDirectoryAtPath:kSharedDataPath
      withIntermediateDirectories:YES
                       attributes:nil
                            error:nil];
    }

    // Set permissions so main app can read/write
    NSDictionary *attrs = @{NSFilePosixPermissions: @(0755)};
    [fm setAttributes:attrs ofItemAtPath:kSharedDataPath error:nil];
}

#pragma mark - Darwin Notification Listeners

void setupDarwinNotifications(void) {
    int token;

    // Listen for rules update
    notify_register_dispatch([kNotifyRulesUpdated UTF8String], &token,
        dispatch_get_main_queue(), ^(int t) {
            NSLog(@"NotifyFilter Helper: Rules updated, reloading...");
            [ruleMatcher reloadRules];
        });

    // Listen for stop command
    notify_register_dispatch([kNotifyStop UTF8String], &token,
        dispatch_get_main_queue(), ^(int t) {
            NSLog(@"NotifyFilter Helper: Stop command received");
            shouldRun = NO;
            CFRunLoopStop(CFRunLoopGetMain());
        });
}

void postDarwinNotification(NSString *name) {
    notify_post([name UTF8String]);
}

#pragma mark - Heartbeat

void startHeartbeat(void) {
    // Send heartbeat every 30 seconds
    dispatch_source_t timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    );

    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC, 0);

    dispatch_source_set_event_handler(timer, ^{
        // Touch heartbeat file
        NSString *timestamp = [[NSDate date] description];
        [timestamp writeToFile:kHeartbeatFilePath
                    atomically:YES
                      encoding:NSUTF8StringEncoding
                         error:nil];

        // Post Darwin notification
        postDarwinNotification(kNotifyHeartbeat);
    });

    dispatch_resume(timer);
}

#pragma mark - Notification Handling

void handleMatchedNotification(NSDictionary *notification, NSString *ruleName) {
    NSLog(@"NotifyFilter Helper: Matched notification from %@ - %@",
          notification[@"bundleId"], notification[@"title"]);

    // Read existing matched notifications
    NSMutableArray *matched = [NSMutableArray array];
    NSData *existingData = [NSData dataWithContentsOfFile:kMatchedFilePath];

    if (existingData) {
        NSArray *existing = [NSJSONSerialization JSONObjectWithData:existingData
                                                            options:0
                                                              error:nil];
        if (existing) {
            [matched addObjectsFromArray:existing];
        }
    }

    // Add new notification
    NSMutableDictionary *entry = [notification mutableCopy];
    entry[@"matchedRuleName"] = ruleName;
    entry[@"timestamp"] = [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]];
    [matched addObject:entry];

    // Write back
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:matched
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];
    [jsonData writeToFile:kMatchedFilePath atomically:YES];

    // Notify main app
    postDarwinNotification(kNotifyMatched);
}

#pragma mark - Main

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSLog(@"NotifyFilter Helper: Starting (uid=%d, pid=%d)", getuid(), getpid());

        // Check if running as root
        if (getuid() != 0) {
            NSLog(@"NotifyFilter Helper: ERROR - Must run as root");
            return 1;
        }

        // Check for daemon flag
        BOOL isDaemon = NO;
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--daemon") == 0) {
                isDaemon = YES;
                break;
            }
        }

        // Setup
        setupSignalHandlers();
        writePidFile();
        setupSharedDirectory();

        // Initialize components
        ruleMatcher = [[RuleMatcher alloc] initWithRulesPath:kRulesFilePath];
        monitor = [[NotificationMonitor alloc] init];

        // Set callback for matched notifications
        monitor.matchCallback = ^(NSDictionary *notification) {
            NSString *matchedRule = [ruleMatcher evaluateNotification:notification];
            if (matchedRule) {
                handleMatchedNotification(notification, matchedRule);
            }
        };

        // Setup Darwin notification listeners
        setupDarwinNotifications();

        // Start heartbeat
        startHeartbeat();

        // Start monitoring
        [monitor startMonitoring];

        NSLog(@"NotifyFilter Helper: Running...");

        // Run main loop
        if (isDaemon) {
            CFRunLoopRun();
        } else {
            // Non-daemon mode - run for testing
            [[NSRunLoop currentRunLoop] run];
        }

        NSLog(@"NotifyFilter Helper: Shutting down...");

        // Cleanup
        [monitor stopMonitoring];
        [[NSFileManager defaultManager] removeItemAtPath:kPidFilePath error:nil];

        return 0;
    }
}
