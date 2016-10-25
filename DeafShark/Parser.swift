//
//  Parser.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/16/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Cocoa

open class DSParser {
	var tokens: [DeafSharkToken]
	var lineContext: [LineContext]
	lazy open fileprivate(set) var errors = [DSError]()
	
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
	
	func getOperatorPrecedence(_ op: String) -> Int {
		return self.binaryOperatorPrecedence[op]!
	}
	
	func consumeToken() {
		tokens.remove(at: 0)
		lineContext.remove(at: 0)
	}
	
	func generateAST() -> DSBody? {
		return parseBody()
	}
	
	func parseBody(_ bracesRequired: Bool = false) -> DSBody? {
		if bracesRequired {
			switch tokens[0] {
			case .leftBrace:
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
				case .rightBrace:
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
			} else if errors.count > 0 {
				return nil
			}
		}
		
		return body
	}
	
	func parseStatement() -> DSAST? {
		switch tokens[0] {
		case .variableDeclaration:
			fallthrough
		case .constantDeclaration:
			return parseDeclarationStatement()
		case .integerLiteral(_):
			fallthrough
		case .floatLiteral(_):
			fallthrough
		case .identifier(_):
			if let lhs = parsePrimary() {
				if tokens.count == 0 {
					return lhs
				}
				switch tokens[0] {
				case .infixOperator("=") where lhs.isAssignable:
					return parseAssignment(lhs)
				default:
					return parseOperationRHS(precedence: 0, lhs: lhs)
				}
			} else {
				return nil
			}
		case .function:
			return parseFunctionDeclaration()
		case .while:
			fallthrough
		case .for:
			fallthrough
		case .if:
			return parseConditionalStatement()
		case .return:
			return parseReturnStatement()
		case .newline:
			consumeToken()
			return nil
		default:
			errors.append(DSError(message: "Unexpected token \(tokens[0]) encountered", lineContext: self.lineContext[0]))
			return nil
		}
	}
	
	func parseOperationRHS(precedence: Int,  lhs: DSExpr) -> DSExpr? {
		if tokens.count == 0 {
			return lhs
		}
		
		while tokens.count > 0 {
		switch tokens[0] {
			case .infixOperator(let op):
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
					case .infixOperator(let nextOp):
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
			case .leftBracket:
				consumeToken()
				
				var depth = 1
				for token in tokens {
					switch token {
					case .rightBracket:
						depth -= 1
					case .leftBracket:
						depth += 1
					default:
						break
					}
					
					if depth == 0 {
						break
					}
				}
				
				if depth > 0 {
					errors.append(DSError(message: "Mismatched parentheses", lineContext: self.lineContext[0]))
					return nil
				}
			//TODO: Handle pre/postfix ops
			default:
				return lhs
			}
		}
		
		return lhs
	}
	
