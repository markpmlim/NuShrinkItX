//
//  ShrinkItArchive.m
//  QuickLookSHK
//
//  Created by mark lim on 5/20/15.
//  Copyright 2015 IncrementalInnovation. All rights reserved.
//

#import "ShrinkItArchive.h"
#import "ShrinkItArchiveItem.h"
#import "SHTree.h"
#import "SHTreeObject.h"
#import "SHTreeRecord.h"
#include <time.h>
#include <UserDefines.h>

@interface ShrinkItArchive () {
    // Instance variables backing the properties declared in ShrinkItArchive.h
    NSData *_dataContents;
    NSMutableArray *_items;
    NSMutableArray *_treeTableList;
}


@end

@implementation ShrinkItArchive


typedef struct {
    u_int8_t nufile_id[6];                  // +00
    u_int16_t master_crc;                   // +06
    u_int32_t total_records;                // +08
    GSDateTimeRec archive_create_when;      // +12
    GSDateTimeRec archive_mod_when;         // +20
    u_int16_t master_version;               // +28
    u_int32_t master_eof;                   // +38
} MasterHeaderType;

MasterHeaderType masterHeaderRecord;

// Variables specific to QuickLookSHK
ShrinkItFileKind        kind;
NSUInteger              headerOffset;
NSUInteger              endOfDataMark;    // # of bytes of data - sentinel


const static u_int8_t binary2ID[] = {0x0A, 0x47, 0x4C};
const static u_int8_t magicNumberSHK[] = {0x4E, 0xF5, 0x46, 0xE9, 0x6C, 0xE5};
const static u_int8_t magicNumberSEA[] = {0x4E, 0xF5, 0x46, 0xE9, 0x6C, 0xE5, 0x4E, 0xF5, 0x46, 0xD8};
const static NSUInteger kNuMasterRecordSize = 48;
const static NSUInteger kMinNuRecordSize = 56;
const static NSUInteger kMinimumFileSize = 56 + 48;
const static NSUInteger kBinary2HeaderSize = 128;
const static NSUInteger kNuSeaFileOffset = 0x2ee5;

-(id) initWithPath:(NSString *)pathToFile {
	self = [super init];
	if (self != nil) {
		@try {
            self.dataContents = [NSData dataWithContentsOfFile: pathToFile];
		}
		@catch (NSException * e)
		{
			//NSLog(@"Problem reading file:%@: %@", [e name], [e reason]);
			//dataContents = nil;		// dataContents would already be nil
			return nil;
		}

		self.items = [[NSMutableArray alloc] init];			// We own this
		// Minimum size of a NuFx archive = size of 1 kNuMasterRecordSize + size of 1 NuRecord?
		if ([self.dataContents length] < (kMinNuRecordSize + kNuMasterRecordSize)) {
			self.dataContents = nil;
			self.items = nil;
			return nil;
		}
		else {
			endOfDataMark = [self.dataContents length];
			headerOffset = 0;
			if (![self masterHeaderAtHeaderOffset:&headerOffset]) {
				self.dataContents = nil;
				self.items = nil;
				return nil;
			}
			//NSLog(@"data offset of archive's Master Record:0x%0x", headerOffset);
		}
	}
	return self;
}


// Method to check for shk archive; it searches the first 128+48 bytes
// for a NuMasterRecord signature. For a plain SHK, it's at 0x00;
// for an SHK with BNY header, it should be at 128 (0x80)
-(BOOL) isShkOrShkInBNY:(NSUInteger *)dataOffset {
	BOOL success = NO;
	kind = kIsShkWithBny;			// assume this is the case

	NSRange range;
	NSData *signatureSHK = [NSData dataWithBytes:(const void *)magicNumberSHK
										  length:6];
	NSUInteger currOffset = *dataOffset;

	// stop search if we could get nufile_id when file offset >= stopOffset
	NSUInteger stopOffset = endOfDataMark - 6;
	if (stopOffset > (kBinary2HeaderSize + kNuMasterRecordSize)) {
		stopOffset = kBinary2HeaderSize + kNuMasterRecordSize;
	}

	NSData *signature = nil;
	do {
		range  = NSMakeRange(currOffset, 6);
        [self.dataContents getBytes:&masterHeaderRecord.nufile_id
							  range:range];
		signature = [NSData dataWithBytes:(const void *)masterHeaderRecord.nufile_id
								   length:6];
		if ([signature isEqualToData:signatureSHK]) {
			if (currOffset == 0)
				kind = kIsPlainShk;
			success = YES;
			break;
		}
		currOffset++;
	} while (currOffset < stopOffset);
	*dataOffset = currOffset;	// just in case it's a ShkInBNY file
	return success;
}

/*
 Identify if the file has a binary wrapper.
 */
-(BOOL) isBinaryII {
	NSRange range = NSMakeRange(0, 3);
	NSData *binIISignature = [NSData dataWithBytes:(const void *)binary2ID
											length:3];
	u_int8_t signII[3];
	[self.dataContents getBytes:signII
						  range:range];
		NSData *signature = [NSData dataWithBytes:(const void *)signII
										   length:3];
	if ([signature isEqualToData:binIISignature]) {
		return YES;
	}
	else {
		return NO;
	}

}

