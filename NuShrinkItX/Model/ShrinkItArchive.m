//
//  ShrinkItArchive.m
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NuShrinkItX-Swift.h"	// auto-generated
#import "ShrinkItArchive.h"
#import "ShrinkItArchiveItem.h"
#import "NUError.h"
#include "DateUtils.h"
#include <sys/xattr.h>
#include <stdlib.h>

@interface ShrinkItArchive ()

@property NSMutableArray	*archiveItems;			// list of ShrinkItArchiveItems
@property NSMutableArray	*recordIndexes;			// list of NuRecordIdx's
@property (copy) NSString   *nufxWorkPath;			// used by NuFX library
@property NSDate			*creationDateTime;
@property NSDate			*modificationDateTime;

@end


@implementation ShrinkItArchive

// Properties are backed by instance variables which are prepended by a _.
// No need to declare @synthesize propertyName;

/*
 Returns nil if the archive or temporary work file(s) can not be opened/created.
*/
-(instancetype) initWithPath:(NSString *)path
					   error:(NSError **)errorPtr {

	if (errorPtr != nil) {
		*errorPtr = nil;
	}
	self = [super init];
	if (self) {
		//NSLog(@"init archive object");
		self.pathName = path;
		AppDelegate *delegate =  [[NSApplication sharedApplication] delegate];
		// nufxWorkPath is used by the NuFX library for input/output to a NuFX document.
        NSString *workingDir = [[delegate uniqueDirectoryInApplicationWorkDirectory] path];
        NSString *filename = path.lastPathComponent;
        self.nufxWorkPath = [NSString stringWithFormat:@"%@/%@", workingDir, filename];
		//self.nufxWorkPath = [NSString stringWithFormat:@"%@.XXXXXX", self.pathName];
		char *temp = mktemp((char *)[self.nufxWorkPath cStringUsingEncoding:NSUTF8StringEncoding]);
		if (temp != NULL) {
			NuError nuErr = NuOpenRW([self.pathName cStringUsingEncoding:NSUTF8StringEncoding],
									 temp,
									 kNuOpenCreat,
									 &_pArchive);
			
			if (nuErr != kNuErrNone) {
				//NSLog(@"Error:%d", nuErr);
				if (errorPtr != nil) {
					*errorPtr = [NUError errorWithCode:nuErr];
				}
				self = nil;
			}
		}
		else {
			if (errorPtr != nil) {
				// We could not create a temporary file required by NuFX library.
				NSMutableDictionary *infoDict = [NSMutableDictionary dictionary];
				// ErrorDescription will be constructed from the given domain & error code
				[infoDict setObject:@"The temporary work file required by NuFX could not be created."
							 forKey:NSLocalizedFailureReasonErrorKey];
				*errorPtr = [NSError errorWithDomain:NSCocoaErrorDomain
												code:NSFileWriteUnknownError
											userInfo:infoDict];
			}
			self = nil;
		}
	}
	return self;
}

// Seems to called whenever an instance of ShrinkItArchive is no longer used
// for example, when it goes out of scope.
-(void) dealloc {
	//NSLog(@"ShrinkitArchive dealloc");
	NuClose(_pArchive);		// nufxWorkPath will be deleted by NuFX library
}

/*
 Is it necessary to have a callback?
 Yes, we must build up an array of ptrs to NuRecords.
 Alternatively, we can utilize the NuRecord returned by this callback to create an
 instance of a Objective-C/Swift class which will be added to a NSMutableArray.

 Qn: If this is a Swift class, how do we call the C func NuContents? And suppose, we
 manage to setup the callback correctly, then how do we return the NuRecords to the
 Swift calling class.
 */
NuResult addRecord(NuArchive* pArchive, void* vpRecord) {

	const NuRecord *pRecord = (NuRecord *) vpRecord;
	NuError nuErr = kNuErrNone;

	// We must use an NSNumber wrapper object to wrap the item's recordIdx.
	//NSString *keyIndex = [NSString stringWithFormat:@"%0x", pRecord->recordIdx];
	NSNumber *keyIndex = [NSNumber numberWithUnsignedInt:pRecord->recordIdx];
	void *pThis;
	// Get the passed objective-C object and ...
	NuGetExtraData(pArchive, (void **) &pThis);
	if (nuErr == kNuErrNone) {
		// ... cast it into an instance of the correct class.
		// May have to use CFBridgingRelease
		ShrinkItArchive *ourArchive = (__bridge ShrinkItArchive *)pThis;

		// Add the keyIndex object to the recordIndexes NSArray
		[ourArchive.recordIndexes addObject:keyIndex];
		return kNuOK;
	}
	else {
		return kNuAbort;
	}
}

