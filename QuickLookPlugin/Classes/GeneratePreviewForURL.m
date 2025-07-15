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
		NSString *utiStr = (__bridge NSString *)contentTypeUTI;
		NSString *path = [(__bridge NSURL *)url path];
		NSString *fileExt = [[path pathExtension] uppercaseString];

		// Problem with suffix SEA has been resolved; reserved for macOS StuffIt.
		ShrinkItArchive *shkDoc = [[ShrinkItArchive alloc] initWithPath:path];
		if (shkDoc == nil) {
			//NSLog(@"Problem opening SHK archive");
			goto bailOut;
		}

		NSArray<ShrinkItArchiveItem *> *records = [shkDoc archiveItems];
		if (records != nil) {
			// No problems encountered while extracting the items' info.
			NSMutableString *html = [[NSMutableString alloc] initWithString:@"<!DOCTYPE html>\n"];
			[html appendString:@"<html>\n<head>\n"];
			// attachments
			[html appendString:@"<script type=\"text/javascript\" src=\"cid:jquery.js\">"];
			[html appendString:@"</script>\n"];
			[html appendString:@"<script type=\"text/javascript\" src=\"cid:treeTable.js\">"];
			[html appendString:@"</script>\n"];
			[html appendString:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"cid:style.css\">"];
			// internal css works.
			//[html appendString:@"<style>\nbody {\nbackground-color: powderblue;\n}\n"];
			//[html appendString:@"</style>\n"];
			[html appendString:@"<img src=\"cid:Archive.png\" align=\"right\"><br>"];

			// Load the java scripts to attach to the HTML object.
			NSBundle *bundle = [NSBundle bundleForClass:[ShrinkItArchive class]];
			NSString *jqueryFile = [bundle pathForResource:@"jquery"
													ofType:@"js"];
			NSData *jqueryData = [NSData dataWithContentsOfFile:jqueryFile];
			NSString *ttFile = [bundle pathForResource:@"treeTable"
												ofType:@"js"];
			NSData *ttData = [NSData dataWithContentsOfFile:ttFile];
			NSURL *imgFile = [bundle URLForResource:@"Archive"
									  withExtension:@"png"];
			NSData *imgData = [NSData dataWithContentsOfURL:imgFile];
			NSURL *cssFile = [bundle URLForResource:@"style"
									  withExtension:@"css"];
			NSData *cssData = [NSData dataWithContentsOfURL:cssFile];

			NSDictionary *jqueryProps = @{(__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/javascript",
										  (__bridge NSString *)kQLPreviewPropertyAttachmentDataKey : jqueryData
										};

			NSDictionary *ttProps = @{(__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/javascript",
									  (__bridge NSString *)kQLPreviewPropertyAttachmentDataKey : ttData
									};

			NSDictionary *imgProps = @{(__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"image/png",
									  (__bridge NSString *)kQLPreviewPropertyAttachmentDataKey : imgData
									  };

			NSDictionary *cssProps = @{(__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/css",
									   (__bridge NSString *)kQLPreviewPropertyAttachmentDataKey : cssData
									   };

			NSDictionary *properties = @{	// properties for the HTML data
										 (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
										 (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html",
										 // properties for attaching the JavaScript
										 (__bridge NSString *)kQLPreviewPropertyAttachmentsKey : @{
													@"jquery.js" : jqueryProps,
													@"treeTable.js" : ttProps,
													@"style.css" : cssProps,
													@"Archive.png" : imgProps
												 },
										 };
			[html appendString:@"</head>\n"];

			[html appendString:@"<body>\n<table id=\"table\">\n"];
			//[html appendFormat:@"<caption>\n<b>Contents of %@</b></caption>\n", [path lastPathComponent]];
			// thead => The table header
			// tr => A table row
			// th => A table cell that is a header; defaults to center & bold.
			// td => A table cell that is data
			[html appendString:@"<tr>\n<th>FileName</th>\n<th>File Type</th>\n<th>Date Modified</th>\n<th>Size</th>\n</tr>\n<br>"];
			NSString *tableOutput = [shkDoc preRenderedTreeTable];
			[html appendString:tableOutput];

			[html appendString:@"</table>\n"];

			[html appendString:@"<script type=\"text/javascript\">\n"];
			// The following line will register treetable on the window object("this")
			[html appendString:@"com_github_culmat_jsTreeTable.register(this)\n"];
			// Collapse the entire tree by sending the message "expandLevel" to the treeTable object.
			[html appendString:@"treeTable($('#table')).expandLevel(0)\n"];
			[html appendString:@"</script>\n"];

			[html appendString:@"</body>\n</html>\n"];

			QLPreviewRequestSetDataRepresentation(preview,
												  (__bridge CFDataRef)[html dataUsingEncoding:NSUTF8StringEncoding],
												  kUTTypeHTML,
												  (__bridge CFDictionaryRef) properties);
		}
	}

bailOut:
	return kQLReturnNoError;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}