// Method to check for self-extracting archive
// It searches the first (dataOffset + 48) bytes for a NuMasterRecord +
// followed by a NuRecord signature.
// For a plain SEA archive, it's at 0x38f; for an SEA with BNY header
//  it should be at 0x38f + 0x80 = 0x40f.
-(BOOL) isSeaOrSeaInBNY:(NSUInteger *)dataOffset {
	kind = kIsSeaWithBny;
	BOOL success = NO;
	NSRange range;
	
	NSUInteger currOffset = *dataOffset;	// start search from here
	//NSLog(@"Start searching from:0x%0x", currOffset);
	NSData *signatureSEA = [NSData dataWithBytes:(const void *)magicNumberSEA
										  length:10];
	NSUInteger stopOffset = endOfDataMark - 10;
	do {
		range = NSMakeRange(currOffset, 10);
		u_int8_t signSEA[10];
		[self.dataContents getBytes:signSEA
							  range:range];
		NSData *signature2 = nil;
		signature2 = [NSData dataWithBytes:(const void *)signSEA
									length:10];
		if ([signature2 isEqualToData:signatureSEA]) {
			//NSLog(@"SEA");
			if (currOffset == 0x38f)
				kind = kIsPlainSea;
			success = YES;
			break;
		}
		currOffset++;
	} while (currOffset < stopOffset);
	// search for NuMaster Record should start from 0x2ee5...
	//*dataOffset = currOffset + 10;	// ... but we are playing safe
	*dataOffset = 0x2ee5;
	return success;
}

/*
 Read in the master header.
 For a plain SHK file, header offset is @ 0x0000.
 For a BXY file, the header offset is @ 0x0080.
 For a SEA file, the header offset is @ 0x2ee5.
 For a BSE file, the header offset is @ 0x2ee5+0x80 = 0x2f65.
 Inspection of SEA and BSE files indicates there is a 10-byte signature
 consisting of a NuArchive master signature followed by a NuRecord item
 signature at the above respective locations of such files.
 */
-(BOOL) masterHeaderAtHeaderOffset:(NSUInteger *)dataOffset {
	BOOL success = NO;
	NSData *signature = nil;
	NSRange range;
	NSUInteger currOffset;
	NSData *signatureSHK;
	if ((*dataOffset + kNuMasterRecordSize) >= endOfDataMark) {
		//NSLog(@"File is too small");
		goto bailOut;
	}
/*
	if ([self isBinaryII]) {
		NSLog(@"File has a BinaryII wrapper");
		// Not used
	}
 */
	signatureSHK = [NSData dataWithBytes:(const void *)magicNumberSHK
								  length:6];
	currOffset = *dataOffset;
	if ([self isShkOrShkInBNY:&currOffset]) {
		//NSLog(@"SHK or Binary SHK");
		*dataOffset = currOffset;		// will be 0x80 if SHK in BNY
	}
	else {
		// We continue the search from where it stops:128+4
		// Alternatively: we can start the search @ 0x38f
		//currOffset = 0x38f;
		if ([self isSeaOrSeaInBNY:&currOffset]) {
			//NSLog(@"SEA or Binary SEA");
			*dataOffset = currOffset;	// 0x2ee5 or 0x2ee5+0x80
		}
		else {
			goto bailOut;
		}
	}
	//NSLog(@"Searching for the Master Record from:0x%0x", currOffset);
	// Done: Add a loop to search for a MasterRecord signature; record it so that
	//  the program may start searching NuRecords from this offset + 48
	NSUInteger stopOffset = endOfDataMark - 6;
	if (currOffset > stopOffset) {
		// Play safe here in case both searches
		//NSLog(@"Can't find master header:0x%0x", currOffset);
		goto bailOut;
	}

	// For plain SHK files or SHK files with Binary II wrapper, there shouldn't be
	// any further search. For SEA or SEA with Binary II wrapper, search will
	// continue until it locates  the NuMaster Record header.
	u_int8_t inputBuf[8];				// up to 8 bytes
	do {
		range  = NSMakeRange(currOffset, 6);
		[self.dataContents getBytes:&masterHeaderRecord.nufile_id
							  range:range];
		signature = [NSData dataWithBytes:(const void *)masterHeaderRecord.nufile_id
								   length:6];
		if ([signature isEqualToData:signatureSHK]) {
			success = YES;
			break;
		}
		currOffset++;
	} while (currOffset < stopOffset);

	// We assume the information after the magic number is valid.
	// todo: make it more robust by adding exception handling code.
	if ([signature isEqualToData:signatureSHK]) {
		currOffset += 6;
		range  = NSMakeRange(currOffset, 2);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		masterHeaderRecord.master_crc = inputBuf[0] + (inputBuf[1] << 8);
		currOffset += 2;
		range = NSMakeRange(currOffset,4);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		masterHeaderRecord.total_records = inputBuf[0] + (inputBuf[1] << 8) + (inputBuf[2] << 16) + (inputBuf[3] << 24);
		////NSLog(@"%d", total_records);
		currOffset += 4;
		range = NSMakeRange(currOffset, 8);
		[self.dataContents getBytes:&masterHeaderRecord.archive_create_when
							  range:range];
		currOffset += 8;
		range = NSMakeRange(currOffset, 8);
		[self.dataContents getBytes:&masterHeaderRecord.archive_mod_when
							  range:range];
		currOffset += 8;
		range = NSMakeRange(currOffset, 2);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		masterHeaderRecord.master_version = inputBuf[0] + (inputBuf[1] << 8);
		range = NSMakeRange(38,4);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		masterHeaderRecord.master_eof = inputBuf[0] + (inputBuf[1] << 8) + (inputBuf[2] << 16) + (inputBuf[3] << 24);
		success = YES;
	}
bailOut:
	return success;
}