// This method returns an NSMutableArray of record indices which are
// assigned by the NuFX library to NuRecords.
// A simple callback C function "addRecord" is implemented.
- (BOOL) readArchive:(NSError **)outError {

	self.recordIndexes = [NSMutableArray array];
	BOOL result = YES;
	if (outError != nil) {
		*outError = nil;
	}
	// Use the NuFX library function below to pass an objective-C object
	// to the "addRecords" C function above.
	// May have to use CFBridgingRetain
	NuError nuErr = kNuErrNone;
	nuErr = NuSetExtraData(_pArchive, (__bridge void *)self);
	if (nuErr != kNuErrNone) {
		result = NO;
		goto bailOut;
	}

	nuErr = NuContents(_pArchive, addRecord);
	if (nuErr != kNuErrNone) {
		result = NO;
	}
bailOut:
	// Report as a NuFX library error.
	if (result == NO && outError != nil) {
		*outError = [NUError errorWithCode:nuErr];
	}
	return result;
}


// Check if the archive item is an Apple II disk image.
-(BOOL) isDisk:(const NuRecord * )pRecord {

	const NuThread *pThread = NULL;
	uint32_t i;
	BOOL result = NO;
	
	for (i = 0; i < (uint32_t)NuRecordGetNumThreads(pRecord); i++) {
		pThread = NuGetThread(pRecord, i);
		if (NuGetThreadID(pThread) == kNuThreadIDDiskImage) {
			result = YES;
			break;
		}
	}
	return result;
}

// Valid values for the parameter `whichThreadID` are:
// kNuThreadIDDataFork, kNuThreadIDRsrcFork, and kNuThreadIDDiskImage
- (uint32_t) uncompressedForkSize:(const NuRecord *)pRecord
						forThread:(uint32_t)whichThreadID {

	const NuThread *pThread = NULL;
	uint32_t size = 0;
	
	for (int i = 0; i < (int)NuRecordGetNumThreads(pRecord); i++) {
		pThread = NuGetThread(pRecord, i);
		if (NuGetThreadID(pThread) == whichThreadID) {
			//cout << "Thread Index:"  << pThread->threadIdx << endl;
			//cout << "size:"  << pThread->thThreadEOF << endl;
			if (whichThreadID == kNuThreadIDDiskImage) {
				// thread_EOF might be zero for disk images
				//cout << "disk image size:" << pThread->actualThreadEOF << endl;
				size = pThread->actualThreadEOF;
			}
			else {
				size = pThread->thThreadEOF;
			}
			break;
		}
	}
	return size;
}

// Valid values for the paramter `which` are:
// kNuThreadIDDataFork, kNuThreadIDRsrcFork, kNuThreadIDDiskImage
- (uint32_t) compressedForkSize:(const NuRecord *)pRecord
					  forThread:(uint32_t)whichThreadID {

	const NuThread *pThread = NULL;
	uint32_t size = 0;
	
	for (int i = 0; i < (uint32_t)NuRecordGetNumThreads(pRecord); i++) {
		pThread = NuGetThread(pRecord, i);
		if (NuGetThreadID(pThread) == whichThreadID) {
			size = pThread->thCompThreadEOF;
			break;
		}
	}
	return size;
}

// If any of the item paths have slashes, return NO
- (BOOL) validatePathsOfItems:(NSMutableArray *)items {

	BOOL result = YES;
	NSCharacterSet *invalidChars = [NSCharacterSet characterSetWithCharactersInString:@"/"];
	for (int i=0; i < items.count; i++) {
		ShrinkItArchiveItem *item = items[i];
		if (item.fileSysInfo == 0x3a || item.fileSysInfo == 0x5a) {
			NSString *scanString = item.fileName;
			// KIV: besides a /, what other chars are not permitted?
			NSRange range = [scanString rangeOfCharacterFromSet:invalidChars];
			if (range.location != NSNotFound) {
				result = NO;
				break;
			}
		}
	}
	return result;
}

