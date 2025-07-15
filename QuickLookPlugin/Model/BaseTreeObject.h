//
//  BaseNode.h
//  NuShrinkItX
//
//  Created by mark lim on 4/17/13.
//  Copyright 2013 Incremental Innovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BaseTreeObject : NSObject <NSCoding, NSCopying>

@property (copy)	            NSString		*nodeTitle;
@property (copy)	            NSMutableArray	*children;
@property (unsafe_unretained)	BaseTreeObject	*parentObject;
@property (assign)	            BOOL			isLeaf;

- (NSArray *) keysForEncoding;

@end
