//
//  RuleMatcher.m
//  NotifyFilter Root Helper
//
//  Evaluates notifications against user-defined filter rules
//

#import "RuleMatcher.h"

// Match types
typedef NS_ENUM(NSInteger, MatchType) {
    MatchTypeEquals = 0,
    MatchTypeContains = 1,
    MatchTypeStartsWith = 2,
    MatchTypeEndsWith = 3,
    MatchTypeNotEquals = 4,
    MatchTypeNotContains = 5
};

// Condition fields
typedef NS_ENUM(NSInteger, ConditionField) {
    ConditionFieldSender = 0,
    ConditionFieldKeyword = 1,
    ConditionFieldApp = 2
};

// Rule actions
typedef NS_ENUM(NSInteger, RuleAction) {
    RuleActionNotify = 0,
    RuleActionBlock = 1
};

// Logic operators
typedef NS_ENUM(NSInteger, LogicOperator) {
    LogicOperatorAnd = 0,
    LogicOperatorOr = 1
};

#pragma mark - RuleCondition

@interface RuleCondition : NSObject
@property (nonatomic, assign) ConditionField field;
@property (nonatomic, assign) MatchType matchType;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, assign) BOOL isCaseSensitive;
@end

@implementation RuleCondition

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    RuleCondition *condition = [[RuleCondition alloc] init];

    NSString *fieldStr = dict[@"field"];
    if ([fieldStr isEqualToString:@"sender"]) {
        condition.field = ConditionFieldSender;
    } else if ([fieldStr isEqualToString:@"keyword"]) {
        condition.field = ConditionFieldKeyword;
    } else if ([fieldStr isEqualToString:@"app"]) {
        condition.field = ConditionFieldApp;
    }

    NSString *matchStr = dict[@"matchType"];
    if ([matchStr isEqualToString:@"equals"]) {
        condition.matchType = MatchTypeEquals;
    } else if ([matchStr isEqualToString:@"contains"]) {
        condition.matchType = MatchTypeContains;
    } else if ([matchStr isEqualToString:@"startsWith"]) {
        condition.matchType = MatchTypeStartsWith;
    } else if ([matchStr isEqualToString:@"endsWith"]) {
        condition.matchType = MatchTypeEndsWith;
    } else if ([matchStr isEqualToString:@"notEquals"]) {
        condition.matchType = MatchTypeNotEquals;
    } else if ([matchStr isEqualToString:@"notContains"]) {
        condition.matchType = MatchTypeNotContains;
    }

    condition.value = dict[@"value"] ?: @"";
    condition.isCaseSensitive = [dict[@"isCaseSensitive"] boolValue];

    return condition;
}

- (BOOL)matchesNotification:(NSDictionary *)notification {
    NSString *fieldValue = [self getFieldValue:notification];
    NSString *compareValue = self.isCaseSensitive ? fieldValue : [fieldValue lowercaseString];
    NSString *targetValue = self.isCaseSensitive ? self.value : [self.value lowercaseString];

    switch (self.matchType) {
        case MatchTypeEquals:
            return [compareValue isEqualToString:targetValue];

        case MatchTypeContains:
            return [compareValue containsString:targetValue];

        case MatchTypeStartsWith:
            return [compareValue hasPrefix:targetValue];

        case MatchTypeEndsWith:
            return [compareValue hasSuffix:targetValue];

        case MatchTypeNotEquals:
            return ![compareValue isEqualToString:targetValue];

        case MatchTypeNotContains:
            return ![compareValue containsString:targetValue];
    }

    return NO;
}

- (NSString *)getFieldValue:(NSDictionary *)notification {
    switch (self.field) {
        case ConditionFieldSender:
            return notification[@"title"] ?: @"";

        case ConditionFieldKeyword: {
            // Search in title, subtitle, and body
            NSString *title = notification[@"title"] ?: @"";
            NSString *subtitle = notification[@"subtitle"] ?: @"";
            NSString *body = notification[@"body"] ?: @"";
            return [NSString stringWithFormat:@"%@ %@ %@", title, subtitle, body];
        }

        case ConditionFieldApp:
            return notification[@"bundleId"] ?: @"";
    }

    return @"";
}

@end

#pragma mark - FilterRule

@interface FilterRule : NSObject
@property (nonatomic, copy) NSString *ruleId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, assign) RuleAction action;
@property (nonatomic, strong) NSArray<RuleCondition *> *conditions;
@property (nonatomic, assign) LogicOperator logicOperator;
@end

