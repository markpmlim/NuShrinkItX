//
//  ShrinkItArchive.h
//  QuickLookSHK
//
//  Created by mark lim on 5/20/15.
//  Copyright 2015 IncrementalInnovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "UserDefines.h"

// This class is used by both QuickLookSHK and SpotlightSHK.
@interface ShrinkItArchive : NSObject 

// Use accessor methods for objects;
@property (strong) NSData            *dataContents;
@property (strong) NSMutableArray    *items;

// public methods.
- (id) initWithPath:(NSString *)path;
- (NSArray *) archiveItems;

// Forward declaration of internal methods.
- (BOOL) masterHeaderAtHeaderOffset:(NSUInteger*)dataOffset;

@end
