//
//  SharedTypes.h
//  NotifyFilter
//
//  Shared constants and types between main app and root helper
//

#ifndef SharedTypes_h
#define SharedTypes_h

// Darwin notification names for IPC
#define NOTIFY_FILTER_MATCHED       "com.notifyfilter.matched"
#define NOTIFY_FILTER_RULES_UPDATED "com.notifyfilter.rules.updated"
#define NOTIFY_FILTER_START         "com.notifyfilter.start"
#define NOTIFY_FILTER_STOP          "com.notifyfilter.stop"
#define NOTIFY_FILTER_HEARTBEAT     "com.notifyfilter.heartbeat"

// File paths
#define NOTIFICATION_DB_PATH        "/var/mobile/Library/DuetExpertCenter/streams/userNotificationEvents/local"
#define SHARED_DATA_PATH            "/var/mobile/Library/NotifyFilter"
#define RULES_FILE_PATH             "/var/mobile/Library/NotifyFilter/rules.json"
#define MATCHED_FILE_PATH           "/var/mobile/Library/NotifyFilter/matched.json"
#define PROCESSED_FILE_PATH         "/var/mobile/Library/NotifyFilter/processed.json"
#define PID_FILE_PATH               "/var/tmp/notifyfilter.pid"
#define HEARTBEAT_FILE_PATH         "/var/tmp/notifyfilter.heartbeat"

// SEGB file format markers
#define SEGB_SIGNATURE              "SEGB"
#define SEGB_HEADER_SIZE            56
#define SEGB_RECORD_HEADER_SIZE     32

// SEGB field markers
#define SEGB_FIELD_GUID             0x12
#define SEGB_FIELD_TITLE            0x1A
#define SEGB_FIELD_SUBTITLE         0x22
#define SEGB_FIELD_BODY             0x2A
#define SEGB_FIELD_BUNDLE_ID        0x42
#define SEGB_FIELD_APPLE_ID         0xA2

// Record status
#define SEGB_STATUS_ACTIVE          0x01000000
#define SEGB_STATUS_DELETED         0x03000000

// Helper commands
typedef enum {
    HelperCommandStart = 1,
    HelperCommandStop = 2,
    HelperCommandStatus = 3,
    HelperCommandReloadRules = 4
} HelperCommand;

// Match types for rules
typedef enum {
    MatchTypeEquals = 0,
    MatchTypeContains = 1,
    MatchTypeStartsWith = 2,
    MatchTypeEndsWith = 3,
    MatchTypeNotEquals = 4,
    MatchTypeNotContains = 5
} MatchType;

// Condition fields
typedef enum {
    ConditionFieldSender = 0,
    ConditionFieldKeyword = 1,
    ConditionFieldApp = 2
} ConditionField;

// Rule actions
typedef enum {
    RuleActionNotify = 0,
    RuleActionBlock = 1
} RuleAction;

// Logic operators
typedef enum {
    LogicOperatorAnd = 0,
    LogicOperatorOr = 1
} LogicOperator;

#endif /* SharedTypes_h */
