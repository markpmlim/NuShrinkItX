//
//  SHTreeObject.h
//  NuShrinkItX
//
//  Created by mark lim on 4/16/13.
//  Copyright 2013 Incremental Innovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BaseTreeObject.h"
@class SHTreeRecord;
/*
 Objects of this class are the content objects of an NSTreeController object.
 */
@interface SHTreeObject : BaseTreeObject 

@property (copy)	NSString		*pathName;
@property (copy)	NSString		*fileName;
@property (copy)	NSString		*fileTypeText;
@property (copy)	NSString		*creationDateTime;
@property (copy)	NSString		*modificationDateTime;
@property (copy)	NSString		*totalSize;
@property (copy)	NSString		*nodeID;        // Use by the
@property (copy)	NSString		*parentNodeID;  // Javascript treeTable.js
@property (assign)	NSUInteger	    levelNumber;

+ (SHTreeObject *) rootTreeObject;
- (SHTreeObject *) initWithRecord:(SHTreeRecord *)rec;
- (BOOL) addToRootObject:(SHTreeObject *)rootObject;

// internal methods
- (BOOL) addChildObject:(SHTreeObject *)entry;
- (SHTreeObject *) childDirectoryWithName:(NSString *)str
                       createIfNotPresent:(BOOL)flag;
- (void) generateNewPaths:(NSString *)prefix;

// for debugging
- (void) printFlatList;

@end
