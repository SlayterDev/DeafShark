//
//  Error.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Cocoa

public func ==(lhs: DSError, rhs: DSError) -> Bool {
	return lhs.message == rhs.message && lhs.lineContext == rhs.lineContext
}

public class DSError: NSObject {
	var message: String
	var lineContext: LineContext
	
	override public var description: String {
		return "Error encountered at line: " + lineContext.line.description + ", pos: " + lineContext.pos.description + ": " + message
	}
	
	init(message: String, lineContext: LineContext) {
		self.message = message
		self.lineContext = lineContext
	}
}
