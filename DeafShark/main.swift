//
//  main.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation


var inputFile = ""

if Process.arguments.count == 1 || Process.arguments.contains("--help") {
	print("DeafShark compiler -- Written by Bradley Slayter")
	print("\nBasic usage: \(Process.arguments[0]) <inputfile>")
	print("<inputfile>: The source file you wish to compile. (Must end with .ds)")
	print("\nOther options:")
	print("--verbose\tDisplay the AST and LLVM IR during compilation")
	print("--emit-ast\tDisplay the AST (Abstract Syntax Tree) and stop compilation")
	print("--emit-ir \tDisplay the LLVM IR (Intermidiate Representation) and stop compilation\n")
	exit(0)
}

for arg in Process.arguments {
	let nsarg = arg as NSString
	if nsarg.hasSuffix(".ds") {
		inputFile = arg
		break
	}
}

if inputFile == "" {
	print("Missing input file")
	exit(1)
}

let fileContent: String
do {
	var nsFileContent = try NSString(contentsOfFile: inputFile, encoding: NSUTF8StringEncoding)
	nsFileContent = nsFileContent.restoreEscapeCharacters()
	fileContent = nsFileContent as String
} catch {
	print("Could not open file")
	exit(1)
}

if let ast = fileContent.tokenize()?.parse() {
	if Process.arguments.contains("--verbose") || Process.arguments.contains("--emit-ast") {
		print(ast.description)
		
		if Process.arguments.contains("--emit-ast") {
			exit(0)
		}
	}

	if let body = ast as? DSBody {
		body.codeGen()
	}
}
