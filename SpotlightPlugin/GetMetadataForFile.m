// Modified to call the method GetMetadataForFile instead of GetMetadataForURL
// for backward compatibility with 10.5.x
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h> 
#import <Foundation/Foundation.h>
#import "ShrinkItArchive.h"
#import "ShrinkItArchiveItem.h"

/* -----------------------------------------------------------------------------
   Step 1
   Set the UTI types the importer supports
  
   Modify the CFBundleDocumentTypes entry in Info.plist to contain
   an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes 
   that your importer can handle
  
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 2 
   Implement the GetMetadataForURL function
  
   Implement the GetMetadataForURL function below to scrape the relevant
   metadata from your document and return it as a CFDictionary using standard keys
   (defined in MDItem.h) whenever possible.
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 3 (optional) 
   If you have defined new attributes, update schema.xml and schema.strings files
   
   The schema.xml should be added whenever you need attributes displayed in 
   Finder's get info panel, or when you have custom attributes.  
   The schema.strings should be added whenever you have custom attributes. 
 
   Edit the schema.xml file to include the metadata keys that your importer returns.
   Add them to the <allattrs> and <displayattrs> elements.
  
   Add any custom types that your importer requires to the <attributes> element
  
   <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>
  
   ----------------------------------------------------------------------------- */



/* -----------------------------------------------------------------------------
    Get metadata attributes from file

   This function's job is to extract useful information your file format supports
   and return it as a dictionary
 
 Todo: use GetMetadataForURL.
   ----------------------------------------------------------------------------- */
Boolean GetMetadataForFile(void* thisInterface, 
						   CFMutableDictionaryRef attributes, 
						   CFStringRef contentTypeUTI,
						   CFStringRef pathToFile) {
	@autoreleasepool {
		/* Pull any available metadata from the file at the specified path */
		/* Return the attribute keys and attribute values in the dict */
		/* Return TRUE if successful, FALSE if there was no data provided */
		NSString *path = (__bridge NSString *)pathToFile;
		ShrinkItArchive *archive = [[ShrinkItArchive alloc] initWithPath:path];
		
		if (archive != nil) {
			NSArray *records = [archive archiveItems];
			if (records != nil) {
				NSMutableDictionary *dict = (__bridge NSMutableDictionary *)attributes;
				NSMutableArray *fileNames = [NSMutableArray array];
				NSMutableArray *modDates = [NSMutableArray array];

				for (int i=0; i<records.count; ++i) {
					ShrinkItArchiveItem *item = records[i];
					[fileNames addObject:item.fileName];
					[modDates addObject:item.modificationDateTime];
				}
				dict[@"com_incrementalinnovation_NuShrinkItX_ItemNames"] = fileNames;
				dict[@"com_incrementalinnovation_NuShrinkItX_ItemModDates"] = modDates;
			}
		}
	}
 bailOut:
    return YES;
}
