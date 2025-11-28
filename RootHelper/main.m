//
//  main.m
//  Noti5 Root Helper
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
static NSString *const kSharedDataPath = @"/var/mobile/Library/Noti5";
static NSString *const kRulesFilePath = @"/var/mobile/Library/Noti5/rules.json";
static NSString *const kMatchedFilePath = @"/var/mobile/Library/Noti5/matched.json";
static NSString *const kProcessedFilePath = @"/var/mobile/Library/Noti5/processed.json";
static NSString *const kPidFilePath = @"/var/tmp/noti5.pid";
static NSString *const kHeartbeatFilePath = @"/var/tmp/noti5.heartbeat";

// Darwin notification names
static NSString *const kNotifyMatched = @"com.noti5.matched";
static NSString *const kNotifyRulesUpdated = @"com.noti5.rules.updated";
static NSString *const kNotifyStart = @"com.noti5.start";
static NSString *const kNotifyStop = @"com.noti5.stop";
static NSString *const kNotifyHeartbeat = @"com.noti5.heartbeat";

// Global state
static BOOL shouldRun = YES;
static NotificationMonitor *monitor = nil;
static RuleMatcher *ruleMatcher = nil;

#pragma mark - Signal Handlers

void handleSignal(int signal) {
    NSLog(@"Noti5 Helper: Received signal %d, shutting down...", signal);
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
            NSLog(@"Noti5 Helper: Rules updated, reloading...");
            [ruleMatcher reloadRules];
        });

    // Listen for stop command
    notify_register_dispatch([kNotifyStop UTF8String], &token,
        dispatch_get_main_queue(), ^(int t) {
            NSLog(@"Noti5 Helper: Stop command received");
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
        dispatch_get_main_queue()  // Use main queue to keep run loop alive
    );

    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC, 0);

    dispatch_source_set_event_handler(timer, ^{
        // Touch heartbeat file
        NSString *timestamp = [[NSDate date] description];
        NSError *error;
        BOOL success = [timestamp writeToFile:kHeartbeatFilePath
                                   atomically:YES
                                     encoding:NSUTF8StringEncoding
                                        error:&error];
        if (!success) {
            NSLog(@"Noti5 Helper: Failed to write heartbeat: %@", error);
        }

        // Post Darwin notification
        postDarwinNotification(kNotifyHeartbeat);
        NSLog(@"Noti5 Helper: Heartbeat sent");
    });

    dispatch_resume(timer);

    // Send first heartbeat immediately
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *timestamp = [[NSDate date] description];
        [timestamp writeToFile:kHeartbeatFilePath
                    atomically:YES
                      encoding:NSUTF8StringEncoding
                         error:nil];
        postDarwinNotification(kNotifyHeartbeat);
        NSLog(@"Noti5 Helper: Initial heartbeat sent");
    });
}

#pragma mark - Notification Handling

void handleMatchedNotification(NSDictionary *notification, NSString *ruleName) {
    NSLog(@"Noti5 Helper: Matched notification from %@ - %@",
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
        NSLog(@"Noti5 Helper: Starting (uid=%d, pid=%d)", getuid(), getpid());

        // Check if running as root
        if (getuid() != 0) {
            NSLog(@"Noti5 Helper: WARNING - Not running as root (uid=%d)", getuid());
            NSLog(@"Noti5 Helper: Some functionality may be limited");
            // Don't exit - try to continue anyway for testing
        }

        // Check for daemon flag
        BOOL isDaemon = NO;
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--daemon") == 0) {
                isDaemon = YES;
                break;
            }
        }

        NSLog(@"Noti5 Helper: Daemon mode: %@", isDaemon ? @"YES" : @"NO");

        // Setup
        setupSignalHandlers();
        writePidFile();
        setupSharedDirectory();

        NSLog(@"Noti5 Helper: Basic setup complete");

        @try {
            // Initialize components
            ruleMatcher = [[RuleMatcher alloc] initWithRulesPath:kRulesFilePath];
            NSLog(@"Noti5 Helper: RuleMatcher initialized with %lu rules", (unsigned long)[ruleMatcher ruleCount]);

            monitor = [[NotificationMonitor alloc] init];
            NSLog(@"Noti5 Helper: NotificationMonitor initialized");

            // Set callback for matched notifications
            monitor.matchCallback = ^(NSDictionary *notification) {
                @try {
                    NSString *matchedRule = [ruleMatcher evaluateNotification:notification];
                    if (matchedRule) {
                        handleMatchedNotification(notification, matchedRule);
                    }
                } @catch (NSException *exception) {
                    NSLog(@"Noti5 Helper: Exception in match callback: %@", exception);
                }
            };

            // Setup Darwin notification listeners
            setupDarwinNotifications();
            NSLog(@"Noti5 Helper: Darwin notifications setup complete");

            // Start heartbeat
            startHeartbeat();
            NSLog(@"Noti5 Helper: Heartbeat started");

            // Start monitoring
            [monitor startMonitoring];
            NSLog(@"Noti5 Helper: Monitoring started");

        } @catch (NSException *exception) {
            NSLog(@"Noti5 Helper: Exception during initialization: %@", exception);
            NSLog(@"Noti5 Helper: Reason: %@", exception.reason);
            NSLog(@"Noti5 Helper: Will continue with heartbeat only");
        }

        NSLog(@"Noti5 Helper: Running main loop...");

        // Run main loop
        if (isDaemon) {
            CFRunLoopRun();
        } else {
            // Non-daemon mode - run for testing
            [[NSRunLoop currentRunLoop] run];
        }

        NSLog(@"Noti5 Helper: Shutting down...");

        // Cleanup
        if (monitor) {
            [monitor stopMonitoring];
        }
        [[NSFileManager defaultManager] removeItemAtPath:kPidFilePath error:nil];

        return 0;
    }
}
