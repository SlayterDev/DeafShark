//
//  DSAST.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/16/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Cocoa

@objc open class DSAST: NSObject {
	var children: [DSAST] = []
	
	override init() {
		
	}
	
	init(lineContext: LineContext?) {
		super.init()
		self.lineContext = lineContext
	}
	
	fileprivate var explicitLineContext: LineContext?
	
	var lineContext: LineContext? {
		get {
			return explicitLineContext ?? children.first?.lineContext
		}
		set (explicitLineContext) {
			self.explicitLineContext = explicitLineContext
		}
	}
	
	override open var description: String {
		return ("DeafSharkAST" + self.childDescriptions)
	}
	
	open var childDescriptions: String {
		let indentedDescriptions = self.children.map({ (child: DSAST) -> String in
			child.description.components(separatedBy: "\n").reduce("") {
				return $0 + "\n\t" + $1
			}
		})
		
		return indentedDescriptions.reduce("", +)
	}
}

// Program Body
open class DSBody: DSAST {
	func codeGen() {
		Codegen.topLevel_Codegen(self)
	}
}

open class DSExpr: DSAST {
	let isAssignable: Bool
	init(assignable: Bool = false, lineContext: LineContext?) {
		self.isAssignable = assignable
		super.init(lineContext: lineContext)
	}
}

@objc open class DSType: DSAST {
	var identifier: String
	var itemCount: Int?
	
	override init() {
		self.identifier = ""
		super.init()
	}
	
	init(identifier: String, itemCount: Int?, lineContext: LineContext?) {
		self.identifier = identifier
		self.itemCount = itemCount
		super.init(lineContext: lineContext)
	}
	
	override open var description: String {
		return "DeafSharkType - type:\(identifier)"
	}
	
	func getItemCount() -> Int {
		return itemCount!
	}
}

open class DSAssignment: DSAST {
	var storage: DSExpr
	var expression: DSExpr
	
	init(storage: DSExpr, expression: DSExpr) {
		self.storage = storage
		self.expression = expression
		super.init(lineContext: nil)
		self.children = [self.storage, self.expression]
	}
	
	override open var description: String {
		return "DeafSharkAssignment " + self.childDescriptions
	}
}

open class DSDeclaration: DSAST {
	var identifier: String
	var isConstant: Bool
	var type: DSType?
	var assignment: DSExpr? {
		didSet {
			self.children.append(assignment!)
		}
	}
	
	init(id: String, type: DSType?, lineContext: LineContext?) {
		identifier = id
		isConstant = true
		self.type = type
		super.init(lineContext: lineContext)
		if let type = type {
			self.children.append(type)
		}
	}
	
	convenience init(id: String, lineContext: LineContext?) {
		self.init(id: id, type: nil, lineContext: lineContext)
	}
	
	override open var description: String {
		return "DeafSharkDeclaration - identifier:\(identifier), isConstant:\(isConstant)" + self.childDescriptions
	}
}

open class DSBinaryExpression: DSExpr {
	let op: String
	let lhs: DSExpr
	let rhs: DSExpr
	
	init(op: String, lhs: DSExpr, rhs: DSExpr) {
		self.op = op
		self.lhs = lhs
		self.rhs = rhs
		super.init(assignable: false, lineContext: nil)
		
		switch lhs {
		case let l as DSBinaryExpression:
			self.children.append(contentsOf: l.children)
		default:
			self.children.append(lhs)
		}
		
		switch rhs {
		case let r as DSBinaryExpression:
			self.children.append(contentsOf: r.children)
		default:
			self.children.append(rhs)
		}
	}
	
	override open var description: String {
		return "DeafSharkBinaryOperation - op:\(op)" + "\n RH\(op): " + self.lhs.description + "\n LH\(op): " + self.rhs.description
	}
}

open class DSFunctionType: DSType {
	var parameterType: DSType
	var returnType: DSType
	
	init(parameterType: DSType, returnType: DSType, lineContext: LineContext? = nil) {
		self.parameterType = parameterType
		self.returnType = returnType
		super.init(identifier: "func", itemCount: nil, lineContext: lineContext)
	}
	
	override open var description: String {
		var description = "("
		description += parameterType.description
		description += " -> "
		description += returnType.description
		description += ")"
		return description
	}
}

open class DSFunctionParameter: DSDeclaration {}

open class DSFunctionBody: DSBody {
	init(_ body: DSBody, lineContext: LineContext?) {
		super.init(lineContext: lineContext)
		self.children = body.children
		self.lineContext = body.lineContext
	}
	
	override open var description: String {
		return "DeafSharkFunctionBody" + self.childDescriptions
	}
}

open class DSFunctionDeclaration: DSAST {
	var prototype: DSFunctionPrototype
	var body: DSFunctionBody?
	
	init(id: String, parameters: [DSDeclaration], returnType: DSType, body: DSFunctionBody?, lineContext: LineContext?) {
		self.prototype = DSFunctionPrototype(id: id, parameters: parameters, returnType: returnType, lineContext: lineContext)
		self.body = body
		super.init(lineContext: lineContext)
		self.children.append(self.prototype)
		if let body = self.body {
			self.children.append(body)
		}
	}
	
