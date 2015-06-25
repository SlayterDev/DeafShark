//
//  main.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation

if let ast = "let x = 5 + 5\nlet y = 9 * 9".tokenize()?.parse() {
	print(ast.description)
	
	if let body = ast as? DSBody {
		body.codeGen()
	}
}
