//
//  TreeViewController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Cocoa
import NuFX
/*
 It is important to note that views can not access their view controllers but the latter can
 access the former using their `view` property

 Both NSOutlineView and NSTableView classes are sub-classes of NSView.
 NSView adopts the NSDraggingDestination protocol.
*/
@objc
class TreeViewController: NSViewController, NSOutlineViewDataSource {

    @IBOutlet weak var nuOutlineView: NSOutlineView!        // Note: We didn't sub-class NSOutlineView.
	@IBOutlet weak var treeController: NSTreeController!    // For outline view
	@IBOutlet weak var outlineViewContextMenu: NSMenu!		// connect to outlineView's menu outlet

    var draggedNodes: [NSTreeNode]?
	var sortDescr: NSSortDescriptor!
	var fileCopyQueue: OperationQueue!                      // KIV

    var dirUrlOfPromisedFiles : URL?
	var promisedFiles: [String]?

    // In Interface Builder, click on `Size` NSTextField widget.
    // Binding Inspector -> Value -> Bind to: Tree View Controller -> Model Key Path -> totalSize.
    // Note: the property must be declared as @objc
    @objc dynamic var totalSize: NSNumber!

    // The instance variable below is set by its associated window controller.
    // On window closing, its value will be set to nil
    // Note: the property must be declared as @objc dynamic
    @objc dynamic weak var document: NUDocument?

    // This property must be set correctly. Refer: MainWindowController.swift
    override var representedObject: Any? {
        didSet {
            self.document = representedObject as? NUDocument
        }
    }

    // Better to put this method here rather than in NUDocument
    func archiveSize() -> NSNumber {
        guard let document = self.document
        else {
            //Swift.print("TreeViewContrller's document property is not set")
            return NSNumber(value: 0 as Int64)
        }

        let workDir = document.archiveOnDiskPath
        let fmgr = FileManager.default
        let dirEnum = fmgr.enumerator(atPath: workDir!)
        var isDir = ObjCBool(false)
        var runningTotal: Int64 = 0

        while let relPathOfItem = dirEnum!.nextObject() as? String {
            // Note: workDir has a trailing slash
            let fullPathname = workDir! + relPathOfItem
            var attr: [FileAttributeKey : Any]? = nil
            if fmgr.fileExists(atPath: fullPathname,
                               isDirectory:&isDir) && !isDir.boolValue {
                // We are only interested in the leaves
                do {
                    // Extended attributes are not returned by the call below.
                    // So, the size does not include the size of the resource fork.
                    attr = try fmgr.attributesOfItem(atPath: fullPathname)
                }
                catch let error as NSError {
                    attr = nil
                    (NSApp.delegate as! AppDelegate).reportFileErrors(error)
                }
                if (attr != nil) {
                    // The size of the resource fork must be obtained separately.
                    runningTotal = runningTotal + Int64((attr![FileAttributeKey.size] as? NSNumber)!.uint64Value)
                    let rsize = getxattr(fullPathname, XATTR_RESOURCEFORK_NAME,
                                         nil, ULONG_MAX, 0, XATTR_NOFOLLOW)
                    if rsize > 0 {
                        runningTotal = runningTotal + Int64(rsize)
                    }
                }
            }
        } // while
        return NSNumber(value: runningTotal as Int64)
    }

	// Tags for the contextual menu items
    // Set in IB
	let editAttributesTag = 0
	let previewDocumentTag = 1
	let deleteFilesTag = 2
	let addDiskImageTag = 3

	var attributesWindowController: AttributesWindowController?

