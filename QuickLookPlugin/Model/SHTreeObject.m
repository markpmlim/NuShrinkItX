//
//  SHTreeObject.m
//  NuShrinkItX
//
//  Created by mark lim on 4/16/13.
//  Copyright 2013 Incremental Innovation. All rights reserved.
//

#import "SHTreeObject.h"
#import "SHTreeRecord.h"

// Note: instance variables may not be placed in categories.
// Use a class extension to declare the instance variables backing the properties.
@interface SHTreeObject () {
    // Instance variables backing the properties declared in SHTreeObject.h
    NSString        *_pathName;
    NSString        *_fileName;
    NSString        *_fileTypeText;
    NSString        *_creationDateTime;
    NSString        *_modificationDateTime;
    NSString        *_totalSize;
    NSString        *_nodeID;
    NSString        *_parentNodeID;
    NSUInteger      _levelNumber;       // root level = 0
}
@end

@implementation SHTreeObject

/*
 The pathName of proxy root node is represented by an empty string.
 However, initially it is set to a single slash to denote it is a
 folder and then set to an empty string. This will ensure when the
 pathName property of all tree objects will not have a leading slash.
 There are 2 instances whereby this property must be computed:
 1) when a flat list has missing entries
 2) when there is a drag-and-drop leading to changes in the tree structure.
 No leadingPath is used in this implementation. The proxy root node is
 not to be used other than acting as an anchor for insertion into
 a tree or sub-tree.
 */
+ (SHTreeObject *) rootTreeObject {

    SHTreeRecord *dummy = [[SHTreeRecord alloc] init];
	// We should use string literals which are NSContantString objects.
	dummy.pathName = @"/";
	dummy.fileTypeText = @"DIR";
	dummy.creationDateTime = @"";
	dummy.modificationDateTime = @"";
	dummy.totalSize = @"";
	SHTreeObject *rootObj = [[SHTreeObject alloc] initWithRecord:dummy];

    rootObj.pathName = @"";		// Set to an empty string
	rootObj.fileName = @"";
	return rootObj;
}

/*
 All folder pathnames must end with a slash. This ensures the property isLeaf
 is initialized correctly.
 */
- (SHTreeObject *) initWithRecord:(SHTreeRecord *)aRec {

    self = [super init];
	if (self) {
		// The property isLeaf relies on the "pathName" having a trailing slash.
		// We could use the "isLeaf" property of SHTreeRecord.
        self.isLeaf = ([aRec.pathName hasSuffix:@"/"]) ? NO : YES;
		if (self.isLeaf) {
			// The super class BaseTreeObject has allocated
			// an empty array as part of its init method.
			self.children = nil;
		}

		// `pathName` has a trailing / if the tree object represents a folder.
        self.pathName = [aRec.pathName copy];
		/*
		 NB. `fileName` should not have a trailing slash; removed by the NSString
		 lastPathComponent method.
		 */
		self.fileName = [[self.pathName lastPathComponent] copy];
		self.fileTypeText = [aRec.fileTypeText copy];
		self.creationDateTime = [aRec.creationDateTime copy];
		self.modificationDateTime = [aRec.modificationDateTime copy];
		self.totalSize = [aRec.totalSize copy];
		self.nodeID = [[NSString string] copy];
		self.parentNodeID = [[NSString string] copy];

		// Note: If "patName" has a trailing slash e.g. "child1/",
		// the # of components is 1 more than expected i.e. 2
		self.levelNumber = [[self.pathName pathComponents] count];  // starts from 1

		if (!self.isLeaf) {
			// root level tree objects will be 0-based.
			self.levelNumber--;
		}
	}
	return self;		
}

-(void) dealloc {
	//NSLog(@"Deallocating SHTreeObject:%@", self);
	self.parentObject = nil;			// This is a weak link.
}

// overridden method - add additional keys which are the properties
// of an instance of SHTreeObject. The copyWithZone: method of its super class
// will automatically used the expanded set of keys.
- (NSArray *) keysForEncoding
{
	NSArray *additionalKeys = [NSArray arrayWithObjects:
									@"fileName",
									@"pathName",
									@"fileTypeText",
									@"creationDateTime",
									@"modificationDateTime",
									@"totalSize",
									@"nodeID",
									@"parentNodeID",
									@"levelNumber",
									nil];
	return [[super keysForEncoding] arrayByAddingObjectsFromArray: additionalKeys];
}

// Called by a tree object with another as parameter
- (NSComparisonResult) compare:(SHTreeObject *)other {
	return [[self pathName] localizedCaseInsensitiveCompare:[other pathName]];
}

// The child nodes in the "children" array are maintained in alphabetic order as they are added.
- (BOOL) addChildObject:(SHTreeObject *)entry {
    if (!self.children)				// Not a folder
		return NO;
    [self.children addObject:entry];
	entry.parentObject = self;	// Receiver is the parent of added entry.
    [self.children sortUsingSelector:@selector(compare:)];
    return YES;
}


