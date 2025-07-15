//
//  TypesConverter.m
//  SwiftNuShrinkItX
//
//  Created by Mark Lim on 9/1/16.
//  Copyright © 2016 Mark Lim. All rights reserved.
//

#import "TypesConvert.h"

const NSString *PDOSFileType = @"PdosFileType";
const NSString *PDOSAuxType = @"PdosAuxType";
const NSString *PDOSAccess = @"PdosAccess";

@implementation TypesConvert

/*
 Convert hex to decimal. Taken from HFS.cpp of CiderPress's DiskImgLib
 */
int FromHex(char hexVal) {
	if (hexVal >= '0' && hexVal <= '9')
		return hexVal - '0';
	else if (hexVal >= 'a' && hexVal <= 'f')
		return hexVal -'a' + 10;
	else if (hexVal >= 'A' && hexVal <= 'F')
		return hexVal - 'A' + 10;
	else
		return -1;
}

// Just a C-function
// Convert HFS FileType & Creator codes to ProDOS
void mapHfsTypes(OSType hfsFileType, OSType hfsCreatorType,
				 unsigned int *fileType, unsigned int *auxType) {

    if (hfsFileType == 'BINA') {
		//NSLog(@"BINA");
		*fileType = 0x00;
		*auxType = 0x0000;
	}
	else if (hfsFileType == 'TEXT') {
		//NSLog(@"TEXT");
		*fileType = 0x04;
		*auxType = 0x0000;
	}
	else if (hfsFileType == 'MIDI') {
		//NSLog(@"MIDI");
		*fileType = 0xD7;
		*auxType = 0x0000;
	}
	else if (hfsFileType == 'AIFF') {
		//NSLog(@"AIFF");
		*fileType = 0xD8;
		*auxType = 0x0000;
	}
	else if (hfsFileType == 'AIFC') {
		//NSLog(@"AIFC");
		*fileType = 0xD8;
		*auxType = 0x0001;
	}
	else if (hfsCreatorType == 'pdos') {
		if (hfsFileType == 'PS16') {
			// There will be a loss in accuracy if a PS16 file is dragged to
			// the MacOSX desktop and then back to a ProDOS formatted disk image
			//NSLog(@"PS16");
			*fileType = 0xb3;
			*auxType = 0x0000;
		}
		else if (hfsFileType == 'PSYS') {
			// There will be a loss in accuracy if a SYS file is dragged to
			// the MacOSX desktop and then back to a ProDOS formatted disk image
			//NSLog(@"PSYS");
			*fileType = 0xff;
			*auxType = 0x0000;
		}
		else if ((hfsFileType & 0xffff) == 0x2020) {
			// case: 'XY  ', where XY are ASCII hex digits 0x30-3f
			int digit1, digit2;
			
			digit1 = FromHex((char) (hfsFileType >> 24));
			digit2 = FromHex((char) (hfsFileType >> 16));
			if (digit1 < 0 || digit2 < 0) {
				NSLog(@"  Unexpected: pdos + %0x", hfsFileType);
				*fileType = 0x00;
				*auxType = 0x0000;
			}
			else {
				*fileType = digit1 << 4 | digit2;
				*auxType = 0x0000;
			}
		}
		else {
			// Assume 'p' $b3 $db $yz
			*fileType = (hfsFileType >> 16) & 0xff;
			*auxType = hfsFileType & 0xffff;
		}
	}
	else {
		*fileType = 0x00;
		*auxType = 0x0000;
	}
}