/*
 Alternative: Makes use of the fact that a SEA/SEA in BNY file has a 10-byte
  signature consisting of a Master Record signature followed imediately by
  a NuRecord signature. When the method encounters a Master Record signature,
  it checks further if it's actually part of the 10-byte signature. If yes,
  we have a SEA/SEA in BNY file.
*/
 -(BOOL) masterHeaderAtHeaderOffset2:(NSUInteger *)dataOffset {
	NSData *signatureSHK = [NSData dataWithBytes:(const void *)magicNumberSHK
										  length:6];
	NSData *signatureSEA = [NSData dataWithBytes:(const void *)magicNumberSEA
										  length:10];
	BOOL success = NO;
	NSRange range;
	NSData *signature = nil;
	NSUInteger stopOffset = endOfDataMark - 6;
	NSUInteger currOffset = *dataOffset;
	do {
		range  = NSMakeRange(currOffset, 6);
		[self.dataContents getBytes:(void *)masterHeaderRecord.nufile_id
							  range:range];
		signature = [NSData dataWithBytes:(const void *)masterHeaderRecord.nufile_id
								   length:6];
		if ([signature isEqualToData:signatureSHK]) {
			// if next 4 bytes are not 0xD846F54E, then we have the correct master record header
			range  = NSMakeRange(currOffset, 10);
			u_int8_t signSEA[10];
			[self.dataContents getBytes:(void *)signSEA
								  range:range];
			NSData *signature2 = [NSData dataWithBytes:(const void *)signSEA
												length:10];
			if (![signature2 isEqualToData:signatureSEA]) {
				// We have a Master Record signature w/o NuRecord signature;
				//  this is the one we want. Proceed to parse it.
				break;
			}
			// We have the signature of a self-extracting archive, continue
			//  searching for the second Master Record signature.
			currOffset = 0x2ee5 -1;		// search from this location
		}
		currOffset++;
	} while (currOffset < stopOffset);
	*dataOffset = currOffset;
	//NSLog(@"Master Record signature is at:0x%0x", currOffset);
	u_int8_t inputBuf[8];				// up to 8 bytes
	do {
		range  = NSMakeRange(currOffset, 6);
		[self.dataContents getBytes:&masterHeaderRecord.nufile_id
							  range:range];
		signature = [NSData dataWithBytes:(const void *)masterHeaderRecord.nufile_id
								   length:6];
		if ([signature isEqualToData:signatureSHK]) {
			success = YES;
			break;
		}
		currOffset++;
	} while (currOffset < stopOffset);

	if ([signature isEqualToData:signatureSHK]) {
		currOffset += 6;
		range  = NSMakeRange(currOffset, 2);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		masterHeaderRecord.master_crc = inputBuf[0] + (inputBuf[1] << 8);
		currOffset += 2;
		range = NSMakeRange(currOffset, 4);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		masterHeaderRecord.total_records = inputBuf[0] + (inputBuf[1] << 8) + (inputBuf[2] << 16) + (inputBuf[3] << 24);
		////NSLog(@"%d", total_records);
		currOffset += 4;
		range = NSMakeRange(currOffset, 8);
		[self.dataContents getBytes:&masterHeaderRecord.archive_create_when
							  range:range];
		currOffset += 8;
		range = NSMakeRange(currOffset, 8);
		[self.dataContents getBytes:&masterHeaderRecord.archive_mod_when
							  range:range];
		currOffset += 8;
		range = NSMakeRange(currOffset, 2);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		masterHeaderRecord.master_version = inputBuf[0] + (inputBuf[1] << 8);
		range = NSMakeRange(38,4);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		masterHeaderRecord.master_eof = inputBuf[0] + (inputBuf[1] << 8) + (inputBuf[2] << 16) + (inputBuf[3] << 24);
		success = YES;
	}
bailOut:
	return success;
}

#pragma mark helper functions
time_t gsDateTimeToUnixTime(GSDateTimeRec gsDateTime) {
	struct tm tmRec;

	u_int16_t year = gsDateTime.year;
	if (year < 40) {
		year += 100;
	}
	tmRec.tm_sec = gsDateTime.second;
	tmRec.tm_min = gsDateTime.minute;
	tmRec.tm_hour = gsDateTime.hour;
	tmRec.tm_mday = gsDateTime.day + 1;
	tmRec.tm_mon = gsDateTime.month;
	tmRec.tm_year = year;
	tmRec.tm_wday = 0;
	tmRec.tm_yday = 0;
	tmRec.tm_isdst = -1;
	tmRec.tm_gmtoff = 0;
	//tmRec.tm_zone = nil;
	
	time_t when = mktime(&tmRec);
	if (when == -1) {
		when = 0;
	}
	return when;
}

