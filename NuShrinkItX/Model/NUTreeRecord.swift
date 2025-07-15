//
//  NUTreeRecord.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//
// The methods of this class are used to format the data into a form
// required by NUTreeObject.

import Cocoa


/*
 An instance of this class is instantiated by an instance of ShrinkItArchive.
 The objects of this class are the `content` of the NSArrayController of TableViewController.
*/
class NUTreeRecord: NSObject {
    // There is no starting / but an ending / if `pathName` is a folder.
    // In this app, it is relative to the archive-on-disk pathname.
    @objc dynamic var pathName: String          // relative path name
	@objc dynamic var fileTypeTxt: String
    @objc dynamic var modificationDate: Date
	var auxTypeTxt: String
	var creationDate: Date
	var format: String
	var size: UInt32
	var access: String
	
	// Look up the string translation of a ProDOS file type
    class func string(from fileType: UInt32) -> String {

		var retStr = String()		// empty string

		if (Int(fileType) < fileTypeNames.count) {
			retStr = fileTypeNames[Int(fileType)]
		}
		else {
			retStr = kUnknownTypeStr
		}
		return retStr;
	}

	// Convert access bits into a String object.
	// If the file's access bits are destroy, rename, and write enabled, it is unlocked.
	// If all three are disabled, it is locked. 
	// Any other combination of access bits is called restricted access.
	class func convert(access: UInt32) -> String {

		var accessStr = String()		// empty string
		accessStr += (access & 0x80) != 0 ? "d" : "-"	// destroy
		accessStr += (access & 0x40) != 0 ? "n" : "-"	// rename
		accessStr += (access & 0x20) != 0 ? "b" : "-"	// backup
		accessStr += (access & 0x04) != 0 ? "i" : "-"	// invisible
		accessStr += (access & 0x02) != 0 ? "w" : "-"
		accessStr += (access & 0x01) != 0 ? "r" : "-"
		return accessStr;
	}

	class func translate(fileSysID sysID: UInt16) -> String {

		let fileSysID = FileSystemFormat(rawValue: UInt32(sysID))
		var sysIDStr = String()		// empty string
		if (fileSysID == .proDOS) {
			sysIDStr = proDOSText
		}
		else if (fileSysID == .dos33) {
			sysIDStr = dos33Text
		}
		else if (fileSysID == .dos32) {
			sysIDStr = dos32Text
		}
		else if (fileSysID == .pascal) {
			sysIDStr = pascalText
		}
		else if (fileSysID == .macHFS) {
			sysIDStr = hfsText
		}
		else {
			sysIDStr = "Unknown";
		}
		return sysIDStr
	}

	// Swift will complain if this is not declared.
	required override init() {
		pathName = ""
		fileTypeTxt = ""
		auxTypeTxt = ""
		creationDate = Date()
		modificationDate = Date()
		format = ""
		size = 0
		access = ""
	}

	// Note: Both path and dirPath are absolute pathnames.
    // `path` is the pathname of the file or sub-directory within the archive-on-disk.
    // NB. No ending / even if it is name of a sub-directory.
    // `dirPath` is the file's folder name relative to the working directory.
	convenience init?(path: String,
	                  inDirectory dirPath: String) {

		self.init()
		//var outErr: NSError?
		var isDir = ObjCBool(false)

		let fm = FileManager.default
		var attrDict: NSDictionary?
		do {
			attrDict = try fm.attributesOfItem(atPath: path) as NSDictionary?
		}
		catch {
			//outErr = error
			//Swift.print("attribute \(outErr) with", path)
			attrDict = nil
			return nil
		}

		var nufxSysID: UInt16 = 0
		if attrDict != nil {
            // Get the size of the extended attribute block first.
			let eaSize = getxattr(path, XATTR_NUFX_NAME,
			                      nil, ULONG_MAX, 0, XATTR_NOFOLLOW)
            // Does this file have extended attribute values?
			if eaSize > 0 {
				let rawMemoryPtr = malloc(eaSize)
				getxattr(path, XATTR_NUFX_NAME,
				         rawMemoryPtr, Int(XATTR_NUFX_LENGTH), 0, XATTR_NOFOLLOW)
				let bufferPtr = rawMemoryPtr!.bindMemory(to: UInt8.self,
				                                         capacity: Int(XATTR_NUFX_LENGTH))
				var nufxAccess: UInt32 = 0
				memcpy(&nufxAccess, UnsafeRawPointer(bufferPtr+4),  4)
				nufxAccess = NSSwapLittleIntToHost(nufxAccess)
				self.access = NUTreeRecord.convert(access: nufxAccess)
				memcpy(&nufxSysID, UnsafeRawPointer(bufferPtr),  2)
				nufxSysID = NSSwapLittleShortToHost(nufxSysID)
				self.format = NUTreeRecord.translate(fileSysID: nufxSysID)
				free(rawMemoryPtr)
			}
			else {
                // defaults.
				self.access = "dnb-wr"
				self.format = "Unknown"
			}

			// NB. "attrDict" must be declared as NSDictionary since we are calling the
			// TypesConvert osxFileAttributes method below.
            // This is a custom dictionary unlike [FileAttributeKey : Any] which is
            // returned by FileManager.
			attrDict = TypesConvert.osxFileAttributes(attrDict as! [String : AnyObject],
			                                          toFileSystem: nufxSysID) as NSDictionary?
			var fileType = (attrDict![PDOSFileType] as! NSNumber).uint32Value
			let auxType = (attrDict![PDOSAuxType] as! NSNumber).uint32Value

			// `path` is the absolute pathname of the file or directory located
            //  on the disk device. We need to remove the archive-on-disk pathname from it.
            // NB. both `path` and `dirPath` has no ending / if item is a folder.
            //Swift.print("\(path), \(dirPath)")
            let index = dirPath.endIndex
            let range = index..<path.endIndex
            let relativePath = String(path[range])
            //let relativePath = path.substring(from: index)
			self.pathName = relativePath
			if fm.fileExists(atPath: path,
			                 isDirectory:&isDir) && isDir.boolValue {
                // Make sure `pathName` ends with a /
				self.pathName = self.pathName + "/"
				fileType = 0x0f     // ProDOS dir type
			}
			self.fileTypeTxt = NUTreeRecord.string(from: fileType)
			self.auxTypeTxt = String(format: "$%04X", auxType)
			self.creationDate = attrDict!.fileCreationDate()!
			self.modificationDate = attrDict!.fileModificationDate()!
			let rsrcSize = getxattr(path, XATTR_RESOURCEFORK_NAME,
									nil, ULONG_MAX, 0, XATTR_NOFOLLOW)
			if rsrcSize <= 0 {
				self.size = UInt32(attrDict!.fileSize())
			}
			else {
				self.size = UInt32(Int(attrDict!.fileSize()) + rsrcSize)
			}
			// KIV: what to do if the path is a compressed disk?
		}
	}
}

