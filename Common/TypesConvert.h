//
//  TypesConverter.h
//  SwiftNuShrinkItX
//
//  Created by Mark Lim on 9/1/16.
//  Copyright © 2016 Mark Lim. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *PDOSFileType;
extern NSString *PDOSAuxType;
extern NSString *PDOSAccess;

@interface TypesConvert: NSObject

+ (NSDictionary *) osxFileAttributes:(NSDictionary *)osxAttr
						toFileSystem:(unsigned short)fileSysID;

+ (NSDictionary *) hfsCodesForFileType:(OSType)fileType
							andAuxType:(OSType)auxType
						  toFileSystem:(unsigned short)fileSysID;
@end
