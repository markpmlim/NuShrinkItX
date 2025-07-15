//
//  ShrinkItArchiveItem.h
//  QuickLookSHK
//
//  Created by mark lim on 5/20/15.
//  Copyright 2015 IncrementalInnovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "UserDefines.h"

@interface ShrinkItArchiveItem: NSObject
/*
 An instance of ShrinkItArchive needs access to these properties.
 The instance variables are accessed through these properties.
 */
@property (assign) u_int32_t nufile_id;
@property (assign) u_int16_t header_crc;
@property (assign) u_int16_t attrib_count;
@property (assign) u_int16_t version_number;
@property (assign) u_int32_t total_threads;
@property (assign) u_int16_t file_sys_id;
@property (assign) u_int16_t file_sys_info;
@property (assign) u_int32_t access;
@property (assign) u_int32_t file_type;
@property (assign) u_int32_t extra_type;
@property (assign) u_int16_t storage_type;
@property (assign) CompressedDataDescriptor dataDescriptor;
@property (assign) CompressedDataDescriptor resourceDescriptor;

// Properties are atomic by default.
@property (strong) NSDate *create_when;
@property (strong) NSDate *mod_when;
@property (strong) NSDate *archive_when;
// The following properties may be used by SpotlightSHK.
@property (strong) NSString *fileName;
@property (strong) NSString *fileType;
@property (strong) NSString *creationDateTime;
@property (strong) NSString *modificationDateTime;
@property (strong) NSString *totalSize;

@end
