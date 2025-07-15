//
//  Error.h
//
//  Created by  mark lim on on 2/12/014.
//  Copyright (c) 2014 Interactive Solutions. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "NufxLib.h"

extern NSString *const NufxLibErrorDomain;

@interface NUError : NSError

- (instancetype) initWithCode:(NSInteger)code;

+ (instancetype) errorWithCode:(NSInteger)code;

@end
