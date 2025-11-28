//
//  NotificationMonitor.h
//  NotifyFilter Root Helper
//
//  Monitors notification database directory for changes using kqueue
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^NotificationMatchCallback)(NSDictionary *notification);

@interface NotificationMonitor : NSObject

// Callback when a notification matches rules
@property (nonatomic, copy, nullable) NotificationMatchCallback matchCallback;

// Path to notification database
@property (nonatomic, readonly) NSString *databasePath;

// Is currently monitoring
@property (nonatomic, readonly) BOOL isMonitoring;

// Start monitoring for new notifications
- (void)startMonitoring;

// Stop monitoring
- (void)stopMonitoring;

// Manually scan for new notifications (for testing)
- (void)scanNow;

@end

NS_ASSUME_NONNULL_END