// Look up the string translation of a ProDOS file type
- (NSString *) stringWithFileType:(unsigned int) fType {
	NSString *retStr=nil;
	
	if (fType < NELEM(gFileTypeNames)) {
		retStr = [NSString stringWithCString:gFileTypeNames[fType]
									encoding:NSUTF8StringEncoding];
	}
	else {
		retStr = [NSString stringWithCString:kUnknownTypeStr
									encoding:NSUTF8StringEncoding];
	}
	return retStr;
}

- (NSString *) fileSize:(u_int32_t)size {
	NSString *sizeStr;
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[numberFormatter setMaximumFractionDigits:1];
	
	double sz;
	if (size < 1024) {
		sizeStr = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:size]];
		sizeStr = [NSString stringWithFormat:@"%@ bytes", sizeStr];
	}
	else if (size >= 1024 && size < 1048576) {
		sz = (double)size/1024;
		sizeStr = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:sz]];
		sizeStr = [NSString stringWithFormat:@"%@ KB", sizeStr];
	}
	else if (size >= 1048576 && size < 1073741824) {
		sz = (double)size/1048576;
		sizeStr = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:sz]];
		sizeStr = [NSString stringWithFormat:@"%@ MB", sizeStr];
	}
	else {
		sz = (double)size/1073741824;
		sizeStr = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:sz]];
		sizeStr = [NSString stringWithFormat:@"%@ GB", sizeStr];
	}
	return sizeStr;
}

