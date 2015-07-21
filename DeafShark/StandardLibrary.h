//
//  StandardLibrary.h
//  DeafShark
//
//  Created by Bradley Slayter on 7/18/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "llvm/IR/DataLayout.h"
#include "llvm/IR/Verifier.h"
#include "llvm/Analysis/Passes.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/Bitcode/ReaderWriter.h"
#include "llvm/Support/raw_ostream.h"

@interface StandardLibrary : NSObject

+(llvm::Constant *) getFunction:(NSString *)functionName withBuilder:(llvm::IRBuilder<>)Builder andModule:(llvm::Module *)theModule;

@end
