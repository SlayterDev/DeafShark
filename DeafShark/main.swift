//
//  main.swift
//  DeafShark
//
//  Created by Bradley Slayter on 6/15/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

import Foundation

let (dst, errors) = DeafSharkToken.tokenize("let x = 5")

print(dst.description)
