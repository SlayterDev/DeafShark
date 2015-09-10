//
//  Extensions.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation

prefix operator / {}

prefix func /(regex: String) -> NSRegularExpression {
	return try! NSRegularExpression(pattern: regex, options: NSRegularExpressionOptions())
}

func /(lhs: NSRegularExpression, rhs: String) -> NSRegularExpression {
	let pattern = lhs.pattern
	var optionsMask: UInt = 0
	
	rhs.match(/"i") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpressionOptions.CaseInsensitive.rawValue
	}
	rhs.match(/"x") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpressionOptions.AllowCommentsAndWhitespace.rawValue
	}
	rhs.match(/"q") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpressionOptions.IgnoreMetacharacters.rawValue
	}
	rhs.match(/"s") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpressionOptions.DotMatchesLineSeparators.rawValue
	}
	rhs.match(/"m") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpressionOptions.AnchorsMatchLines.rawValue
	}
	rhs.match(/"w") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpressionOptions.UseUnicodeWordBoundaries.rawValue
	}
	rhs.match(/"d") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpressionOptions.UseUnixLineSeparators.rawValue
	}
	return try! NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions(rawValue: optionsMask))
}

func ~=(string: String, regex: NSRegularExpression) -> Bool {
	let range = NSMakeRange(0, string.characters.count)
	let match = regex.firstMatchInString(string, options: NSMatchingOptions(), range: range)
	return match != nil
}

extension String {
	func range() -> NSRange {
		return NSMakeRange(0, self.characters.count)
	}
	
	func match(regex: NSRegularExpression, closure: (matches: [String]) -> ()) -> String? {
		if let match = regex.firstMatchInString(self, options: NSMatchingOptions(), range: self.range()) {
			var groups: [String] = []
			for index in 0..<match.numberOfRanges {
				let rangeAtIndex: NSRange = match.rangeAtIndex(index)
				let myString = self as NSString
				var group: String!
				if rangeAtIndex.location != NSNotFound {
					group = myString.substringWithRange(rangeAtIndex)
				} else {
					group = ""
				}
				groups.append(group)
			}
			
			closure(matches: groups)
			return nil
		} else {
			return self
		}
	}
	
	func tokenize() -> DeafSharkLexicalRepresentation? {
		let (rep, errors) = DeafSharkToken.tokenize(self)
		if errors == nil {
			return rep
		} else {
			return nil
		}
	}
	
	subscript (i: Int) -> Character {
		return self[self.startIndex.advancedBy(i)]
	}
	
	subscript (i: Int) -> String {
		return String(self[i] as Character)
	}
	
	subscript (r: Range<Int>) -> String {
		return substringWithRange(Range(start: startIndex.advancedBy(r.startIndex), end: startIndex.advancedBy(r.endIndex)))
	}
}

extension DeafSharkLexicalRepresentation {
	func parse() -> DSAST? {
		let parser = DSParser(tokens: tokens, lineContext: context)
		if let AST = parser.generateAST() {
			return AST
		} else {
			for error in parser.errors {
				print(error.description)
			}
			return nil
		}
	}
}

extension NSString {
	func restoreEscapeCharacters() -> NSString {
		var temp = self
		temp = temp.stringByReplacingOccurrencesOfString("\\n", withString: "\n")
		temp = temp.stringByReplacingOccurrencesOfString("\\\"", withString: "\"")
		temp = temp.stringByReplacingOccurrencesOfString("\\\'", withString: "\'")
		temp = temp.stringByReplacingOccurrencesOfString("\\r", withString: "\r")
		temp = temp.stringByReplacingOccurrencesOfString("\\t", withString: "\t")
		return temp
	}
}
