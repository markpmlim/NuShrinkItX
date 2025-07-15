//
//  TableViewController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Cocoa
/**
 Both NSOutlineView and NSTableView classes are sub-classes of NSView.
 NSView adopts the NSDraggingDestination protocol.
 */
class TableViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var nuTableView: NSTableView!
	@IBOutlet weak var arrayController: NSArrayController!  // NUTreeRecord

    // Note: the instance variable below must be preceded by @objc
	@objc dynamic weak var document: NUDocument?

	override var representedObject: Any? {
		didSet {
			// Update the view, if already loaded.
			self.document = representedObject as? NUDocument
		}
	}

	override func viewWillAppear() {
		// This appears neccessary despite the fact it is set in UI element.
		let doc = (self.document! as NUDocument)
        self.arrayController.content = doc.fileEntries
	}

	// Must be done programmatically because the NSSearchField is instantiated in
	// main window controller scene. We couldn't bind the array controller 
	// declared here to the instance of NSSearchField in MainWindowController.
	func fileFilter() {
		let doc = (self.document! as NUDocument)
		let mainWindowController =  doc.mainWinController
		let searchField = mainWindowController!.searchField
		self.arrayController.filterPredicate = NSPredicate(format: "pathName contains[c] %@",
                                                           (searchField?.stringValue)!)
	}

    override func viewDidLoad() {
		// Drag outside application
		self.nuTableView.setDraggingSourceOperationMask(.copy,
                                                        forLocal : false)
	}

    /// Mark: Implementation of NSTableViewDataSource methods
	func tableView(_ tv: NSTableView,
	               writeRowsWith rowIndexes: IndexSet,
	               to pboard: NSPasteboard) -> Bool {

        pboard.declareTypes([.filePromise],
		                    owner:self)
		let prom = [""]
		pboard.setPropertyList(prom,
		                       forType: .filePromise)
		return true
	}

    /*
     Destination can be another outline view or finder.
     For example, we can drag from one or more selected items of the tableview of a window
     of NuShrinkItX to the outlineView of another window of NuShrinkItX.
     */
	func tableView(_ tv: NSTableView,
	               namesOfPromisedFilesDroppedAtDestination dropDestination: URL,
	               forDraggedRowsWith indexSet: IndexSet) -> [String] {

        // Mark the dragged row(s) as selected.
        if indexSet.first != nil {
            self.arrayController.setSelectionIndexes(indexSet)
        }
        var namesOfFiles = [String]()
        let destDirPath = dropDestination.path		// no trailing slash
        let fmgr = FileManager.default
        // NUTreeRecord objects are returned -> we use its `pathName` property
        // to get archived item from the archive
        let selectedObjects = self.arrayController.selectedObjects as! [NUTreeRecord]
        let doc = self.document! as NUDocument
        let workDirPath = doc.archiveOnDiskPath

        for rec in selectedObjects {
            let absSrcPath = workDirPath!.appending(rec.pathName)
            let fileName = (rec.pathName as NSString).lastPathComponent
            namesOfFiles.append(fileName)
            let absDestPath = (destDirPath + "/") + fileName
            let dataFork = fmgr.contents(atPath: absSrcPath)
            var rsrcFork: UnsafeMutableRawPointer? = nil
            let rsrcSize = getxattr(absSrcPath, XATTR_RESOURCEFORK_NAME,
                                    nil, ULONG_MAX, 0, XATTR_NOFOLLOW)
            if rsrcSize > 0 {
                rsrcFork = malloc(rsrcSize)
                getxattr(absSrcPath, XATTR_RESOURCEFORK_NAME,
                         rsrcFork, rsrcSize, 0, XATTR_NOFOLLOW)
            }
            var fileAttr: [FileAttributeKey : Any]?
            do {
                fileAttr = try fmgr.attributesOfItem(atPath: absSrcPath)
            }
            catch _ {
                fileAttr = nil
            }
            if (dataFork != nil) {
                fmgr.createFile(atPath: absDestPath,
                                contents: dataFork,
                                attributes: fileAttr)
                if (rsrcSize > 0) {
                    //NSLog(@"writing resource fork of:%@", destPathName);
                    setxattr(absDestPath, XATTR_RESOURCEFORK_NAME,
                             rsrcFork, rsrcSize, 0, XATTR_NOFOLLOW)
                }
            }
            if (dataFork == nil && rsrcSize > 0) {
                //NSLog(@"File has only a resource fork");
                // KIV: succeed
                fmgr.createFile(atPath: absDestPath,
                                contents: nil,
                                attributes: fileAttr)
                setxattr(absDestPath, XATTR_RESOURCEFORK_NAME,
                         rsrcFork, rsrcSize, 0, XATTR_NOFOLLOW);
            }
            if rsrcFork != nil {
                free(rsrcFork)
            }
        } // for
		return namesOfFiles
	}

}
