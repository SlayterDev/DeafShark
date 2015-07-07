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
			} else if errors.count > 0 {
				return nil
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
		case .Function:
			return parseFunctionDeclaration()
		case .While:
			fallthrough
		case .For:
			fallthrough
		case .If:
			return parseConditionalStatement()
		case .Return:
			return parseReturnStatement()
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
		} else {
			print("Some damn error")
		}
		return nil
	}
	
	func parseStorageDeclaration(isFunctionParameter: Bool = false) -> DSDeclaration? {
		var type: DSType?
		let context = self.lineContext[0]
		if let declarationID = parseDeclaration() {
			let declaration = isFunctionParameter ? DSFunctionParameter(id: declarationID, lineContext: context) : DSDeclaration(id: declarationID, lineContext: context)
			if tokens.count > 0 {
				switch tokens[0] {
				case .As:
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
			return (isFunctionParameter) ? declaration as! DSFunctionParameter : declaration
		} else {
			return nil
		}
	}
	
	func parseType() -> DSType? {
		switch tokens[0] {
		case .Identifier(let t):
			let context = self.lineContext[0]
			consumeToken()
			return DSType(identifier: t, lineContext: context)
		//TODO: void/tuples
		default:
			return nil
		}
	}
	
	func parseDeclaration() -> String? {
		switch tokens[0] {
		case .Identifier(let string):
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
		var token: DeafSharkToken = .If
		switch tokens[0] {
		case .For:
			consumeToken()
			return parseForStatement()
		case .If:
			fallthrough
		case .While:
			token = tokens[0]
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected 'while'.", lineContext: context))
		}
		
		if let cond = parseExpression(), let body = parseBody(true) {
			switch token {
			case .While:
				return DSWhileStatement(condition: cond, body: body, lineContext: context)
			case .If:
				let ifstat = DSIfStatement(condition: cond, body: body, lineContext: context)
				switch tokens[0] {
				case .Else:
					consumeToken()
					if let elseBody = parseBody(true) {
						ifstat.elseBody = elseBody
					} else {
						errors.append(DSError(message: "Missing expected 'else' body.", lineContext: self.lineContext[0]))
						return nil
					}
				default:
					break
				}
				return ifstat
			default:
				return nil
			}
		}
		
		return nil
	}
	
	func parseForStatement() -> DSForStatement? {
		let initial = parseDeclarationStatement() as? DSDeclaration
		
		print(initial?.description)
		
		switch tokens[0] {
		case .Semicolon:
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected semicolon.", lineContext: self.lineContext[0]))
		}
		
		let condition = parseExpression()
		
		switch tokens[0] {
		case .Semicolon:
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected semicolon.", lineContext: self.lineContext[0]))
		}
		
		let increment = parseExpression()
		
		switch tokens[0] {
		case .Semicolon:
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected semicolon.", lineContext: self.lineContext[0]))
		}
		
		if let body = parseBody(true) {
			return DSForStatement(initial: initial!, condition: condition!, increment: increment!, body: body, lineContext: self.lineContext[0])
		} else {
			errors.append(DSError(message: "Missing expected 'for' body.", lineContext: self.lineContext[0]))
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
		case .BooleanLiteral(let bool):
			consumeToken()
			return DSBooleanLiteral(val: bool, lineContext: context)
		case .StringLiteral(let string):
			consumeToken()
			return DSStringLiteral(val: string, lineContext: context)
		default:
			errors.append(DSError(message: "\(tokens[0]) is not a DeafShark expression.", lineContext: context))
			return nil
		}
	}
	
	func parseFunctionDeclaration() -> DSFunctionDeclaration? {
		let context = self.lineContext[0]
		switch tokens[0] {
		case .Function:
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected 'func'.", lineContext: context))
			return nil
		}
		
		let functionId: String
		switch tokens[0] {
		case .Identifier(let string):
			functionId = string
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected identifier.", lineContext: context))
			return nil
		}
		
		switch tokens[0] {
		case .LeftBracket:
			consumeToken()
		default:
			errors.append(DSError(message: "Missing expected '('.", lineContext: context))
		}
		
		let parameters = parseParams()
		
		let returnType: DSType
		
		let returnTypeContext = self.lineContext[0]
		switch tokens[0] {
		case .Arrow:
			consumeToken()
			if let type = parseType() {
				returnType = type
			} else {
				return nil
			}
		default:
			returnType = DSType(identifier: "void", lineContext: context)
		}
		
		var body: DSFunctionBody?
		if (tokens.isEmpty) {
			errors.append(DSError(message: "Missing function body.", lineContext: returnTypeContext))
			return nil
		}
		let bodyContext = self.lineContext[0]
		switch tokens[0] {
		case .LeftBrace:
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
			case .RightBracket:
				consumeToken()
				return functionParameters
			case .Comma:
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
		
		if tokens.count == 0 {
			return identifier
		}
		switch tokens[0] {
		case .LeftBracket:
			consumeToken()
			var args = [DSExpr]()
			while true {
				if tokens.count == 0 {
					errors.append(DSError(message: "Missing expected '(' in function call", lineContext: context))
					return nil
				}
				switch tokens[0] {
				case .RightBracket:
					consumeToken()
					return DSCall(identifier: identifier, arguments: args)
				case .Comma:
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
}