	override open var description: String {
		return "DeafSharkFunctionDeclaration - \(self.prototype.identifier) -> \(self.prototype.type!.identifier)" + self.childDescriptions
	}
}

open class DSFunctionPrototype: DSDeclaration {
	var parameters: [DSDeclaration]
	
	init(id: String, parameters: [DSDeclaration], returnType: DSType, lineContext: LineContext?) {
		self.parameters = parameters
		super.init(id: id, type: returnType, lineContext: lineContext)
	}
	
	override open var description: String {
		var description = "DeafSharkFunctionPrototype - \(self.identifier)( "
		for param in self.parameters {
			description += param.identifier + " "
		}
		description += ") -> \(self.type!.identifier)" + self.childDescriptions
		return description
	}
}

open class DSCall: DSExpr {
	let identifier: DSIdentifierString
	
	init(identifier: DSIdentifierString, arguments: [DSExpr]) {
		self.identifier = identifier
		super.init(lineContext: nil)
		let args = arguments as [DSAST]
		self.children.append(contentsOf: args)
	}
	
	override open var description: String {
		return "DeafSharkFunctionCall - identifier:\(identifier.name)" + self.childDescriptions
	}
}

open class DSConditionalStatement: DSAST {
	let cond: DSExpr
	let body: DSBody
	
	init(condition: DSExpr, body: DSBody, lineContext: LineContext?) {
		self.cond = condition
		self.body = body
		super.init(lineContext: lineContext)
		self.lineContext = lineContext
	}
}

open class DSIfStatement: DSConditionalStatement {
	var elseBody: DSBody?
	var alternates: [DSIfStatement]?
	
	override init(condition: DSExpr, body: DSBody, lineContext: LineContext?) {
		self.elseBody = nil
		self.alternates = [DSIfStatement]()
		super.init(condition: condition, body: body, lineContext: lineContext)
	}
	
	override open var description: String {
		var desc = "DeafSharkIfStatement - condition:\(self.cond.description)"
		
		for alt in alternates! {
			desc += " " + alt.description
		}
		
		return desc
	}
}

open class DSWhileStatement: DSConditionalStatement {
	override open var description: String {
		return "DeafSharkWhileStatement - condition:\(self.cond.description)" + self.body.description
	}
}

open class DSForStatement: DSConditionalStatement {
	let initial: DSAST
	let increment: DSExpr
	
	init(initial: DSAST, condition: DSExpr, increment: DSExpr, body: DSBody, lineContext: LineContext?) {
		self.initial = initial
		self.increment = increment
		super.init(condition: condition, body: body, lineContext: lineContext)
	}
	
	override open var description: String {
		return "DeafSharkForStatement - condition:\(self.cond.description)" + self.body.description
	}
}

open class DSReturnStatement: DSExpr {
	let statement: DSExpr
	
	init (statement: DSExpr, lineContext: LineContext?) {
		self.statement = statement
		super.init(assignable: false, lineContext: lineContext)
	}
}

open class DSBreakStatement: DSExpr {
	init (lineContext: LineContext?) {
		super.init(assignable: false, lineContext: lineContext)
	}
	
	override open var description: String {
		return "DeafSharkBreakStatement - break"
	}
}

open class DSIdentifierString: DSExpr {
	var name: String
	var arrayAccess: DSExpr?
	
	init(name: String, lineContext: LineContext) {
		self.name = name
		super.init(assignable: true, lineContext: lineContext)
	}
	
	override open var description: String {
		return "DeafSharkIdentifier - name:\(name) " + ((self.arrayAccess == nil) ? "" : "[" + self.arrayAccess!.description + "]")
	}
}

open class DSStringLiteral: DSExpr {
	let val: String
	init (val: String, lineContext: LineContext?) {
		self.val = val
		super.init(lineContext: lineContext)
	}
	
	override open var description: String {
		return "DeafSharkStringLiteral - val:\"\(val)\""
	}
}

open class DSSignedIntegerLiteral: DSExpr {
	let val: Int
	init(val: Int, lineContext: LineContext?) {
		self.val = val
		super.init(lineContext: lineContext)
	}
	
	override open var description: String {
		return "DeafSharkSignedIntegerLiteral - val:\(val)"
	}
}

open class DSFloatLiteral: DSExpr {
	let val: Float
	init(val: Float, lineContext: LineContext?) {
		self.val = val
		super.init(lineContext: lineContext)
	}
	
	override open var description: String {
		return "DeafSharkFloatLiteral - val:\(val)"
	}
}

open class DSBooleanLiteral: DSExpr {
	let val: Bool
	init(val: Bool, lineContext: LineContext?) {
		self.val = val
		super.init(lineContext: lineContext)
	}
	
	override open var description: String {
		return "DeafSharkBooleanLiteral - val:\(val)"
	}
}

open class DSArrayLiteral: DSExpr {
	init(elements: [DSExpr], lineContext: LineContext?) {
		super.init(lineContext: lineContext)
		self.children = elements
	}
	
	override open var description: String {
		return "DeafSharkArrayLiteral" + self.childDescriptions
	}
}
