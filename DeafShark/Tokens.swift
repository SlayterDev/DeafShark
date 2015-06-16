//
//  Tokens.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation

enum DeafSharkToken: CustomStringConvertible, Equatable {
	case Invalid(String)
	
	case Function
	
	case LeftBracket, LeftBrace, RightBracket, RightBrace
	
	case IntegerLiteral(Int), FloatLiteral(Float), StringLiteral(String)
	
	case VariableDeclaration, ConstantDeclaration
	
	case Identifier(String)
	
	case PrefixOperator(String), InfixOperator(String), PostfixOperator(String)
	
	case Newline
	
	var description: String {
		switch self {
		case .Invalid(let string):
			return "Invalid token \(string)"
		case .Function:
			return "func"
		case .LeftBracket:
			return "("
		case .LeftBrace:
			return "{"
		case .RightBracket:
			return ")"
		case .RightBrace:
			return "}"
		case .IntegerLiteral(let val):
			return val.description
		case .FloatLiteral(let float):
			return float.description
		case .StringLiteral(let string):
			return string
		case .Identifier(let string):
			return string
		case .VariableDeclaration:
			return "var"
		case .ConstantDeclaration:
			return "let"
		case .PrefixOperator(let string):
			return string
		case .PostfixOperator(let string):
			return string
		case .InfixOperator(let string):
			return string
		case .Newline:
			return "\n"
		
		}
	}
	
	static func tokenize(var input: String) -> (DeafSharkLexicalRepresentation, [DSError]?) {
		var errors = [DSError]()
		
		let identifierRegex = "([a-z_][a-z0-9]*)"
		
		var linepos = 1, line = 1
		
		var tokens = [DeafSharkToken]()
		var context = [LineContext]()
		
		while (!input.isEmpty) {
			let cachedLinePos = linepos
			let cachedLine = line
			
			input
			// Match float literal
			.match(/"^[0-9]*\\.[0-9]+"/"i") {
				let num = $0[0] as NSString
				tokens.append(.FloatLiteral(num.floatValue))
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// Match an Int literal
			.match(/"^[0-9]+"/"i") {
				let num = strtol($0[0], nil, 10)
				tokens.append(.IntegerLiteral(num))
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// Match var decl
			.match(/"^var(?!\(identifierRegex))") {
				tokens.append(.VariableDeclaration)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// Match let decl
			.match(/"^let(?!\(identifierRegex))") {
				tokens.append(.ConstantDeclaration)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			// Match func decl
			.match(/"^func(?!\(identifierRegex))") {
				tokens.append(.VariableDeclaration)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			
			// Identifiers
			
			.match(/"^([\\+\\-]{2,})?\(identifierRegex)([\\+\\-]{2,})?"/"i") {
				var newLinePos = cachedLinePos
				if !$0[1].isEmpty {
					// tokenize prefix
					tokens.append(.PrefixOperator($0[1]))
					context.append(LineContext(pos: newLinePos, line: cachedLine))
					newLinePos += $0[1].characters.count
				}
				// tokenize identifier
				tokens.append(.Identifier($0[2]))
				context.append(LineContext(pos: newLinePos, line: cachedLine))
				newLinePos += $0[2].characters.count
				if !$0[3].isEmpty {
					// tokenize postfix
					tokens.append(.PostfixOperator($0[3]))
					context.append(LineContext(pos: newLinePos, line: cachedLine))
				}
				linepos += $0[0].characters.count
			}?
				
			// Operators and puctuation
				
			// infix operators
			.match(/"^[\\+\\-/*<>=](=)?") {
				tokens.append(.InfixOperator($0[0]))
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			
			// Parantheses and Braces
			
			// left bracket `(`
			.match(/"^\\(") {
				tokens.append(.LeftBracket)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			
			// left brace `{`
			.match(/"^\\{") {
				tokens.append(.LeftBrace)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			
			// right bracket `)`
			.match(/"^\\)") {
				tokens.append(.RightBracket)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			
			// right brace `}`
			.match(/"^\\}") {
				tokens.append(.LeftBracket)
				context.append(LineContext(pos: cachedLinePos, line: cachedLine))
				linepos += $0[0].characters.count
			}?
			
			// newline
			.match(/"^(\\n)+") {
				tokens.append(.Newline)
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
				tokens.append(.Invalid($0[0]))
				context.append(LineContext(pos: linepos, line: line))
				errors.append(DSError(message: "Invalid syntax \($0[0]) encountered", lineContext: LineContext(pos: linepos, line: line)))
				linepos += $0[0].characters.count
			}
			
			let index = input.startIndex
			let newIndex = advance(index, linepos - cachedLinePos)
			input = input.substringFromIndex(newIndex)
		}
		
		let rep = DeafSharkLexicalRepresentation(tokens: tokens, context: context)
		if errors.isEmpty {
			return (rep, nil)
		} else {
			return (rep, errors)
		}
	}
}

func ==(lhs: DeafSharkToken, rhs: DeafSharkToken) -> Bool {
	switch (lhs, rhs) {
	case (let .IntegerLiteral(x), let .IntegerLiteral(y)):
		return x == y
	case (let .Identifier(x), let .Identifier(y)):
		return x == y
	case (let .FloatLiteral(x), let .FloatLiteral(y)):
		return x == y
	default:
		return false
	}
}