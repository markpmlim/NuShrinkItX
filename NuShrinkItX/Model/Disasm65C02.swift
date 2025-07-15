//
//  Disasm65C02.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Foundation

class Disasm65C02: NSObject {

	enum AddressingMode: UInt32 {
		case indirectX = 0				// 0 (Indirect,X)
		case zeroPage					// 1
		case immediate					// 2
		case absolute					// 3
		case indirectY					// 4 (Indirect),Y
		case zeroPageX					// 5 Zero Page,X
		case absoluteY					// 6 absolute,Y
		case absoluteX					// 7 absolute,X
		case accum						// 8
		case relative					// 9
		case implied					// 10
		case indirect					// 11 (absolute
		case zeroPageY					// 12 Zero Page,Y
		case stack						// 13
		case absIndexedIndirect			// 14 (absolute,X) - new 65C02 mode
		case zeroPageIndirect			// 15 (ZeroPage) - new 65C02 mode
		case kUnknownAddrMode = 0xff
	}

	class func listing(_ fileContents: Data,
	                   withAddress startAddress: UInt32) -> String? {

		guard let url = Bundle.main.url(forResource: "65C02",
		                                withExtension: "plist")
		else {
			return nil
		}

		// We have to instantiate using NSDictionary methods.
		guard let disasmDict = NSDictionary(contentsOf: url)
		else {
			return nil
		}
		//Swift.print(disasmDict)
		// Start disassembling
		let addressingModes = disasmDict["AddressingModes"] as! Array<UInt32>
		let mnemonics = disasmDict["Mnemonics"] as! Array<String>
		let opcodeLengths = disasmDict["OpcodeLengths"] as! Array<UInt32>
		let str = NSMutableString()
    /*
		let buffer = (fileContents as NSData).bytes.bindMemory(to: UInt8.self,
		                                                       capacity: fileContents.count)
 */
        let buffer = fileContents
		var currentOffset = 0					// offset into the data buffer
		let length = fileContents.count
		var currentAddr = startAddress
		let endAddr = startAddress + UInt32(length)

		while (currentAddr < endAddr) {
			let s1 = String(format:"$%04X:   ", currentAddr)
			str.append(s1)
			let opcode = buffer[currentOffset]
			let opcodeLen = opcodeLengths[Int(opcode)]
			let addrMode = AddressingMode(rawValue: addressingModes[Int(opcode)])
			let mnem = mnemonics[Int(opcode)]

			if (opcodeLen == 1) {
				// eg 00			BRK
				str.appendFormat("%02X          %@",
				                 buffer[currentOffset], mnem)
			}
			else if (opcodeLen == 2) {
				// eg A9 9A			LDA
				str.appendFormat("%02X %02X       %@",
				                 buffer[currentOffset], buffer[currentOffset+1], mnem)
			}
			else if (opcodeLen == 3) {
				// eg 20 C4 20		JSR
				str.appendFormat("%02X %02X %02X    %@",
				                 buffer[currentOffset], buffer[currentOffset+1], buffer[currentOffset+2], mnem)
			}
				
			// the values of addrMode are hard-coded in plist file.
			switch(addrMode!) {
			case .indirectX:
				str.appendFormat("   ($%02X,X)",
				                 buffer[currentOffset + 1])
			case .zeroPage:
				str.appendFormat("   $%02X",
				                 buffer[currentOffset + 1])
			case .immediate:
				str.appendFormat("   #$%02X",
				                 buffer[currentOffset + 1])
			case .absolute:
				str.appendFormat("   $%02X%02X",
				                 buffer[currentOffset + 2], buffer[currentOffset + 1])
			case .indirectY:
				str.appendFormat("   ($%02X),Y",
				                 buffer[currentOffset + 1])
			case .zeroPageX:
				str.appendFormat("   $%02X,X",
				                 buffer[currentOffset + 1])
			case .absoluteY:
				str.appendFormat("   $%02X%02X,Y)",
				                 buffer[currentOffset + 2], buffer[currentOffset + 1])
			case .absoluteX:
				str.appendFormat("   $%02X%02X,X",
				                 buffer[currentOffset + 2], buffer[currentOffset + 1])
			case .accum:
				str.appendFormat("   A",
				                 buffer[currentOffset + 1])
			case .relative:
				if buffer[currentOffset + 1]>127 {
					// subtract 256 for a wraparound
					str.appendFormat("   $%04X",
					                 currentAddr + opcodeLen + UInt32(buffer[currentOffset + 1]) - 0x100)
				}
				else {
					str.appendFormat("   $%04X",
					                 currentAddr + opcodeLen + UInt32(buffer[currentOffset + 1]))
				}
			case .implied:
				break
			case .indirect:
				str.appendFormat("   ($%02X%02X)",
				                 buffer[currentOffset + 2], buffer[currentOffset + 1])
			case .zeroPageY:
				str.appendFormat("   $%02X,Y",
				                 buffer[currentOffset + 1])
			case .stack:
				break
			case .absIndexedIndirect:
				str.appendFormat("   ($%02X%02X,X)",
				                 buffer[currentOffset + 2], buffer[currentOffset + 1])
			case .zeroPageIndirect:
				str.appendFormat("   ($%02X)",
				                 buffer[currentOffset + 1])
			default:
				break
			}
			currentOffset += Int(opcodeLen)
			currentAddr += UInt32(opcodeLen)
			str.append("\n")
		} // while
		return str as String
	}

	class func hexListing(_ fileContents: Data,
	                      withAddress startAddress: UInt32) -> String? {

		let numOfBytes: UInt32 = UInt32(fileContents.count)
		let numLines: UInt32 = numOfBytes/16        // # of complete lines
		let numStragglers: UInt32 = numOfBytes % 16 // left over bytes

        let buffer = fileContents
		var currentAddr = startAddress
        var currentRowOffset = 0        // starting offset into buffer of current line
		let str = NSMutableString()
		for row in 0..<Int(numLines) {
            currentRowOffset = row * 16
			str.appendFormat("%04X:", currentAddr)
            for column in 0..<16 {
                str.appendFormat("%02X ", buffer[currentRowOffset+column])
            }
            str.append("\n")
			currentAddr += 16;
		}

        // Print the last (incomplete) line
		if numStragglers != 0 {
			str.appendFormat("%04X:", currentAddr)
            currentRowOffset = Int(numLines) * 16
			for k in 0..<Int(numStragglers) {
				str.appendFormat("%02X ", buffer[currentRowOffset+k])
			}
			str.append("\n")
		}
		return str as String
	}
}
