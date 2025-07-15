//
//  SHTreeRecord.h
//  CiderXPress
//
//  Created by mark lim on 1/8/13.
//  Copyright (c) 2013 Incremental Innovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class ShrinkItArchiveItem;
/*
 This model object class converts a C structure into an Objective-C
 object which is then used to create an instance of SHTreeObject.
 */
@interface SHTreeRecord : NSObject 

@property (copy)   NSString     *pathName;
@property (copy)   NSString		*fileName;
@property (copy)   NSString		*fileTypeText;
@property (copy)   NSString		*creationDateTime;
@property (copy)   NSString		*modificationDateTime;
@property (copy)   NSString		*totalSize;

- (id) initWithShrinkitArchiveItem:(ShrinkItArchiveItem *)aRecord;

@end
