//
//  Parser.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/16/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Cocoa

public class DSParser {
	var tokens: [DeafSharkToken]
	var lineContext: [LineContext]
	lazy public private(set) var errors = [DSError]()
	
	init(tokens: [DeafSharkToken], lineContext: [LineContext] = []) {
		self.tokens = tokens
		self.lineContext = lineContext
	}
	
	func consumeToken() {
		tokens.removeAtIndex(0)
		lineContext.removeAtIndex(0)
	}
	
	func generateAST() -> DSBody? {
		return parseBody()
	}
	
	func parseBody(bracesRequired: Bool = false) -> DSBody? {
		if bracesRequired {
			switch tokens[0] {
			case .LeftBrace:
				consumeToken()
			default:
				errors.append(DSError(message: "Missing expected bracket.", lineContext: self.lineContext[0]))
				return nil
			}
		}
		
		let body = DSBody(lineContext: self.lineContext[0])
		while !tokens.isEmpty {
			if bracesRequired {
				switch tokens[0] {
				case .RightBrace:
					consumeToken()
					return body
				default:
					break
				}
			}
			
			if let statement = parseStatement() {
				body.children.append(statement)
				if errors.count > 0 {
					return nil
				}
			}
		}
		
		return body
	}
	
	func parseStatement() -> DSAST? {
		switch tokens[0] {
		case .VariableDeclaration:
			fallthrough
		case .ConstantDeclaration:
			return parseDeclarationStatement()
		case .IntegerLiteral(_):
			fallthrough
		case .FloatLiteral(_):
			fallthrough
		case .Identifier(_):
			if let lhs = parsePrimary() {
				return lhs
			} else {
				return nil
			}
		case .Newline:
			consumeToken()
			return nil
		default:
			errors.append(DSError(message: "Unexpected token \(tokens[0]) encountered", lineContext: self.lineContext[0]))
			return nil
		}
	}
	
	func parseDeclarationStatement() -> DSAST? {
		var isConstant = true
		switch tokens[0] {
		case .ConstantDeclaration:
			consumeToken()
		case .VariableDeclaration:
			consumeToken()
			isConstant = false
		default:
			errors.append(DSError(message: "Missing expected 'let' or 'var'.", lineContext: self.lineContext[0]))
			return nil
		}
		
		if let declaration = parseStorageDeclaration() {
			declaration.isConstant = isConstant
			return declaration
		}
		return nil
	}
	
	func parseStorageDeclaration() -> DSDeclaration? {
		var type: DSType?
		if let declaration = parseDeclaration() {
			if tokens.count > 0 {
				switch tokens[0] {
				default: // TODO: colon/as
					break
				}
			}
			
			if tokens.count > 0 {
				switch tokens[0] {
				case .InfixOperator(let string):
					if string == "=" {
						consumeToken()
						if let assignment = parseExpression() {
							declaration.assignment = assignment
						} else {
							return nil
						}
					} else {
						return nil // TODO: handle other ops
					}
				default:
					break
				}
			}
			return declaration
		} else {
			return nil
		}
	}
	
	func parseDeclaration() -> DSDeclaration? {
		switch tokens[0] {
		case .Identifier(let string):
			consumeToken()
			let declaration = DSDeclaration(id: string, lineContext: self.lineContext[0])
			return declaration
		default:
			errors.append(DSError(message: "Missing expected identifier.", lineContext: self.lineContext[0]))
			return nil
		}
	}
	
	func parseExpression() -> DSExpr? {
		return parsePrimary()
	}
	
	func parsePrimary() -> DSExpr? {
		let context = self.lineContext[0]
		switch tokens[0] {
		case .Identifier(_):
			return parseIdentifierExpression()
		case .IntegerLiteral(_):
			fallthrough
		case .FloatLiteral(_):
			return parseNumberExpression()
			//TODO: true/false
		default:
			errors.append(DSError(message: "\(tokens[0]) is not a DeafShark expression.", lineContext: context))
			return nil
		}
	}
	
	func parseNumberExpression() -> DSExpr? {
		let context = self.lineContext[0]
		switch tokens[0] {
		case .IntegerLiteral(let int):
			consumeToken()
			return DSSignedIntegerLiteral(val: int, lineContext: context)
		case .FloatLiteral(let float):
			consumeToken()
			return DSFloatLiteral(val: float, lineContext: context)
		default:
			errors.append(DSError(message: "\(tokens[0]) is not a DeafShark expression", lineContext: context))
			return nil
		}
	}
	
	func parseIdentifierExpression() -> DSExpr? {
		let context = self.lineContext[0]
		switch tokens[0] {
		case .Identifier(let id):
			consumeToken()
			return DSIdentifierLiteral(name: id, lineContext: context)
		default:
			errors.append(DSError(message: "Missing expected identifier", lineContext: context))
			return nil
		}
	}
}
