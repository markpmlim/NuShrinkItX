//
//  NUDocument.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Cocoa
import NuFX

let utiString = "appleii.shrinkit-archive"
// The "rootObjects" property will be adjusted automatically if there are subsequent
// changes to the top level objects are as a result of insertions/deletions.
// In Interface Builder, click on `TreeController` widget, then
// Bindings Inspector -> Content Array -> Bind to: Tree View Controller -> Model Key Path: document.rootObjects
class NUDocument: NSDocument, FileManagerDelegate {

    @objc var rootObjects: NSMutableArray?
    @objc dynamic var fileEntries: [NUTreeRecord]?
    
    // The main window controller could be accessed via the `windowControllers` property.
	var mainWinController: MainWindowController?
    var archiveOnDiskPath: String!      // Full pathname of working directory; never nil
	var isDirty = false
	var originalURL: URL!               // This is never nil.
    var didSave: Bool!                  // Quit will rely on this flag

	override init() {
		//Swift.print("document init:")
		let appDelegate = NSApplication.shared.delegate as! AppDelegate
		// Create a folder for the unpacked ShrinkItArchive files.
        // Ensure `archiveOnDiskPath` has a trailing slash.
		archiveOnDiskPath = appDelegate.uniqueDirectoryInApplicationWorkDirectory()!.path.appending("/")
		rootObjects = NSMutableArray()
		super.init()
	}

    override class var autosavesInPlace: Bool {
		return false
	}

    override class var writableTypes: [String] {
        return ["bse", "bxy", "sea", "sdk", "shk"]
    }

    // Within a class function, we should use `NUDocument.self`
    // Within an instance function, type(of: self) must be used.
    override class func isNativeType(_ type: String) -> Bool {
        // NUDocument should return `FunHouseDocument`
        let supportedTypes = NUDocument.self.writableTypes
        return supportedTypes.contains(type)
    }

    // This func is called by NSDocumentController Open... method.
	override func makeWindowControllers() {
        super.makeWindowControllers()
		// Returns the Storyboard that contains our Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! MainWindowController
		self.addWindowController(windowController)
		mainWinController = windowController
	}

