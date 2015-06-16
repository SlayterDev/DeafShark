//
//  main.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation

if let ast = "let x = 5 + 5 \n var y = 10\ny = 12 + 6 * 3 - 4".tokenize()?.parse() {
	print(ast.description)
}
