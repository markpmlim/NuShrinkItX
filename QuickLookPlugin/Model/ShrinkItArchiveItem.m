//
//  ShrinkItArchiveItem.m
//  QuickLookSHK
//
//  Created by mark lim on 5/20/15.
//  Copyright 2015 IncrementalInnovation. All rights reserved.
//

#import "ShrinkItArchiveItem.h"

// Note: instance variables may not be placed in categories.
// Use a class extension to declare the instance variables.
@interface ShrinkItArchiveItem() {
    // The names of these instance variables are specified in FTN $E0/$8002
    // Fixed part of ShrinkIt archive item record.
    u_int32_t _nufile_id;           // +00 better to a u_int32_t instead
    u_int16_t _header_crc;          // +04
    u_int16_t _attrib_count;        // +06 - Take note!!!
    u_int16_t _version_number;      // +08
    u_int32_t _total_threads;       // +10 - Take note!!!
    u_int16_t _file_sys_id;         // +14
    u_int16_t _file_sys_info;       // +16
    u_int32_t _access;              // +18
    u_int32_t _file_type;           // +22
    u_int32_t _extra_type;          // +26
    u_int16_t _storage_type;        // +30 - aka file_sys_block_size
    NSDate *_create_when;           // +32
    NSDate *_mod_when;              // +40
    NSDate *_archive_when;          // +48
    
    // These instance variables are specific to QuickLookSHK
    NSString *_fileName;
    NSString *_fileType;
    NSString *_creationDateTime;
    NSString *_modificationDateTime;
    NSString *_totalSize;

}
@end

// The main implementation.
@implementation ShrinkItArchiveItem


- (instancetype) init {
	self = [super init];
	if (self) {
		_nufile_id = 0xD846F54E;	// Stored in memory as Little Endian format
        // The rest of the properties will be set later.
	}
	return self;
}

- (NSComparisonResult) compare:(ShrinkItArchiveItem *)otherItem {
    return [self.fileName localizedCaseInsensitiveCompare:otherItem.fileName];
}

@end