@implementation FilterRule

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    FilterRule *rule = [[FilterRule alloc] init];

    rule.ruleId = dict[@"id"] ?: [[NSUUID UUID] UUIDString];
    rule.name = dict[@"name"] ?: @"Unnamed Rule";
    rule.isEnabled = [dict[@"isEnabled"] boolValue];
    rule.priority = [dict[@"priority"] integerValue];

    NSString *actionStr = dict[@"action"];
    rule.action = [actionStr isEqualToString:@"block"] ? RuleActionBlock : RuleActionNotify;

    NSString *logicStr = dict[@"logicOperator"];
    rule.logicOperator = [logicStr isEqualToString:@"or"] ? LogicOperatorOr : LogicOperatorAnd;

    // Parse conditions
    NSMutableArray *conditions = [NSMutableArray array];
    NSArray *conditionDicts = dict[@"conditions"];
    for (NSDictionary *condDict in conditionDicts) {
        RuleCondition *condition = [RuleCondition fromDictionary:condDict];
        [conditions addObject:condition];
    }
    rule.conditions = conditions;

    return rule;
}

- (BOOL)matchesNotification:(NSDictionary *)notification {
    if (!self.isEnabled || self.conditions.count == 0) {
        return NO;
    }

    NSMutableArray<NSNumber *> *results = [NSMutableArray array];
    for (RuleCondition *condition in self.conditions) {
        [results addObject:@([condition matchesNotification:notification])];
    }

    switch (self.logicOperator) {
        case LogicOperatorAnd: {
            // All conditions must match
            for (NSNumber *result in results) {
                if (![result boolValue]) return NO;
            }
            return YES;
        }

        case LogicOperatorOr: {
            // Any condition must match
            for (NSNumber *result in results) {
                if ([result boolValue]) return YES;
            }
            return NO;
        }
    }

    return NO;
}

@end

#pragma mark - RuleMatcher

@interface RuleMatcher ()
@property (nonatomic, copy) NSString *rulesPath;
@property (nonatomic, strong) NSArray<FilterRule *> *rules;
@property (nonatomic, assign) BOOL whitelistMode;
@end

@implementation RuleMatcher

- (instancetype)initWithRulesPath:(NSString *)rulesPath {
    self = [super init];
    if (self) {
        _rulesPath = rulesPath;
        _rules = @[];
        _whitelistMode = YES;  // Default to whitelist mode
        [self reloadRules];
    }
    return self;
}

- (BOOL)isWhitelistMode {
    return _whitelistMode;
}

- (NSUInteger)ruleCount {
    return _rules.count;
}

- (void)reloadRules {
    NSLog(@"RuleMatcher: Loading rules from %@", self.rulesPath);

    NSData *data = [NSData dataWithContentsOfFile:self.rulesPath];
    if (!data) {
        NSLog(@"RuleMatcher: No rules file found");
        _rules = @[];
        return;
    }

    NSError *error;
    NSArray *ruleDicts = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

    if (error || ![ruleDicts isKindOfClass:[NSArray class]]) {
        NSLog(@"RuleMatcher: Failed to parse rules: %@", error);
        _rules = @[];
        return;
    }

    NSMutableArray<FilterRule *> *loadedRules = [NSMutableArray array];

    for (NSDictionary *dict in ruleDicts) {
        if ([dict isKindOfClass:[NSDictionary class]]) {
            FilterRule *rule = [FilterRule fromDictionary:dict];
            [loadedRules addObject:rule];
        }
    }

    // Sort by priority
    [loadedRules sortUsingComparator:^NSComparisonResult(FilterRule *a, FilterRule *b) {
        return [@(a.priority) compare:@(b.priority)];
    }];

    _rules = loadedRules;

    NSLog(@"RuleMatcher: Loaded %lu rules", (unsigned long)_rules.count);
}

- (nullable NSString *)evaluateNotification:(NSDictionary *)notification {
    // Find first matching rule
    for (FilterRule *rule in self.rules) {
        if ([rule matchesNotification:notification]) {
            NSLog(@"RuleMatcher: Notification matched rule '%@'", rule.name);

            // In whitelist mode, only "notify" rules trigger alerts
            // In blacklist mode, only "block" rules suppress alerts
            if (rule.action == RuleActionNotify) {
                return rule.name;
            } else {
                // Block action - don't notify
                return nil;
            }
        }
    }

    // No rule matched
    if (self.whitelistMode) {
        // Whitelist mode: no match = block
        NSLog(@"RuleMatcher: No rule matched (whitelist mode - blocking)");
        return nil;
    } else {
        // Blacklist mode: no match = allow
        NSLog(@"RuleMatcher: No rule matched (blacklist mode - allowing)");
        return @"Default (No matching rule)";
    }
}

@end
