#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>
#import "ShrinkItArchive.h"
#import "ShrinkItArchiveItem.h"
OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file

 To enable testing via XCode, refer the weblink:
 https://stackoverflow.com/questions/28318688/cannot-debug-my-quicklook-plugin-under-xcode
 
 Use the qlmanage -t (or -t -s someBiggerNumber), if your code for generating thumbnails
 uses QLThumbnailRequestSetThumbnailWithDataRepresentation and is substantially similar
 to the one for previews. If file name is xxxxxx.shk, generated file is xxxxxx.shk.png
 
 qlmanage does not show HTML output properly if debugged under XCode 7 or later.
 Use qlmanage -o dir to output generated HTML to a file that you can inspect with Quicklook from Finder.
 Works but the generation process of file(s) is/are slow.
 If output directory name is /path/to/dir and the file name is xxxxxx.shk, the generated files
 are in the folder /path/to/dir/xxxxxx.shk.qlpreview/
 

   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface,
							   QLPreviewRequestRef preview,
							   CFURLRef url,
							   CFStringRef contentTypeUTI,
							   CFDictionaryRef options) {

	@autoreleasepool {
		NSString *path = [(__bridge NSURL *)url path];
		NSString *fileExt = [[path pathExtension] uppercaseString];
		
		if ([fileExt isEqualToString:@"SHK"] ||
			[fileExt isEqualToString:@"BXY"] ||
			[fileExt isEqualToString:@"BSE"] ||
			[fileExt isEqualToString:@"SDK"] ||
			[fileExt isEqualToString:@"SEA"]) {
			
			ShrinkItArchive *archve = [[ShrinkItArchive alloc] initWithPath: path];
			if (archve == nil) {
				//NSLog(@"Problem opening SHK archive");
				goto bailOut;
			}
			
			NSArray *records = [archve archiveItems];
			if (records != nil) {
				// See html file for the layout of the table
				NSMutableString *htmlOutput = [[NSMutableString alloc] initWithString:@"<!DOCTYPE html>\n"];
				[htmlOutput appendString:@"<html>\n<head>\n<style>\n"];
				[htmlOutput appendString:@"table, th, td {\n"];
				[htmlOutput appendString:@"border: 0;\n}\n"];
				[htmlOutput appendString:@"</style>\n</head>\n<body>\n\n"];
				[htmlOutput appendString:@"<table align =\"left\" cellpadding=\"2\", cellspacing=\"2\", width=\"640\">\n"];
				[htmlOutput appendString:@"<tr>\n<th align=\"center\">Filename</th>\n"];
				[htmlOutput appendString:@"<th align=\"center\">Filetype</th>\n"];
				[htmlOutput appendString:@"<th align=\"center\">Creation Date</th>\n</tr>\n"];
				
				for (int i=0; i<records.count; ++i)
				{
					ShrinkItArchiveItem *item = [records objectAtIndex:i];
					[htmlOutput appendFormat:@"<tr>\n<td>%@</td>\n<td>%@</td>\n<td>%@</td>\n</tr>\n",
						 item.fileName, item.fileType, item.creationDateTime];
					//NSLog(@"%@ %@ %@\n", item.fileName, item.fileType, item.creationDateTime);
				}
				[htmlOutput appendString:@"</table>\n</body>\n</html>\n"];
				CFDictionaryRef properties = (CFDictionaryRef)NULL;
				QLPreviewRequestSetDataRepresentation(preview,
													  (__bridge CFDataRef)[htmlOutput dataUsingEncoding:NSUTF8StringEncoding],
													  kUTTypeHTML,	//kUTTypePlainText
													  properties);
			}
		}
	}
bailOut:
	return kQLReturnNoError;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}