	override func viewDidLoad() {

        sortDescr = NSSortDescriptor(key: "fileName",
                                     ascending: true,
                                     selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        // This will keep the tree objects sorted.
        self.treeController.sortDescriptors = [sortDescr]

        // KIV - for future use
        fileCopyQueue = OperationQueue()
        fileCopyQueue.maxConcurrentOperationCount = 1

        // NSOutlineView adopts the NSDraggingDestination protocol.
        self.nuOutlineView.registerForDraggedTypes([
            .filenames,             // from Safari or Finder
            .filePromise,           // from Safari or Finder (multiple URLs)
            .url])                  // single url from pasteboard
        // Yes to dragging within application
        nuOutlineView.setDraggingSourceOperationMask([.move, .copy],
                                                     forLocal : true)
        // Yes to dragging outside application
        nuOutlineView.setDraggingSourceOperationMask(.copy,
                                                     forLocal : false)
        // NB. Use Identity Inspector to set: TableColumn - Identity - Identifier in Main.storyboard
        //self.nuOutlineView.tableColumn(withIdentifier: "FileName")!.sortDescriptorPrototype = sortDescr
	}

	// This will be called whenever there is a switch from table view to outline view.
	// or during the first appearance of the outline view.
    // or duing minimizing followed by de-minimizes the main window.
	override func viewWillAppear() {
		willChangeValue(forKey: "totalSize")
		self.totalSize = archiveSize()
		didChangeValue(forKey: "totalSize")
	}


	// Mark - support of intra-document drag-n-drop
	func isTreeNode(_ node: NSTreeNode?,
                    descendantOfNode parent: NSTreeNode) -> Bool {

        var treeNode = node
		while treeNode != nil {
			if treeNode == parent {
				return true
			}
			treeNode = treeNode?.parent
		}
		return false
	}

    /// Mark: Implementation of NSOutlineViewDataSource methods
	// Called for intra-, inter-document and to Finder drag-and-drops
	func outlineView(_ outlineView: NSOutlineView,
	                 writeItems items: [Any],
	                 to pboard: NSPasteboard) -> Bool {

        //Swift.print("writeItems:toPasteboard")
        let pbTypes: [NSPasteboard.PasteboardType] = [
            .filenames,
            .filePromise    // supports NSFilesPromisePboardType
        ]
		pboard.declareTypes(pbTypes,
                            owner: self)
        self.draggedNodes = items as? [NSTreeNode]
		let prom = [""]         // no promised file
		pboard.setPropertyList(prom,
		                       forType: .filePromise)
		return true
	}

	// Todo: improve on the drag-and-drop!
	func outlineView(_ outlineView: NSOutlineView,
	                 validateDrop info: NSDraggingInfo,
	                 proposedItem proposedParentItem: Any?,             // The place the drop is hovering over.
	                 proposedChildIndex index: Int) -> NSDragOperation {// The child index the drop is hovering over.

        //Swift.print("validateDrop")
		var result: NSDragOperation = .generic

		if index == NSOutlineViewDropOnItemIndex {
			// The mouse is hovering over a node
			//Swift.print("Hovering over a leaf node")
			return NSDragOperation()			// none
		}

		let draggingSource = info.draggingSource as? NSOutlineView
		if draggingSource == nil {
			//Swift.print("validateDrop from Finder")
			// Drops from Finder: no further checking required.
			return .copy
		}

		// It's either an intra- or inter-document drop
		if (proposedParentItem == nil) {
			// Drops onto the content area.
			if outlineView == draggingSource {
				// Is the user dragging one or more root nodes?
                // The property `arrangedObjects` is actually an array of instances
                // of _NSControllerTreeProxy. It can respond to the following messages:
                // `children` and `descendantNodeAtIndexPath:`
                let proxyRoot = self.treeController.arrangedObjects
				let rootNodes = proxyRoot.children
				let nodes = self.draggedNodes!
				let set1 = NSMutableSet(array: rootNodes!)
				let set2 = NSSet(array: nodes)
				set1.intersect(set2 as Set<NSObject>)

				let duplicates = set1.allObjects
				if duplicates.count != 0 {
					//Swift.print("One or more root nodes are drag and then drop within the content area");
					return NSDragOperation()
				}
				return .move
			}
			// If we get here, it might be a drag-and-drop
			//		a) from another document or
			//		b) from a sub-folder of the same document
			// onto the content area of the destination outlineview.
			return .generic
		}

        // `proposedParentItem` is not NIL
		//let target = (proposedParentItem! as! NSTreeNode).representedObject as! NUTreeObject
		//Swift.print("validateDrop: on folder \(target.pathName) childIndex \(index)")
		// Drops onto a region other than the content area of the destination outlineview.
		if outlineView == draggingSource {
			//Swift.print("validate: internal drop")
			result = .move
			for draggedNode in self.draggedNodes! {
				if isTreeNode((proposedParentItem as! NSTreeNode),
                              descendantOfNode: draggedNode) {
					//Swift.print("validateDrop: Dragging a folder into one of its sub-folders");
					return NSDragOperation()		// none
				}
				else {
					let proposedParent = proposedParentItem as! NSTreeNode
					if draggedNode.parent == proposedParent {
						//Swift.print("validateDrop: Dragging a node within its containing folder");
						return NSDragOperation()	// none
					}
				}
			} // for
		}
		else {
			// drops from another document
			result = .copy
		}
		return result
	}

	// Called also for inter-application drag-and-drops
	func outlineView(_ outlineView: NSOutlineView,
					 acceptDrop info: NSDraggingInfo,
					 item proposedParentItem: Any?,
					 childIndex index: Int) -> Bool {

        //NSLog("acceptDrop")
		var proposedParentIndexPath: IndexPath
		var result = false

		if proposedParentItem == nil {
			//NSLog("AcceptDrop: onto root level")
			proposedParentIndexPath = IndexPath()
		}
		else {
			//NSLog("AcceptDrop: onto folder");
            proposedParentIndexPath = (proposedParentItem as! NSTreeNode).indexPath
		}

		let draggingSource = info.draggingSource as? NSOutlineView
		let pboard = info.draggingPasteboard	// Get the pasteboard
		if draggingSource == nil {
            // The var `draggingSource` is nil if the source is not in the same application
            // as the destination.
			//let types = pboard.types
			//Swift.print("acceptDrop from Finder or another application", types)
			// An app may be returning both NSFilesPromisePboardType and NSFilenamesPboardType
			// for Inter-Application drag-and-drops whereas CiderXPress is only returning
			// NSFilesPromisePboardType. We handle the promised files first.
			if pboard.availableType(from: [.filePromise]) != nil {
				// The user is dragging file-system based objects (some other app).
				//Swift.print("acceptDrop from Another Application: NSFilesPromisePboardType")
				// Use our own procedure to get the other application to copy the files/folders.
				if !startDropOperation(info) {
					var infoDict = [String : Any]()
					// message text
					infoDict[NSLocalizedDescriptionKey] = "The promised files/folders are not available yet. Use the following procedure instead."
					// informative text
					infoDict[NSLocalizedRecoverySuggestionErrorKey] = "Copy the files/folders to Finder's desktop and drag-and-drop from there."
					let buttonTitles = ["Dismiss"]
					infoDict[NSLocalizedRecoveryOptionsErrorKey] = buttonTitles
					let error = NSError(domain: NSOSStatusErrorDomain, code: 0, userInfo: infoDict)
					let alert = NSAlert(error: error)
					alert.runModal()
					result = false
					return result
				}

				var filesList = [String]()
                // Use files/folders at the location `dirUrlOfPromisedFiles` and convert them
                // to NSFilenamesPboardType.
                for file in self.promisedFiles! {
                    let url = self.dirUrlOfPromisedFiles?.appendingPathComponent(file)
					//Swift.print(url)
					filesList.append(url!.path)
				}
				pboard.declareTypes([.filenames],
				                    owner: self)
				pboard.setPropertyList(filesList,
				                       forType: .filenames)
                //let list = pboard.propertyList(forType: .filenames)
                // If it is nil, then we failed!
				//Swift.print("Do we have one:", list)
				result = handleDropsFromFinder(pboard,
                                               withParentIndexPath: proposedParentIndexPath)

				result = concludeDropOperation(info)
			} // filePromised

			// When storyboards are used, we check for drag-and-drops from Finder.
			else if pboard.availableType(from: [.filenames]) != nil {
				// The user is dragging file-system based objects (probably from Finder)
				//Swift.print("acceptDrop from Finder:NSFilenamesPboardType")
				result = handleDropsFromFinder(pboard,
				                               withParentIndexPath: proposedParentIndexPath)
			}
		}
		else if draggingSource == outlineView {
			if pboard.availableType(from: [.filenames]) != nil {
				//NSLog("acceptDrop within Document")
				result = handleInternalDrops(pboard,
                                             withParentIndexPath: proposedParentIndexPath)
			}
		}
		else {
			// NB. The current value of the "draggedNodes" property can't be used
			// because it's the property of the destination outlineview.
			let srcView = draggingSource!.superview
			let tabViewController = srcView!.window!.contentViewController as! NSTabViewController
            let viewController = tabViewController.children[0] as! TreeViewController
			let srcDoc = viewController.document
			// We have to get the source view controller's draggedNodes
			self.draggedNodes = viewController.draggedNodes		// Needs to be set here!
			result = handleInterDocumentDrops(pboard,
                                              fromSourceDocument: srcDoc!,
                                              withParentIndexPath: proposedParentIndexPath)
			// Instead of calling handleInterDocumentDrops, we could setup a propertyList for
			// type NSFilenamesPboardType here
		}
		return result
	}

}


extension NSPasteboard.PasteboardType {

    static let filenames = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    static let url = NSPasteboard.PasteboardType("NSURLPboardType")
}


