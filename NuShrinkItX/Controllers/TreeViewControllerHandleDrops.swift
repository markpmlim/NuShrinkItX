//
//  ViewControllerHandleDrops.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Foundation
import NuFX

/*
 The extension has the source code of the methods of handling drops onto the destination OutlineView.
 The term `top level` of the proxy root is the root level of the directory tree.
 On the other hand, `top level` of a folder refers to the level of its immediate children.
 */
extension TreeViewController {

    /*
     Just put up an alert
     */
    private func replaceDuplicates() -> Bool {

        var infoDict = [String : Any]()
        // message text
        infoDict[NSLocalizedDescriptionKey] = "There are duplicate items at the drop destination"
        // informative text
        infoDict[NSLocalizedRecoverySuggestionErrorKey] = "Replaced items cannot be restored"
        let buttonTitles = ["Cancel", "Replace"]
        infoDict[NSLocalizedRecoveryOptionsErrorKey] = buttonTitles
        let error = NSError(domain: NSOSStatusErrorDomain, code: 0, userInfo: infoDict)
        let alert = NSAlert(error: error)
        let result = alert.runModal()
        if result == .alertFirstButtonReturn {
            // Cancel
            return false
        }
        else {
            return true
        }
    }

    // Allows for rearrangement of the tree structure.
	func handleInternalDrops(_ pboard: NSPasteboard,
	                         withParentIndexPath parentIndexPath: IndexPath) -> Bool {

        var result: Bool = false

		//Swift.print(pboard, destIndexPath, self.draggedNodes)
        // The following vars are used to check for duplicate names at the destination.
		var topLevelNames = [String]()
		var topLevelDict = [String : IndexPath]()

        /*
         There are only 2 cases. The dragged nodes are added
         a) to a tree node which becomes their parent node,
         b) at the root level of the directory tree.
         */
        let proxyRoot = self.treeController.arrangedObjects
        // `newParentNode` is the node which the dragged nodes will be attached to.
        // It is actually an instance of NSTreeControllerTreeNode (a sub-class of NSTreeNode)
        // and is a private class.
        let newParentNode = proxyRoot.descendant(at: parentIndexPath)
        if newParentNode != nil {
			for node in (newParentNode?.children)! {
				let treeObject = (node.representedObject as! NUTreeObject)
				topLevelNames.append(treeObject.fileName)
				topLevelDict[treeObject.fileName] = node.indexPath
			}
		}
		else {
            // The dragged nodes will be added as roots of the directory tree.
			let childNodes = proxyRoot.children
			for node in childNodes! {
				let treeObject = (node.representedObject as! NUTreeObject)
				topLevelNames.append(treeObject.fileName)
				// Index paths can not be nil even for nodes at the root level.
				topLevelDict[treeObject.fileName] = node.indexPath
			}
		}

        //Swift.print(topLevelNames)
		var newTopLevelNames = [String]()
        for node in self.draggedNodes! {
			let treeObject = (node.representedObject as! NUTreeObject)
			newTopLevelNames.append(treeObject.fileName)
		}

        //Swift.print(newTopLevelNames)
		// Need to remove the old files/folders at destination folder
		// by comparing the names for duplicates.
		let duplicateNames = topLevelNames.filter(newTopLevelNames.contains)
		var removeIndexPath = [IndexPath]()
		if (duplicateNames.count != 0) {
			if !replaceDuplicates() {
                Swift.print("cancelled")
				return result
			}
			else {
                // Only the top-level nodes will be considered.
                // NuShrinkItX does not do a deep enumeration.
				for name in duplicateNames {
					removeIndexPath.append(topLevelDict[name]!)
					//Swift.print(name, topLevelDict[name])
				}
			}
		}

		//Swift.print(removeIndexPath)
		// Remove the old nodes with duplicate filenames
		if (removeIndexPath.count != 0) {
			self.treeController.removeObjects(atArrangedObjectIndexPaths: removeIndexPath)
		}

        // Move the files and sub-folders.
        var absolutePathDestDir: String             // The absolute path name of the destination directory.
		// Get the absolute pathname of the archive-on-disk.
        let workDir = self.document!.archiveOnDiskPath
		if (newParentNode == nil) {
			//Swift.print("Drop onto content area")	// root level
			absolutePathDestDir = workDir!
		}
		else {
			//Swift.print("Drop onto a root level folder/a non-root folder")
			let relDirPath = (newParentNode?.representedObject as! NUTreeObject).pathName
			absolutePathDestDir = workDir! + relDirPath
		}

		//Swift.print(absolutePathDropDir)
		let fmgr = FileManager.default

        // We don't have to use instances of FileOperation here since moves
		// are very fast as no data are copied. The macOS changes the links.
		var isDir = ObjCBool(false)
        for node in self.draggedNodes! {
			let relPath = (node.representedObject as! NUTreeObject).pathName
			let oldPath = workDir! + relPath
			let newPath = absolutePathDestDir + (node.representedObject as! NUTreeObject).fileName
			//Swift.print("moving ", oldPath, " to ", newPath)
			if fmgr.fileExists(atPath: newPath,
			                   isDirectory: &isDir) {
				do {
                    // Remove the duplicate items first.
                    // If the item is a directory, the contents of that directory are recursively deleted.
					try fmgr.removeItem(atPath: newPath)
				}
				catch let error as NSError {
					print("Could not delete the item:", error)
					(NSApp.delegate as! AppDelegate).reportFileErrors(error)
					return result
				}
			}

            do {
				// Checked: all extended attributes are included in the move.
				try fmgr.moveItem(atPath: oldPath, toPath: newPath)
			}
			catch let error as NSError {
                Swift.print("Could not move the item:", error)
				(NSApp.delegate as! AppDelegate).reportFileErrors(error)
				return result
			}
		} // for

		// We need to compute the indexPaths of the tree nodes to be moved.
		var numChildren: Int
		var moveIndexPath: IndexPath
		if (parentIndexPath.count != 0) {
			// Drop into a root level folder/a sub-folder; we add the nodes to the end.
            //Swift.print("Drop into a folder")
			numChildren = newParentNode!.children!.count
			moveIndexPath = parentIndexPath.appending(numChildren)
		}
		else {
			// Drops at the root level requires the proxy root which responds to a `children` message.
			// Since the length of parentIndexPath == 0 & the `newParentNode` var is nil ...
			let childNodes = proxyRoot.children
			numChildren = childNodes!.count
			// ... so we have compute moveIndexPath differently.
			moveIndexPath = IndexPath(index: numChildren)
		}

        self.treeController.move(self.draggedNodes!,
                                 to: moveIndexPath)

		// Now fix the `parentObject` and other properties.
		fixPaths()
		setDirty()
		// Keep the files sorted.
		self.treeController.rearrangeObjects()
		//printTree()
        result = true
        return result
	}


