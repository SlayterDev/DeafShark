//
//  main.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation

if let ast = "func add(x as Int, y as Int) -> Int { let a = x + y }".tokenize()?.parse() {
	print(ast.description)
}
