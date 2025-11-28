//
//  NotificationMonitor.m
//  NotifyFilter Root Helper
//
//  Monitors notification database directory for changes using kqueue
//

#import "NotificationMonitor.h"
#import "SEGBParser.h"
#import <sys/event.h>
#import <sys/stat.h>
#import <fcntl.h>

static NSString *const kNotificationDBPath = @"/var/mobile/Library/DuetExpertCenter/streams/userNotificationEvents/local";
static NSString *const kProcessedFilePath = @"/var/mobile/Library/NotifyFilter/processed.json";

@interface NotificationMonitor ()

@property (nonatomic, assign) int kqueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *fileOffsets;
@property (nonatomic, strong) NSMutableSet<NSString *> *processedGUIDs;
@property (nonatomic, strong) SEGBParser *parser;
@property (nonatomic, strong) dispatch_source_t monitorSource;
@property (nonatomic, strong) dispatch_source_t pollTimer;
@property (nonatomic, assign) BOOL monitoring;

@end

@implementation NotificationMonitor

- (instancetype)init {
    self = [super init];
    if (self) {
        _parser = [[SEGBParser alloc] init];
        _fileOffsets = [NSMutableDictionary dictionary];
        _processedGUIDs = [NSMutableSet set];
        _kqueue = -1;
        _monitoring = NO;

        [self loadProcessedState];
    }
    return self;
}

- (NSString *)databasePath {
    return kNotificationDBPath;
}

- (BOOL)isMonitoring {
    return _monitoring;
}

#pragma mark - State Persistence

- (void)loadProcessedState {
    NSData *data = [NSData dataWithContentsOfFile:kProcessedFilePath];
    if (!data) return;

    NSDictionary *state = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!state) return;

    // Load file offsets
    NSDictionary *offsets = state[@"fileOffsets"];
    if (offsets) {
        [_fileOffsets addEntriesFromDictionary:offsets];
    }

    // Load processed GUIDs (limit to prevent memory bloat)
    NSArray *guids = state[@"processedGUIDs"];
    if (guids) {
        // Keep only most recent 5000 GUIDs
        NSArray *recentGUIDs = guids;
        if (guids.count > 5000) {
            recentGUIDs = [guids subarrayWithRange:NSMakeRange(guids.count - 5000, 5000)];
        }
        [_processedGUIDs addObjectsFromArray:recentGUIDs];
    }
}

- (void)saveProcessedState {
    // Limit GUIDs to prevent file bloat
    NSArray *guidArray = [_processedGUIDs allObjects];
    if (guidArray.count > 5000) {
        guidArray = [guidArray subarrayWithRange:NSMakeRange(guidArray.count - 5000, 5000)];
    }

    NSDictionary *state = @{
        @"fileOffsets": _fileOffsets,
        @"processedGUIDs": guidArray
    };

    NSData *data = [NSJSONSerialization dataWithJSONObject:state
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:nil];
    [data writeToFile:kProcessedFilePath atomically:YES];
}

#pragma mark - Monitoring

- (void)startMonitoring {
    if (_monitoring) return;

    NSLog(@"NotificationMonitor: Starting monitoring at %@", kNotificationDBPath);

    // Find stream directories
    NSArray *streams = [self findStreamDirectories];
    if (streams.count == 0) {
        NSLog(@"NotificationMonitor: No stream directories found!");
        return;
    }

    // Setup kqueue
    _kqueue = kqueue();
    if (_kqueue < 0) {
        NSLog(@"NotificationMonitor: Failed to create kqueue");
        return;
    }

    // Monitor each stream directory
    for (NSString *streamPath in streams) {
        [self addKqueueWatch:streamPath];
    }

    // Start kqueue monitoring in background
    [self startKqueueMonitoring];

    // Also add a polling fallback every 10 seconds
    [self startPollingFallback];

    _monitoring = YES;

    // Initial scan
    [self scanNow];
}

- (void)stopMonitoring {
    if (!_monitoring) return;

    NSLog(@"NotificationMonitor: Stopping monitoring");

    if (_monitorSource) {
        dispatch_source_cancel(_monitorSource);
        _monitorSource = nil;
    }

    if (_pollTimer) {
        dispatch_source_cancel(_pollTimer);
        _pollTimer = nil;
    }

    if (_kqueue >= 0) {
        close(_kqueue);
        _kqueue = -1;
    }

    [self saveProcessedState];

    _monitoring = NO;
}

