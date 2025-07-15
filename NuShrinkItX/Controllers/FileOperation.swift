//
//  FileOperation.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 9/4/16.
//  Copyright © 2016 Incremental Innovation. All rights reserved.
// Not used yet

import Foundation

class FileOperation: Operation
{
	var absoluteSrcPath: String
	var absoluteDestPath: String
	var delegate: TreeViewController
	
	init(sourcePath srcPath: String,
	     destinationPath destPath: String,
	     delegate del: TreeViewController)
    {
		absoluteSrcPath = srcPath
		absoluteDestPath = destPath
		delegate = del
	}

	override func main()
    {
		//Swift.print("copying ", self.absoluteSrcPath, " to", absoluteDestPath)
		delegate.addChild(absoluteDestPath)
	}
}

