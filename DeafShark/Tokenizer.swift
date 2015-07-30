//
//  Tokenizer.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Cocoa

@objc public class LineContext {
	public var pos: Int
	public var line: Int
	
	init(pos: Int, line: Int) {
		self.pos = pos
		self.line = line
	}
	
	var description: String {
		return "line: \(self.line) pos: \(self.pos)"
	}
}

public func ==(lhs: LineContext, rhs: LineContext) -> Bool {
	return lhs.pos == rhs.pos && lhs.line == rhs.line
}

class DeafSharkLexicalRepresentation: CustomStringConvertible {
	var tokens: [DeafSharkToken]
	var context: [LineContext]
	
	init(tokens: [DeafSharkToken], context: [LineContext]) {
		self.tokens = tokens
		self.context = context
	}
	
	var description: String {
		let tokenDescriptions = tokens.map({"\"" + $0.description + "\"" + " "})
		let description = tokenDescriptions.reduce("", combine: { (description, token) -> String in
			description + token
		})
		return description
	}
}

class Tokenizer: NSObject {
	
}
