//
//  ViewControllerContextualMenu.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Foundation

// In Objective-C parlance, this is a "category" of the ViewController class
// In Interface Build, connect contextual menu to outlineView's "menu" outlet.
extension TreeViewController: NSMenuDelegate {

    // Implementation of an NSMenuDelegate protocol method.
	func menuNeedsUpdate(_ menu: NSMenu) {

        let clickedRow = self.nuOutlineView.clickedRow
		var menuItem: NSMenuItem?

		// On entry, disable every menu item.
        // Note: the tag values of the menu items have been set.
		for i in editAttributesTag...addDiskImageTag {
			menuItem = menu.item(withTag: i)
			menuItem!.isEnabled = false
		}

		if (clickedRow == -1) {
			// Content area - enable add disk image item only.
			menuItem = menu.item(withTag: addDiskImageTag)
			menuItem!.isEnabled = true
			return
		}

		var clickedOnMultipleItems = false
		var treeNode: NSTreeNode?
		clickedOnMultipleItems = (self.nuOutlineView.isRowSelected(clickedRow)) &&
								 (self.nuOutlineView.numberOfSelectedRows > 1)

		if (clickedOnMultipleItems) {
		/*
		 We have a right-click on a selected row & there is at least 1 more selected row.
		 We want to consider all rows in the selection. 
		 */
			menuItem = menu.item(withTag: deleteFilesTag)
			menuItem!.isEnabled = true
		}
		else {
			// Consider only the click-on-row which can be selected or otherwise.
			// Note: there can be a selected row if the click-on-row is not selected.
			// Only consider the click-on-row and ignore the selected row(s).
			treeNode = self.nuOutlineView.item(atRow: clickedRow) as? NSTreeNode
			let isLeaf = treeNode!.isLeaf
			if isLeaf {
				//Swift.print("Right-click on a leaf")
				for i in editAttributesTag...deleteFilesTag {
					menuItem = menu.item(withTag: i)
					menuItem!.isEnabled = true
				}
			}
			else {
                // Delete a folder or allow a disk image to be added to the archive.
				for i in deleteFilesTag...addDiskImageTag {
					menuItem = menu.item(withTag: i)
					menuItem!.isEnabled = true
				}
			}
		}
	}

	// KIV: Batch edit attributes of files.
	// The user is allowed to edit leaves only.
	@IBAction func editAttributes(_ sender: AnyObject) {

		let clickedRow = self.nuOutlineView.clickedRow
		//Swift.print("editAttributes", clickedRow, treeObject)
		let treeNode = self.nuOutlineView.item(atRow: clickedRow) as! NSTreeNode
        attributesWindowController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Attributes Window Controller")) as? AttributesWindowController
		// We need this to access the path of the archive-on-disk.
		attributesWindowController!.document = self.document
		// Setup the attributes window for editing.
		let vc = attributesWindowController!.window!.contentViewController as! AttributesViewController
		// Consider passing "treeObject" instead of "treeNode"
		//let treeObject = treeNode.representedObject as! NUTreeObject
		vc.representedObject = treeNode
		let application = NSApplication.shared
		application.runModal(for: attributesWindowController!.window!)
		// Control will return here when the attributes window closes.
		// Ref: AttributesWindowController delegate method "windowWillClose"
	}

