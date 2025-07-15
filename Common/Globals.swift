//
//  GlobalConstants.swift
//  SwiftNuShrinkItX
//
//  Created by Mark Lim on 9/6/16.
//  Copyright © 2016 Mark Lim. All rights reserved.
//

import Foundation

// objective-C cannot see these!
let XATTR_NUFX_NAME = "com.apple.NuFX"

let ULONG_MAX = 0xffff_ffff
// initialized by AppDelegate
var defaultExtendedAttributes = Data()
let proDOSText = "ProDOS";
let dos33Text = "DOS 3.3";
let dos32Text = "DOS 3.2";
let pascalText = "Pascal";
let hfsText = "HFS";
let unknownText = "Unknown";
let kUnknownTypeStr = "???"

// preferences
let kSavedArchiveName = "savedArchiveName";
let kAutoOverWrite = "autoOverWrite";
let kCompressionFormat = "compressionFormat";


enum FileSystemFormat: UInt32 {
	// main filesystem format (based on NuFX enum)
	case unknown = 0
	case proDOS			//  1
	case dos33			//  2
	case dos32			//  3
	case pascal			//  4
	case macHFS			//  5
	case macMFS			//  6
	case lisa			//  7
	case cpm			//  8
	case charFST		//  9 - unused
	case msDOS			// 10 - any FAT filesystem
	case highSierra		// 11
	case iso9660		// 12
	case appleShare		// 13
}

/*
Copied from CiderPress' FileNameConv.cpp
ProDOS file type names; must be entirely in upper case
*/
let fileTypeNames = [
	"NON", "BAD", "PCD", "PTX", "TXT", "PDA", "BIN", "FNT",
	"FOT", "BA3", "DA3", "WPF", "SOS", "$0D", "$0E", "DIR",
	"RPD", "RPI", "AFD", "AFM", "AFR", "SCL", "PFS", "$17",
	"$18", "ADB", "AWP", "ASP", "$1C", "$1D", "$1E", "$1F",
	"TDM", "IPS", "UPV", "$23", "$24", "$25", "$26", "$27",
	"$28", "3SD", "8SC", "8OB", "8IC", "8LD", "P8C", "$2F",
	"$30", "$31", "$32", "$33", "$34", "$35", "$36", "$37",
	"$38", "$39", "$3A", "$3B", "$3C", "$3D", "$3E", "$3F",
	"DIC", "OCR", "FTD", "$43", "$44", "$45", "$46", "$47",
	"$48", "$49", "$4A", "$4B", "$4C", "$4D", "$4E", "$4F",
	"GWP", "GSS", "GDB", "DRW", "GDP", "HMD", "EDU", "STN",
	"HLP", "COM", "CFG", "ANM", "MUM", "ENT", "DVU", "FIN",
	"$60", "$61", "$62", "$63", "$64", "$65", "$66", "$67",
	"$68", "$69", "$6A", "BIO", "$6C", "TDR", "PRE", "HDV",
	"$70", "$71", "$72", "$73", "$74", "$75", "$76", "$77",
	"$78", "$79", "$7A", "$7B", "$7C", "$7D", "$7E", "$7F",
	"$80", "$81", "$82", "$83", "$84", "$85", "$86", "$87",
	"$88", "$89", "$8A", "$8B", "$8C", "$8D", "$8E", "$8F",
	"$90", "$91", "$92", "$93", "$94", "$95", "$96", "$97",
	"$98", "$99", "$9A", "$9B", "$9C", "$9D", "$9E", "$9F",
	"WP ", "$A1", "$A2", "$A3", "$A4", "$A5", "$A6", "$A7",
	"$A8", "$A9", "$AA", "GSB", "TDF", "BDF", "$AE", "$AF",
	"SRC", "OBJ", "LIB", "S16", "RTL", "EXE", "PIF", "TIF",
	"NDA", "CDA", "TOL", "DVR", "LDF", "FST", "$BE", "DOC",
	"PNT", "PIC", "ANI", "PAL", "$C4", "OOG", "SCR", "CDV",
	"FON", "FND", "ICN", "$CB", "$CC", "$CD", "$CE", "$CF",
	"$D0", "$D1", "$D2", "$D3", "$D4", "MUS", "INS", "MDI",
	"SND", "$D9", "$DA", "DBM", "$DC", "DDD", "$DE", "$DF",
	"LBR", "$E1", "ATK", "$E3", "$E4", "$E5", "$E6", "$E7",
	"$E8", "$E9", "$EA", "$EB", "$EC", "$ED", "R16", "PAS",
	"CMD", "$F1", "$F2", "$F3", "$F4", "$F5", "$F6", "$F7",
	"$F8", "OS ", "INT", "IVR", "BAS", "VAR", "REL", "SYS"
]
