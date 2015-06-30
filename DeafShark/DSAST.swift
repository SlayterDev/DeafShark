//
//  DSAST.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/16/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Cocoa

@objc public class DSAST: NSObject {
	var children: [DSAST] = []
	
	init(lineContext: LineContext?) {
		super.init()
		self.lineContext = lineContext
	}
	
	private var explicitLineContext: LineContext?
	
	var lineContext: LineContext? {
		get {
			return explicitLineContext ?? children.first?.lineContext
		}
		set (explicitLineContext) {
			self.explicitLineContext = explicitLineContext
		}
	}
	
	override public var description: String {
		return ("DeafSharkAST" + self.childDescriptions)
	}
	
	public var childDescriptions: String {
		let indentedDescriptions = self.children.map({ (child: DSAST) -> String in
			child.description.componentsSeparatedByString("\n").reduce("") {
				return $0 + "\n\t" + $1
			}
		})
		
		return indentedDescriptions.reduce("", combine: +)
	}
}

// Program Body
public class DSBody: DSAST {
	func codeGen() {
		Codegen.DSBody_Codegen(self)
	}
}

public class DSExpr: DSAST {
	let isAssignable: Bool
	init(assignable: Bool = false, lineContext: LineContext?) {
		self.isAssignable = assignable
		super.init(lineContext: lineContext)
	}
}

public class DSType: DSAST {
	var identifier: String
	
	init(identifier: String, lineContext: LineContext?) {
		self.identifier = identifier
		super.init(lineContext: lineContext)
	}
	
	override public var description: String {
		return "DeafSharkType - type:\(identifier)"
	}
}

public class DSAssignment: DSAST {
	var storage: DSExpr
	var expression: DSExpr
	
	init(storage: DSExpr, expression: DSExpr) {
		self.storage = storage
		self.expression = expression
		super.init(lineContext: nil)
		self.children = [self.storage, self.expression]
	}
	
	override public var description: String {
		return "DeafSharkAssignment " + self.childDescriptions
	}
}

public class DSDeclaration: DSAST {
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
	
	override public var description: String {
		return "DeafSharkDeclaration - identifier:\(identifier), isConstant:\(isConstant)" + self.childDescriptions
	}
}

public class DSBinaryExpression: DSExpr {
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
			self.children.extend(l.children)
		default:
			self.children.append(lhs)
		}
		
		switch rhs {
		case let r as DSBinaryExpression:
			self.children.extend(r.children)
		default:
			self.children.append(rhs)
		}
	}
	
	override public var description: String {
		return "DeafSharkBinaryOperation - op:\(op)" + "\n RH\(op): " + self.lhs.description + "\n LH\(op): " + self.rhs.description
	}
}

public class DSFunctionType: DSType {
	var parameterType: DSType
	var returnType: DSType
	
	init(parameterType: DSType, returnType: DSType, lineContext: LineContext? = nil) {
		self.parameterType = parameterType
		self.returnType = returnType
		super.init(identifier: "func", lineContext: lineContext)
	}
	
	override public var description: String {
		var description = "("
		description += parameterType.description
		description += " -> "
		description += returnType.description
		description += ")"
		return description
	}
}

public class DSFunctionParameter: DSDeclaration {}

public class DSFunctionBody: DSBody {
	init(_ body: DSBody, lineContext: LineContext?) {
		super.init(lineContext: lineContext)
		self.children = body.children
		self.lineContext = body.lineContext
	}
	
	override public var description: String {
		return "DeafSharkFunctionBody" + self.childDescriptions
	}
}

public class DSFunctionDeclaration: DSAST {
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
	
	override public var description: String {
		return "DeafSharkFunctionDeclaration - \(self.prototype.identifier) -> \(self.prototype.type!.identifier)" + self.childDescriptions
	}
}

public class DSFunctionPrototype: DSDeclaration {
	var parameters: [DSDeclaration]
	
	init(id: String, parameters: [DSDeclaration], returnType: DSType, lineContext: LineContext?) {
		self.parameters = parameters
		super.init(id: id, type: returnType, lineContext: lineContext)
	}
	
	override public var description: String {
		var description = "DeafSharkFunctionPrototype - \(self.identifier)( "
		for param in self.parameters {
			description += param.identifier + " "
		}
		description += ") -> \(self.type!.identifier)" + self.childDescriptions
		return description
	}
}

public class DSCall: DSExpr {
	let identifier: DSIdentifierString
	
	init(identifier: DSIdentifierString, arguments: [DSExpr]) {
		self.identifier = identifier
		super.init(lineContext: nil)
		let args = arguments as [DSAST]
		self.children.extend(args)
	}
	
	override public var description: String {
		return "DeafSharkFunctionCall - identifier:\(identifier.name)" + self.childDescriptions
	}
}

public class DSConditionalStatement: DSAST {
	let cond: DSExpr
	let body: DSBody
	
	init(condition: DSExpr, body: DSBody, lineContext: LineContext?) {
		self.cond = condition
		self.body = body
		super.init(lineContext: lineContext)
		self.lineContext = lineContext
	}
}

public class DSIfStatement: DSConditionalStatement {}

public class DSWhileStatement: DSConditionalStatement {}

public class DSIdentifierString: DSExpr {
	var name: String
	
	init(name: String, lineContext: LineContext) {
		self.name = name
		super.init(assignable: true, lineContext: lineContext)
	}
	
	override public var description: String {
		return "DeafSharkIdentifier - name:\(name)"
	}
}

public class DSStringLiteral: DSExpr {
	let val: String
	init (val: String, lineContext: LineContext?) {
		self.val = val
		super.init(lineContext: lineContext)
	}
	
	override public var description: String {
		return "DeafSharkStringLiteral - val:\"\(val)\""
	}
}

public class DSSignedIntegerLiteral: DSExpr {
	let val: Int
	init(val: Int, lineContext: LineContext?) {
		self.val = val
		super.init(lineContext: lineContext)
	}
	
	override public var description: String {
		return "DeafSharkSignedIntegerLiteral - val:\(val)"
	}
}

public class DSFloatLiteral: DSExpr {
	let val: Float
	init(val: Float, lineContext: LineContext?) {
		self.val = val
		super.init(lineContext: lineContext)
	}
	
	override public var description: String {
		return "DeafSharkFloatLiteral - val:\(val)"
	}
}

public class DSBooleanLiteral: DSExpr {
	let val: Bool
	init(val: Bool, lineContext: LineContext?) {
		self.val = val
		super.init(lineContext: lineContext)
	}
	
	override public var description: String {
		return "DeafSharkBooleanLiteral - val:\(val)"
	}
}
