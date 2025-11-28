//
//  RuleMatcher.h
//  NotifyFilter Root Helper
//
//  Evaluates notifications against user-defined filter rules
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RuleMatcher : NSObject

// Initialize with path to rules JSON file
- (instancetype)initWithRulesPath:(NSString *)rulesPath;

// Reload rules from file
- (void)reloadRules;

// Evaluate a notification against all rules
// Returns the name of the matching rule, or nil if no match/should block
- (nullable NSString *)evaluateNotification:(NSDictionary *)notification;

// Global filter mode (whitelist/blacklist)
@property (nonatomic, readonly) BOOL isWhitelistMode;

// Number of loaded rules
@property (nonatomic, readonly) NSUInteger ruleCount;

@end

NS_ASSUME_NONNULL_END
