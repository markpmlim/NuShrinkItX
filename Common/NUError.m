//
//  Error.mn
//
//  Created by  mark lim on on 2/12/014.
//  Copyright (c) 2014 Interactive Solutions. All rights reserved.
//

#import "NUError.h"

@implementation NUError

NSString *const NufxLibErrorDomain = @"com.fadden.NufxLib.ErrorDomain";

- (instancetype) initWithCode:(NSInteger)code {

    NSString *errorTag = @"NuFX Error:";
	int32_t errorCode = (int32_t)code;
  	NSString *errorString = [NSString stringWithCString:NuStrError(errorCode)
											   encoding:NSUTF8StringEncoding];
	NSString *errorMessage = [errorTag stringByAppendingString:errorString];
    NSDictionary *errDict = [NSDictionary dictionaryWithObjectsAndKeys:
								errorMessage, NSLocalizedDescriptionKey,
								errorString, NSLocalizedFailureReasonErrorKey,
								nil];
    return [super initWithDomain:NufxLibErrorDomain
							code:code
						userInfo:errDict];
}

+ (instancetype) errorWithCode:(NSInteger)code {
    return [[NUError alloc] initWithCode:code];
}

@end