// Todo: To make this more robust, we can code each getBytes:range: method
// within an Objective-C @try-@catch exception handler.
// The instance of ShrinkItArchiveItem returned should be set to autorelease.
-(ShrinkItArchiveItem *) shrinkItItemHeaderAtOffset:(NSUInteger *)dataOffset {
	ShrinkItArchiveItem *item = nil;
	u_int8_t inputBuf[4];
	NSUInteger currOffset = *dataOffset;
	NSRange range;
	u_int32_t signature = 0;
	u_int32_t total_Size = 0;
	// Search for a ShrinkItArchiveItem signature
	do {
		range = NSMakeRange(currOffset, 4);
		@try {
			[self.dataContents getBytes:&inputBuf
								  range:range];
		}
		@catch (NSException * e) {
			//NSLog(@"Problem extracting item's signature:%@", e);
			goto bailOut;
		}

		signature = inputBuf[0] + (inputBuf[1] << 8) + (inputBuf[2] << 16) + (inputBuf[3] << 24);
		if (signature == 0xD846F54E) {
			//NSLog(@"Item's file position:0x%0x", currOffset);
			break;
		}
		currOffset++;
	} while (currOffset < endOfDataMark);

	*dataOffset = currOffset;			// Just in case
	// Checks if we have a fixed part (up to option_size)
	if (*dataOffset + kMinNuRecordSize > endOfDataMark) {
		//NSLog(@"Problem extracting shrinkItItem's contents");
		goto bailOut;
	}

	// we assume the information for each archive item is valid
	if (signature == 0xD846F54E) {
		item = [[ShrinkItArchiveItem alloc] init];
		item.nufile_id = signature;
		currOffset += 4;
		range = NSMakeRange(currOffset, 2);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		item.header_crc = inputBuf[0] + (inputBuf[1] << 8);
		//NSLog(@"header_crc:0x%0x", item.header_crc);
		currOffset += 2;
		range = NSMakeRange(currOffset, 2);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		item.attrib_count = inputBuf[0] + (inputBuf[1] << 8);
		//NSLog(@"attrib_count:0x%0x", item.attrib_count);
		if ((*dataOffset + item.attrib_count - 2) >= endOfDataMark) {
			//NSLog(@"The filename_length may not be available");
			item = nil;
			goto bailOut;
		}
		currOffset += 2;
		range = NSMakeRange(currOffset, 2);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		item.version_number = inputBuf[0] + (inputBuf[1] << 8);
		//NSLog(@"version_number:%d", item.version_number);

		currOffset += 2;
		range = NSMakeRange(currOffset, 4);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		item.total_threads = inputBuf[0] + (inputBuf[1] << 8) + (inputBuf[2] << 16) + (inputBuf[3] << 24);
		//NSLog(@"total_threads:%d", item.total_threads);
		
		currOffset += 4;
		range = NSMakeRange(currOffset, 2);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		item.file_sys_id = inputBuf[0] + (inputBuf[1] << 8);
		//NSLog(@"file_sys_id:%d", item.file_sys_id);
		
		currOffset += 2;
		range = NSMakeRange(currOffset, 2);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		item.file_sys_info = inputBuf[0] + (inputBuf[1] << 8);
		//NSLog(@"file_sys_info:0x%0x", item.file_sys_info);

		currOffset += 2;
		range = NSMakeRange(currOffset, 4);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		item.access = inputBuf[0] + (inputBuf[1] << 8) + (inputBuf[2] << 16) + (inputBuf[3] << 24);
		//NSLog(@"access:0x%0x", item.access);

		currOffset += 4;
		range = NSMakeRange(currOffset, 4);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		item.file_type = inputBuf[0] + (inputBuf[1] << 8) + (inputBuf[2] << 16) + (inputBuf[3] << 24);
		//NSLog(@"file_type:0x%0x", item.file_type);
		item.fileType = [self stringWithFileType: item.file_type];

		currOffset += 4;
		range = NSMakeRange(currOffset, 4);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		item.extra_type = inputBuf[0] + (inputBuf[1] << 8) + (inputBuf[2] << 16) + (inputBuf[3] << 24);
		//NSLog(@"extra_type:0x%0x", item.extra_type);

		currOffset += 4;
		range = NSMakeRange(currOffset, 2);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		item.storage_type = inputBuf[0] + (inputBuf[1] << 8);
		//NSLog(@"Storage Type:0x%0x", item.storage_type);

		//=========
		NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
		[outputFormatter setDateFormat:@"dd MMM YYYY"];

		GSDateTimeRec inputDateTimeRec;
		currOffset += 2;
		range = NSMakeRange(currOffset, 8);
		[self.dataContents getBytes:&inputDateTimeRec
							  range:range];
		time_t t = gsDateTimeToUnixTime(inputDateTimeRec);
		NSDate *workDate = [NSDate dateWithTimeIntervalSince1970:t];
		item.creationDateTime = [outputFormatter stringFromDate:workDate];
		NSDate *date = [NSDate dateWithTimeIntervalSince1970: t];
		item.create_when = date;
		//NSLog(@"create_when:%@", item.create_when);

		currOffset += 8;
		range = NSMakeRange(currOffset, 8);
		[self.dataContents getBytes:&inputDateTimeRec
							  range:range];
		t = gsDateTimeToUnixTime(inputDateTimeRec);
		date = [NSDate dateWithTimeIntervalSince1970: t];
		item.modificationDateTime = [outputFormatter stringFromDate:date];
		item.mod_when = date;
		//NSLog(@"mod_when:%@", item.mod_when);

		currOffset += 8;
		range = NSMakeRange(currOffset, 8);
		[self.dataContents getBytes:&inputDateTimeRec
							  range:range];
		t = gsDateTimeToUnixTime(inputDateTimeRec);
		date = [NSDate dateWithTimeIntervalSince1970: t];
		item.archive_when = date;
		//NSLog(@"archive_when:%@", item.archive_when);
		// Variable part of the record starts here.
		currOffset += 8;
		// attrib_count is calculated as a relative offset:
		// 56 + 2(option_size) + sizeof(option_list) + 2(filename_length)
		//NSLog(@"file offset to option_size word:0x%0x", currOffset);
		//NSLog(@"size of gsos option list:%d", *dataOffset + item.attrib_count - 2 - currOffset - 2);
		if (item.version_number > 0) {
			range = NSMakeRange(currOffset, 2);
			[self.dataContents getBytes:&inputBuf
								  range:range];
			u_int16_t option_size = inputBuf[0] + (inputBuf[1] << 8);
			currOffset += 2;
			if (option_size > 0) {
				// We have an GS/OS option list - min 0 max 40 (pg 336 GS/OS 6.0 ref)
				//NSLog(@"The GS/OS option list has a reported size of %d", option_size);
				// We don't need to adjust currOffset; it will be calculated using attrib_count.
				// The possibility of the option_size does not match the size of the
				// option_list cannot be discounted. We must calculate it ourselves.
				// For AppleShare, there 3 fields viz a 32-byte Mac FinderInfo block,
				// a 4-byte parentID and a 4-byte access rights.
				// For HFS, there 2 fields viz a 32-byte Mac FinderInfo block and 4-byte parentID.
				// For GS/OS, there is 1 field (if any) viz a 32-byte Mac FinderInfo block.
				// Todo: Extract (at least 32) option_bytes or we can choose to ignore them.
				
				// ===== ignore =====
			}
		}
		// Calculate the next field which is the filename_length.
		currOffset = *dataOffset + item.attrib_count - 2;
		//NSLog(@"file offset after gsos option list:0x%0x", currOffset);
		range = NSMakeRange(currOffset, 2);
		[self.dataContents getBytes:&inputBuf
							  range:range];
		u_int16_t filename_length = inputBuf[0] + (inputBuf[1] << 8);
		currOffset += 2;
		if (filename_length > 0) {
			// We have a filename and should be found at the relative offset "attrib_count"
			////NSLog(@"There is a filename in the variable part")
			char *strBuf = malloc(filename_length);
			range = NSMakeRange(currOffset, filename_length);
			@try {
				[self.dataContents getBytes:strBuf
									  range:range];
			}
			@catch (NSException * e) {
				//NSLog(@"Problem getting filename:%@", e);
				free(strBuf);
				item = nil;
				goto bailOut;
			}
			// high and low ASCII values are valid
			item.fileName = [[NSString alloc] initWithBytes:strBuf
													 length:filename_length
												   encoding:NSUTF8StringEncoding];
			//NSLog(@"Filename:%@", item.fileName);
			free(strBuf);
			currOffset += filename_length;
		}
		// startOfItemThreads = Beginning of the thread records
		NSUInteger startOfItemThreads = *dataOffset + item.attrib_count + filename_length;
		// endOfItemThreads = End of the thread records
		NSUInteger endOfItemThreads = *dataOffset + item.attrib_count + filename_length +
						item.total_threads * sizeof(ShrinkItThreadRecord);
		if (endOfItemThreads >= endOfDataMark) {
			//NSLog(@"The NuArchive may have an incomplete thread list");
			item = nil;
			goto bailOut;
		}
		// threadItemDataMark is the offset to a thread's data area
		NSUInteger threadItemDataMark = endOfItemThreads;	// offset to 1st item's data area
		u_int32_t threadCount = item.total_threads;

		while (threadCount > 0) {
			range = NSMakeRange(currOffset, 2);
			[self.dataContents getBytes:&inputBuf
								  range:range];
			u_int16_t thread_class = inputBuf[0] + (inputBuf[1] << 8);
			currOffset += 2;

			range = NSMakeRange(currOffset, 2);
			[self.dataContents getBytes:&inputBuf
								  range:range];
			u_int16_t thread_format = inputBuf[0] + (inputBuf[1] << 8);
			currOffset += 2;
			range = NSMakeRange(currOffset, 2);
			[self.dataContents getBytes:&inputBuf
								  range:range];
			u_int16_t thread_kind = inputBuf[0] + (inputBuf[1] << 8);
			currOffset += 2;
			range = NSMakeRange(currOffset, 2);
			[self.dataContents getBytes:&inputBuf
								  range:range];
			// The crc is valid for compressed data for version 2
			//  for compressed data for version 3; invalid for other versions
			u_int16_t thread_crc = inputBuf[0] + (inputBuf[1] << 8);
			if (item.version_number > 1) {
				//NSLog(@"CRC-16 is valid for versions 2 & 3:0x%0x", thread_crc);
			}
			currOffset += 2;
			range = NSMakeRange(currOffset, 4);
			[self.dataContents getBytes:&inputBuf
								  range:range];
			u_int32_t thread_eof = inputBuf[0] + (inputBuf[1] << 8) + (inputBuf[2] << 16) + (inputBuf[3] << 24);
			currOffset += 4;
			range = NSMakeRange(currOffset, 4);
			[self.dataContents getBytes:&inputBuf
								  range:range];
			u_int32_t comp_thread_eof = inputBuf[0] + (inputBuf[1] << 8) + (inputBuf[2] << 16) + (inputBuf[3] << 24);
			//NSLog(@"Compressed EOF:%d", comp_thread_eof);
			currOffset += 4;
			// In some archives for the last thread, the sum of threadItemDataMark
			// & comp_thread_eof happened to be == endOfDataMark.
			// if ((threadItemDataMark + comp_thread_eof) >= endOfDataMark)
			// This statement(s) is/are not necessary since we are going
			// to use a @try-catch directive to capture the data
			if ((threadItemDataMark + comp_thread_eof) > endOfDataMark) {
				//NSLog(@"Offset to the data for this thread is beyond eod");
				//NSLog(@"0x:%x 0x:%x 0x:%x ", threadItemDataMark, comp_thread_eof, endOfDataMark);
				item = nil;
				goto bailOut;
			}
			u_int32_t option = MakeThreadClassAndKind(thread_class, thread_kind);
			switch (option)
			{
			case MakeThreadClassAndKind(kShrinkItThreadClassIsMessage, kShrinkItThreadKindIsText):
				break;
			case MakeThreadClassAndKind(kShrinkItThreadClassIsMessage, kShrinkItThreadKindIsCommentText):
				break;
			case MakeThreadClassAndKind(kShrinkItThreadClassIsMessage, kShrinkItThreadKindIsIcon):
				break;
			case MakeThreadClassAndKind(kShrinkItThreadClassIsControl, kShrinkItThreadKindIsCreateDirectory):
				break;
			case MakeThreadClassAndKind(kShrinkItThreadClassIsData, kShrinkItThreadKindIsDataFork):
				{
					CompressedDataDescriptor dataDescriptor;
					//NSLog(@"Has data Fork");
					dataDescriptor.startMark = (u_int32_t)threadItemDataMark;
					dataDescriptor.uncompressedSize = thread_eof;
					dataDescriptor.compressedSize = comp_thread_eof;
					dataDescriptor.compressedDataFormat = thread_format;
					dataDescriptor.crc = thread_crc;
					item.dataDescriptor = dataDescriptor;
					total_Size += thread_eof;
				}
				break;
			case MakeThreadClassAndKind(kShrinkItThreadClassIsData, kShrinkItThreadKindIsDisk):
				{
					CompressedDataDescriptor dataDescriptor;
					//NSLog(@"Disk Image");
					dataDescriptor.startMark = (u_int32_t)threadItemDataMark;
					dataDescriptor.uncompressedSize = item.extra_type * 512;
					dataDescriptor.compressedSize = comp_thread_eof;
					dataDescriptor.compressedDataFormat = thread_format;
					dataDescriptor.crc = thread_crc;
					item.dataDescriptor = dataDescriptor;
					total_Size += thread_eof;
				}
				break;
			case MakeThreadClassAndKind(kShrinkItThreadClassIsData, kShrinkItThreadKindIsResourceFork):
				{
					CompressedDataDescriptor dataDescriptor;
					//NSLog(@"Has resource Fork");
					dataDescriptor.startMark = (u_int32_t)threadItemDataMark;
					dataDescriptor.uncompressedSize = thread_eof;
					dataDescriptor.compressedSize = comp_thread_eof;
					dataDescriptor.compressedDataFormat = thread_format;
					dataDescriptor.crc = thread_crc;
					item.resourceDescriptor = dataDescriptor;
					total_Size += thread_eof;
				}
				break;
			case MakeThreadClassAndKind(kShrinkItThreadClassIsFilename, kShrinkItThreadKindIsFilename):
				{
					// This thread record has a reserved area predefined by comp_thread_eof.
					// The thread_eof is the length of the fileName.
					// NB. This thread should only be here if there is none in the main area
					//  (@ relative offset attrib_count)
					char *strBuf = malloc(thread_eof);
					range = NSMakeRange(threadItemDataMark, thread_eof);
					@try {
						[self.dataContents getBytes:strBuf
											  range:range];
					}
					@catch (NSException * e) {
						//NSLog(@"Problem extracting filename:%@", e);
						free(strBuf);
						item = nil;
						goto bailOut;
					}
					item.fileName = [[NSString alloc] initWithBytes:strBuf
															 length:thread_eof
														   encoding:NSUTF8StringEncoding];
					//NSLog(@"Filename:%@", item.fileName);
					free(strBuf);
				}
				break;
			default:
				break;
			}
			threadItemDataMark += comp_thread_eof;		// offset to next item's data
			--threadCount;
		}
		item.totalSize = [self fileSize:total_Size];
		// Return current file mark
		*dataOffset = threadItemDataMark;
	}
bailOut:
	return item;
}

