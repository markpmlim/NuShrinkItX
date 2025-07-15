//
//  File.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 9/14/16.
//  Copyright © 2016 Mark Lim. All rights reserved.
//

import Foundation
// UNIXNormalizeFileName ref:Nulib2
// Not unused
class NameNormalization {
	let kForeignIndic = "%"

	class func UNIXNormalizeFileName(_ fileName: String) -> String {
		let destString = String()
		return destString
	}

	// the file system separator can be :, / or \
	class func normalizeProdosPath(_ path: String,
	                               usingFileSystemSeparator fsInfo: Character) {

		let fsSep = String(fsInfo)

		let pathComponents = path.components(separatedBy: fsSep)
	}

	class func normalizeHfsPath(_ path: String,
	                            usingFileSystemSeparator fsInfo: Character) {
	
					let fsSep = String(fsInfo)
		let pathComponents = path.components(separatedBy: fsSep)
					
	
	}

	// We are interested only in the last pathcomponent
	class func normalizeDos3Path(_ path: String,
	                             usingFileSystemSeparator fsInfo: Character) {

					let fsSep = String(fsInfo)
		let pathComponents = path.components(separatedBy: fsSep)
	}

	class func normalizePascalPath(_ path: String,
	                               usingFileSystemSeparator fsInfo: Character) {

					let fsSep = String(fsInfo)
		let pathComponents = path.components(separatedBy: fsSep)
	}

	class func normalizationOfPathName(_ path: String,
	                                   forFileSystemFormat fileSysID : FileSystemFormat,
										usingFileSystemSeparator fsInfo: Character) {
		
			switch(fileSysID) {
			case .proDOS:
				normalizeProdosPath(path,
				                    usingFileSystemSeparator: fsInfo)
				print("prodos")
			
			case .dos33: fallthrough
			case .dos32:
				normalizeDos3Path(path,
				                  usingFileSystemSeparator: fsInfo)
				print("DOS 3")

			case .pascal:
				normalizePascalPath(path,
				                    usingFileSystemSeparator: fsInfo)
				print("Apple Pascal")

			case .macHFS: fallthrough
			case .macMFS:
				normalizeHfsPath(path,
				                 usingFileSystemSeparator: fsInfo)
				print("HFS")
			case .cpm: fallthrough
			case .msDOS: fallthrough
			case .appleShare:
				print("Unsupported")
			default: break
			}
	}
}
