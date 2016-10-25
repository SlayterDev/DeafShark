//
//  Tokens.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation

enum DeafSharkToken: CustomStringConvertible, Equatable {
	case invalid(String)
	
	case function
	
	case leftBracket, leftBrace, rightBracket, rightBrace, arrayLeft, arrayRight
	case arrow, semicolon, comma
	
	case `while`, `for`, `if`, `return`, `else`
	
	case integerLiteral(Int), floatLiteral(Float), stringLiteral(String), booleanLiteral(Bool)
	
	case variableDeclaration, constantDeclaration
	
	case identifier(String), `as`
	
	case prefixOperator(String), infixOperator(String), postfixOperator(String)
	
	case newline
	
	var description: String {
		switch self {
		case .invalid(let string):
			return "Invalid token \(string)"
		case .function:
			return "func"
		case .leftBracket:
			return "("
		case .leftBrace:
			return "{"
		case .rightBracket:
			return ")"
		case .rightBrace:
			return "}"
		case .integerLiteral(let val):
			return val.description
		case .floatLiteral(let float):
			return float.description
		case .stringLiteral(let string):
			return string
		case .identifier(let string):
			return string
		case .variableDeclaration:
			return "var"
		case .constantDeclaration:
			return "let"
		case .prefixOperator(let string):
			return string
		case .postfixOperator(let string):
			return string
		case .infixOperator(let string):
			return string
		case .newline:
			return "\n"
		case .as:
			return "as"
		case .arrow:
			return "->"
		case .semicolon:
			return ";"
		case .comma:
			return ","
		case .booleanLiteral(let bool):
			return "\(bool)"
		case .while:
			return "while"
		case .if:
			return "if"
		case .else:
			return "else"
		case .return:
			return "return"
		case .for:
			return "for"
		case .arrayLeft:
			return "["
		case .arrayRight:
			return "]"
		}
	}
	
