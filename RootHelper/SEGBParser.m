//
//  SEGBParser.m
//  Noti5 Root Helper
//
//  Parses iOS SEGB notification database files
//

#import "SEGBParser.h"
#import <sys/mman.h>
#import <sys/stat.h>
#import <fcntl.h>

// SEGB file format constants
static const char SEGB_SIGNATURE[] = "SEGB";
static const uint32_t SEGB_HEADER_SIZE = 56;
static const uint32_t SEGB_RECORD_HEADER_SIZE = 32;
static const uint32_t SEGB_STATUS_ACTIVE = 0x01000000;
static const uint32_t SEGB_STATUS_DELETED = 0x03000000;

// Field markers in notification records
static const uint8_t FIELD_GUID = 0x12;
static const uint8_t FIELD_TITLE = 0x1A;
static const uint8_t FIELD_SUBTITLE = 0x22;
static const uint8_t FIELD_BODY = 0x2A;
static const uint8_t FIELD_BUNDLE_ID_MARKER = 0x30;
static const uint8_t FIELD_BUNDLE_ID = 0x42;
static const uint8_t FIELD_APPLE_ID = 0xA2;

#pragma mark - SEGBNotificationRecord

@implementation SEGBNotificationRecord

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"guid"] = self.guid ?: @"";
    dict[@"bundleId"] = self.bundleId ?: @"";
    dict[@"title"] = self.title ?: @"";
    if (self.subtitle) dict[@"subtitle"] = self.subtitle;
    dict[@"body"] = self.body ?: @"";
    if (self.appleId) dict[@"appleId"] = self.appleId;
    dict[@"timestamp"] = @([self.timestamp timeIntervalSince1970]);
    dict[@"fileOffset"] = @(self.fileOffset);
    return dict;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<SEGBNotification: %@ from %@ - %@>",
            self.guid, self.bundleId, self.title];
}

@end

#pragma mark - SEGBParser

@implementation SEGBParser

- (BOOL)isValidSEGBFile:(NSString *)path {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return NO;

    // Check file size
    [handle seekToEndOfFile];
    unsigned long long fileSize = [handle offsetInFile];
    if (fileSize < SEGB_HEADER_SIZE) {
        [handle closeFile];
        return NO;
    }

    // Check signature at offset 52
    [handle seekToFileOffset:52];
    NSData *sigData = [handle readDataOfLength:4];
    [handle closeFile];

    if (sigData.length != 4) return NO;

    return memcmp(sigData.bytes, SEGB_SIGNATURE, 4) == 0;
}

- (nullable NSDate *)fileModificationDate:(NSString *)path {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return attrs[NSFileModificationDate];
}

- (NSArray<SEGBNotificationRecord *> *)parseFile:(NSString *)path {
    return [self parseFile:path fromOffset:SEGB_HEADER_SIZE];
}

- (NSArray<SEGBNotificationRecord *> *)parseFile:(NSString *)path fromOffset:(uint64_t)startOffset {
    NSMutableArray<SEGBNotificationRecord *> *records = [NSMutableArray array];

    // Memory-map the file for efficient parsing
    int fd = open([path fileSystemRepresentation], O_RDONLY);
    if (fd < 0) {
        NSLog(@"SEGBParser: Failed to open file: %@", path);
        return records;
    }

    struct stat st;
    if (fstat(fd, &st) < 0) {
        close(fd);
        return records;
    }

    size_t fileSize = st.st_size;
    if (fileSize < SEGB_HEADER_SIZE) {
        close(fd);
        return records;
    }

    void *mapped = mmap(NULL, fileSize, PROT_READ, MAP_PRIVATE, fd, 0);
    if (mapped == MAP_FAILED) {
        close(fd);
        return records;
    }

    const uint8_t *bytes = (const uint8_t *)mapped;

    // Validate signature
    if (memcmp(bytes + 52, SEGB_SIGNATURE, 4) != 0) {
        NSLog(@"SEGBParser: Invalid SEGB signature in %@", path);
        munmap(mapped, fileSize);
        close(fd);
        return records;
    }

    // Parse records
    uint64_t offset = MAX(startOffset, SEGB_HEADER_SIZE);

    while (offset + SEGB_RECORD_HEADER_SIZE < fileSize) {
        @autoreleasepool {
            // Read record header
            uint32_t contentSize = *(uint32_t *)(bytes + offset);
            uint32_t status = *(uint32_t *)(bytes + offset + 4);

            // Convert from little-endian
            contentSize = CFSwapInt32LittleToHost(contentSize);

            // Skip deleted or empty records
            if (status != SEGB_STATUS_ACTIVE || contentSize == 0) {
                // Move to next potential record (8-byte aligned)
                offset = ((offset + SEGB_RECORD_HEADER_SIZE + 7) & ~7);
                continue;
            }

            // Validate content size
            if (offset + SEGB_RECORD_HEADER_SIZE + contentSize > fileSize) {
                break;
            }

            // Read timestamps from header
            uint64_t timestamp1 = *(uint64_t *)(bytes + offset + 8);
            timestamp1 = CFSwapInt64LittleToHost(timestamp1);

            // Parse record content
            const uint8_t *content = bytes + offset + SEGB_RECORD_HEADER_SIZE;
            SEGBNotificationRecord *record = [self parseRecordContent:content
                                                               length:contentSize
                                                            timestamp:timestamp1
                                                           fileOffset:offset];

            if (record && record.bundleId.length > 0) {
                [records addObject:record];
            }

            // Move to next record (8-byte aligned)
            offset += SEGB_RECORD_HEADER_SIZE + contentSize;
            offset = (offset + 7) & ~7;
        }
    }

    munmap(mapped, fileSize);
    close(fd);

    return records;
}

