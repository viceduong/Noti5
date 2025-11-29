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
static NSString *const kRecentFilePath = @"/var/mobile/Library/Noti5/recent.json";
static NSString *const kDebugFilePath = @"/var/mobile/Library/Noti5/debug.log";
static NSString *const kPidFilePath = @"/var/tmp/noti5.pid";
static NSString *const kHeartbeatFilePath = @"/var/tmp/noti5.heartbeat";

// Recent notifications storage (for rule creation in main app)
static NSMutableArray *recentNotifications = nil;
static const NSUInteger kMaxRecentNotifications = 50;

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

#pragma mark - Debug Logging

void writeDebugLog(NSString *message) {
    static NSFileHandle *debugHandle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSFileManager defaultManager] createFileAtPath:kDebugFilePath contents:nil attributes:nil];
        debugHandle = [NSFileHandle fileHandleForWritingAtPath:kDebugFilePath];
    });

    NSString *timestamp = [[NSDate date] description];
    NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];

    @synchronized(debugHandle) {
        [debugHandle seekToEndOfFile];
        [debugHandle writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
        [debugHandle synchronizeFile];
    }

    NSLog(@"Noti5 Helper: %@", message);
}

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

#pragma mark - Recent Notifications

void saveRecentNotification(NSDictionary *notification) {
    if (!recentNotifications) {
        // Load existing recent notifications
        recentNotifications = [NSMutableArray array];
        NSData *existingData = [NSData dataWithContentsOfFile:kRecentFilePath];
        if (existingData) {
            NSArray *existing = [NSJSONSerialization JSONObjectWithData:existingData
                                                                options:0
                                                                  error:nil];
            if (existing) {
                [recentNotifications addObjectsFromArray:existing];
            }
        }
    }

    // Add notification with timestamp
    NSMutableDictionary *entry = [notification mutableCopy];
    entry[@"timestamp"] = [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]];

    // Insert at beginning (newest first)
    [recentNotifications insertObject:entry atIndex:0];

    // Keep only last N notifications
    while (recentNotifications.count > kMaxRecentNotifications) {
        [recentNotifications removeLastObject];
    }

    // Save to file
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:recentNotifications
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];
    [jsonData writeToFile:kRecentFilePath atomically:YES];

    NSLog(@"Noti5 Helper: Saved recent notification from %@ (total: %lu)",
          notification[@"bundleId"], (unsigned long)recentNotifications.count);
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
            NSLog(@"Noti5 Helper: ERROR - Must run as root");
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

        // Debug: Log database path info
        writeDebugLog(@"=== Noti5 Helper Starting ===");
        NSDictionary *systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
        writeDebugLog([NSString stringWithFormat:@"iOS Version: %@", systemVersion[@"ProductVersion"] ?: @"unknown"]);
        writeDebugLog([NSString stringWithFormat:@"UID: %d, EUID: %d", getuid(), geteuid()]);
        writeDebugLog([NSString stringWithFormat:@"Database path: %@", [monitor databasePath]]);

        NSFileManager *fm = [NSFileManager defaultManager];

        // List ALL contents of /var/mobile/Library to find what exists
        writeDebugLog(@"=== Full /var/mobile/Library listing ===");
        NSArray *allMobileLib = [fm contentsOfDirectoryAtPath:@"/var/mobile/Library" error:nil];
        writeDebugLog([NSString stringWithFormat:@"Total items: %lu", (unsigned long)allMobileLib.count]);
        for (NSString *item in allMobileLib) {
            writeDebugLog([NSString stringWithFormat:@"  %@", item]);
        }
        BOOL isDir = NO;
        BOOL dbExists = [fm fileExistsAtPath:[monitor databasePath] isDirectory:&isDir];
        writeDebugLog([NSString stringWithFormat:@"Database path exists: %@, isDirectory: %@",
                      dbExists ? @"YES" : @"NO", isDir ? @"YES" : @"NO"]);

        if (dbExists && isDir) {
            NSError *error;
            NSArray *contents = [fm contentsOfDirectoryAtPath:[monitor databasePath] error:&error];
            writeDebugLog([NSString stringWithFormat:@"Database contents: %@", contents]);
            if (error) {
                writeDebugLog([NSString stringWithFormat:@"Error listing directory: %@", error]);
            }

            // List files in first subdirectory (stream)
            for (NSString *item in contents) {
                NSString *subPath = [[monitor databasePath] stringByAppendingPathComponent:item];
                BOOL subIsDir;
                if ([fm fileExistsAtPath:subPath isDirectory:&subIsDir] && subIsDir) {
                    NSArray *subContents = [fm contentsOfDirectoryAtPath:subPath error:nil];
                    writeDebugLog([NSString stringWithFormat:@"  Stream '%@' files: %@", item, subContents]);
                }
            }
        }

        // Check alternative paths and explore structure
        NSArray *altPaths = @[
            @"/var/mobile/Library/DuetExpertCenter",
            @"/var/mobile/Library/DuetExpertCenter/streams",
            @"/var/mobile/Library/DuetExpertCenter/streams/userNotificationEvents",
            @"/var/mobile/Library/DuetExpertCenter/streams/userNotificationEvents/local",
            @"/private/var/mobile/Library/DuetExpertCenter/streams/userNotificationEvents/local",
            @"/var/mobile/Library/Duet",
            @"/var/mobile/Library/Duet/Notifications"
        ];
        for (NSString *path in altPaths) {
            BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];
            writeDebugLog([NSString stringWithFormat:@"Path '%@': exists=%@, isDir=%@",
                          path, exists ? @"YES" : @"NO", isDir ? @"YES" : @"NO"]);

            // If it exists and is a directory, list contents
            if (exists && isDir) {
                NSArray *contents = [fm contentsOfDirectoryAtPath:path error:nil];
                writeDebugLog([NSString stringWithFormat:@"  Contents: %@", contents]);
            }
            // If it exists but is a file, show file info
            else if (exists && !isDir) {
                NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
                writeDebugLog([NSString stringWithFormat:@"  File size: %@, type: %@",
                              attrs[NSFileSize], attrs[NSFileType]]);
            }
        }

        // Explore DuetExpertCenter structure
        writeDebugLog(@"=== Exploring /var/mobile/Library/DuetExpertCenter ===");
        NSString *duetBase = @"/var/mobile/Library/DuetExpertCenter";
        if ([fm fileExistsAtPath:duetBase isDirectory:&isDir] && isDir) {
            NSArray *duetContents = [fm contentsOfDirectoryAtPath:duetBase error:nil];
            writeDebugLog([NSString stringWithFormat:@"DuetExpertCenter contents: %@", duetContents]);

            // Check streams subdirectory
            NSString *streamsPath = [duetBase stringByAppendingPathComponent:@"streams"];
            if ([fm fileExistsAtPath:streamsPath isDirectory:&isDir] && isDir) {
                NSArray *streamContents = [fm contentsOfDirectoryAtPath:streamsPath error:nil];
                writeDebugLog([NSString stringWithFormat:@"streams/ contents: %@", streamContents]);

                // List all stream directories
                for (NSString *stream in streamContents) {
                    NSString *streamPath = [streamsPath stringByAppendingPathComponent:stream];
                    if ([fm fileExistsAtPath:streamPath isDirectory:&isDir] && isDir) {
                        NSArray *streamFiles = [fm contentsOfDirectoryAtPath:streamPath error:nil];
                        writeDebugLog([NSString stringWithFormat:@"  streams/%@/ contents: %@", stream, streamFiles]);
                    }
                }
            }
        }

        // Also check for BulletinBoard and other notification paths
        writeDebugLog(@"=== Checking all potential notification paths ===");
        NSArray *bbPaths = @[
            @"/var/mobile/Library/BulletinBoard",
            @"/var/mobile/Library/SpringBoard",
            @"/var/mobile/Library/SpringBoard/PushStore",
            @"/var/mobile/Library/UserNotifications",
            @"/var/mobile/Library/Preferences",
            @"/var/mobile/Library/Duet",
            @"/var/mobile/Library/Biome",
            @"/var/mobile/Library/Biome/streams",
            @"/private/var/db/biome",
            @"/private/var/db/biome/streams"
        ];
        for (NSString *path in bbPaths) {
            BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];
            writeDebugLog([NSString stringWithFormat:@"Path '%@': exists=%@, isDir=%@",
                          path, exists ? @"YES" : @"NO", isDir ? @"YES" : @"NO"]);
            if (exists && isDir) {
                NSArray *contents = [fm contentsOfDirectoryAtPath:path error:nil];
                writeDebugLog([NSString stringWithFormat:@"  Contents: %@", contents]);

                // Look for notification-related subdirectories
                for (NSString *item in contents) {
                    NSString *lower = [item lowercaseString];
                    if ([lower containsString:@"notif"] || [lower containsString:@"bulletin"] ||
                        [lower containsString:@"push"] || [lower containsString:@"user"]) {
                        NSString *subPath = [path stringByAppendingPathComponent:item];
                        writeDebugLog([NSString stringWithFormat:@"  -> Found interesting: %@", subPath]);
                        if ([fm fileExistsAtPath:subPath isDirectory:&isDir] && isDir) {
                            NSArray *subContents = [fm contentsOfDirectoryAtPath:subPath error:nil];
                            writeDebugLog([NSString stringWithFormat:@"     Contents: %@", subContents]);
                        }
                    }
                }
            }
        }

        // Search for SEGB files in common locations
        writeDebugLog(@"=== Searching for notification databases ===");
        NSArray *searchPaths = @[
            @"/var/mobile/Library/Biome/streams",
            @"/private/var/db/biome/streams",
            @"/private/var/db/biome/streams/restricted",
            @"/var/db/biome/streams",
            @"/var/db/biome/streams/restricted"
        ];

        // First check if base biome paths exist
        NSArray *biomeBases = @[
            @"/private/var/db/biome",
            @"/var/db/biome",
            @"/private/var/db"
        ];
        for (NSString *base in biomeBases) {
            BOOL baseExists = [fm fileExistsAtPath:base isDirectory:&isDir];
            writeDebugLog([NSString stringWithFormat:@"Biome base '%@': exists=%@, isDir=%@",
                          base, baseExists ? @"YES" : @"NO", isDir ? @"YES" : @"NO"]);
            if (baseExists && isDir) {
                NSArray *baseContents = [fm contentsOfDirectoryAtPath:base error:nil];
                writeDebugLog([NSString stringWithFormat:@"  Contents: %@", baseContents]);
            }
        }

        // Broad search - check /var/mobile/Library for anything notification-related
        writeDebugLog(@"=== Broad search in /var/mobile/Library ===");
        NSString *mobileLib = @"/var/mobile/Library";
        NSArray *mobileLibContents = [fm contentsOfDirectoryAtPath:mobileLib error:nil];
        for (NSString *item in mobileLibContents) {
            NSString *lower = [item lowercaseString];
            if ([lower containsString:@"notif"] || [lower containsString:@"bulletin"] ||
                [lower containsString:@"push"] || [lower containsString:@"duet"] ||
                [lower containsString:@"biome"] || [lower containsString:@"usernotif"]) {
                writeDebugLog([NSString stringWithFormat:@"Found: /var/mobile/Library/%@", item]);
                NSString *itemPath = [mobileLib stringByAppendingPathComponent:item];
                if ([fm fileExistsAtPath:itemPath isDirectory:&isDir] && isDir) {
                    NSArray *subContents = [fm contentsOfDirectoryAtPath:itemPath error:nil];
                    writeDebugLog([NSString stringWithFormat:@"  Contents: %@", subContents]);
                }
            }
        }

        // Check BulletinBoard specifically - this is where iOS stores notification data
        writeDebugLog(@"=== Checking BulletinBoard in detail ===");
        NSString *bbPath = @"/var/mobile/Library/BulletinBoard";
        if ([fm fileExistsAtPath:bbPath isDirectory:&isDir]) {
            writeDebugLog([NSString stringWithFormat:@"BulletinBoard exists, isDir=%@", isDir ? @"YES" : @"NO"]);
            if (isDir) {
                NSArray *bbContents = [fm contentsOfDirectoryAtPath:bbPath error:nil];
                writeDebugLog([NSString stringWithFormat:@"  Contents: %@", bbContents]);

                // Check each subdirectory
                for (NSString *sub in bbContents) {
                    NSString *subPath = [bbPath stringByAppendingPathComponent:sub];
                    if ([fm fileExistsAtPath:subPath isDirectory:&isDir] && isDir) {
                        NSArray *subContents = [fm contentsOfDirectoryAtPath:subPath error:nil];
                        writeDebugLog([NSString stringWithFormat:@"  %@/ contents: %@", sub, subContents]);
                    }
                }
            }
        } else {
            writeDebugLog(@"BulletinBoard does not exist");
        }

        // Check /private/var for notification databases
        writeDebugLog(@"=== Checking /private/var paths ===");
        NSArray *privateVarPaths = @[
            @"/private/var/mobile/Library/BulletinBoard",
            @"/private/var/mobile/Library/SpringBoard",
            @"/private/var/mobile/Library/UserNotifications"
        ];
        for (NSString *path in privateVarPaths) {
            BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];
            writeDebugLog([NSString stringWithFormat:@"Path '%@': exists=%@, isDir=%@",
                          path, exists ? @"YES" : @"NO", isDir ? @"YES" : @"NO"]);
            if (exists && isDir) {
                NSArray *contents = [fm contentsOfDirectoryAtPath:path error:nil];
                writeDebugLog([NSString stringWithFormat:@"  Contents: %@", contents]);
            }
        }
        for (NSString *searchPath in searchPaths) {
            if ([fm fileExistsAtPath:searchPath isDirectory:&isDir] && isDir) {
                NSArray *streams = [fm contentsOfDirectoryAtPath:searchPath error:nil];
                for (NSString *stream in streams) {
                    NSString *lower = [stream lowercaseString];
                    if ([lower containsString:@"notif"] || [lower containsString:@"user"]) {
                        writeDebugLog([NSString stringWithFormat:@"Found potential notification stream: %@/%@", searchPath, stream]);
                        NSString *streamPath = [searchPath stringByAppendingPathComponent:stream];
                        if ([fm fileExistsAtPath:streamPath isDirectory:&isDir] && isDir) {
                            NSArray *streamContents = [fm contentsOfDirectoryAtPath:streamPath error:nil];
                            writeDebugLog([NSString stringWithFormat:@"  Contents: %@", streamContents]);

                            // Check local subdirectory
                            NSString *localPath = [streamPath stringByAppendingPathComponent:@"local"];
                            if ([fm fileExistsAtPath:localPath isDirectory:&isDir] && isDir) {
                                NSArray *localContents = [fm contentsOfDirectoryAtPath:localPath error:nil];
                                writeDebugLog([NSString stringWithFormat:@"  local/ Contents: %@", localContents]);
                            }
                        }
                    }
                }
            }
        }

        // Set callback for all notifications
        monitor.matchCallback = ^(NSDictionary *notification) {
            writeDebugLog([NSString stringWithFormat:@"CALLBACK: Got notification from %@", notification[@"bundleId"]]);

            // Save ALL notifications to recent (for rule creation in main app)
            saveRecentNotification(notification);

            // Then evaluate against rules
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
        writeDebugLog(@"Starting notification monitoring...");
        [monitor startMonitoring];
        writeDebugLog([NSString stringWithFormat:@"Monitor isMonitoring: %@", [monitor isMonitoring] ? @"YES" : @"NO"]);

        NSLog(@"Noti5 Helper: Running...");
        writeDebugLog(@"=== Helper started successfully ===");

        // Run main loop
        if (isDaemon) {
            CFRunLoopRun();
        } else {
            // Non-daemon mode - run for testing
            [[NSRunLoop currentRunLoop] run];
        }

        NSLog(@"Noti5 Helper: Shutting down...");

        // Cleanup
        [monitor stopMonitoring];
        [[NSFileManager defaultManager] removeItemAtPath:kPidFilePath error:nil];

        return 0;
    }
}
