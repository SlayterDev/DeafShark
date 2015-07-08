//
//  Codegen_NonSwift.h
//  DeafShark
//
//  Created by Bradley Slayter on 7/8/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#ifndef Codegen_NonSwift_h
#define Codegen_NonSwift_h

#include "llvm/IR/Verifier.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/Bitcode/ReaderWriter.h"
#include "llvm/Support/raw_ostream.h"

#include <Foundation/Foundation.h>

@class DSCall;

@interface Codegen : NSObject

+(llvm::Value *) Call_Codegen:(DSCall *)expr;

@end

#endif /* Codegen_NonSwift_h */
