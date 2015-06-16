//
//  main.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation

if let ast = "let x as Int = 5 + 5".tokenize()?.parse() {
	print(ast.description)
}
