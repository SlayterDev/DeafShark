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
			default:
				break
			}
		}
		
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
		default:
			rhsFormat += ""
		}
		
		return ((lhsFormat + rhsFormat), args)
	}
	
}