- (SEGBNotificationRecord *)parseRecordContent:(const uint8_t *)content
                                        length:(size_t)length
                                     timestamp:(uint64_t)timestamp
                                    fileOffset:(uint64_t)fileOffset {

    SEGBNotificationRecord *record = [[SEGBNotificationRecord alloc] init];
    record.fileOffset = fileOffset;

    // Convert Apple Cocoa timestamp to NSDate
    // Apple Cocoa timestamp is seconds since Jan 1, 2001
    NSTimeInterval cocoaTimestamp = (double)timestamp / 1000000000.0;  // Convert nanoseconds
    record.timestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:cocoaTimestamp];

    size_t pos = 0;

    // Skip initial unknown bytes (typically 3-4 bytes)
    if (length > 3) pos = 3;

    while (pos < length) {
        uint8_t marker = content[pos++];

        switch (marker) {
            case FIELD_GUID: {
                // GUID is typically 36 bytes (UUID string)
                if (pos < length) {
                    uint8_t guidLen = content[pos++];
                    if (pos + guidLen <= length && guidLen > 0) {
                        record.guid = [[NSString alloc] initWithBytes:content + pos
                                                               length:guidLen
                                                             encoding:NSUTF8StringEncoding];
                        pos += guidLen;
                    }
                }
                break;
            }

            case FIELD_TITLE: {
                NSUInteger titleLen = [self readVarintFrom:content position:&pos length:length];
                if (pos + titleLen <= length && titleLen > 0) {
                    record.title = [[NSString alloc] initWithBytes:content + pos
                                                            length:titleLen
                                                          encoding:NSUTF8StringEncoding];
                    pos += titleLen;
                }
                break;
            }

            case FIELD_SUBTITLE: {
                NSUInteger subtitleLen = [self readVarintFrom:content position:&pos length:length];
                if (pos + subtitleLen <= length && subtitleLen > 0) {
                    record.subtitle = [[NSString alloc] initWithBytes:content + pos
                                                               length:subtitleLen
                                                             encoding:NSUTF8StringEncoding];
                    pos += subtitleLen;
                }
                break;
            }

            case FIELD_BODY: {
                NSUInteger bodyLen = [self readVarintFrom:content position:&pos length:length];
                if (pos + bodyLen <= length && bodyLen > 0) {
                    record.body = [[NSString alloc] initWithBytes:content + pos
                                                           length:bodyLen
                                                         encoding:NSUTF8StringEncoding];
                    pos += bodyLen;
                }
                break;
            }

            case FIELD_BUNDLE_ID_MARKER: {
                // Bundle ID region - look for 0x00 0x42 pattern
                if (pos + 1 < length && content[pos] == 0x00 && content[pos + 1] == FIELD_BUNDLE_ID) {
                    pos += 2;
                    NSUInteger bundleLen = [self readVarintFrom:content position:&pos length:length];
                    if (pos + bundleLen <= length && bundleLen > 0) {
                        record.bundleId = [[NSString alloc] initWithBytes:content + pos
                                                                   length:bundleLen
                                                                 encoding:NSUTF8StringEncoding];
                        pos += bundleLen;
                    }
                }
                break;
            }

            case FIELD_BUNDLE_ID: {
                // Direct bundle ID field
                NSUInteger bundleLen = [self readVarintFrom:content position:&pos length:length];
                if (pos + bundleLen <= length && bundleLen > 0 && !record.bundleId) {
                    record.bundleId = [[NSString alloc] initWithBytes:content + pos
                                                               length:bundleLen
                                                             encoding:NSUTF8StringEncoding];
                    pos += bundleLen;
                }
                break;
            }

            case FIELD_APPLE_ID: {
                // Apple ID / contact identifier
                if (pos < length && content[pos] == 0x01) {
                    pos++;
                    NSUInteger idLen = [self readVarintFrom:content position:&pos length:length];
                    if (pos + idLen <= length && idLen > 0) {
                        record.appleId = [[NSString alloc] initWithBytes:content + pos
                                                                  length:idLen
                                                                encoding:NSUTF8StringEncoding];
                        pos += idLen;
                    }
                }
                break;
            }

            default:
                // Skip unknown fields
                break;
        }
    }

    // Generate GUID if not found
    if (!record.guid) {
        record.guid = [[NSUUID UUID] UUIDString];
    }

    return record;
}

// Read variable-length integer (protobuf-style varint)
- (NSUInteger)readVarintFrom:(const uint8_t *)bytes position:(size_t *)pos length:(size_t)length {
    NSUInteger result = 0;
    int shift = 0;

    while (*pos < length) {
        uint8_t byte = bytes[(*pos)++];
        result |= ((NSUInteger)(byte & 0x7F)) << shift;

        if ((byte & 0x80) == 0) {
            break;
        }

        shift += 7;
        if (shift >= 64) break;  // Prevent overflow
    }

    return result;
}

@end
