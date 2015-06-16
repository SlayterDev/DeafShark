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
	
	var binaryOperatorPrecedence: Dictionary<String, Int> = [
		"<<":   160,
		">>":   160,
		
		"*":    150,
		"/":    150,
		"%":    150,
		"&*":   150,
		"&/":   150,
		"&%":   150,
		"&":    150,
		
		"+":    140,
		"-":    140,
		"&+":   140,
		"&-":   140,
		"|":    140,
		"^":    140,
		
		"..":   135,
		"...":  135,
		
		"is":   132,
		"as":   132,
		
		"<":    130,
		"<=":   130,
		">":    130,
		">=":   130,
		"==":   130,
		"!=":   130,
		"===":  130,
		"!==":  130,
		"~=":   130,
		
		"&&":   120,
		
		"||":   110,
		
		"?":    100,
		
		"=":    90,
		"*=":   90,
		"/=":   90,
		"%=":   90,
		"+=":   90,
		"-=":   90,
		"<<=":  90,
		">>=":  90,
		"&=":   90,
		"^=":   90,
		"|=":   90,
		"&&=":  90,
		"||=":  90,
	]
	
	init(tokens: [DeafSharkToken], lineContext: [LineContext] = []) {
		self.tokens = tokens
		self.lineContext = lineContext
	}
	
	func getOperatorPrecedence(op: String) -> Int {
		return self.binaryOperatorPrecedence[op]!
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
				if tokens.count == 0 {
					return lhs
				}
				switch tokens[0] {
				case .InfixOperator("=") where lhs.isAssignable:
					return parseAssignment(lhs)
				default:
					return parseOperationRHS(precedence: 0, lhs: lhs)
				}
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
	
	func parseOperationRHS(precedence precedence: Int,  lhs: DSExpr) -> DSExpr? {
		if tokens.count == 0 {
			return lhs
		}
		
		switch tokens[0] {
		case .InfixOperator(let op):
			let tokenPrecedence = getOperatorPrecedence(op)
			
			if tokenPrecedence < precedence {
				return lhs
			}
			
			consumeToken()
			
			if let rhs = parsePrimary() {
				if tokens.count == 0 {
					return DSBinaryExpression(op: op, lhs: lhs, rhs: rhs)
				}
				
				switch tokens[0] {
				case .InfixOperator(let nextOp):
					let nextPrecedence = getOperatorPrecedence(nextOp)
					
					// next token is higher precedence
					if tokenPrecedence < nextPrecedence {
						if let newRhs = parseOperationRHS(precedence: tokenPrecedence, lhs: rhs) {
							return parseOperationRHS(precedence: precedence + 1, lhs: DSBinaryExpression(op: op, lhs: lhs, rhs: newRhs))
						} else {
							return nil
						}
					}
					return parseOperationRHS(precedence: precedence + 1, lhs: DSBinaryExpression(op: op, lhs: lhs, rhs: rhs))
				default:
					return DSBinaryExpression(op: op, lhs: lhs, rhs: rhs)
				}
			} else {
				return nil
			}
		//TODO: Handle pre/postfix ops
		default:
			return lhs
		}
	}
	
	func parseAssignment(store: DSExpr) -> DSAssignment? {
		switch tokens[0] {
		case .InfixOperator("="):
			consumeToken()
			if let rhs = parseExpression() {
				return DSAssignment(storage: store, expression: rhs)
			} else {
				return nil
			}
		default:
			errors.append(DSError(message: "Missing expected '='", lineContext: self.lineContext[0]))
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
				case .InfixOperator("="):
					consumeToken()
					if let assignment = parseExpression() {
						declaration.assignment = assignment
					} else {
						return nil
					}
				// TODO: handle other ops
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
		if let primary = parsePrimary() {
			return parseOperationRHS(precedence: 0, lhs: primary)
		} else {
			return nil
		}
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
		var identifier: DSIdentifierString!
		switch tokens[0] {
		case .Identifier(let id):
			consumeToken()
			identifier =  DSIdentifierString(name: id, lineContext: context)
		default:
			errors.append(DSError(message: "Missing expected identifier", lineContext: context))
			return nil
		}
		
		
		switch tokens[0] {
		//TODO: handle function calls
		default:
			return identifier
		}
	}
}