- (NSArray<NSString *> *)findStreamDirectories {
    NSMutableArray *streams = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:kNotificationDBPath]) {
        NSLog(@"NotificationMonitor: Database path does not exist: %@", kNotificationDBPath);
        return streams;
    }

    NSError *error;
    NSArray *contents = [fm contentsOfDirectoryAtPath:kNotificationDBPath error:&error];

    if (error) {
        NSLog(@"NotificationMonitor: Failed to list directory: %@", error);
        return streams;
    }

    for (NSString *item in contents) {
        NSString *fullPath = [kNotificationDBPath stringByAppendingPathComponent:item];
        BOOL isDir;
        if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) {
            [streams addObject:fullPath];
        }
    }

    NSLog(@"NotificationMonitor: Found %lu stream directories", (unsigned long)streams.count);

    return streams;
}

- (void)addKqueueWatch:(NSString *)path {
    int fd = open([path fileSystemRepresentation], O_RDONLY);
    if (fd < 0) {
        NSLog(@"NotificationMonitor: Failed to open directory for watching: %@", path);
        return;
    }

    struct kevent change;
    EV_SET(&change, fd, EVFILT_VNODE,
           EV_ADD | EV_ENABLE | EV_CLEAR,
           NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB,
           0, (__bridge void *)path);

    if (kevent(_kqueue, &change, 1, NULL, 0, NULL) < 0) {
        NSLog(@"NotificationMonitor: Failed to add kqueue watch for: %@", path);
        close(fd);
    } else {
        NSLog(@"NotificationMonitor: Watching directory: %@", path);
    }
}

- (void)startKqueueMonitoring {
    _monitorSource = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_READ, _kqueue, 0,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    );

    __weak typeof(self) weakSelf = self;

    dispatch_source_set_event_handler(_monitorSource, ^{
        struct kevent event;
        struct timespec timeout = {0, 0};

        while (kevent(weakSelf.kqueue, NULL, 0, &event, 1, &timeout) > 0) {
            NSString *path = (__bridge NSString *)event.udata;
            NSLog(@"NotificationMonitor: Directory changed: %@", path);
            [weakSelf processDirectory:path];
        }
    });

    dispatch_resume(_monitorSource);
}

- (void)startPollingFallback {
    _pollTimer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    );

    dispatch_source_set_timer(_pollTimer, DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC, NSEC_PER_SEC);

    __weak typeof(self) weakSelf = self;

    dispatch_source_set_event_handler(_pollTimer, ^{
        [weakSelf scanNow];
    });

    dispatch_resume(_pollTimer);
}

#pragma mark - Scanning

- (void)scanNow {
    NSArray *streams = [self findStreamDirectories];
    for (NSString *streamPath in streams) {
        [self processDirectory:streamPath];
    }
}

- (void)processDirectory:(NSString *)dirPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;

    NSArray *files = [fm contentsOfDirectoryAtPath:dirPath error:&error];
    if (error) {
        NSLog(@"NotificationMonitor: Failed to list files in %@: %@", dirPath, error);
        return;
    }

    for (NSString *filename in files) {
        @autoreleasepool {
            NSString *filePath = [dirPath stringByAppendingPathComponent:filename];

            // Skip non-files
            BOOL isDir;
            if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && isDir) {
                continue;
            }

            // Check if it's a SEGB file
            if (![_parser isValidSEGBFile:filePath]) {
                continue;
            }

            // Get last processed offset for this file
            uint64_t lastOffset = [_fileOffsets[filePath] unsignedLongLongValue];

            // Parse new records
            NSArray<SEGBNotificationRecord *> *records = [_parser parseFile:filePath fromOffset:lastOffset];

            if (records.count > 0) {
                NSLog(@"NotificationMonitor: Found %lu new records in %@", (unsigned long)records.count, filename);

                for (SEGBNotificationRecord *record in records) {
                    [self processRecord:record];

                    // Update offset
                    if (record.fileOffset > lastOffset) {
                        lastOffset = record.fileOffset;
                    }
                }

                _fileOffsets[filePath] = @(lastOffset);
            }
        }
    }

    // Periodically save state
    static int scanCount = 0;
    if (++scanCount % 10 == 0) {
        [self saveProcessedState];
    }
}

- (void)processRecord:(SEGBNotificationRecord *)record {
    // Check if already processed
    if ([_processedGUIDs containsObject:record.guid]) {
        return;
    }

    // Mark as processed
    [_processedGUIDs addObject:record.guid];

    // Skip empty notifications
    if (record.bundleId.length == 0) {
        return;
    }

    // Skip very old notifications (older than 5 minutes)
    NSTimeInterval age = -[record.timestamp timeIntervalSinceNow];
    if (age > 300) {
        return;
    }

    NSLog(@"NotificationMonitor: Processing notification from %@ - %@",
          record.bundleId, record.title ?: @"(no title)");

    // Call callback
    if (self.matchCallback) {
        self.matchCallback([record toDictionary]);
    }
}

@end
