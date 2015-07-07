//
//  LoopGeneration.m
//  DeafShark
//
//  Created by Bradley Slayter on 7/7/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#import "LoopGeneration.h"
#import "Codegen+NonSwift.h"
#import "DeafShark-Swift.h"

using namespace llvm;

@implementation LoopGeneration

+(Value *) WhileLoop_Codegen:(DSWhileStatement *)expr withBuilder:(IRBuilder<>)Builder {
	Function *theFunc = Builder.GetInsertBlock()->getParent();
	//BasicBlock *preHeaderBB = Builder.GetInsertBlock();
	BasicBlock *loopBB = BasicBlock::Create(getGlobalContext(), "loop", theFunc);
	
	Builder.CreateBr(loopBB);
	Builder.SetInsertPoint(loopBB);
	
	//PHINode *Variable = Builder.CreatePHI(Type::getInt32Ty(getGlobalContext()), 2, )
	
	if ([Codegen Body_Codegen:expr.body andFunction:theFunc] == 0)
		return 0;
	
	Value *cond = [Codegen Expression_Codegen:expr.cond];
	if (cond == 0)
		return 0;
	
	cond = Builder.CreateFCmpONE(cond, ConstantFP::get(getGlobalContext(), APFloat(0.0)), "loopcond");
	
	//BasicBlock *loopEndBB = Builder.GetInsertBlock();
	BasicBlock *afterBB = BasicBlock::Create(getGlobalContext(), "afterLoop", theFunc);
	
	Builder.CreateCondBr(cond, loopBB, afterBB);
	Builder.SetInsertPoint(afterBB);
	
	return Constant::getNullValue(Type::getDoubleTy(getGlobalContext()));
}

@end