// Ensure we return a NIL object if we encounter any problem extracting
// the archived items.
-(BOOL) build
{
	BOOL success = YES;
/*
	// debugging
	switch (kind)
	{
	case kIsPlainShk:
		NSLog(@"Plain SHK");
		break;
	case kIsShkWithBny:
		NSLog(@"SHK with Binary II wrapper");
		break;
	case kIsPlainSea:
		NSLog(@"Plain SEA");
		break;
	case kIsSeaWithBny:
		NSLog(@"SEA with Binary II wrapper");
		break;
	default:
		break;
	}
 */
	NSUInteger dataOffset = headerOffset;
	for (int i=0; i < masterHeaderRecord.total_records; ++i) {
		//NSLog(@"======= item %d =========", i+1);
		ShrinkItArchiveItem *item = [self shrinkItItemHeaderAtOffset:&dataOffset];
		if (self.items != nil && item != nil) {
			[self.items addObject:item];
		}
		else {
			success = NO;			// Flag we have a problem with the NuFX header.
			break;
		}
	}
	//NSLog(@"# of items:%d", items.count);
	return success;
}

// This needs to change if the archive is modifiable.
-(NSArray *) archiveItems
{
	if ([self.items count] != 0) {
		//NSLog(@"We had already parsed the file");
	}
	else {
		if (![self build]) {
			// Something's wrong with the archive - corrupted header?
			if (self.items != nil) {
				self.items = nil;
			}
			if (self.dataContents != nil) {
				self.dataContents = nil;
			}
		}
	}

	// We don't own the returned value.
	return [self.items sortedArrayUsingSelector:@selector(compare:)];
}