// This method presumes the method attributesOfItemAtPath had been called.
// Get prodos file and aux type from an OSX file's HFS FileType Code
+ (NSDictionary *) osxFileAttributes:(NSDictionary *)osxAttr
						toFileSystem:(u_int16_t)fileSysID {

    OSType hfsFileType = [[osxAttr objectForKey:NSFileHFSTypeCode] unsignedIntValue];
	OSType hfsCreatorType = [[osxAttr objectForKey:NSFileHFSCreatorCode] unsignedIntValue];
	u_int32_t fileType;
	u_int32_t auxType;

	if (fileSysID == 5) {
		// Macintosh HFS: No change
		fileType = hfsFileType;
		auxType = hfsCreatorType;
	}
	else {
		// GS/OS, ProDOS, Pascal or DOS3.x etc
		// This case is treated separately
		if (hfsCreatorType == 'dCpy' && hfsFileType == 'dImg') {
			fileType = 0xe0;
			auxType = 0x0005;
		}
        else {
			mapHfsTypes(hfsFileType, hfsCreatorType,
                        &fileType, &auxType);
        }
	}
	
	NSNumber *fileTypeCode = [NSNumber numberWithUnsignedInt:fileType];
	NSNumber *auxTypeCode = [NSNumber numberWithUnsignedInt:auxType];
	NSMutableDictionary *newAttr = [NSMutableDictionary dictionary];
	// Preserve all attributes returned/set by OS X
	[newAttr addEntriesFromDictionary:osxAttr];
	// the original values of the keys HFSTypeCode & HFSCreatorCode are unchanged
	// the values for the keys pdosFileType & pdosAuxType will be hfsTypeCode and
	// hfsCreatorCode if the fileSysID is HFS (5)
	[newAttr setObject:fileTypeCode
				forKey:PDOSFileType];
	[newAttr setObject:auxTypeCode
				forKey:PDOSAuxType];
	return newAttr;
}

/*
 Convert a ProDOS file type and aux type to a MacOS hfsTypeCode.
 The general case is done first; it covers the case $B3, $DByz. For specific
 cases, the initial typeCode object will be replaced.
 */
NSNumber* getTypeCodeForFileType(OSType fileType, OSType auxType) {

	NSNumber *typeCode;
	OSType hfsType;
	hfsType = 0x70000000 + (fileType << 16) + auxType;
	typeCode = [NSNumber numberWithUnsignedInt:hfsType];

	switch (fileType) {
		case 0x00:
			// checked
			if (auxType == 0x0000)  {
				typeCode = [NSNumber numberWithUnsignedInt:'BINA'];
            }
			break;
		case 0x04:
			// checked
			if (auxType == 0x0000)  {
				typeCode = [NSNumber numberWithUnsignedInt:'TEXT'];
            }
			break;
		case 0xb3:
			// checked
			if ((auxType & 0xff00) != 0xdb00) {
				typeCode = [NSNumber numberWithUnsignedInt:'PS16'];
			}
			break;
		case 0xd7:
			// checked
			if (auxType == 0x0000) {
				typeCode = [NSNumber numberWithUnsignedInt:'MIDI'];
            }
			break;
		case 0xd8:
			// both checked
			if (auxType == 0x0000)  {
				typeCode = [NSNumber numberWithUnsignedInt:'AIFF'];
            }
			if (auxType == 0x0001)  {
				typeCode = [NSNumber numberWithUnsignedInt:'AIFC'];
            }
			break;
		case 0xff:
			// checked
			typeCode = [NSNumber numberWithUnsignedInt:'PSYS'];
			break;
		default:
			break;
	}
	return typeCode;
}

// Get the hfs filetype and creator codes of the file; 0xe0/0x0005 is done
// separately from the others because it's too specific.
+ (NSDictionary *) hfsCodesForFileType:(OSType)fileType
							andAuxType:(OSType)auxType
						  toFileSystem:(unsigned short)fileSysID {

    NSNumber *typeCode;
	NSNumber *creatorCode;

	if (fileSysID == 5) {
		// no change if it's already HFS type and creator codes
		typeCode = [NSNumber numberWithUnsignedInt:fileType];
		creatorCode = [NSNumber numberWithUnsignedInt:auxType];
	}
	else {
		// For ProDOS, DOS3.3 and Apple Pascal
		if (fileType == 0xe0 && auxType == 0x0005) {
			// checked
			typeCode = [NSNumber numberWithUnsignedInt:'dImg'];
			creatorCode = [NSNumber numberWithUnsignedInt:'dCpy'];
		}
		else {
			// For the rest, pass the task to the helper method
			typeCode = getTypeCodeForFileType(fileType, auxType);
			creatorCode = [NSNumber numberWithUnsignedInt:'pdos'];
		}
	}

	// Return the HFS TypeCode and CreatorCode to the caller.
	NSDictionary *codesDict = [NSDictionary dictionaryWithObjectsAndKeys:
										   typeCode, NSFileHFSTypeCode,
										   creatorCode, NSFileHFSCreatorCode,
										   nil];

	return codesDict;
}


@end
