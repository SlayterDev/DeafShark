//
//  Extensions.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation

prefix operator /

prefix func /(regex: String) -> NSRegularExpression {
	return try! NSRegularExpression(pattern: regex, options: NSRegularExpression.Options())
}

func /(lhs: NSRegularExpression, rhs: String) -> NSRegularExpression {
	let pattern = lhs.pattern
	var optionsMask: UInt = 0
	
	let _ = rhs.match(/"i") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpression.Options.caseInsensitive.rawValue
	}
	let _ = rhs.match(/"x") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpression.Options.allowCommentsAndWhitespace.rawValue
	}
	let _ = rhs.match(/"q") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpression.Options.ignoreMetacharacters.rawValue
	}
	let _ = rhs.match(/"s") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpression.Options.dotMatchesLineSeparators.rawValue
	}
	let _ = rhs.match(/"m") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpression.Options.anchorsMatchLines.rawValue
	}
	let _ = rhs.match(/"w") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpression.Options.useUnicodeWordBoundaries.rawValue
	}
	let _ = rhs.match(/"d") { (groups: [String]) -> () in
		optionsMask |= NSRegularExpression.Options.useUnixLineSeparators.rawValue
	}
	return try! NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options(rawValue: optionsMask))
}

func ~=(string: String, regex: NSRegularExpression) -> Bool {
	let range = NSMakeRange(0, string.characters.count)
	let match = regex.firstMatch(in: string, options: NSRegularExpression.MatchingOptions(), range: range)
	return match != nil
}

extension String {
	func range() -> NSRange {
		return NSMakeRange(0, self.characters.count)
	}
	
	func match(_ regex: NSRegularExpression, closure: (_ matches: [String]) -> ()) -> String? {
		if let match = regex.firstMatch(in: self, options: NSRegularExpression.MatchingOptions(), range: self.range()) {
			var groups: [String] = []
			for index in 0..<match.numberOfRanges {
				let rangeAtIndex: NSRange = match.rangeAt(index)
				let myString = self as NSString
				var group: String!
				if rangeAtIndex.location != NSNotFound {
					group = myString.substring(with: rangeAtIndex)
				} else {
					group = ""
				}
				groups.append(group)
			}
			
			closure(groups)
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
		return self[self.characters.index(self.startIndex, offsetBy: i)]
	}
	
	subscript (i: Int) -> String {
		return String(self[i] as Character)
	}
	
	subscript (r: Range<Int>) -> String {
		return substring(with: characters.index(startIndex, offsetBy: r.lowerBound)..<characters.index(startIndex, offsetBy: r.upperBound))
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
		temp = temp.replacingOccurrences(of: "\\n", with: "\n") as NSString
		temp = temp.replacingOccurrences(of: "\\\"", with: "\"") as NSString
		temp = temp.replacingOccurrences(of: "\\\'", with: "\'") as NSString
		temp = temp.replacingOccurrences(of: "\\r", with: "\r") as NSString
		temp = temp.replacingOccurrences(of: "\\t", with: "\t") as NSString
		return temp
	}
}