	// `parentIndexPath` is indexPath of the destination folder which will become
	// the parent folder for all those files/sub-folders dragged from Finder.
	func handleDropsFromFinder(_ pboard: NSPasteboard,
	                           withParentIndexPath parentIndexPath: IndexPath) -> Bool {

        // Absolute pathnames of the files/sub-folders dragged from Finder to the ShrinkIt archive.
		guard let absoluteSrcPaths = pboard.propertyList(forType: .filenames) as? [String]
        else {
            return false
        }
        let fmgr = FileManager.default
        // `workDir` is the full pathname of the archive-on-disk folder.
        let workDir = self.document?.archiveOnDiskPath
        let parentNode = self.treeController.arrangedObjects.descendant(at: parentIndexPath)
        // The following vars are used to check for duplicate names at the destination.
        var topLevelNames = [String]()
        var topLevelDict = [String: IndexPath]()
        if parentNode != nil {
            // Drop onto a folder of the destination directory tree.
            // The folder could be at the root level.
            for node in (parentNode?.children)! {
                let treeObject = (node.representedObject as! NUTreeObject)
                topLevelNames.append(treeObject.fileName)
                topLevelDict[treeObject.fileName] = node.indexPath
            }
        }
        else {
            // Drop onto the root level of destination directory tree.
            let proxyRoot = self.treeController.arrangedObjects
            let childNodes = proxyRoot.children
            for node in childNodes! {
                let treeObject = (node.representedObject as! NUTreeObject)
                topLevelNames.append(treeObject.fileName)
                // Indexpaths can not be nil even for nodes at the root level.
                topLevelDict[treeObject.fileName] = node.indexPath
            }
        }
        //Swift.print(topLevelNames)

        var newTopLevelNames = [String]()
        for absSrcPath in absoluteSrcPaths {
            let name = (absSrcPath as NSString).lastPathComponent
            newTopLevelNames.append(name)
        }
        //Swift.print(newTopLevelNames)

        // Compare the names for duplicates and return them
        let duplicateNames = topLevelNames.filter(newTopLevelNames.contains)
        var removeIndexPaths = [IndexPath]()
        if (duplicateNames.count != 0) {
            if !replaceDuplicates() {
                //Swift.print("cancelled")
                return false
            }
            else {
                for name in duplicateNames {
                    removeIndexPaths.append(topLevelDict[name]!)
                    //Swift.print(name, topLevelDict[name])
                }
            }
        }
        //Swift.print(removeIndexPath)

        var destinationDirPath: String      // The destination folder of the drop
        // Note: `destinationDirPath` is relative to the proxy root of the directory tree.
        if (parentIndexPath.count > 0) {
            // Drop onto a folder of the directory tree; it can be one of
            // root level folders of the multi-rooted tree.
            //Swift.print("Drop onto a root level folder/sub-folder")
            let treeObject = parentNode?.representedObject as! NUTreeObject
            destinationDirPath = treeObject.pathName		// has a trailing slash
        }
        else {
            //Swift.print("Drop onto content area or in between root level nodes")
            destinationDirPath = String()				// empty string
        }

        //Swift.print(destinationDirPath)

        // `absoluteDestPaths` is the array of absolute pathnames that will be used to build
        // an array of NUTreeObjects.
        // Only leaves will be added to the `absoluteDestPaths` array.
        var absoluteDestPaths = [String]()
 
        for absSrcPath in absoluteSrcPaths {
           var isDir = ObjCBool(false)
            if fmgr.fileExists(atPath: absSrcPath,
                               isDirectory: &isDir) && isDir.boolValue {
                do {
                    // All `absSrcPath` that are the paths of folders will be used to create
                    // the top level folders of the proxy root of a sub-tree.
                    // Create a top level folder under destination folder.
                    let absoluteDestDirPath = workDir! + destinationDirPath + (absSrcPath as NSString).lastPathComponent
                    //Swift.print("Create dir:", absoluteDestDirPath)
                    try fmgr.createDirectory(atPath: absoluteDestDirPath,
                                             withIntermediateDirectories: true,
                                             attributes: nil)
                }
                catch let error as NSError {
                    //Swift.print("Could not create a top level folder under the destination folder:", error)
                    (NSApp.delegate as! AppDelegate).reportFileErrors(error)
                    return false
                }

                // Process all files/sub-folders within the top level of the source folder.
                // Note: if this source folder is empty, the corresponding dest folder will not be created.
                // `dirEnum` has methods for obtaining attributes of paths etc.
                let dirEnum = fmgr.enumerator(atPath: absSrcPath)
                // The values of `relPathOfItem` will be relative to `absSrcPath` (which is a folder)
                while let relPathOfItem = dirEnum!.nextObject() as? String {
                    // Assumes `absSrcPath` has no trailing slash. The path names of folders
                    // returned by FileManager do not have trailing slashes.
                    let absoluteSrcPathOfItem = absSrcPath + "/" + relPathOfItem
                    // `destRelativePath` will be relative to the destination folder.
                    let destRelativePath = (absSrcPath as NSString).lastPathComponent + "/" + relPathOfItem
                    //Swift.print("src", absoluteSrcPathOfItem)
                    //Swift.print("dest", destRelativePath)
                    if fmgr.fileExists(atPath: absoluteSrcPathOfItem,
                                       isDirectory: &isDir) && isDir.boolValue {
                        do {
                            // `absoluteSrcPathOfItem` is the path name of a sub-folder of `absSrcPath`.
                            // It also means `absoluteDestPath` is the path name of a folder.
                            let absoluteDestPath = workDir! + destinationDirPath + destRelativePath
                            //Swift.print("Create sub-dir:", absoluteDestPath)
                            // Create the corresponding destination folder of `absoluteSrcPathOfItem`
                            try fmgr.createDirectory(atPath: absoluteDestPath,
                                                     withIntermediateDirectories: true,
                                                     attributes: nil)
                        }
                        catch let error as NSError {
                            //Swift.print("Error \(error) creating the sub-dir")
                            (NSApp.delegate as! AppDelegate).reportFileErrors(error)
                            return false
                        }
                        // Note: we don't append the absolute path of the newly-created sub-folder.
                        // The folder exists within the archive-on-disk but if it's empty,
                        // it will not be displayed in the UI.
                    }
                    else {
                        // Read and write a leaf
                        // `absoluteSrcPathOfItem` is the path name of an ordinary file.
                        let absoluteDestPath = workDir! + destinationDirPath + destRelativePath
                        let name = (absoluteDestPath as NSString).lastPathComponent
                        let first = name.startIndex
                        let hidden = (name[first] == Character("."))
                        if (!hidden) {
                            do {
                                //Swift.print("read", absoluteSrcPathOfItem, "write", absoluteDestPath)
                                try copyFile(atPath: absoluteSrcPathOfItem,
                                             toPath: absoluteDestPath,
                                             createIfNeeded: true)
                            }
                            catch let error as NSError {
                                (NSApp.delegate as! AppDelegate).reportFileErrors(error)
                                return false
                            }
                        }
                        absoluteDestPaths.append(absoluteDestPath)
                    }
                } // while
            }
            else {
                // We have a leaf at the top level of the destination folder.
                var relPathOfItem: String
                let fileName = (absSrcPath as NSString).lastPathComponent
                if ((parentIndexPath as NSIndexPath).length > 0) {
                    // Read and write a leaf within a root level folder/sub-folder.
                    relPathOfItem = destinationDirPath + fileName
                }
                else {
                    // Read and write a leaf at root level of directory tree
                    // `destinationDirPath` should be an empty string
                    relPathOfItem = fileName
                }

                // "absoluteDestPath" is a location on the HDD
                let absoluteDestPath = workDir! + relPathOfItem
                //Swift.print("read", srcPath, "write", absoluteDestPath)
                do {
                    //Swift.print("read", absoluteSrcPathOfItem, "write", absoluteDestPath)
                    try copyFile(atPath: absSrcPath,
                                 toPath: absoluteDestPath,
                                 createIfNeeded: true)
                    absoluteDestPaths.append(absoluteDestPath)
                }
                catch let error as NSError {
                    (NSApp.delegate as! AppDelegate).reportFileErrors(error)
                    return false
                }
            }
        } // for
        
        // At this point, we should have finish copying all files to their respective disk locations.
        // Compute the index paths of the tree nodes to be created within the directory tree.
        var dropIndexPath: IndexPath
        if (parentIndexPath.count > 0) {
            //Swift.print("A root level folder/some sub-folder")
            let numChildren = parentNode!.children!.count
            dropIndexPath = parentIndexPath.appending(numChildren)
        }
        else {
            //Swift.print("content area")
            // `parentNode` is nil if the drop is on the content area
            let proxyRoot = self.treeController.arrangedObjects
            let childNodes = proxyRoot.children
            let numChildren = childNodes!.count
            dropIndexPath = IndexPath(index: numChildren)
        }

        // NB. the `pathName` property of each instance of  NUTreeObject created is relative
        // to the path name of the `parentNode` which is the destination of the drop.
        // Their values are not correct because when the sub-tree(s) are attached to the
        // parentNode, their values must be relative to the path name of the archive-on-disk.
        // Their `parentObject` property may need to be fixed as well.
        let absPathOfDestinationDir = workDir! + destinationDirPath

        // Build a multi-rooted directory subtree.
        guard let rootObjectsOfSubTree = NUTree.buildWithPaths(absoluteDestPaths,
                                                               inDirectory: absPathOfDestinationDir)
        else {
            //Swift.print("empty subtree")
            return false
        }

        // Remove the old nodes with duplicate filenames
        if (removeIndexPaths.count != 0) {
            self.treeController.removeObjects(atArrangedObjectIndexPaths: removeIndexPaths)
        }

        //  Now attach the subtree to the main directory tree.
        for child in rootObjectsOfSubTree.reverseObjectEnumerator() {
            //Swift.print(child)
            self.treeController.insert(child,
                                       atArrangedObjectIndexPath: dropIndexPath)
        }

        
        fixPaths()
        //Swift.print("====== print the tree======")
        //printTree()
        // we should update the original archive file just in case
        // some joker decides to drag the newly created nodes to Finder!
        self.treeController.rearrangeObjects()
        setDirty()

        return true
    }

	