// Depth first transversal.
// Compute a value for the property nodeID
- (void) generateIdentifierForNode:(NSTreeNode *)treeNode {

    if (treeNode != nil) {
		SHTreeObject *treeObj = treeNode.representedObject;
        // The indexPath of an NSTreeNode object is unique.
		NSIndexPath *indexPath = treeNode.indexPath;
		NSUInteger *indexes = malloc(sizeof(NSUInteger) * indexPath.length);
		[indexPath getIndexes:indexes];     // deprecated for macOS 10.12
		NSString *idStr = @"id";
		for (int i = 0; i<indexPath.length; i++) {
			idStr = [idStr stringByAppendingFormat:@"-%lu", indexes[i]];
		}
		treeObj.nodeID = idStr;

		// The proxy root tree node is NOT an instance of NSTreeNode!
		// It only responds to the messages "childNodes" & "descendantNodeAtIndexPath"
        // Refer: NSTreeController - arrangedObjects
		NSString *parentID = nil;
		if (treeObj.parentObject != nil) {
			NSTreeNode *parentNode = treeNode.parentNode;
			//NSLog(@"%@", [parentNode class]);
			SHTreeObject *parentObj = [parentNode representedObject];
			parentID = parentObj.nodeID;
		}
		else {
			parentID = [NSString string];
		}
		treeObj.parentNodeID = parentID;

		// No "parentID" property declared in SHTreeObject.
		//NSLog(@"%@ %@ %@ %@", treeObj.pathName, treeObj.nodeID, treeObj.parentNodeID, treeObj.fileTypeText);
		[self.treeTableList addObject:treeObj];
		free(indexes);
		if (!treeNode.isLeaf) {
			NSArray *children = treeNode.childNodes;
			for (NSTreeNode *child in children) {
				[self generateIdentifierForNode:child];
			}
		}
	}
}

