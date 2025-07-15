//
//  ShrinkItArchiveItem.h
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class ShrinkItArchive;
/*
extern NSString *NUFXFileSysID;
extern NSString *NUFXFileSysInfo;
extern NSString *NUFXFileAccess;
extern NSString *NUFXStorageType;
extern NSString *NUFXArchiveWhen;
extern NSString *NUFXOptionSize;
extern NSString *NuFXGSOSFSTInfo;
 */
#define XATTR_NUFX_LENGTH	64

@interface ShrinkItArchiveItem: NSObject {
	// 10.6 or later instance vars need not be declared here
}

// File attributes which have an equivalent counterpart in OS X
@property (assign)	uint32_t		fileType;						// file_type
@property (assign)	uint32_t		auxType;						// extra_type
@property (strong)	NSDate			*creationDateTime;
@property (strong)	NSDate			*modificationDateTime;
// extended file attributes which are attached to a file on HDD
@property (assign)	uint16_t		fileSysID;						// file system identifier
@property (assign)	uint16_t		fileSysInfo;					// file separator as declared in file_sys_info
@property (assign)	uint32_t		access;							// bit flags
@property (assign)	uint16_t		storageType;					// seedling, sapling, extended
@property (strong)	NSDate			*archivedDateTime;
@property (assign)	uint16_t		optionListSize;					// read-only
@property (strong)	NSData			*optionListData;

@property (assign)	uint32_t		totalThreads;					// # of threads this item has
@property (assign)	BOOL			isDisk;
@property (copy)	NSString		*fileName;						// as stored in archive
@property (copy)	NSString		*separator;						// 0x3a, 0x2f, 0x5c
@property (assign)	uint32_t		diskCompressedSize;
@property (assign)	uint32_t		diskUncompressedSize;
@property (assign)	uint32_t		dataForkCompressedSize;
@property (assign)	uint32_t		dataForkUncompressedSize;
@property (assign)	uint32_t		resourceForkUncompressedSize;
@property (assign)	uint32_t		resourceForkCompressedSize;
@property (strong)	NSNumber		*recordIndex;
@property (weak) 	ShrinkItArchive	*owner;
/*
// these are not necessary
@property (assign)	uint16_t		diskThreadFormat;
@property (assign)	uint16_t		dataForkThreadFormat;			// are these necessary?
@property (assign)	uint16_t		resourceForkThreadFormat;		// 0x2 (old style), or 0x3 (new style)
*/
- (NSData *) contentsOfDataFork;
- (NSData *) contentsOfResourceFork;
- (NSDictionary *) attributes;
- (NSData *) extendedAttributes;
- (void) setAttributes:(NSDictionary *)fileAttr;
- (void) setExtendedAttributes:(NSData *)data;
@end
