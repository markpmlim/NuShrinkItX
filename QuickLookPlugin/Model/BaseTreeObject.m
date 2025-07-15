//
//  BaseTreeObject.m
//  NuShrinkItX
//
//  Created by mark lim on 4/17/13.
//  Copyright 2013 Incremental Innovation. All rights reserved.
//

#import "BaseTreeObject.h"

// Note: instance variables may not be placed in categories.
// Use a class extension to declare the instance variables backing the properties.
@interface BaseTreeObject () {
    // Instance variables backing the properties declared in BaseTreeObject.h
    NSString        *_nodeTitle;
    NSMutableArray  *children;
    BaseTreeObject  *__unsafe_unretained _parentObject;
    BOOL            _isLeaf;
}
@end

@implementation BaseTreeObject

/*
 Init a container (folder/directory/parent object) by default.
 The sub-class must allocate memory for the "children" property.
 */
- (id) init {
    if (self = [super init]) {
        [self setNodeTitle:@"Untitled"];
        [self setChildren:[NSMutableArray array]];        // empty array
        [self setIsLeaf:NO];
    }
    return self;
}

// No need to release the parentObject
- (void) dealloc {
    if (children) {
        children = nil;
    }
}

/*
 Implementation of methods to ensure Key-Value Coding compliance of our class BaseTreeObject
 (Ref: Key-Value Coding Programming Guide)
 */
// Returns the children entries of (folder) entry
// This pair of getter and setter will override the compiler-generated methods.
- (NSMutableArray *) children {
    return children;
}

- (void) setChildren:(NSMutableArray *)newChildren {
    if (children != newChildren) {
        children = [[NSMutableArray alloc] initWithArray:newChildren
                                               copyItems:YES];
    }
}

/*
 Indexed accessor methods to handle objects/items in the array used by the TreeController.
 Reference: Key-Value Coding Programming Guide - Accessor Search Patterns.
 */
- (NSUInteger) countOfChildren {

    if (self.isLeaf)
        return 0;        // A leaf does not have any children
    return [self.children count];
}

- (void) insertObject:(id)object
    inChildrenAtIndex:(NSUInteger)index {

    if (self.isLeaf)
        return;
    [self.children insertObject:object
                        atIndex:index];
}

- (void) removeObjectFromChildrenAtIndex:(NSUInteger)index {
    
    if (self.isLeaf)
        return;
    [self.children removeObjectAtIndex:index];
}


- (id) objectInChildrenAtIndex:(NSUInteger)index {
    if (self.isLeaf)
        return nil;
    return [self.children objectAtIndex:index];
}


- (void) replaceObjectInChildrenAtIndex:(NSUInteger)index
                             withObject:(id)object {
    if (self.isLeaf)
        return;
    [self.children replaceObjectAtIndex:index
                             withObject:object];
}

// To support encoding/decoding
- (NSArray *) keysForEncoding {
    return [NSArray arrayWithObjects:
                    @"isLeaf",
                    @"children",
                    @"parentObject",
                    nil];
}

- (id) copyWithZone:(NSZone *)zone {
    BaseTreeObject *copy = [[[self class] allocWithZone:zone] init];
    
    if (! copy)
        return nil;
    for (NSString *key in [self keysForEncoding]) {
        [copy setValue:[self valueForKey:key]
                forKey:key];
    }
    return copy;
}

- (id) initWithCoder:(NSCoder *)decoder {
    if (!(self = [super init]))
        return nil;
    
    for (NSString *key in self.keysForEncoding) {
        [self setValue:[decoder decodeObjectForKey:key]
                forKey:key];
    }

    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    for (NSString *key in self.keysForEncoding)
        [encoder encodeObject:[self valueForKey:key]
                       forKey:key];
    
}

- (void) setNilValueForKey:(NSString *)key {
    if ([key isEqualToString:@"isLeaf"])
        self.isLeaf = NO;
    else
        [super setNilValueForKey:key];
}
@end
