//
//  ShrinkItArchive.h
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NufxLib.h"

@class ShrinkItArchiveItem;

@interface ShrinkItArchive: NSObject {
	// 10.6 or later instance vars need not be declared here
}

@property (assign) NuArchive		*pArchive;				// We don't own this
@property (strong) NSString			*pathName;				// unix pathname

// public methods.
- (instancetype) initWithPath:(NSString *)path
						error:(NSError **)errorPtr;
- (BOOL) readArchive:(NSError **)outError;
- (NSMutableArray *) items:(NSError **)outError;
- (NSData *) contentsOfDataForkOfItem:(ShrinkItArchiveItem *)item;
- (NSData *) contentsOfResourceForkOfItem:(ShrinkItArchiveItem *)item;
- (BOOL) validatePathsOfItems:(NSMutableArray *)items;
- (BOOL) addItem:(ShrinkItArchiveItem *)item
		withPath:(NSString *)srcPath
		   error:(NSError **)errorPtr;

@end
