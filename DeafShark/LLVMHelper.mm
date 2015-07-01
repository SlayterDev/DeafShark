//
//  LLVMHelper.m
//  DeafShark
//
//  Created by Bradley Slayter on 6/30/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#import "LLVMHelper.h"
#import "DeafShark-Swift.h"

using namespace llvm;

@implementation LLVMHelper

+(Value *) VariableExpr_Codegen:(DSIdentifierString *)expr symbolTable:(std::map<NSString *, AllocaInst *>)namedValues andBuilder:(IRBuilder<>)Builder {
	Value *V = namedValues[expr.name];
	if (V == 0) return 0;
	
	return Builder.CreateLoad(V, [expr.name cStringUsingEncoding:NSUTF8StringEncoding]);
}

+(Value *) valueForArgument:(DSAST *)argument symbolTable:(std::map<NSString *, AllocaInst *>)namedValues andBuilder:(IRBuilder<>)Builder {
	if ([argument isKindOfClass:DSSignedIntegerLiteral.class]) {
		DSSignedIntegerLiteral *intLit = (DSSignedIntegerLiteral *)argument;
		
		return ConstantInt::get(getGlobalContext(), APInt(32, (int)intLit.val));
	} else if ([argument isKindOfClass:DSIdentifierString.class]) {
		return [self VariableExpr_Codegen:(DSIdentifierString *)argument symbolTable:namedValues andBuilder:Builder];
	}
	
	return nil;
}

@end
