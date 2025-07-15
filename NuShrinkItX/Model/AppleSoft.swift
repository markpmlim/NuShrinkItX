//
//  AppleSoft.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Foundation

class AppleSoft: NSObject {

	class func listing(_ fileContents: Data) -> String? {

		guard let url = Bundle.main.url(forResource: "AppleSoft",
		                                withExtension: "plist")
		else {
			return nil
		}

		// We have to instantiate using NSDictionary methods.
		guard let dict = NSDictionary(contentsOf: url)
		else {
			return nil
		}

		guard let appleSoftTokens = dict as? Dictionary<String, String>
		else {
			return nil
		}

        let basicListing: String = fileContents.withUnsafeBytes {
            (srcBytes: UnsafeRawBufferPointer) in
            guard let startPtr = srcBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
            else {
                return String()
            }
            var listing = String()
            var linePtr = startPtr          // type: UnsafePointer<UInt8>
            var link: UInt16 = UInt16(linePtr[0]) | (UInt16(linePtr[1]) << 8)
 
            while link != 0 {
                let lineNum = UInt16(linePtr[2]) | (UInt16(linePtr[3]) << 8)
                listing.append(String(format:" %u ", lineNum))
                var bytePtr = linePtr + 4       // skip over the 4-byte header

                while bytePtr[0] != 0 {
                    // Is it an AppleSoft token?
                    if bytePtr[0] > 127 {
                        let key = String(format:"%u", bytePtr[0])
                        //Swift.print(key)
                        // An optional is used to prevent a crash if a key is not in dictionary.
                        if let keyWord = appleSoftTokens[key] {
                            listing.append(String(format:" %@ ", keyWord))
                        }
                        else {
                            // keys 235 - 255 are not recorded in the dictionary.
                            listing.append(" ERROR ")
                        }
                    }
                    else {
                        // Output as is
                        listing.append(String(format:"%c", bytePtr[0]))
                    }
                    bytePtr += 1
                }
                
                // Next AppleSoft line
                listing.append("\n")
                // Assumes AppleSoft program loads at $0801
                linePtr = startPtr + Int(link - 0x801)
                link = UInt16(linePtr[0]) | (UInt16(linePtr[1]) << 8)
            } // while
            return listing as String
        }
        return basicListing
    }
}
