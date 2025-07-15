//
//  HexFormatter.swift
//  SwiftNuShrinkItX
//
//  Created by Mark Lim on 9/27/16.
//  Copyright © 2016 Mark Lim. All rights reserved.
//http://stackoverflow.com/questions/26590729/custom-nsformatter-returning-nil-in-swift

import Foundation

@objc class HexFormatter: Formatter
{
	var hexDigitCharSet = CharacterSet(charactersIn:"0123456789abcdefABCDEF")

	// Return a String object that represents "anObject" for display
	// KIV. pad with leading and trailing zeroes?
	override func string(for obj: Any?) -> String? {
		if obj is String {
			return obj as? String
		}
		if obj is NSNumber {
			//let str = String((obj as! NSNumber).uint32Value, radix: 16, uppercase:true)
			let str = String(format: "%04x", (obj as! NSNumber).uint32Value)
			return str
		}
		return nil
	}
	
	// Return a String object that is used for editing
	override func editingString(for obj: Any) -> String? {
		if let number = obj as? NSNumber {
			//let str = NSString(format: "%04x", number.unsignedIntegerValue)
			//let str = String(number.uint32Value, radix: 16, uppercase:true)
			let str = String(format: "%04x", number.uint32Value)
			return str
		}
		else if let str = obj as? NSString {
			return str as String
		}
		return nil
	}
/*
	func numberFromHexString(string: String) -> NSNumber?
	{
		// Trim string to only valid characters
		let range = string.rangeOfCharacterFromSet(hexDigitCharSet)
		let hexString = string.substringWithRange(range!)
		let len = hexString.lengthOfBytesUsingEncoding(NSASCIIStringEncoding)
		if len == 0 {
			return nil
		}
		// Calculate the value
		var value = 0
		var factor = 1
		var index = hexString.endIndex
		let zero = 0x30
		let nine = 0x39
		let a = 0x61
		let f = 0x66
		let A = 0x41
		let F = 0x46
		var ch = 0
		for var i = len - 1; i >= 0; --i {
			let c = hexString[index]
			if ("0" <= c && c <= "9") {
				ch = c.toInt()
				value += (ch - 0x30) * factor
			}
			else if ("a" <= c && c <= "f")
			{
				ch = c.hashValue
				value += (ch - 0x61 + 10) * factor
			}
			else if ("A" <= c && c <= "F")
			{
				ch = c.hashValue
				value += (ch - A + 10) * factor
			}
			factor *= 16
			index = index.advancedBy(1)
		}
		return NSNumber(unsignedInt: UInt32(value))
	}
*/
	// Returns the object created from "string"
	override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
	                             for string: String,
								 errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {

		// Assumes Swift 2.1
		let errString = "Not a hexdecimal string" as NSString
		if let number = UInt32(string, radix: 16) {
			// assumes obj is never nil or crash
			obj?.pointee = NSNumber(value: UInt32(number) as UInt32)
			return true
		}
		else {
			if error != nil {
				error?.pointee = errString
			}
			return false
		}
	}

	override func isPartialStringValid(_ partialString: String,
	                                   newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?,
	                                   errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {

			let editString = partialString as NSString
			let len = editString.lengthOfBytes(using: String.Encoding.ascii.rawValue)
			if len > 4 {
				return false
			}
			let errString = "Must be a hexidecimal value" as NSString
			// Are all the characters hex digits?
			for i in 0 ..< len {
				let c = editString.character(at: i)
				if !hexDigitCharSet.contains(UnicodeScalar(c)!) {
					if error != nil {
						error?.pointee = errString
					}
					return false
				}
			}
			return true
		}
}
