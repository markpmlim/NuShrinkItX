#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Cocoa/Cocoa.h>

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface,
								 QLThumbnailRequestRef thumbnail,
								 CFURLRef url,
								 CFStringRef contentTypeUTI,
								 CFDictionaryRef options,
								 CGSize maxSize) {

    // We assume all icons are squares
	@autoreleasepool {
		//NSString *utiTypeStr = (__bridge NSString *)contentTypeUTI;
		//NSLog(@"QuickLook UTI:%@", utiTypeStr);
		NSString *path = [(__bridge NSURL *)url path];
		NSString *fileExt = [[path pathExtension] uppercaseString];

		if ([fileExt isEqualToString:@"SHK"] ||
			[fileExt isEqualToString:@"BXY"] ||
			[fileExt isEqualToString:@"SEA"] ||
			[fileExt isEqualToString:@"SDK"] ||
			[fileExt isEqualToString:@"BSE"]) {
			// We are now at 10.10 so we can use the method URLForResource:withExtension:
			NSURL *iconURL = [[NSBundle bundleWithIdentifier: @"com.incrementalinnovation.QuickLookSHK"] URLForResource:@"Archive"
																										  withExtension:@"icns"];
			NSNumber *scaleFactor = [(__bridge NSDictionary *)options valueForKey:(NSString *)kQLThumbnailOptionScaleFactorKey];  // can be >1 on Retina displays
			CGSize desiredSize;
			if (scaleFactor != nil) {
				// will this branch be taken?
				desiredSize = CGSizeMake(maxSize.width * scaleFactor.floatValue,
										 maxSize.height * scaleFactor.floatValue);
			}
			else {
				desiredSize = CGSizeMake(maxSize.width,
										 maxSize.height);
			}

			// Set value of QLThumbnailMinimumSize key of info.plist to 16
			// for system to display small icons of size 16x16.
			// The following might not be necessary. See Quicklook plugin of CiderXPress
			// Will 1024x1024 inter-polated images be generated correctly.
			NSImage *nsImage = [[NSImage alloc] initWithContentsOfURL:iconURL];
			NSAffineTransform *at = [NSAffineTransform transform];	// identity matrix
			NSArray *reps = [nsImage representations];
			NSBitmapImageRep *rep = nil;
			if (desiredSize.height <= 16) {
				// 16x16 icon not displayed.
				rep = reps[4];					// 16 x 16
				[at scaleBy: scaleFactor == nil ? 1.0 : scaleFactor.floatValue];
			}
			else if (desiredSize.height > 16 && desiredSize.height <= 32) {
				rep = reps[3];					// 32 x 32
				[at scaleBy: scaleFactor == nil ? 1.0 : scaleFactor.floatValue];
			}
			else if (desiredSize.height > 32 && desiredSize.height <= 64) {
				rep = reps[2];					// 128 x 128
				[at scaleBy: scaleFactor == nil ? 0.5 : scaleFactor.floatValue];
			}
            else if (desiredSize.height > 64 && desiredSize.height <= 128) {
				rep = reps[2];					// 128 x 128
				[at scaleBy: scaleFactor == nil ? 1.0 : scaleFactor.floatValue];
			}
			else if (desiredSize.height > 128 && desiredSize.height <= 256) {
				rep = reps[1];					// 256 x 256
				[at scaleBy: scaleFactor == nil ? 1.0 : scaleFactor.floatValue];
			}
			else if (desiredSize.height > 256 && desiredSize.height <= 512) {
				rep = reps[0];					// 512 x 512
				[at scaleBy: scaleFactor == nil ? 1.0 : scaleFactor.floatValue];
			}
			else if (desiredSize.height > 512) {
				// retina displays
				rep = reps[0];					// 512 x 512
				[at scaleBy: scaleFactor == nil ? 2.0 : scaleFactor.floatValue];
			}

			NSRect proposedRect = NSMakeRect(0, 0,
											 desiredSize.width, desiredSize.height);
			NSGraphicsContext *context = [NSGraphicsContext currentContext];
			NSDictionary *hints = [NSDictionary dictionaryWithObjectsAndKeys:
									   at, NSImageHintCTM,
									   [NSNumber numberWithUnsignedInt:NSImageInterpolationMedium], NSImageHintInterpolation,
									   nil];
			CGImageRef cgImage = [rep CGImageForProposedRect:&proposedRect
													 context:context
													   hints:hints];
			// Draw the "badge" (file extension). Qn: how to draw in bold.
			NSDictionary *properties = (desiredSize.height > 16 ? [NSDictionary dictionaryWithObject:fileExt
																							  forKey:(NSString *)kQLThumbnailPropertyExtensionKey] : NULL);
			QLThumbnailRequestSetImage(thumbnail,
									   cgImage,
									   (__bridge CFDictionaryRef)properties);
		}
	}
	return kQLReturnNoError;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail) {
    // Implement only if supported
}
