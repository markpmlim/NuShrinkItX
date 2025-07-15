//
//  TreeViewControllerPromisedFiles.swift
//  NuShrinkItX
//
//  Created by Mark Lim Pak Mun on 6/26/2025.
//  Copyright © 2025 Mark Lim. All rights reserved.
//

extension TreeViewController {

    // Recursive
    private func copyItem(atNode srcNode: NSTreeNode,
                          toURL destFolderURL: URL) {

        let fmgr = FileManager.default
        // All our files resides under the `workDir` folder which is never NIL.
        guard let workDir = self.document?.archiveOnDiskPath
        else {
            return
        }
        let treeObject = srcNode.representedObject as! NUTreeObject
        // `relSrcPathR` is elative to the working directory.
        let relSrcPath = treeObject.pathName
        // Location where the file is located on the user's disk.
        let absoluteSrcPath = workDir + relSrcPath
        let fileName = treeObject.fileName
        if treeObject.isLeaf {
            let absoluteDestURL = destFolderURL.appendingPathComponent(fileName)
            // Copy file contents and OSX file attributes as well as extended attributes.
            //Swift.print(absoluteSrcPath, absoluteDestURL.path)
            do {
                try copyFile(atPath: absoluteSrcPath,
                             toPath: absoluteDestURL.path,
                             createIfNeeded: false)
            }
            catch let error as NSError {
                (NSApp.delegate as! AppDelegate).reportFileErrors(error)
                return
            }
        }
        else {
            // Visit the parent first; we should create the parent folder
            // before writing out the file contents of its children.
            let temp = (destFolderURL.path as NSString).appendingPathComponent(fileName)
            let fullPathName = temp + "/"
            let newURL = URL(fileURLWithPath: fullPathName)
            do {
                try fmgr.createDirectory(atPath: newURL.path,
                                         withIntermediateDirectories: true,
                                         attributes: nil)
           }
            catch let error as NSError {
                (NSApp.delegate as! AppDelegate).reportFileErrors(error)
                return
            }

            // Proceed to visit the children recursively.
            for i in 0 ..< srcNode.children!.count {
                let childNode = (srcNode.children?[i])! as NSTreeNode
                copyItem(atNode: childNode,
                         toURL: newURL)
            }
        }
    }

    //// Implementation of a method of the NSOutlineViewDataSource protocol.
    // Drop-and-drag to Finder or to another application.
    // The other application must be able to receive the promised files.
    // Deprecated as of macOS 10.13
    func outlineView(_ outlineView: NSOutlineView,
                     namesOfPromisedFilesDroppedAtDestination dropDestination: URL,
                     forDraggedItems items: [Any]) -> [String] {

        var fileNames = [String]()
        for draggedNode in items as! [NSTreeNode] {
            copyItem(atNode: draggedNode,
                     toURL: dropDestination)
            // The user will have remove the extended attributes using
            // the menu item "Cleanup" under the Edit menu.
            let treeObject = draggedNode.representedObject as! NUTreeObject
            fileNames.append(treeObject.fileName)
        }
        return fileNames
    }

    //// Implementation of a method of the NSOutlineViewDataSource protocol
    // User must select the items before dragging and dropping into the trash can.
    func outlineView(_ outlineView: NSOutlineView,
                     draggingSession session: NSDraggingSession,
                     endedAt screenPoint: NSPoint,
                     operation: NSDragOperation) {

        if (operation == .delete) {
            //Swift.print("array of nodes:", self.draggedNodes)
            // Only works if one or more item(s) are selected.
            // The var `clickedRow` will return -1 if no items are selected.
            // We can't call removeItems(at:) because the var `clickedRow` will be -1
            var  srcIndexPaths = [IndexPath]()
            for node in self.draggedNodes! {
                srcIndexPaths.append(node.indexPath)
                deleteItem(at: node)
            }
            treeController.removeObjects(atArrangedObjectIndexPaths: srcIndexPaths)
            fixPaths()
            setDirty()
        }
    }

    // This method can be renamed since it will be called by our instance of MainViewController.
    // This is also called when there is a drag-and-drop from a tableview of a window of this
    // application to the outlineview of another window of NuShrintItX.
    func startDropOperation(_ sender : NSDraggingInfo) -> Bool {

        //Swift.print("startDropOperation")
        var result = false
        self.dirUrlOfPromisedFiles = (NSApp.delegate as! AppDelegate).uniqueDirectoryInApplicationWorkDirectory() as URL?
        //Swift.print(self.dirUrlOfPromisedFiles)
        let fmgr = FileManager.default
        do {
            try fmgr.createDirectory(at: self.dirUrlOfPromisedFiles!,
                                     withIntermediateDirectories: true,
                                     attributes: nil)
        }
        catch {
            (NSApp.delegate as! AppDelegate).reportFileErrors(error as NSError)
            //Swift.print(error)
            return result
        }
        
        // Pass this location to the other application eg CiderXPress/Finder.
        // `promisedFiles` is an array of paths of the top level files/folders at the directory URL
        // Note: the method below is deprecated for macOS 10.14 or later.
        self.promisedFiles = sender.namesOfPromisedFilesDropped(atDestination: self.dirUrlOfPromisedFiles!)
        //Swift.print(self.promisedFiles)

        // Give source application a head start of 2.0 s. Will that work if a large # of
        // files/folders are sent by the source application?
        // Drag and Drop Programming Guide - Dragging File Promises
        // KIV. use a modal dialog box here instead of a timer.

        let currRunLoop = RunLoop.current
        let limitDate = Date(timeIntervalSinceNow: 2.0)
        currRunLoop.run(until: limitDate)
        // Need to figure out a better way to delay until ALL files/folders at in the destination URL.
        // Use a file exit loop or filewatcher or distributed notification?

        result = true
        return result
    }

    func concludeDropOperation(_ sender : NSDraggingInfo) -> Bool {

        //Swift.print("concludeDropOperation")
        var result = true
        let pboard = sender.draggingPasteboard
        let types = pboard.types
        if types?.contains(.filePromise) != nil {
            let fm = FileManager.default
            do {
                // Just remove the temporary folder.
                //Swift.print("Deleting \(String(describing: self.dirUrlOfPromisedFiles))")
                try fm.removeItem(at: self.dirUrlOfPromisedFiles!)
            }
            catch let error as NSError {
                Swift.print("Couldn't delete\(String(describing: self.dirUrlOfPromisedFiles)): error\(error)")
                result = false
            }
        }
        return result
    }

}
