//
//  CompilerHelper.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/30/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Cocoa

@objc class CompilerHelper: NSObject {
	static let sharedInstance = CompilerHelper()
	
	var printCallArgs: [DSAST]
	
	override init() {
		printCallArgs = [DSAST]()
	}
	
	func getMostRecentPrintArgs() -> [DSAST] {
		return self.printCallArgs
	}
	
	func formatForType(type: String) -> String {
		switch (type) {
		case "Int":
			return "%d"
		case "String":
			return "%s"
		default:
			return "%d"
		}
	}
	
	func getPrintFormatString(call: DSCall) -> NSString {
		let args = call.children
		printCallArgs = [DSAST]()
		
		var format = ""
		
		for child in args {
			switch child {
			case let stringLit as DSStringLiteral:
				format += stringLit.val
			case let intLit as DSSignedIntegerLiteral:
				format += "%d"
				printCallArgs.append(intLit)
			case let expr as DSBinaryExpression:
				var binExpArgs = [DSAST]()
				var binExpForm = ""
				(binExpForm, binExpArgs) = binaryExprFormat(expr)
				format += binExpForm
				printCallArgs += binExpArgs
			case let expr as DSIdentifierString:
				let type = Codegen.typeForIdentifier(expr)
				format += formatForType(type)
				printCallArgs.append(expr)
			default:
				break
			}
		}
		
		format += "\n"
		
		return format as NSString
	}
	
	func binaryExprFormat(expr: DSBinaryExpression) -> (String, [DSAST]) {
		var args = [DSAST]()
		
		var lhsFormat = ""
		switch expr.lhs {
		case let stringLit as DSStringLiteral:
			lhsFormat += stringLit.val
		case let intLit as DSSignedIntegerLiteral:
			lhsFormat += "%d"
			args.append(intLit)
		case let binExpr as DSBinaryExpression:
			var binExpArgs = [DSAST]()
			var binExpFormat = ""
			(binExpFormat, binExpArgs) = binaryExprFormat(binExpr)
			lhsFormat += binExpFormat
			args += binExpArgs
		case let expr as DSIdentifierString:
			lhsFormat += "%d"
			args.append(expr)
		default:
			lhsFormat += ""
		}
		
		var rhsFormat = ""
		switch expr.rhs {
		case let stringLit as DSStringLiteral:
			rhsFormat += stringLit.val
		case let intLit as DSSignedIntegerLiteral:
			rhsFormat += "%d"
			args.append(intLit)
		case let binExpr as DSBinaryExpression:
			var binExpArgs = [DSAST]()
			var binExpFormat = ""
			(binExpFormat, binExpArgs) = binaryExprFormat(binExpr)
			rhsFormat += binExpFormat
			args += binExpArgs
		case let expr as DSIdentifierString:
			rhsFormat += "%d"
			args.append(expr)
		default:
			rhsFormat += ""
		}
		
		return ((lhsFormat + rhsFormat), args)
	}
	
	func isValidBinaryAssignment(expr: DSBinaryExpression) -> Bool {
		switch expr.op {
		case "+=":
			fallthrough
		case "-=":
			fallthrough
		case "/=":
			fallthrough
		case "*=":
			return true
		default:
			return false
		}
	}
	
	func getModuleName() -> String {
		let nsInputFile = inputFile as NSString
		return nsInputFile.lastPathComponent.stringByDeletingPathExtension
	}
	
}
