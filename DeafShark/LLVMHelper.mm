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

+(Value *) valueForArgument:(DSAST *)argument {
	if ([argument isKindOfClass:DSSignedIntegerLiteral.class]) {
		DSSignedIntegerLiteral *intLit = (DSSignedIntegerLiteral *)argument;
		
		return ConstantInt::get(getGlobalContext(), APInt(32, (int)intLit.val));
	}
	
	return nil;
}

@end