// This method utilizes the array of NuRecordIdxs (recordIndexes) to build
// an array of ShrinkItArchiveItems which is an Objective-C class.
// Once the ShrinkItArchiveItems array is setup, the array of indexes may be
// discarded especially in the event that NuRecords are deleted from the NuArchive.
// A dictionary [recIndex : ShrinkItArchiveItem] may be built here.
-(NSMutableArray *) items:(NSError **)outError {

	self.archiveItems = [NSMutableArray array];			// an empty array
	NuError nuErr = kNuErrNone;
	if (outError != nil) {
		*outError = nil;
	}

	for (unsigned int i = 0; i < self.recordIndexes.count; ++i) {
		NuRecordIdx recordIndex = [[self.recordIndexes objectAtIndex:i] unsignedIntValue];
		NuRecord *pRecord;
		nuErr = NuGetRecord(_pArchive, recordIndex, (const NuRecord **)&pRecord);
		if (nuErr == kNuErrNone) {
			ShrinkItArchiveItem *item = [[ShrinkItArchiveItem alloc] init];
			item.owner = self;			// should be an ShrinkItArchive object

			time_t time1;
			DateTimeToUNIXTime(&pRecord->recArchiveWhen, &time1);
			item.archivedDateTime = [NSDate dateWithTimeIntervalSince1970:time1];
            // fileName - actually a partial pathname with no leading separator.
			item.fileName = [NSString stringWithCString:pRecord->filenameMOR
												encoding:NSUTF8StringEncoding];
			// We can't wrap the recordIdx here and expect it to be the same as
			// in the map or dictionary since we may opt to use one of either.
			//NSLog(@"Check:%d %d", recordIndex, pRecord->recordIdx);

			item.recordIndex = [self.recordIndexes objectAtIndex:i];
			DateTimeToUNIXTime(&pRecord->recCreateWhen, &time1);
			item.creationDateTime = [NSDate dateWithTimeIntervalSince1970:time1];
			DateTimeToUNIXTime(&pRecord->recModWhen, &time1);
			item.modificationDateTime = [NSDate dateWithTimeIntervalSince1970:time1];
			item.fileType = pRecord->recFileType;
			item.auxType = pRecord->recExtraType;
			item.fileSysID = pRecord->recFileSysID;
			item.fileSysInfo = pRecord->recFileSysInfo;
			if (pRecord->recFileSysInfo == 0x3a) {
				item.separator = @":";		// HFS or GSOS
			}
			else if (pRecord->recFileSysInfo == 0x5c) {
				item.separator = @"\\";		// MSDOS - a double backslash is neccessary
			}
			else if (pRecord->recFileSysInfo == 0x2f) {
				item.separator = @"/";		// ProDOS, Unix
			}
			item.access = pRecord->recAccess;
			item.storageType = pRecord->recStorageType;
			// this may not be present in SHK archive item.
			item.optionListSize = pRecord->recOptionSize;
			if (item.optionListSize == 0) {
				item.optionListData = [NSData data];
			}
			else {
				//NSLog(@"%@", item.fileName);
				item.optionListData = [NSData dataWithBytes:pRecord->recOptionList
													  length:item.optionListSize];
			}

			// For each archive item, there is a list of 16-byte thread records;
			// the NuLib refers to these as NuThread records.
			item.totalThreads = NuRecordGetNumThreads(pRecord);
			if (!(item.isDisk = [self isDisk:pRecord])) {
				// To extract the following we use the thread id constants
				item.dataForkUncompressedSize = [self uncompressedForkSize:pRecord
																  forThread:kNuThreadIDDataFork];
				item.dataForkCompressedSize = [self compressedForkSize:pRecord
																	forThread:kNuThreadIDDataFork];
				item.resourceForkUncompressedSize = [self uncompressedForkSize:pRecord
																	  forThread:kNuThreadIDRsrcFork];
				item.resourceForkCompressedSize = [self compressedForkSize:pRecord
																  forThread:kNuThreadIDRsrcFork];
				/*
				 NSLog(@"dataFork size %d, Compressed size:%d, resFork size %d, Compressed size:%d",
						 item->dataForkUncompressedSize,
						 item->dataForkCompressedSize,
						 item->resourceForkUncompressedSize,
						 item->resourceForkCompressedSize);
				 */
			}
			else {
				//NSLog(@"We have a disk");
				item.diskUncompressedSize = [self uncompressedForkSize:pRecord
															  forThread:kNuThreadIDDiskImage];
				item.diskCompressedSize = [self compressedForkSize:pRecord
														  forThread:kNuThreadIDDiskImage];
				/*
				 NSLog(@"Uncompress size %d, Compressed size:%d",
						 item->diskUncompressedSize,
						 item->diskCompressedSize);
				 */
			}
			[self.archiveItems addObject:item];
		}
		else {
			// Proceed to return a NuError
			goto bailOut;
		}
	}
	return self.archiveItems;
bailOut:
	if (outError != nil) {
		*outError = [NUError errorWithCode:nuErr];
	}
	return nil;
}


