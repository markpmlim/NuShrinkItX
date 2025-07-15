//
//  CPDataRecord.m
//  CiderXPress
//
//  Created by mark lim on 1/8/13.
//  Copyright (c) 2013 Incremental Innovation. All rights reserved.
//

#import "SHTreeRecord.h"
#import "ShrinkItArchiveItem.h"

/*
 Copied from CiderPress' FileNameConv.cpp
 ProDOS file type names; must be entirely in upper case
 */
const char *gFileTypeNames[256] = {
	"NON", "BAD", "PCD", "PTX", "TXT", "PDA", "BIN", "FNT",
	"FOT", "BA3", "DA3", "WPF", "SOS", "$0D", "$0E", "DIR",
	"RPD", "RPI", "AFD", "AFM", "AFR", "SCL", "PFS", "$17",
	"$18", "ADB", "AWP", "ASP", "$1C", "$1D", "$1E", "$1F",
	"TDM", "IPS", "UPV", "$23", "$24", "$25", "$26", "$27",
	"$28", "3SD", "8SC", "8OB", "8IC", "8LD", "P8C", "$2F",
	"$30", "$31", "$32", "$33", "$34", "$35", "$36", "$37",
	"$38", "$39", "$3A", "$3B", "$3C", "$3D", "$3E", "$3F",
	"DIC", "OCR", "FTD", "$43", "$44", "$45", "$46", "$47",
	"$48", "$49", "$4A", "$4B", "$4C", "$4D", "$4E", "$4F",
	"GWP", "GSS", "GDB", "DRW", "GDP", "HMD", "EDU", "STN",
	"HLP", "COM", "CFG", "ANM", "MUM", "ENT", "DVU", "FIN",
	"$60", "$61", "$62", "$63", "$64", "$65", "$66", "$67",
	"$68", "$69", "$6A", "BIO", "$6C", "TDR", "PRE", "HDV",
	"$70", "$71", "$72", "$73", "$74", "$75", "$76", "$77",
	"$78", "$79", "$7A", "$7B", "$7C", "$7D", "$7E", "$7F",
	"$80", "$81", "$82", "$83", "$84", "$85", "$86", "$87",
	"$88", "$89", "$8A", "$8B", "$8C", "$8D", "$8E", "$8F",
	"$90", "$91", "$92", "$93", "$94", "$95", "$96", "$97",
	"$98", "$99", "$9A", "$9B", "$9C", "$9D", "$9E", "$9F",
	"WP ", "$A1", "$A2", "$A3", "$A4", "$A5", "$A6", "$A7",
	"$A8", "$A9", "$AA", "GSB", "TDF", "BDF", "$AE", "$AF",
	"SRC", "OBJ", "LIB", "S16", "RTL", "EXE", "PIF", "TIF",
	"NDA", "CDA", "TOL", "DVR", "LDF", "FST", "$BE", "DOC",
	"PNT", "PIC", "ANI", "PAL", "$C4", "OOG", "SCR", "CDV",
	"FON", "FND", "ICN", "$CB", "$CC", "$CD", "$CE", "$CF",
	"$D0", "$D1", "$D2", "$D3", "$D4", "MUS", "INS", "MDI",
	"SND", "$D9", "$DA", "DBM", "$DC", "DDD", "$DE", "$DF",
	"LBR", "$E1", "ATK", "$E3", "$E4", "$E5", "$E6", "$E7",
	"$E8", "$E9", "$EA", "$EB", "$EC", "$ED", "R16", "PAS",
	"CMD", "$F1", "$F2", "$F3", "$F4", "$F5", "$F6", "$F7",
	"$F8", "OS ", "INT", "IVR", "BAS", "VAR", "REL", "SYS"
};

NSString * const XPAuxTypes		= @"AuxTypes";
NSString * const XPFileTypes	= @"FileTypes";
NSString * const unknownText	= @"Unknown";

// Note: instance variables may not be placed in categories.
// Use a class extension to declare the instance variables backing the properties.
@interface SHTreeRecord () {
    // Instance variables backing the properties declared in SHTreeRecord.h
    NSString    *_pathName;            // stored as a unix pathname with / as separators
    NSString    *_fileName;
    NSString    *_fileTypeText;
    NSString    *_creationDateTime;
    NSString    *_modificationDateTime;
    NSString    *_totalSize;

}
@end

@implementation SHTreeRecord


// Don't call the initializer method below directly.
// The method buildTreeTable will call this initializer for every
// instance of ShrinkItArchiveItem.
- (instancetype) initWithShrinkitArchiveItem:(ShrinkItArchiveItem *)archiveItem {
	self = [super init];
	if (self) {
		// For a proxy root object, pathName is to a zero length cString.
		NSString *tempString = [NSString stringWithString:archiveItem.fileName];
		NSString *separator = nil;
		if (archiveItem.file_sys_info == 0x3a)
			separator = @":";
		else if (archiveItem.file_sys_info == 0x2f)
			separator = @"/";
		else if (archiveItem.file_sys_info == 0x5c)
			separator = @"\\";

		NSArray *componentArray = [tempString componentsSeparatedByString:separator];
		/*
		 We are using factory methods or methods returning objects whose owner
		 is some other object elsewhere. If we must add ourselves as an owner,
		 we can use setter methods to retain these objects. Objects can be
		 prefixed with "self" or send a "retain" message if these are not
		 to be de-allocated when they go out-of-scope.
		 */
		// Note: all ShrinkItArchive items are stored as leaves in a ShrinkIt archive.
        self.pathName = [componentArray componentsJoinedByString:@"/"];
		self.fileName = [self.pathName lastPathComponent];
		self.fileTypeText = archiveItem.fileType;
		self.creationDateTime = archiveItem.creationDateTime;
		self.modificationDateTime = archiveItem.modificationDateTime;
		self.totalSize = archiveItem.totalSize;
	}
	return self;
}

@end