	// Only allow raw disk images to be added to folders or the proxy root folder
	@IBAction func addDiskImage(_ sender: AnyObject) {

		// Need to declare these 4 as var here
		var eaSize: Int
		var absolutePath: String?
		var originalEA: UnsafeMutableRawPointer
		var currentEA: UnsafeMutableRawPointer

		func restoreFileState() {
			// If there is a cancellation, we will still have to either remove
			// the extended attributes or restore the old ones.
			if eaSize < 0 {
				//Swift.print("Removing attr from original file")
				removexattr(absolutePath!, XATTR_NUFX_NAME, XATTR_NOFOLLOW)
			}
			else {
				//Swift.print("Restoring original attr to original file")
				setxattr(absolutePath!, XATTR_NUFX_NAME,
				         originalEA, Int(XATTR_NUFX_LENGTH),
				         0, XATTR_NOFOLLOW)
			}
			//Swift.print("free memory")
			free(originalEA)
			free(currentEA)
		}

		//===== start of main function =====
		let clickedRow = self.nuOutlineView.clickedRow
		var parentIndexPath: IndexPath
		let op = NSOpenPanel()
		op.allowsMultipleSelection = false
		op.canChooseDirectories = false
		let fileTypes = ["do", "po", "dsk", "img"]
		op.allowedFileTypes = fileTypes
		let button = op.runModal()
		if button == .OK {
			absolutePath = op.urls[0].path
		}
		else {
			return
		}

        if (clickedRow == -1) {
			// Click on the content area.
			parentIndexPath = IndexPath()
		}
		else {
			let treeNode = self.nuOutlineView.item(atRow: clickedRow) as! NSTreeNode
			parentIndexPath = treeNode.indexPath
		}

		// Looks like we need to check the size of the file or NuFX won't accept it.
		// We need to know the file size of the disk image early so that
		// the file_sys_block_size (aka storage_type) can be set.
		let fmgr = FileManager.default
		// The var below has to be an NSDictionary because we will call the
		// TypesConvert class method hfsCodes:andAuxType:toFileSystem.
		var fileAttr: NSDictionary?
		do {
			// NB. Extended attributes are not returned by the call below.
			fileAttr = try fmgr.attributesOfItem(atPath: absolutePath!) as NSDictionary
		}
		catch let error as NSError {
			(NSApp.delegate as! AppDelegate).reportFileErrors(error)
			return
		}

		// Warning: disk may have a resource fork attached so the size might be incorrect.
		let diskSize = (fileAttr![FileAttributeKey.size.rawValue] as! NSNumber).uint64Value//
		var fileSysBlockSize: UInt16 = 0
		var numDiskBlocks: UInt64 = 0
		// There are only two officially supported block sizes: 512 and 524
		var rem = diskSize % 524
		if rem == 0 {
			numDiskBlocks = diskSize / 524
			fileSysBlockSize = 524
		}
		rem = diskSize % 512
		if rem == 0 {
			numDiskBlocks = diskSize / 512
			fileSysBlockSize = 512
		}

		let minNumBlocks: UInt64 = 280
		let maxNumBlocks: UInt64 = 4194304
		if fileSysBlockSize == 0 ||
			(numDiskBlocks < minNumBlocks || numDiskBlocks > maxNumBlocks) {
			var infoDict = [String : Any]()
			// message text
			infoDict[NSLocalizedDescriptionKey] = "This disk image cannot be added to the archive"
			// informative text
			if fileSysBlockSize == 0 {
				//print("can't determine the block size")
				infoDict[NSLocalizedRecoverySuggestionErrorKey] = "The block size cannot be determined."
			}
			else if numDiskBlocks < minNumBlocks {
				infoDict[NSLocalizedRecoverySuggestionErrorKey] = "The disk capacity must not be less than 140 KB."
			}
			else if numDiskBlocks > maxNumBlocks {
				infoDict[NSLocalizedRecoverySuggestionErrorKey] = "The disk capacity exceeds 2 GB."
			}
			let buttonTitles = ["OK"]
			infoDict[NSLocalizedRecoveryOptionsErrorKey] = buttonTitles
			let error = NSError(domain: NSOSStatusErrorDomain, code: 0, userInfo: infoDict)
			let alert = NSAlert(error: error)
			alert.runModal()
			return
		}

        // Extended attributes are preseved on HFS+, exFAT-formatted HDD  & APFS.
		// Tag an extended attribute to the original file if it does not have one.
		eaSize = getxattr(absolutePath!, XATTR_NUFX_NAME,
		                  nil, ULONG_MAX, 0, XATTR_NOFOLLOW)
		originalEA = malloc(Int(XATTR_NUFX_LENGTH))
		// Use a working copy to add to the original file.
		currentEA = malloc(Int(XATTR_NUFX_LENGTH))
		var storageType = NSSwapHostShortToLittle(fileSysBlockSize)	// this can be 524
		if eaSize < 0 {
			// Original file does not have an extended attribute
			memcpy(currentEA, (defaultExtendedAttributes as NSData).bytes,
			       defaultExtendedAttributes.count)
		}
		else {
			// Load the file's extended attributes & save it temporarily.
			getxattr(absolutePath!, XATTR_NUFX_NAME,
			         originalEA, Int(XATTR_NUFX_LENGTH), 0, XATTR_NOFOLLOW)
			// Use a working copy
			memcpy(currentEA, originalEA, Int(XATTR_NUFX_LENGTH))
		}
		memcpy(currentEA+8, &storageType, 2);
		setxattr(absolutePath!, XATTR_NUFX_NAME,
		         currentEA, Int(XATTR_NUFX_LENGTH),
		         0, XATTR_NOFOLLOW)

		// Create a property list before calling the method handleDropsFromFinder:withParentIndexPath:
        let pboard = NSPasteboard.general
		let filesList = [absolutePath!]
		//Swift.print(filesList)
		pboard.declareTypes([.filenames],
		                    owner: self)
		pboard.setPropertyList(filesList as AnyObject,
		                       forType: .filenames)
		
		// The user may cancel the drop if there is a duplicate so we need to perform
		// the "calisthenics" of getting, saving & removing the extended attributes.
		// Not only that, we must not modify the UI etc.
		if handleDropsFromFinder(pboard,
		                         withParentIndexPath: parentIndexPath) {
			// A treenode was successfully added so we can proceed to modify the UI.
			var treeNodeAdded: NSTreeNode
			var parentTreeNode: NSTreeNode
			if parentIndexPath.count != 0 {
				parentTreeNode = self.nuOutlineView.item(atRow: clickedRow)! as! NSTreeNode
				// We know the instance of NSTreeNode added happens to be the last child of its parent.
				let numChildren = parentTreeNode.children?.count
				let relativeIndexPath = IndexPath(index: numChildren!-1)
				treeNodeAdded = parentTreeNode.descendant(at: relativeIndexPath)!
			}
			else {
				let proxyRoot = self.treeController.arrangedObjects
				// We know the instance of NSTreeNode added happens to be the last child of its parent.
                let childNodes = proxyRoot.children
				let numChildren = childNodes!.count
				let relativeIndexPath = IndexPath(index: numChildren-1)
				treeNodeAdded = proxyRoot.descendant(at: relativeIndexPath)!
			}

/*
			// Alternatively, we can search the array of child nodes
			let diskName = (absolutePath! as NSString).lastPathComponent
			Swift.print("name of disk image:", diskName)
            // parentTreeNode = self.nuOutlineView.item(atRow: clickedRow)! as! NSTreeNode
            for node in (parentTreeNode.children! as [NSTreeNode]) {
				let name = (node.representedObject as! NUTreeObject).fileName
				if name == diskName {
					Swift.print("Got a hit", node, treeNodeAdded)
					treeNodeAdded = node
				}
			}
*/
			// Now adjust the auxtype
			let treeObjectAdded = treeNodeAdded.representedObject as! NUTreeObject
			let auxType = numDiskBlocks
			//Swift.print(auxType)
			let auxTypeTxt = String(format: "$%04X", auxType)
			treeObjectAdded.willChangeValue(forKey: "auxTypeTxt")
			treeObjectAdded.auxTypeTxt = auxTypeTxt
			treeObjectAdded.didChangeValue(forKey: "auxTypeTxt")
			
			// We must also set the auxtype of the file in the archive-on-disk.
			// Convert ProDOS file/aux types to HFSType and HFSCreator codes
			fileAttr = TypesConvert.hfsCodes(forFileType: 0,
			                                 andAuxType: UInt32(numDiskBlocks),
			                                 toFileSystem: 1) as NSDictionary	// ProDOS, DOS3.x, Pascal
			// Remember the `pathName` property has no starting slash.
			let relativePath = (treeNodeAdded.representedObject as! NUTreeObject).pathName
			let fullPath = self.document!.archiveOnDiskPath + relativePath
			//Swift.print(fullPath)
			var newFileAttr: [FileAttributeKey : Any]
			do {
				// Extended attributes are not returned by the method below.
				newFileAttr = try fmgr.attributesOfItem(atPath: fullPath)
			}
			catch let error as NSError {
				(NSApp.delegate as! AppDelegate).reportFileErrors(error)
				restoreFileState()
				return
			}

            newFileAttr[FileAttributeKey.hfsTypeCode] = fileAttr![FileAttributeKey.hfsTypeCode.rawValue]
			newFileAttr[FileAttributeKey.hfsCreatorCode] = fileAttr![FileAttributeKey.hfsCreatorCode.rawValue]
			do {
				try fmgr.setAttributes(newFileAttr,
                                       ofItemAtPath: fullPath)
				//Swift.print("set attributes successfully")
			}
			catch let error as NSError {
				(NSApp.delegate as! AppDelegate).reportFileErrors(error)
				restoreFileState()
				return
			}
			restoreFileState()
		} // Add disk image succeeded
		else {
			// Either errors encountered or user had cancelled the operation.
			restoreFileState()
		}
	} // addDiskImage