    // All other menu items under the File Menu are not validated here.
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(save(_:)) {
            return true
        }
        return false
    }
    /*
     All items are stored as leaves in a NuFX archive.
     This function will write out the items of the NuFx archive to a physical
     disk device as a directory tree.
     */
	func createArchiveOnDiskWithItems(_ items: NSMutableArray) {

		let fm = FileManager.default
		var outErr: NSError?
		
		for obj in items {
			let item = obj as! ShrinkItArchiveItem
			// It's important the item.separator be set correctly
			let components = item.fileName.components(separatedBy: item.separator)
			let relativePath = NSString.path(withComponents: components)
            // The full pathname of each leaf
			let fullPathName = archiveOnDiskPath.appendingFormat("%@", relativePath)
			if components.count > 1 {
                // The leaf is in a sub-directory; remove the file name of the leaf
				let subDirPath = (fullPathName as NSString).deletingLastPathComponent
				var isDir = ObjCBool(false)
				if !fm.fileExists(atPath: subDirPath, isDirectory: &isDir) {
					//Swift.print("Create containing dir:\(subDirPath)")
                    // subDirPath has no trailing /
					do {
					 try fm.createDirectory(atPath: subDirPath,
					                        withIntermediateDirectories: true,
					                        attributes: nil)
					}
					catch let error as NSError {
						outErr = error
						//Swift.print("createArchiveOnDiskWithItems:\(outErr)")
					}
				}
			}

			// Note: All archived items are stored in a NuFX document as leaves
			//Swift.print("Create file:\(fullPathName)")
			let fileAttr = item.attributes() as NSDictionary
			let dataForkData = item.contentsOfDataFork()
			let rsrcForkData = item.contentsOfResourceFork()

            // Write out the data of the archived item.
			if (dataForkData != nil) {
				fm.createFile(atPath: fullPathName,
				              contents: dataForkData,
				              attributes: nil)
				if rsrcForkData != nil {
					setxattr((fullPathName as NSString).fileSystemRepresentation,
					         XATTR_RESOURCEFORK_NAME, (rsrcForkData! as NSData).bytes,
					         (rsrcForkData!.count), 0, XATTR_NOFOLLOW)
				}
			}
			else {
				// empty data fork
				if (rsrcForkData != nil)
				{	// We have a file with just a resource fork so create an empty file ...
					fm.createFile(atPath: fullPathName,
					              contents: nil,
					              attributes: nil)
					// ... first and then write out its resource fork
					setxattr((fullPathName as NSString).fileSystemRepresentation,
					         XATTR_RESOURCEFORK_NAME, (rsrcForkData! as NSData).bytes,
					         (rsrcForkData!.count), 0, XATTR_NOFOLLOW)
				}
			}
			do {
				try fm.setAttributes(fileAttr as! [FileAttributeKey : Any],
				                     ofItemAtPath: fullPathName)
			}
			catch let error as NSError {
				outErr = error
			}

            // All regular files read from an archive and written to the archive-on-disk
			// must be given extended attributes.
			let extendedAttr = item.extendedAttributes() as NSData
			setxattr((fullPathName as NSString).fileSystemRepresentation, XATTR_NUFX_NAME,
			         extendedAttr.bytes, (extendedAttr.length), 0, XATTR_NOFOLLOW)
		}
	}
	
	// Get the full path names of the list of files and sub-folders under
	// `dirPath` which is the path of the archive-on-disk.
    func absolutePathnamesOfItems(atPath dirPath: String) -> [String]? {

        let fm = FileManager.default
		var fullPaths = [String]()

        var isDir = ObjCBool(false)
		// Check it's a directory; return nil
		if (fm.fileExists(atPath: dirPath, isDirectory:&isDir) && isDir.boolValue) {
            // Process the entire contents of the directory at `dirPath`,
            // including the full path names of sub-directories.
			let dirEnum = fm.enumerator(atPath: dirPath)
			while let relPathOfItem = dirEnum!.nextObject() as? String {
				let fullPathname = dirPath + relPathOfItem
				let url = URL(fileURLWithPath: fullPathname)
				let name = url.lastPathComponent
				let first = name.startIndex
                // Ignore hidden files (probably) created by the OS.
				let hidden = (name[first] == Character("."))
				if (!hidden) {
					fullPaths.append(fullPathname)
				}
			} // while
			return fullPaths
		}
		else {
            //Swift.print("Not a directory")
			return nil
		}
	}

	// All instances of NUTreeObject have a parentObject irrespective of
	// whether they are at the top level or not.
	// We may/may not need to see the "parentObject" property; should have been set
	//  to nil for top level tree objects.
    // For debugging only:
	func traverseTree(_ treeObj: NUTreeObject) {

        //Swift.print(treeObj.pathName, treeObj, terminator:" ")
		if treeObj.parentObject != nil {
            Swift.print(treeObj.parentObject!)
		}
		else {
			Swift.print("no parent object")
		}
        // Do a recursive call down the tree if object is NOT a leaf.
		if (!treeObj.isLeaf) {
			let children = treeObj.children!
			for child in children {
				traverseTree(child as! NUTreeObject)
			}
		}
	}

	// For debugging only:
	func printTree(_ root: NUTreeObject) {
		let children = root.children!
		// Top level child nodes of tree
		for child in children {
			traverseTree(child as! NUTreeObject)
		}
	}

	// We are not handling error recoveries yet.
	// dummy
	override func attemptRecovery(fromError error: Error,
	                              optionIndex recoveryOptionIndex: Int) -> Bool {

        if (recoveryOptionIndex == 0) {
			return true
		}
		return false
	}

    // NSDocument is part of the responder chain.
	// This is called automatically when the "Open Archive..." menu item is selected or when
	// there is a drag-n-drop of an archive document onto this app's icon in the dock.
	override func read(from absoluteURL: URL,
	                   ofType typeName: String) throws {

		let fmgr = FileManager.default
		// Make sure the NuFX document is on a writable medium.
		if !fmgr.isWritableFile(atPath: absoluteURL.path) {
			var infoDict = [String : Any]()
			infoDict[NSLocalizedRecoverySuggestionErrorKey] = "Copy the file to a writable volume."
			infoDict[NSRecoveryAttempterErrorKey] = self		// A dummy method is used
			throw NSError(domain: NSCocoaErrorDomain,
			              code: NSFileWriteVolumeReadOnlyError,
			              userInfo: infoDict)
		}

        // Declare the variable "archive" as a local so it will be deallocated when it goes out of scope.
		var archive: ShrinkItArchive? = nil
		do {
			try archive = ShrinkItArchive(path: absoluteURL.path)
		}
		catch let error as NSError {
			throw NSError(domain: error.domain,
			              code: error.code,
			              userInfo: error.userInfo)
		}

		guard archive != nil else {
			throw NSError(domain: NSOSStatusErrorDomain,
			              code: openErr,
			              userInfo: nil)
		}

		originalURL = absoluteURL
		isDirty = false

        // The tree can be built by using NSFileManager methods including
		// createDirectoryAtPath:withIntermediateDirectories:attributes:error:
		do {
			try archive!.read()
		}
		catch let error as NSError {
			// `error` must be an NuError
			// The readFromURL:ofType: will exit; its caller will handle the error.
			throw NSError(domain: error.domain,
			              code: error.code,
			              userInfo: error.userInfo)
            // In other words, a return is not required after the above throw statement.
		}

    /*  For debugging purposes:
        // Need to publicly declare the property `recordIndexes` of ShrinkItArchive
        let recIndexes = (archive!.recordIndexes)!
        for i in 0..<recIndexes.count {
            let recordIndex = (recIndexes[i] as! NSNumber).int32Value
            var pRecord: UnsafePointer<NuRecord>?        // null pointer
            let nuErr: NuError = NuGetRecord(archive!.pArchive, NuRecordIdx(recordIndex), &pRecord);
            let filename = String(cString:pRecord!.pointee.filenameMOR, encoding: String.Encoding.ascii)
            Swift.print("\(filename)")
        }
    */
		// Read all archived items from NuFX archive.
		let items: NSMutableArray?
		do {
			try items = archive!.items()
		}
		catch let error as NSError {
			items = nil
			throw NSError(domain: error.domain,
			              code: error.code,
			              userInfo: error.userInfo)
		}

		// Check if the file names in the archive are valid for UNIX
		if items != nil &&  archive!.validatePaths(ofItems: items) {
			// Write the archived items to the temporary location including Apple II disk images
			createArchiveOnDiskWithItems(items!)

			// How do we remove the instance of ShrinkItArchive "archive"?
			// Will the instance of ShrinkitArchive be deallocated on exit from this method? - YES
			// Note: NuClose is called by ShrinkitArchive's dealloc method.
			// We don't have to set "archive" to nil since it is a local var; when program
			// execution reaches the end of this method, it will be out of scope and
			// therefore should be deallocated since the strong reference is broken.

			// Now read the names of all files including sub-folders from the archive-on-disk
			// and create the content objects of the NSTreeController.
			//Swift.print("Reading from \(archiveOnDiskPath)")
            let flatLists = absolutePathnamesOfItems(atPath: archiveOnDiskPath)
			self.rootObjects = NUTree.buildWithPaths(flatLists!,
			                                         inDirectory: archiveOnDiskPath)
		}
		else {
			throw NSError(domain: NSOSStatusErrorDomain,
			              code: openErr,
			              userInfo: nil)
		}
	}

	// Called when the "Save" menu item is selected.
	// We are managing the "isDirty" property ourselves instead of relying
	// on OS X. Somehow, updateChangeCount: will trigger of autoSave.
	override func save(to url: URL,
	                   ofType typeName: String,
                       for saveOperation: NSDocument.SaveOperationType,
	                   completionHandler: @escaping (Error?) -> Void) {
        // This block of code is supposed to be called when the `Save` operation completes.
		//Swift.print("saveToURL", url, saveOperation)
        didSave = false                 // assume we fail to save the archive
		let fm = FileManager.default
        //fm.delegate = self
		var isDir = ObjCBool(false)
		var outErr: NSError?

        // First, we have to rename the archive by adding a file extension BAK.
        // Check if a file or folder exists at the disk location
        if (fm.fileExists(atPath: url.path, isDirectory:&isDir))  {
            // We have a folder at the location.
            if isDir.boolValue {
                Swift.print("Oops! Directory at", url)
                return
            }
            else {
                // Proceed to the original file. Ensure there is no folder with the
                // name archive.shk.BAK
                let backupURL = url.appendingPathExtension("BAK")
                //Swift.print(backupURL)
                if fm.fileExists(atPath: backupURL.path,
                                 isDirectory: &isDir) {
                    if isDir.boolValue {
                        Swift.print("A folder exists at:", backupURL)
                        return
                    }
                    else {
                        Swift.print("BAK exists: Deleting ...")
                        do {
                            // The file manager delegate method fileManager(_:shouldRemoveItemAt:)
                            // will be called
                            try fm.removeItem(at: backupURL)
                        }
                        catch let error {
                            // Not called
                            Swift.print("Can't delete the file ...", error)
                            return
                        }
                    }
                }

                do {
                    // Now, attempt to rename the archive.
                    try fm.moveItem(at: url, to: backupURL)
                }
                catch let error {
                    // Put up an alert here.
                    Swift.print("Error: \(error) Can't rename the folder at:", url)
                    return
                }
            }
        }

        // Declaring `archive` as a local means it will be deallocated automatically.
        // NuClose will be called during the deallocation. Refer: ShrinkItArchive.m
		var archive: ShrinkItArchive? = nil
		// Create a new one since the archive had been renamed successfully.
		do {
			try archive = ShrinkItArchive(path: url.path)
		}
		catch let error as NSError {
			NSLog("Can't create the archive for output:\(error)")
            return
		}

		guard archive != nil else {
			//Swift.print("Can't save the document")
			// KIV: let user save somewhere else?
			outErr = NSError(domain: NSOSStatusErrorDomain, code: writErr, userInfo: nil)
			completionHandler(outErr)
			return
		}

		var statusFlags: UInt32 = 0
		// Do we check for errors here?
        var nuErr: NuError = kNuErrNone

		let appDefaults = UserDefaults.standard
		var format = UInt32(appDefaults.integer(forKey: kCompressionFormat))
		format += kNuCompressNone.rawValue
		nuErr = NuSetValue(archive?.pArchive, kNuValueDataCompression, format)
		if (nuErr.rawValue != 0) {
			//Swift.print("Can't set the compression method")
			outErr = NSError(domain: NSOSStatusErrorDomain, code: writErr, userInfo: nil)
			completionHandler(outErr)
			return
		}

		// Only leaves will be saved to the archive.
        // ShrinkIt Archives as proposed by Andy Nicholas don't support
        // a hierarchical structure e.g. a BTree.
		let flatLists = absolutePathnamesOfItems(atPath: archiveOnDiskPath)
		var leaves = [String]()
		for path in flatLists! {
			if (fm.fileExists(atPath: path,
			                  isDirectory:&isDir) && !isDir.boolValue) {
				leaves.append(path)
			}
		}

		// Create the instances of ShrinkItArchiveItem which will be added
		// to the newly-created SHK document or existing NuFX document.
		// Note: For existing documents, all items will be replaced
		//var items = [ShrinkItArchiveItem]()
		let rawMemoryPtr = malloc(Int(XATTR_NUFX_LENGTH))

		// Start index of relative paths
		let index = archiveOnDiskPath.endIndex
		var itemAttrs: NSDictionary?	// = [String : Any]()
		for path in leaves {
			do {
				try itemAttrs = fm.attributesOfItem(atPath: path) as NSDictionary
				// No errors so we can continue.
				let eaSize = getxattr(path, XATTR_NUFX_NAME,
				                      nil, ULONG_MAX, 0, XATTR_NOFOLLOW)
                // Is the extended attribute size zero?
				if (eaSize > 0) {
                    // No
					let bufferPtr = rawMemoryPtr!.bindMemory(to: UInt8.self,
					                                         capacity: Int(XATTR_NUFX_LENGTH))
					memset(bufferPtr, 0, Int(XATTR_NUFX_LENGTH))
					let item = ShrinkItArchiveItem()
                    let range = index..<path.endIndex
                    let relativePath = String(path[range])
					//let relativePath = path.substring(from: index)
                    //Swift.print("relative path", relativePath)
					// Note: the item's "fileName" property has a slash as its file separator;
					// it might be different from that stored in its "fileSysInfo" property.
					// This will be fixed when the method addItem:withPath:error: is called.
					item.fileName = relativePath
					getxattr(path, XATTR_NUFX_NAME,
					         rawMemoryPtr, Int(XATTR_NUFX_LENGTH), 0, XATTR_NOFOLLOW)
					let data = Data(bytes: UnsafePointer<UInt8>(bufferPtr), count: Int(XATTR_NUFX_LENGTH))
					item.setExtendedAttributes(data)
					item.setAttributes(itemAttrs as! [FileAttributeKey : Any])
					do {
						try archive?.add(item, withPath: path)
					}
					catch let error as NSError {
						Swift.print("Can't add \(item.fileName) to the archive \(archive?.pathName):\(error)")
					}
				}
			}
			catch let error as NSError {
				outErr = error
				completionHandler(outErr)
				continue				// try next item.
			}
		} // for

		// Write out every NuFX record to the archive.
		nuErr = NuFlush(archive?.pArchive, &statusFlags)
		if let err = outErr {
			Swift.print("The error should have been displayed", err)
			// KIV: display another error alert?
            return
		}

        free(rawMemoryPtr)

		mainWinController!.setDocumentEdited(false)
		isDirty = false
		// Whether it's an existing or newly-created file, the following works.
		NSDocumentController.shared.noteNewRecentDocumentURL(originalURL!)
		self.mainWinController!.window?.setTitleWithRepresentedFilename(originalURL!.path)
        didSave = true
		//Swift.print("Successfully saved")
	}

	// Completion Handler
	func showSaveError(_ error: Error?) {
		if let err = error {
			let docCountroller = NSDocumentController.shared
			docCountroller.presentError(err)
		}
	}

    // The "Save" button should be enabled whenever document is dirty.
	// Called whenever the application quits or when Command-S is pressed.
    // This is the Objective-C method `saveDocument:`
    // This action is connected to FirstResponder in IB.
	@IBAction override func save(_ sender: Any?) {
        // `sender` is the `Save` menu item of the main NSMenuBar
        // or nil if called from the Application Delegate during an exit.
		//Swift.print("save:", sender)
        // Ensure if the Backup file exist, it is not a folder.
        let fm = FileManager.default
        let backupURL = originalURL.appendingPathExtension("BAK")
        var isDir = ObjCBool(false)
        if fm.fileExists(atPath: backupURL.path,
                         isDirectory: &isDir) {
            if isDir.boolValue {
                let alert = NSAlert()
                alert.alertStyle = .informational
                let folderName = backupURL.lastPathComponent
                let archiveName = originalURL.lastPathComponent
                alert.messageText = NSLocalizedString("A folder with the name \(folderName) exists.", comment: "The alert's messageText")
                alert.informativeText = NSLocalizedString("Please delete or rename it so that the archive \(archiveName) can be saved.",
                                                          comment: "The alert's informativeText")
                let okButtonTitle = NSLocalizedString("OK", comment: "The alert's OK button")
                alert.addButton(withTitle: okButtonTitle)
                alert.runModal()
                didSave = false
                return
            }
        }

        // Overwrite the old file.
		save(to: originalURL!,
		     ofType: utiString,
		     for: .saveOperation,
		     completionHandler: showSaveError)
	}

    /*
     The absolute pathname of each file stored on the user's storage device.
     */
	func readFileEntries() -> [NUTreeRecord] {
		let fm = FileManager.default
		var isDir = ObjCBool(false)
		let flatLists = absolutePathnamesOfItems(atPath: archiveOnDiskPath)
		var leaves = [String]()
		for path in flatLists! {
			if fm.fileExists(atPath: path,
			                 isDirectory:&isDir) && !isDir.boolValue {
				leaves.append(path)
			}
		}

		var records = [NUTreeRecord]()
		for path in leaves {
			let treeRec = NUTreeRecord(path: path,
			                           inDirectory: archiveOnDiskPath)
			records.append(treeRec!)
		}
		return records
	}

    func fileManager(_ fileManager: FileManager, shouldRemoveItemAt URL: URL) -> Bool {
        Swift.print("shouldRemoveItemAt")
        var isDir = ObjCBool(false)

        if (fileManager.fileExists(atPath: URL.path, isDirectory: &isDir)  && isDir.boolValue) {
            // There is a directory with the file extension .BAK
            Swift.print("Should not delete directory", URL.path)
            return false
        }
        return true
    }

}
/*
	// This method is not used anymore;
	// called by saveToURL:ofType:forSaveOperation:completionHandler:
	// whenever the app quit or window closing
	// It tries to save a temporary file  whose url is within the TemporaryItems folder
	override func writeToURL(url: NSURL, ofType typeName: String,
							forSaveOperation saveOperation: NSSaveOperationType,
							originalContentsURL absoluteOriginalContentsURL: NSURL?) throws {
		print("writeToURL", url, typeName)

		let flatLists = absolutePathnamesOfItems(at: workDirName)
		var pathOfLeaves = [String]()
		let fmgr = NSFileManager.defaultManager()
		var outErr: NSError?
		var isDir = ObjCBool(false)
		for path in flatLists! {
			if fmgr.fileExistsAtPath(path, isDirectory: &isDir) && !isDir {
				pathOfLeaves.append(path)
			}
		}
		// create the instances of ShrinkItArchiveItem here. Remember to strip off
		// the path to the working folder on HDD (archive-on-disk)
		var archiveItems = [ShrinkItArchiveItem]()
		let startIndex = (workDirName as String).endIndex
		for pathOfLeaf in pathOfLeaves {
			// remove
			let name = pathOfLeaf.substringFromIndex(startIndex)
			var itemAttrs = [String : AnyObject]()
			do {
				try itemAttrs = fmgr.attributesOfItemAtPath(pathOfLeaf)
			}
			catch let error as NSError {
				outErr = error
			}
			
			let item = ShrinkItArchiveItem()
			item.fileName = name
			let typeCode = UInt32((itemAttrs[NSFileHFSTypeCode]?.unsignedIntegerValue)!)
			item.fileType = (typeCode >> 16) & 0xff
			item.auxType = typeCode & 0xffff
			item.creationDateTime = itemAttrs[NSFileCreationDate] as! NSDate
			item.modificationDateTime = itemAttrs[NSFileModificationDate] as! NSDate
			//NSLog("%@, %0x, %0x %@, %@", item.fileName, item.fileType, item.auxType,
			//	item.creationDateTime, item.modificationDateTime)
			archiveItems.append(item)
		}
		
		var fileAttr: [String : AnyObject]?
		do {
			try fileAttr = fmgr.attributesOfItemAtPath(absoluteOriginalContentsURL!.path!)
		}
		catch let err as NSError {
			outErr = err
			print(err)
		}
		fileAttr![NSFileModificationDate] = NSDate()
		do {
			try fmgr.setAttributes(fileAttr!,
				ofItemAtPath: absoluteOriginalContentsURL!.path!)
		}
		catch let err as NSError {
			outErr = err
			print(err)
		}
	}
*/

