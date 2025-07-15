//
//  ShrinkItArchiveItem.m
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

#import "ShrinkItArchiveItem.h"
#import "ShrinkItArchive.h"
#import "TypesConvert.h"
#include "DateUtils.h"


@implementation ShrinkItArchiveItem

// Properties are backed by instance variables which are prepended by a _.
// No need to declare @synthesize propertyName;

-(instancetype) init {
	self = [super init];
	if (self) {
	}
	return self;
}

// Returns the contents of the file's data fork wrapper as an instance of NSData
// Returns nil if there is no data fork or cannot be extracted.
-(NSData *) contentsOfDataFork {
	NSData *data = [self.owner contentsOfDataForkOfItem:self];
	return data;
}

// Returns the contents of the file's resource fork wrapper in an instance of NSData
// Returns nil if there is no resource fork or cannot be extracted.
-(NSData *) contentsOfResourceFork
{
	NSData *data = [self.owner contentsOfResourceForkOfItem:self];
	return data;
}

// Returns the 4 file attributes of an NuFX archive item which can be
// converted to those of OS X. It calls a factory method to convert
// proDOS files with a specific file and aux types so that the information
// is not lost when the file is copied to an HFS+-formatted HDD.
-(NSDictionary *) attributes {

	NSDictionary *attr = [TypesConvert hfsCodesForFileType:self.fileType
												andAuxType:self.auxType
											  toFileSystem:self.fileSysID];

	NSMutableDictionary *fileAttr = [NSMutableDictionary dictionaryWithDictionary:attr];
	fileAttr[NSFileModificationDate] = self.modificationDateTime;
	fileAttr[NSFileCreationDate] = self.creationDateTime;
	return fileAttr;
}

// Uses the attributes of a OS X file to set 4 file attributes of
// an NuFX archive item. It calls a factory method to convert attributes of
// files which originally was a proDOS file with specific file and aux types.
-(void) setAttributes:(NSDictionary *) fileAttr {

	NSDictionary *attrs = [TypesConvert osxFileAttributes:fileAttr
											 toFileSystem:self.fileSysID];
	// if fileSysID is HFS, the original values for the keys HFSTypeCode &
	// HFSCreatorCode are also returned as values for the keys
	// pdosFileType & pdosAuxType
	self.fileType = [attrs[PDOSFileType] unsignedIntValue];
	self.auxType = [attrs[PDOSAuxType] unsignedIntValue];
	// No change in the creation/modification dates
	self.modificationDateTime = fileAttr[NSFileModificationDate];
	//NSLog(@"%@", modificationDateTime);
	self.creationDateTime = fileAttr[NSFileCreationDate];
}

/*
To check:
 Returns the other file attributes of an NuFX archive item
 cannot be converted. The caller must called setxattr to
 attached the contents to a file stored on the HDD.
 Note: only HFS+-formatted HDD supports extended attributes;
 ex-FAT or msdos HDD may not.
 */
-(NSData *) extendedAttributes {

	Byte buffer[XATTR_NUFX_LENGTH];
	uint16_t tmp16;
	uint32_t tmp32;

	memset(buffer, 0, sizeof(buffer));
	//buffer[0] = fileSysID & 0xff;
	//buffer[1] = (fileSysID >> 8) & 0xff;
	tmp16 = NSSwapHostShortToLittle(self.fileSysID);
	memcpy(buffer, &tmp16, 2);
	tmp16 = NSSwapHostShortToLittle(self.fileSysInfo);
	memcpy(buffer+2, &tmp16, 2);

	tmp32 = NSSwapHostIntToLittle(self.access);
	memcpy(buffer+4, &tmp32, 4);
	tmp16 = NSSwapHostShortToLittle(self.storageType);
	memcpy(buffer+8, &tmp16, 2);
	NuDateTime date;
	// Convert NSDate to NuDateTime?
	time_t when = self.archivedDateTime.timeIntervalSince1970;
	UNIXTimeToDateTime(&when, &date);
	memcpy(buffer+10, &date, 8);
	// There is no support for adding a GS/OS option list to a NuRecord
	// in the original source code. NuShrinkItX uses a slightly modified version.
	if (self.optionListSize != 0) {
		//NSLog(@"extendedAttributes:%d", self.optionListSize);
		tmp16 = NSSwapHostShortToLittle(self.optionListSize);
		memcpy(buffer+18, &tmp16, 2);
		memcpy(buffer+20, self.optionListData.bytes, self.optionListData.length);
	}

	// NB. if optionListSize is 0, the rest of the buffer would have been padded with zeroes
	return [NSData dataWithBytes:buffer
						  length:XATTR_NUFX_LENGTH];
}

// set the other attributes of an archived item.
-(void) setExtendedAttributes:(NSData *)data {

	const void *bufferPtr;
	uint16_t tmp16;
	uint32_t tmp32;

	bufferPtr = data.bytes;
	tmp16 = *(uint16_t *)bufferPtr;
	//NSLog(@"fileSysID:$%0x", tmp16);
	self.fileSysID = NSSwapLittleShortToHost(tmp16);
	tmp16 = *(uint16_t *)(bufferPtr+2);
	self.fileSysInfo = NSSwapLittleShortToHost(tmp16);
	//NSLog(@"fileSysInfo:$%0x", tmp16);
	//set item separator
	if (self.fileSysInfo == 0x3a) {
		self.separator = @":";
	}
	else if (self.fileSysInfo == 0x2f) {
		self.separator = @"/";
	}
	else if (self.fileSysInfo == 0x5c) {
		self.separator = @"\\";
	}

	tmp32 = *(uint32_t *)(bufferPtr+4);
	self.access = NSSwapLittleIntToHost(tmp32);
	tmp16 = *(uint16_t *)(bufferPtr+8);
	self.storageType = NSSwapLittleShortToHost(tmp16);

	NuDateTime date;
	memcpy(&date, bufferPtr+10, 8);
	time_t when;
	DateTimeToUNIXTime(&date, &when);
	self.archivedDateTime = [NSDate dateWithTimeIntervalSince1970:when];
	tmp16 = *(uint16_t *)(bufferPtr+18);
	self.optionListSize = NSSwapLittleShortToHost(tmp16);
	if (self.optionListSize != 0) {
		void *listBytes = malloc(self.optionListSize);
		memcpy(listBytes, bufferPtr+20, self.optionListSize);
		self.optionListData = [NSData dataWithBytes:listBytes
										length:self.optionListSize];
		free(listBytes);
	}
	else {
		self.optionListData = [NSData data];
	}
}

@end