	func parseAssignment(_ store: DSExpr) -> DSAssignment? {
		switch tokens[0] {
		case .infixOperator("="):
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
		case .constantDeclaration:
			consumeToken()
		case .variableDeclaration:
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
	
	func parseStorageDeclaration(_ isFunctionParameter: Bool = false) -> DSDeclaration? {
		var type: DSType?
		let context = self.lineContext[0]
		if let declarationID = parseDeclaration() {
			let declaration = isFunctionParameter ? DSFunctionParameter(id: declarationID, lineContext: context) : DSDeclaration(id: declarationID, lineContext: context)
			if tokens.count > 0 {
				switch tokens[0] {
				case .as:
					consumeToken()
					type = parseType()
					if type == nil {
						errors.append(DSError(message: "Missing type declaration.", lineContext: self.lineContext[0]))
						return nil
					}
					declaration.type = type
				default:
					break
				}
			}
			
			if tokens.count > 0 {
				switch tokens[0] {
				case .infixOperator("="):
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
			
			if declaration.assignment == nil && declaration.type == nil {
				errors.append(DSError(message: "Error for \(declaration.identifier). If no initialization given, declaration must have a type", lineContext: self.lineContext[0]))
				return nil
			}
			
			return (isFunctionParameter) ? declaration as! DSFunctionParameter : declaration
		} else {
			return nil
		}
	}
	
	func parseType() -> DSType? {
		var isArray = false
		while tokens.count > 0 {
			switch tokens[0] {
			case .identifier(var t):
				let context = self.lineContext[0]
				consumeToken()
				
				var itemCount: Int? = nil
				if isArray {
					t = "Array," + t
					switch tokens[0] {
					case .infixOperator(let op):
						if op == "*" {
							consumeToken()
							
							switch tokens[0] {
							case .integerLiteral(let n):
								consumeToken()
								itemCount = n
							default:
								errors.append(DSError(message: "Expexted size in array type declaration.", lineContext: self.lineContext[0]))
							}
						}
					default:
						errors.append(DSError(message: "Expexted '*' in type declaration.", lineContext: self.lineContext[0]))
						return nil
					}
					
					switch tokens[0] {
					case .arrayRight:
						consumeToken()
					default:
						errors.append(DSError(message: "Expexted ']' in type declaration.", lineContext: self.lineContext[0]))
					}
				}
				
				return DSType(identifier: t, itemCount: itemCount, lineContext: context)
			case .arrayLeft:
				consumeToken()
				isArray = true
			//TODO: void/tuples
			default:
				return nil
			}
		}
		
		return nil
	}
	
	func parseDeclaration() -> String? {
		switch tokens[0] {
		case .identifier(let string):
			consumeToken()
			return string
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
	
	func parseReturnStatement() -> DSReturnStatement? {
		consumeToken()
		
		if let rhs = parseExpression() {
			return DSReturnStatement(statement: rhs, lineContext: self.lineContext[0])
		} else {
			return nil
		}
	}
	
	func parseConditionalStatement() -> DSConditionalStatement? {
		let context = self.lineContext[0]
		var token: DeafSharkToken = .if
		switch tokens[0] {
		case .for:
			consumeToken()
			return parseForStatement()
		case .if:
			fallthrough
		case .while:
			token = tokens[0]
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected 'while'.", lineContext: context))
		}
		
		if let cond = parseExpression(), let body = parseBody(true) {
			switch token {
			case .while:
				return DSWhileStatement(condition: cond, body: body, lineContext: context)
			case .if:
				let ifstat = DSIfStatement(condition: cond, body: body, lineContext: context)
				while tokens.count > 0 {
					var breakLoop = false
					switch tokens[0] {
					case .else:
						consumeToken()
						
						// Check for else if
						switch tokens[0] {
						case .leftBrace:
							if let elseBody = parseBody(true) {
								ifstat.elseBody = elseBody
								return ifstat
							} else {
								errors.append(DSError(message: "Missing expected 'else' body.", lineContext: self.lineContext[0]))
								return nil
							}
						case .if:
							consumeToken()
							if let elifCond = parseExpression(), let elifBody = parseBody(true) {
								ifstat.alternates?.append(DSIfStatement(condition: elifCond, body: elifBody, lineContext: self.lineContext[0]))
							} else {
								errors.append(DSError(message: "Missing expected 'else if' body.", lineContext: self.lineContext[0]))
								return nil
							}
						default:
							errors.append(DSError(message: "Missing expected 'else' body.", lineContext: self.lineContext[0]))
						}
					default:
						breakLoop = true
						break
					}
					
					if breakLoop {
						break
					}
				}
				return ifstat
			default:
				return nil
			}
		}
		
		return nil
	}
	
	func parseForStatement() -> DSForStatement? {
		let initial: DSAST
		switch tokens[0] {
		case .variableDeclaration:
			fallthrough
		case .constantDeclaration:
			fallthrough
		case .identifier(_):
			initial = parseStatement()!
		default:
			errors.append(DSError(message: "invalid for loop initialization", lineContext: self.lineContext[0]))
			return nil
		}
		
		switch tokens[0] {
		case .semicolon:
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected semicolon.", lineContext: self.lineContext[0]))
		}
		
		let condition = parseExpression()
		
		switch tokens[0] {
		case .semicolon:
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected semicolon.", lineContext: self.lineContext[0]))
		}
		
		let increment = parseExpression()
		
		switch tokens[0] {
		case .semicolon:
			consumeToken()
		default:
			break
		}
		
		if let body = parseBody(true) {
			return DSForStatement(initial: initial, condition: condition!, increment: increment!, body: body, lineContext: self.lineContext[0])
		} else {
			errors.append(DSError(message: "Missing expected 'for' body.", lineContext: self.lineContext[0]))
			return nil
		}
		
	}
	
	func parsePrimary() -> DSExpr? {
		let context = self.lineContext[0]
		switch tokens[0] {
		case .identifier(_):
			return parseIdentifierExpression()
		case .integerLiteral(_):
			fallthrough
		case .floatLiteral(_):
			return parseNumberExpression()
		case .booleanLiteral(let bool):
			consumeToken()
			return DSBooleanLiteral(val: bool, lineContext: context)
		case .stringLiteral(let string):
			consumeToken()
			return DSStringLiteral(val: string, lineContext: context)
		case .arrayLeft:
			return parseArray()
		default:
			errors.append(DSError(message: "\(tokens[0]) is not a DeafShark expression.", lineContext: context))
			return nil
		}
	}
	
	func parseFunctionDeclaration() -> DSFunctionDeclaration? {
		let context = self.lineContext[0]
		switch tokens[0] {
		case .function:
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected 'func'.", lineContext: context))
			return nil
		}
		
		let functionId: String
		switch tokens[0] {
		case .identifier(let string):
			functionId = string
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected identifier.", lineContext: context))
			return nil
		}
		
		switch tokens[0] {
		case .leftBracket:
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected '('.", lineContext: context))
		}
		
		let parameters = parseParams()
		
		let returnType: DSType
		
		let returnTypeContext = self.lineContext[0]
		switch tokens[0] {
		case .arrow:
			consumeToken()
			if let type = parseType() {
				returnType = type
			} else {
				return nil
			}
		default:
			returnType = DSType(identifier: "void", itemCount: nil, lineContext: context)
		}
		
		var body: DSFunctionBody?
		if (tokens.isEmpty) {
			errors.append(DSError(message: "Missing function body.", lineContext: returnTypeContext))
			return nil
		}
		let bodyContext = self.lineContext[0]
		switch tokens[0] {
		case .leftBrace:
			if let closure = parseBody(true) {
				body = DSFunctionBody(closure, lineContext: bodyContext)
				fallthrough
			} else {
				return nil
			}
		default:
			return DSFunctionDeclaration(id: functionId, parameters: parameters!, returnType: returnType, body: body, lineContext: context)
		}
	}
	
	func parseParams() -> [DSFunctionParameter]? {
		var functionParameters: [DSFunctionParameter] = [DSFunctionParameter]()
		
		while true {
			switch tokens[0] {
			case .rightBracket:
				consumeToken()
				return functionParameters
			case .comma:
				consumeToken()
			default:
				if let arg = parseStorageDeclaration(true) as? DSFunctionParameter {
					functionParameters.append(arg)
				} else {
					return nil
				}
			}
		}
	}
	
	func parseNumberExpression() -> DSExpr? {
		let context = self.lineContext[0]
		switch tokens[0] {
		case .integerLiteral(let int):
			consumeToken()
			return DSSignedIntegerLiteral(val: int, lineContext: context)
		case .floatLiteral(let float):
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
		case .identifier(let id):
			consumeToken()
			
			if id == "break" {
				return DSBreakStatement(lineContext: context)
			}
			
			identifier =  DSIdentifierString(name: id, lineContext: context)
			switch tokens[0] {
			case .arrayLeft:
				consumeToken()
				if let expr = parseExpression() {
					identifier.arrayAccess = expr
				}
				// May not be needed
				switch tokens[0] {
				case .arrayRight:
					consumeToken()
				default:
					errors.append(DSError(message: "Expected ']'", lineContext: self.lineContext[0]))
					return nil
				}
			default:
				break
			}
		default:
			errors.append(DSError(message: "Missing expected identifier", lineContext: context))
			return nil
		}
		
		if tokens.count == 0 {
			return identifier
		}
		switch tokens[0] {
		case .leftBracket:
			consumeToken()
			var args = [DSExpr]()
			while true {
				if tokens.count == 0 {
					errors.append(DSError(message: "Missing expected '(' in function call", lineContext: context))
					return nil
				}
				switch tokens[0] {
				case .rightBracket:
					consumeToken()
					return DSCall(identifier: identifier, arguments: args)
				case .comma:
					consumeToken()
				default:
					if let exp = parseExpression() {
						args.append(exp)
					} else {
						return nil
					}
				}
			}
		default:
			return identifier
		}
	}
	
	func parseArray() -> DSArrayLiteral? {
		consumeToken()
		
		var elements = [DSExpr]()
		while tokens.count > 0 {
			switch tokens[0] {
			case .comma:
				consumeToken()
			case .arrayRight:
				consumeToken()
				return DSArrayLiteral(elements: elements, lineContext: self.lineContext[0])
			default:
				if let expr = parseExpression() {
					elements.append(expr)
				} else {
					errors.append(DSError(message: "Not a valid array expression", lineContext: self.lineContext[0]))
					return nil
				}
			}
		}
		
		errors.append(DSError(message: "Missing end of array", lineContext: self.lineContext[0]))
		return nil
	}
}