/*
 May create a sub-folder entry. Returns nil if the receiver is a leaf or
 the targeted "str" is not found.
 However, if the "createIfNotPresent" flag is YES, a sub-folder entry will
 will created provided it does not exist and the receiver is itself a parent
 entry.
 */
- (SHTreeObject *) childDirectoryWithName:(NSString *)str
					   createIfNotPresent:(BOOL)flag {

    SHTreeObject *childObject = nil;
    for (SHTreeObject *entry in self.children) {
		// Scan through the list of (the receiver's) children for a folder
		// (sub-folder) entry with the targeted "str"
        if ([[entry fileName] isEqualToString:str] && ![entry isLeaf]) {
			// There is a folder/sub-folder entry with the targeted "str".
            childObject = (SHTreeObject *)entry;
			break;
        }
    } // for

	// This branch may not be taken if all pathnames are already in depth-first traversal.
	// e.g. folder1, folder1/file1, folder1/file2, folder2/file1, folder3/file1, etc.
    if (!childObject && flag && !self.isLeaf) {
		// Create a sub-folder entry if it does not exist.
		// NB. A trailing slash is added to indicate it's a directory entry.
		SHTreeRecord *aRec = [[SHTreeRecord alloc] init];
		aRec.pathName = [[[self pathName] stringByAppendingPathComponent:str] stringByAppendingString:@"/"];
		//NSLog(@"Create a non-leaf tree object: %@", aRec.pathName);
		//aRec.fileTypeText = [NSString stringWithString:@"DIR"];
		aRec.fileTypeText = @"DIR";
		aRec.creationDateTime = @"";
		aRec.modificationDateTime = @"";
		aRec.totalSize = @"";
		childObject = [[SHTreeObject alloc] initWithRecord:aRec];
		//NSLog(@"Create folder %@", [childNode pathName]); 
		[self addChildObject:childObject];
    }
	// "childObject" might be nil if receiver is a leaf.
    return childObject;
}

/*
 Insert a tree object to the tree structure starting from the root; the 
 tree object must be created first before it is added to the tree.
 The parameter `rootObject` cannot be nil; it should be the proxy root
 created by a call to the method initRootObject.
 */
- (BOOL) addToRootObject:(SHTreeObject *)rootObject {
 
    SHTreeObject *directoryEntry = rootObject;
	NSString *leadingPath = [[self pathName] stringByDeletingLastPathComponent];	// name of folders including proxy root
	NSArray *components = [leadingPath pathComponents];

	/*
	 We use a for-loop to descend the directory tree, creating
	 any sub-folder(s) if necessary.
	 */
    for (NSString *component in components) {
		// If a component (which represents a folder name) is NOT the proxy
		//  root (which is signified by a single /), create it if necessary.
		directoryEntry = [directoryEntry childDirectoryWithName:component
											 createIfNotPresent:YES];
    }
    return directoryEntry ? [directoryEntry addChildObject:self] : NO;
}

// Generate a new path name and file name for each node of the tree;
// the prefix parameter cannot be null ie ""
-(void) generateNewPaths:(NSString *)prefix {
	if ([self isLeaf]) {
		//NSLog(@"Leaf:%@ %@", prefix, [self fileName]);
		NSString *newPath = [prefix stringByAppendingString:self.fileName];
		self.fileName = [newPath lastPathComponent];    // not necessary
		self.pathName = newPath;
		//NSLog(@"Path of Leaf:%@", newPath);
	}
	else {
		//NSLog(@"Folder: %@ %@", prefix, [self fileName]);
		NSString *newPath = [prefix stringByAppendingString:self.fileName];
		self.fileName = [newPath lastPathComponent];	// not necessary
		self.pathName = [newPath stringByAppendingString:@"/"];
		NSString *newPrefix = [newPath stringByAppendingString:@"/"];
		//NSLog(@"Path of Folder: %@", newPrefix);
		for (id obj in [self children]) {
			[obj generateNewPaths:newPrefix];
		}
	}
}

#pragma mark for debugging
// -(void) printFlatList:(NSInteger)depth
-(void) printFlatList {
	if ([self isLeaf]) {
		NSLog(@"  Leaf:%@  fullPath:%@", [self fileName], [self pathName]);
	}
	//NSLog(@"Leaf:%@", [self path]);
	else {
		NSLog(@"Folder:%@  fullPath:%@", [self fileName], [self pathName]);
		//NSLog(@"Folder:%@", [self path]);
		for (id obj in [self children])
			[obj printFlatList];
	}
}

/*
-(void) printTree
{
	if ([self isLeaf]) {
        NSLog(@"Parent: %@ Leaf: %@", [[self parentObject] path], [self path]);
	}
	else {
		NSLog(@"Parent: %@   Folder:%@", [[self parentObject] path], [self path]);
		for (id obj in [self children])
			[obj printTree];
	}
}
*/

@end