	// User must select one or more rows before doing a right-click
	// NB. right-click (or control-click) to take precedence!
	@IBAction func removeItems(_ sender: AnyObject) {

        let clickedRow = self.nuOutlineView.clickedRow
		var  srcIndexPaths = [IndexPath]()

		if (clickedRow == -1) {
			//Swift.print("content")
			// Click on content area
			return
		}
		else {
            if (clickedRow >= 0 && !self.nuOutlineView.isRowSelected(clickedRow)) {
				//2a) Right-click (control-click) on an item (node) that is not selected.
                let treeNode = self.nuOutlineView.item(atRow: clickedRow) as! NSTreeNode
				//Swift.print("Right-clicked", treeNode)
                deleteItem(at: treeNode)
				srcIndexPaths.append(treeNode.indexPath)

			}
			else {
				// case 2b: All selected items (including the right-clicked item)
				let selectedIndexes = self.nuOutlineView.selectedRowIndexes
				var index = selectedIndexes.first	// changed!
				while (index != nil) {
					let treeNode = self.nuOutlineView.item(atRow: index!) as! NSTreeNode
                    deleteItem(at: treeNode)
					srcIndexPaths.append(treeNode.indexPath)
					index = selectedIndexes.integerGreaterThan(index!)
				}
			}
		}

        self.treeController.removeObjects(atArrangedObjectIndexPaths: srcIndexPaths)
		//printTree()
		fixPaths()
		setDirty()
	}

