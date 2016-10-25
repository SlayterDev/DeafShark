//
//  main.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation


var inputFile = ""

if CommandLine.arguments.count == 1 || CommandLine.arguments.contains("--help") {
	print("DeafShark compiler -- Written by Bradley Slayter")
	print("\nBasic usage: \(CommandLine.arguments[0]) <inputfile>")
	print("<inputfile>: The source file you wish to compile. (Must end with .ds)")
	print("\nOther options:")
	print("--verbose\tDisplay the AST and LLVM IR during compilation")
	print("--emit-ast\tDisplay the AST (Abstract Syntax Tree) and stop compilation")
	print("--emit-ir \tDisplay the LLVM IR (Intermidiate Representation) and stop compilation")
	print("-bc       \tCompile the code to LLVM bitcode\n")
	exit(0)
}

for arg in CommandLine.arguments {
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
	var nsFileContent = try NSString(contentsOfFile: inputFile, encoding: String.Encoding.utf8.rawValue)
	nsFileContent = nsFileContent.restoreEscapeCharacters()
	fileContent = nsFileContent as String
} catch {
	print("Could not open file")
	exit(1)
}

if let ast = fileContent.tokenize()?.parse() {
	if CommandLine.arguments.contains("--verbose") || CommandLine.arguments.contains("--emit-ast") {
		print(ast.description)
		
		if CommandLine.arguments.contains("--emit-ast") {
			exit(0)
		}
	}

	if let body = ast as? DSBody {
		body.codeGen()
	}
}