NuThread *GetThread(const NuRecord *pRecord, uint32_t which) {

	NuThread *pThread = NULL;
	uint32_t i;
	
	for (i = 0; i < (uint32_t)NuRecordGetNumThreads(pRecord); i++) {
		pThread = (NuThread *)NuGetThread(pRecord, i);
		if (NuGetThreadID(pThread) == which) {
			break;
		}
	}
	// NULL is returned if the thread is not found
	return pThread;
}

// Should this method return an error?
// Returns nil if there is no data fork or cannot be extracted.
// An error will be sent to the log if it cannot be extracted.
-(NSData *) contentsOfDataForkOfItem:(ShrinkItArchiveItem *)item
{
	NuError nuErr = kNuErrNone;
	NUError *errOut = nil;
	NSData *forkData = nil;
	const NuRecord *pRecord;
	nuErr = NuGetRecord(_pArchive, item.recordIndex.unsignedIntValue, &pRecord);
	//NSLog(@"%s", pRecord->filenameMOR);
	uint32_t which;
	if (item.isDisk) {
		which = kNuThreadIDDiskImage;
	}
	else {
		which = kNuThreadIDDataFork;
	}
	uint32_t size = [self uncompressedForkSize:pRecord
									 forThread:which];
	if (size == 0) {
		// no error output to log
		goto bailOut;					// empty data fork
	}

	NuThread *pThread = GetThread(pRecord, which);
	if (pThread == NULL) {
		// no error output to log
		goto bailOut;
	}

	uint32_t actualThreadEOF = pThread->actualThreadEOF;
	void *dataBuffer = malloc(actualThreadEOF);
	NuDataSink *pDataSink = NULL;
	
	nuErr = NuCreateDataSinkForBuffer(true, kNuConvertOff, (unsigned char *)dataBuffer,
									  actualThreadEOF, &pDataSink);
	if (nuErr != kNuErrNone) {
		errOut = [NUError errorWithCode:nuErr];
		NSLog(@"NuFX library error:%@ for %@", errOut, item.fileName);
		free(dataBuffer);
		dataBuffer = NULL;
		if (pDataSink == NULL) {
			NuFreeDataSink(pDataSink);
		}
		goto bailOut;
	}

	nuErr = NuExtractThread(_pArchive, pThread->threadIdx, pDataSink);
	if (nuErr != kNuErrNone) {
		errOut = [NUError errorWithCode:nuErr];
		NSLog(@"NuFX library error:%@ for %@", errOut, item.fileName);
		free(dataBuffer);
		dataBuffer = NULL;
		if (pDataSink == NULL) {
			NuFreeDataSink(pDataSink);
		}
		goto bailOut;
	}
	if (pDataSink == NULL) {
		NuFreeDataSink(pDataSink);
	}
	forkData = [NSData dataWithBytes:dataBuffer
							  length:actualThreadEOF];
	free(dataBuffer);
bailOut:
	return forkData;
}

