//
//  Codegen+NonSwift.h
//  DeafShark
//
//  Created by Bradley Slayter on 7/7/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#ifndef Codegen_NonSwift_h
#define Codegen_NonSwift_h

#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/Bitcode/ReaderWriter.h"
#include "llvm/Support/raw_ostream.h"

@class DSBody;
@class DSExpr;

@interface Codegen : NSObject

+(llvm::Value *) Body_Codegen:(DSBody *)body andFunction:(llvm::Function *)f;
+(llvm::Value *) Expression_Codegen:(DSExpr *)expr;

@end

#endif /* Codegen_NonSwift_h */
