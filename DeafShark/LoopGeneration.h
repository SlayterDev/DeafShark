//
//  LoopGeneration.h
//  DeafShark
//
//  Created by Bradley Slayter on 7/7/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/Bitcode/ReaderWriter.h"
#include "llvm/Support/raw_ostream.h"

@class DSWhileStatement;

@interface LoopGeneration : NSObject

+(llvm::Value *) WhileLoop_Codegen:(DSWhileStatement *)expr withBuilder:(llvm::IRBuilder<>)Builder;

@end