// Should this method return an error?
// Returns nil if there is no resource fork or cannot be extracted.
// An error will be sent to the log if it cannot be extracted.
-(NSData *) contentsOfResourceForkOfItem:(ShrinkItArchiveItem *)item {

	NuError nuErr = kNuErrNone;
	NUError *errOut = nil;
	NSData *forkData = nil;
	const NuRecord *pRecord;
	nuErr = NuGetRecord(_pArchive, item.recordIndex.unsignedIntValue, &pRecord);
	uint32_t size = [self uncompressedForkSize: pRecord
									 forThread: kNuThreadIDRsrcFork];
	if (size == 0) {
		// no error output to log
		goto bailOut;					// empty resource fork
	}

	NuThread *pThread = GetThread(pRecord, kNuThreadIDRsrcFork);
	if (pThread == NULL) {
		// no error output to log
		goto bailOut;
	}

	uint32_t actualThreadEOF = pThread->actualThreadEOF;
	void *dataBuffer = malloc(actualThreadEOF);
	NuDataSink *pDataSink = NULL;

	nuErr = NuCreateDataSinkForBuffer(true, kNuConvertOff, (unsigned char *)dataBuffer,
									  actualThreadEOF, &pDataSink);
	if (nuErr != kNuErrNone) {
		errOut = [NUError errorWithCode:nuErr];
		NSLog(@"NuFX library error:%@ for %@", errOut, item.fileName);
		free(dataBuffer);
		dataBuffer = NULL;
		if (pDataSink) {
			NuFreeDataSink(pDataSink);
		}
		goto bailOut;
	}

	nuErr = NuExtractThread(_pArchive, pThread->threadIdx, pDataSink);
	if (nuErr != kNuErrNone) {
		errOut = [NUError errorWithCode:nuErr];
		NSLog(@"NuFX library error:%@ for %@", errOut, item.fileName);
		free(dataBuffer);
		dataBuffer = NULL;
		if (pDataSink) {
			NuFreeDataSink(pDataSink);
		}
		goto bailOut;
	}
	if (pDataSink) {
		NuFreeDataSink(pDataSink);
	}
	forkData = [NSData dataWithBytes:dataBuffer
							  length:actualThreadEOF];
	free(dataBuffer);
bailOut:
	return forkData;
}

#pragma write an item to NuFX document
// This is an internal method; the caller will deal with any error retuned.
- (NuError) addFile:(const char *)srcPath
   usingFileDetails:(NuFileDetails *)pFileDetails
		hasDataFork:(BOOL)hasDataFork
	hasResourceFork:(BOOL)hasResourceFork {

	NuError nuErr = kNuErrNone;
	NuRecordIdx recordIdx;
	if (hasDataFork) {
		//NSLog(@"Write the data fork:%s", srcPath);
		nuErr = NuAddFile(_pArchive, srcPath, pFileDetails, false, &recordIdx);
		if (nuErr != kNuErrNone) {
			//NSLog(@"Error %d adding data fork to file: %s", nuErr, srcPath);
			goto bailOut;
		}
		else {
			//NSLog(@"%s data fork added successfully", srcPath);
		}
	}

	// Is there a way of determining if a file has a resource fork using NufxLib?
	if (hasResourceFork) {
		//NSLog(@"Write the resource fork:%s", srcPath);
		pFileDetails->threadID = kNuThreadIDRsrcFork;
		nuErr = NuAddFile(_pArchive, srcPath, pFileDetails, true, &recordIdx);
		if (nuErr != kNuErrNone) {
			//NSLog(@"Error %d adding resource fork to file: %s", nuErr, srcPath);
			goto bailOut;
		}
		else {
			//NSLog(@"%s resource fork added successfully", srcPath);
		}
		//NSLog(@"%s added successfully", srcPath);
	}

	// We should not do a flush here because the write process will be slow
	// if there are lots of files to be written.
	// The save method in NUDocument will do the needful.
	//u_int32_t status = 0;
	//nuErr = NuFlush(_pArchive, &status);
bailOut:
// caller will deal with the error.
//	if (nuErr != kNuErrNone) {
//		NSLog(@"NuFX error:%d", nuErr);
//	}
	return nuErr;
}

