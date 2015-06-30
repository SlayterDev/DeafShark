//
//  main.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation


var inputFile = ""

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
	fileContent = try NSString(contentsOfFile: inputFile, encoding: NSUTF8StringEncoding) as String
} catch {
	print("Could not open file")
	exit(1)
}

if let ast = fileContent.tokenize()?.parse() {
	print(ast.description)

	if let body = ast as? DSBody {
		body.codeGen()
	}
} else {
	print("Something went wrong")
}