	private func isTextFile(_ path: String) -> Bool {

		var result = false
		let fmgr = FileManager.default
		var attrDict: NSDictionary?	// Custom Dictionary
		do {
			attrDict = try fmgr.attributesOfItem(atPath: path) as NSDictionary
		}
		catch let error {
			//Swift.print("Can't get file's attributes:", error)
			return result
		}

        attrDict = TypesConvert.osxFileAttributes((attrDict! as! [AnyHashable : Any]),
		                                          toFileSystem: 1) as NSDictionary?	// prodos, pascal, dos3.x
		let fType = (attrDict![PDOSFileType] as! NSNumber).uint32Value
		let aType = (attrDict![PDOSAuxType] as! NSNumber).uint32Value
		let fileExtension = (path as NSString).pathExtension.uppercased()

		let isDocSuffix = fileExtension == "DOC" ||
                          fileExtension == "DOCS" ||
                          fileExtension == "TXT" ||
                          fileExtension == "TEXT"

        let isFileTypeTxt = (fType == 0x04) || (fType == 0xB0)
		let isTeachDoc = (fType == 0x50) && (aType == 0x5445)
		let isTxtFile = isDocSuffix || isFileTypeTxt || isTeachDoc
		if (isTxtFile) {
			result = true
		}
		return result
	}

    /*
     Todo: Preview more file types
     */
	private func isItemBrowsable(atPath path: String) -> Bool {

        var result = false
		if self.isTextFile(path) {
			result = true
		}
		else {
			let fmgr = FileManager.default
			var attrDict: NSDictionary?
			do {
				attrDict = try fmgr.attributesOfItem(atPath: path) as NSDictionary
			}
			catch let error as NSError {
				print("Can't get the file's attributes:", error)
				return result
			}
            attrDict = TypesConvert.osxFileAttributes((attrDict! as! [AnyHashable : Any]),
			                                          toFileSystem: 1) as NSDictionary		// prodos, pascal, dos3.x
			let fType = (attrDict![PDOSFileType] as! NSNumber).uint32Value
			let aType = (attrDict![PDOSAuxType] as! NSNumber).uint32Value
			result = (fType == 0x06) || (fType == 0xFC) || (fType == 0xFF)
		}
		return result
	}

	// Multiple preview windows can be opened any time.
	@IBAction func previewDocument(_ sender: AnyObject) {

        let clickedRow = self.nuOutlineView.clickedRow
		let treeNode = self.nuOutlineView.item(atRow: clickedRow) as! NSTreeNode
		let treeObject = treeNode.representedObject as! NUTreeObject
		let relativePath = treeObject.pathName
		var previewWinController: PreviewWindowController? = nil

		if (treeObject.isLeaf) {
			let winControllers = self.document!.windowControllers
			//Swift.print(winControllers)
			var previewWinTitles = [String]()
            // Use a brute-force method.
            // KIV: use a array filter?
			for obj in winControllers {
				if obj is PreviewWindowController {
					let winTitle = obj.window!.title
					previewWinTitles.append(winTitle)
					//Swift.print(previewWinTitles)
				}
			} // for

			let wTitle = (relativePath as NSString).lastPathComponent
			//Swift.print(wTitle, previewWinTitles.count)
			if previewWinTitles.count == 0 || !previewWinTitles.contains(wTitle) {
				let doc = self.document! as NUDocument
				let workDirPath = doc.archiveOnDiskPath     // has a trailing /
				let absPathOfItem = workDirPath!.appending(relativePath)
                if !isItemBrowsable(atPath: absPathOfItem) {
					Swift.print("Not a text document")
					return
				}

                let storyboard = NSStoryboard(name: NSStoryboard.Name("Secondary"), bundle: nil)
                previewWinController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("PreviewWindowController")) as? PreviewWindowController
				previewWinController!.shouldCloseDocument = false
				//previewWinController!.window!.setTitleWithRepresentedFilename(wTitle)	// bug?
				//Swift.print(previewWinController!.window!.title)
                if previewWinController!.formatDocument(atPath: absPathOfItem) {
					doc.addWindowController(previewWinController!)
					previewWinController!.showWindow(self)
				}
				else {
					// Should we dispose to the preview window controller?
					// Since it's not added to the document's list of windowcontrollers
					// it should be released when it goes out of scope.
					Swift.print("Problem generating listing")
				}
			}
			else {
                // KIV. An alert here instead of printing to console.
				Swift.print("preview window for this document already opened")
			}
		}
	}
}