	// This should be similar to drops from Finder except the src paths
	// are from another archive-on-disk. The property `draggedNodes` has
	// been set by the method outlineView:writeItems:toPasteboard:
	// Alternatively, in validateDrop or acceptDrop, we could set up a
	// property list and then call handleDropsFromFinder:
	func handleInterDocumentDrops(_ pboard: NSPasteboard,
	                              fromSourceDocument srcDoc: NUDocument,
	                              withParentIndexPath parentIndexPath: IndexPath) -> Bool {
        var result: Bool

        //Swift.print("handleInterDocumentDrops:fromSourceDocument:withParentIndexPath")
		//Swift.print("Figure out the source paths")
		// We need the fullpathname of the source archive-on-disk in order to get
		// the array of source paths of the dragged nodes.
		var absoluteSrcPaths = [String]()
		// `draggedNodes` property had been set to that in the source view controller.
		for node in self.draggedNodes! {
			let treeObject = node.representedObject as! NUTreeObject
			let srcPath = srcDoc.archiveOnDiskPath + treeObject.pathName
			absoluteSrcPaths.append(srcPath)
		}
		// The NSPasteboard method below must be called before the method setPropertyList:forType:
		pboard.declareTypes([.filenames],
		                    owner: self)
		pboard.setPropertyList(absoluteSrcPaths,
		                       forType: .filenames)
		result = handleDropsFromFinder(pboard,
                                       withParentIndexPath: parentIndexPath)
        return result
	}
}