// This should return an error
-(BOOL) addItem:(ShrinkItArchiveItem *)item
	   withPath:(NSString *)srcPath
		  error:(NSError **)errorPtr {

	if (errorPtr != nil) {
		*errorPtr = nil;
	}
	BOOL succeeded = YES;
	NSFileManager *fm = [NSFileManager defaultManager];

	NuFileDetails nuFileDetails;
	memset(&nuFileDetails, 0, sizeof(nuFileDetails));
	// Replace file separator with the correct one
	NSArray *comps = [item.fileName componentsSeparatedByString:@"/"];
	NSString *fsSep = @"/";
	if (item.fileSysInfo == 0x3a) {
		fsSep = @":";
	}
	else if (item.fileSysInfo == 0x2f) {
		fsSep = @"/";
	}
	else if (item.fileSysInfo == 0x5c) {
		fsSep = @"\\";
	}

	NSString *relativePath = [comps componentsJoinedByString:fsSep];
	//NSLog(@"%@ %@", item->fileName,relativePath);
	const char *srcName;
	srcName = [relativePath cStringUsingEncoding:NSUTF8StringEncoding];
	NuDateTime createWhen;
	time_t time1;
	time1 = [item.creationDateTime timeIntervalSince1970];
	UNIXTimeToDateTime(&time1, &createWhen);

	NuDateTime modWhen;
	time1 = [item.modificationDateTime timeIntervalSince1970];
	UNIXTimeToDateTime(&time1, &modWhen);
	NuDateTime archiveWhen;
	time1 =  [item.archivedDateTime timeIntervalSince1970];
	UNIXTimeToDateTime(&time1, &archiveWhen);
	
	// Now fill in NuFX library's NuFileDetails structure
	if (item.storageType == 512 || item.storageType == 524) {
		//NSLog(@"adding a disk image");
		nuFileDetails.threadID = kNuThreadIDDiskImage;
	}
	else {
		nuFileDetails.threadID = kNuThreadIDDataFork;
	}
	nuFileDetails.origName = srcName;
	nuFileDetails.storageNameMOR = srcName;			// v3.0 Mac OS Roman
	nuFileDetails.fileSysID = item.fileSysID;
	nuFileDetails.fileSysInfo = item.fileSysInfo;
	nuFileDetails.access = item.access;
	nuFileDetails.fileType = item.fileType;
	nuFileDetails.extraType = item.auxType;
	nuFileDetails.storageType = item.storageType;
	nuFileDetails.createWhen = createWhen;
	nuFileDetails.modWhen = modWhen;
	nuFileDetails.archiveWhen = archiveWhen;

	// The original code in NuFX library does not allow an Apple GS/OS option list
	// to be added even though it had been preserved by NuShrinkItX.
	// We have added support writing of an option list by modifying NuFX library.
	if (item.optionListSize != 0) {
		nuFileDetails.optionSize = item.optionListSize;
		uint8_t *optionList = malloc(item.optionListSize);
		// We must pass a COPY to the NuFX library ...
		memcpy(optionList, [item.optionListData bytes], [item.optionListData length]);
		// ... and let it take ownership of the pointer.
		// Reason: the "item" (an instance of ShrinkItArchiveItem) may be deallocated
		// before NuFX library gets the pointer returned by [optionListData bytes]
		nuFileDetails.optionList = optionList;
	}
	else {
		nuFileDetails.optionSize	= 0;
		nuFileDetails.optionList	= NULL;
	}
	//NSLog(@"info:$%0x $%0x", item->fileSysInfo, item->fileSysID);
	NSDictionary *attrDict;
	attrDict = [fm attributesOfItemAtPath:srcPath
									error:errorPtr];
	// kiv: return the filemanager error

	BOOL hasDataFork = [attrDict fileSize] > 0 ? true : false;
	ssize_t resourceForkSize = getxattr([srcPath fileSystemRepresentation],
										XATTR_RESOURCEFORK_NAME, NULL, ULONG_MAX, 0, XATTR_NOFOLLOW);

	BOOL hasResourceFork = (resourceForkSize > 0 && resourceForkSize <= ULONG_MAX) ? true : false;

	NuError nuErr = [self addFile:[srcPath cStringUsingEncoding:NSMacOSRomanStringEncoding]
				 usingFileDetails:&nuFileDetails
					  hasDataFork:hasDataFork
				  hasResourceFork:hasResourceFork];
	if (nuErr != kNuErrNone && errorPtr != nil) {
		*errorPtr = [NUError errorWithCode:nuErr];
        succeeded = NO;
	}
bailOut:
	return succeeded;
}

@end