	static func tokenize(_ inputString: String) -> (DeafSharkLexicalRepresentation, [DSError]?) {
		var errors = [DSError]()
		var input = inputString
		
		let identifierRegex = "([a-z_][a-z0-9]*)"
		
		var linepos = 1, line = 1
		
		var tokens = [DeafSharkToken]()
		var context = [LineContext]()
		
		while (!input.isEmpty) {
			let cachedLinePos = linepos
			let cachedLine = line
			
			let _ = input
			// Match float literal
			.match(/"^(-)?[0-9]*\\.[0-9]+"/"i") {
				let num = $0[0] as NSString
				tokens.append(.floatLiteral(num.floatValue))
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
				
				if Array(arrayLiteral: input)[$0[0].characters.count] == "-" {
					tokens.append(.infixOperator(Array(arrayLiteral: input)[$0[0].characters.count]))
					context.append(LineContext(pos: cachedLinePos, line: cachedLine))
					linepos += 1
				}
			}?
			// Match an Int literal
			.match(/"^(-)?[0-9]+"/"i") {
				let num = strtol($0[0], nil, 10)
				tokens.append(.integerLiteral(num))
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
				
				if input[$0[0].characters.count] == "-" {
					tokens.append(.infixOperator("-"))
					context.append(LineContext(pos: cachedLinePos, line: cachedLine))
					linepos += 1
				}
			}?
			
			// Language keywords
			
			// Match var decl
			.match(/"^var(?!\(identifierRegex))") {
				tokens.append(.variableDeclaration)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// Match let decl
			.match(/"^let(?!\(identifierRegex))") {
				tokens.append(.constantDeclaration)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// Match if statement
			.match(/"^if(?!\(identifierRegex))") {
				tokens.append(.if)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// Match else statement
			.match(/"^else") {
				tokens.append(.else)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// Match while
			.match(/"^while(?!\(identifierRegex))") {
				tokens.append(.while)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// Match for
			.match(/"^for(?!\(identifierRegex))") {
				tokens.append(.for)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// Match let decl
			.match(/"^return(?!\(identifierRegex))") {
				tokens.append(.return)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// Match func decl
			.match(/"^func(?!\(identifierRegex))") {
				tokens.append(.function)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// as keyword
			.match(/"^as") {
				tokens.append(.as)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// true keyword
			.match(/"^(true|YES)") {
				tokens.append(.booleanLiteral(true))
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// false keyword
			.match(/"^(false|NO)") {
				tokens.append(.booleanLiteral(false))
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
				
			// Identifiers
			
			.match(/"^([\\+\\-]{2,})?\(identifierRegex)([\\+\\-]{2,})?"/"i") {
				var newLinePos = cachedLinePos
				if !$0[1].isEmpty {
					// tokenize prefix
					tokens.append(.prefixOperator($0[1]))
					context.append(LineContext(pos: newLinePos, line: cachedLine))
					newLinePos += $0[1].characters.count
				}
				// tokenize identifier
				tokens.append(.identifier($0[2]))
				context.append(LineContext(pos: newLinePos, line: cachedLine))
				newLinePos += $0[2].characters.count
				if !$0[3].isEmpty {
					// tokenize postfix
					tokens.append(.postfixOperator($0[3]))
					context.append(LineContext(pos: newLinePos, line: cachedLine))
				}
				linepos += $0[0].characters.count
				
				if input[$0[0].characters.count] == "-" {
					tokens.append(.infixOperator("-"))
					context.append(LineContext(pos: cachedLinePos, line: cachedLine))
					linepos += 1
				}
			}?
			// match string literals
			.match(/"^\"(\\.|[^\"])*\"") {
				var string = $0[0]
                let index = string.index(after: string.startIndex)
                let end = string.index(index, offsetBy: string.characters.count - 2)
                let range = index..<end
				string = string.substring(with: range)
				
				tokens.append(.stringLiteral(string as String))
				
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count // Plus two for the quotes
			}?
			
			// match a comment
			.match(/"^//(.*)\\n") {
				linepos += $0[0].characters.count
			}?
			// match a block comment
			.match(/"^/\\*(.*)\\*/") {
				linepos += $0[0].characters.count
			}?
				
				
			// Operators and puctuation
				
				
			// return type arrow
			.match(/"^->") {
				tokens.append(.arrow)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// infix operators
			.match(/"^[\\+\\-/*<>=%](=)?") {
				tokens.append(.infixOperator($0[0]))
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// comma
			.match(/"^,") {
				tokens.append(.comma)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			
			// Parantheses and Braces
			
			// left bracket `(`
			.match(/"^\\(") {
				tokens.append(.leftBracket)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// left brace `{`
			.match(/"^\\{") {
				tokens.append(.leftBrace)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// right bracket `)`
			.match(/"^\\)") {
				tokens.append(.rightBracket)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// right brace `}`
			.match(/"^\\}") {
				tokens.append(.rightBrace)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// right brace `}`
			.match(/"^\\[") {
				tokens.append(.arrayLeft)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// right brace `}`
			.match(/"^\\]") {
				tokens.append(.arrayRight)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			
			// semicolon
			.match(/"^(;)+") {
				tokens.append(.semicolon)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			
			// newline
			.match(/"^(\\n)+") {
				tokens.append(.newline)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0.count - 1
				line += $0.count - 1
			}?
			
			// match other whitespace
			.match(/"^\\s") {
				linepos += $0[0].characters.count
			}?
			
			// everything else is an error
			.match(/"^.*") {
				tokens.append(.invalid($0[0]))
				context.append(LineContext(pos: linepos, line: line))
				errors.append(DSError(message: "Invalid syntax \($0[0]) encountered", lineContext: LineContext(pos: linepos, line: line)))
				linepos += $0[0].characters.count
			}
			
			let index = input.startIndex
            let newIndex = input.index(index, offsetBy: linepos - cachedLinePos)
			
			if line > cachedLinePos {
				linepos = 0
			}
			
			input = input.substring(from: newIndex)
		}
		
		let rep = DeafSharkLexicalRepresentation(tokens: tokens, context: context)
		if errors.isEmpty {
			return (rep, nil)
		} else {
			for error in errors {
				print(error.description)
			}
			
			return (rep, errors)
		}
	}
}

func ==(lhs: DeafSharkToken, rhs: DeafSharkToken) -> Bool {
	switch (lhs, rhs) {
	case (let .integerLiteral(x), let .integerLiteral(y)):
		return x == y
	case (let .identifier(x), let .identifier(y)):
		return x == y
	case (let .floatLiteral(x), let .floatLiteral(y)):
		return x == y
	default:
		return false
	}
}