/*
 a) Build a tree of model objects.
 b) Attach the root objects to an instance of NSTreeController.
 c) Do a depth-first traversal to build a list that is compatible
  to the tree table used by the treeTable.js script.
 d) Build a pre-rendered tree table that will be passed to the
 the treeTable.js script.
  */
-(void) buildTree {
	NSMutableArray *flatList = [NSMutableArray array];
	// We use the list of ShrinkIt archive items to create a list of
	// instances of SHTreeObjects.
	for (ShrinkItArchiveItem *item in self.items) {
		SHTreeRecord *rec = [[SHTreeRecord alloc] initWithShrinkitArchiveItem:item];
		SHTreeObject *treeObj = [[SHTreeObject alloc] initWithRecord:rec];
		[flatList addObject:treeObj];
	}

	// Use the flat list to build a multi-rooted tree of model objects.
	NSMutableArray *rootObjects = [SHTree buildMultipleRoots:flatList];
	NSTreeController *treeController = [[NSTreeController alloc] init];
	[treeController setChildrenKeyPath:@"children"];
	[treeController setLeafKeyPath:@"isLeaf"];
    // The representedObject of an instance of NSTreeNode is an instance of SHTreeObject.
	[treeController setObjectClass:[SHTreeObject class]];
    // Bind the roots of the tree to an instance of NSTreeController.
	[treeController setContent:rootObjects];

	// Build the tree table list.
	id proxyRoot = [treeController arrangedObjects];            // proxy for the root tree node
	NSArray<NSTreeNode *> *childArray = [proxyRoot childNodes];	// root nodes
	//NSLog(@"================ Print Depth-First ================");
	//NSLog(@"# of root nodes %ld", [childArray count]);
	self.treeTableList = [NSMutableArray array];
	for (int i=0; i < [childArray count]; i++) {
		NSTreeNode *rootNode = childArray[i];
		[self generateIdentifierForNode:rootNode];
		//SHTreeObject *rootObject = [rootNode representedObject];
		//NSLog(@"%@ %@ %@", rootObject.pathName, rootObject.nodeID, rootObject.parentNodeID);
        // The parentNodeID of SHTreeObjects at the rool level is an empty string.
        // The parent of NSTreeNodes at the root level is the proxy root tree node.
	}
}

// Format the treeTable list into a pre-rendered tree.
// This method is called by the function GeneratePreviewForURL
- (NSMutableString *) preRenderedTreeTable {
	[self buildTree];
	NSMutableString *treeOutput = [NSMutableString string];
	for (SHTreeObject *treeObj in self.treeTableList) {
		// There are 4 cases.
		if (treeObj.parentObject == nil) {
			// root level
			if (treeObj.isLeaf) {
				// leaf at root level
				[treeOutput appendFormat:@"<tr data-tt-id=\"%@\">\n<td>%@</td>\n<td>%@</td>\n<td>%@</td>\n<td>%@</td>\n</tr>\n",
				 treeObj.nodeID, treeObj.fileName, treeObj.fileTypeText, treeObj.modificationDateTime, treeObj.totalSize];
			}
			else {
				// folder at root level
				[treeOutput appendFormat:@"<tr data-tt-id=\"%@\">\n<td>%@</td>\n<td>%@</td>\n</tr>\n",
					treeObj.nodeID, treeObj.fileName, @"DIR"];
			}
		}
		else {
			// non-root level
			if (treeObj.isLeaf) {
				// leaf within a folder
				[treeOutput appendFormat:@"<tr data-tt-id=\"%@\" data-tt-parent-id=\"%@\">\n<td>%@</td>\n<td>%@</td>\n<td>%@</td>\n<td>%@</td>\n</tr>\n",
					treeObj.nodeID, treeObj.parentNodeID, treeObj.fileName, treeObj.fileTypeText, treeObj.modificationDateTime, treeObj.totalSize];
			}
			else {
				// sub-folder
				[treeOutput appendFormat:@"<tr data-tt-id=\"%@\" data-tt-parent-id=\"%@\">\n<td>%@</td>\n<td>%@</td>\n</tr>\n",
					treeObj.nodeID, treeObj.parentNodeID, treeObj.fileName, @"DIR"];
			}
		}

		//NSLog(@"%@ %@ %@ %@", treeObj.pathName, treeObj.nodeID, treeObj.parentNodeID, treeObj.fileTypeText);
	} // for
	//NSLog(@"%@", treeOutput);

	return treeOutput;
}
@end
