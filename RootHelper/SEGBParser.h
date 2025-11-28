//
//  SEGBParser.h
//  NotifyFilter Root Helper
//
//  Parses iOS SEGB notification database files
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Parsed notification record
@interface SEGBNotificationRecord : NSObject

@property (nonatomic, copy) NSString *guid;
@property (nonatomic, copy) NSString *bundleId;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, copy, nullable) NSString *body;
@property (nonatomic, copy, nullable) NSString *appleId;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, assign) uint64_t fileOffset;

- (NSDictionary *)toDictionary;

@end

// SEGB file parser
@interface SEGBParser : NSObject

// Parse a single SEGB file
// Returns array of SEGBNotificationRecord objects
- (NSArray<SEGBNotificationRecord *> *)parseFile:(NSString *)path;

// Parse file starting from a specific offset (for incremental reads)
- (NSArray<SEGBNotificationRecord *> *)parseFile:(NSString *)path fromOffset:(uint64_t)offset;

// Validate SEGB file header
- (BOOL)isValidSEGBFile:(NSString *)path;

// Get file modification date
- (nullable NSDate *)fileModificationDate:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
