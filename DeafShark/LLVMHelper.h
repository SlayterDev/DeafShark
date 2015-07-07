//
//  LLVMHelper.h
//  DeafShark
//
//  Created by Bradley Slayter on 6/30/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/Bitcode/ReaderWriter.h"
#include "llvm/Support/raw_ostream.h"

@class DSAST;
@class DSType;

@interface LLVMHelper : NSObject

+(llvm::Value *) valueForArgument:(DSAST *)argument symbolTable:(std::map<NSString *, llvm::AllocaInst *>)namedValues andBuilder:(llvm::IRBuilder<>)Builder;
+(llvm::Type *) typeForArgument:(DSType *)argument withBuilder:(llvm::IRBuilder<>)Builder;

@end
