//
//  CPPWrapper.m
//  DeafShark
//
//  Created by Bradley Slayter on 6/23/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#import "Codegen.h"
#import "DeafShark-Swift.h"

#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/Bitcode/ReaderWriter.h"
#include "llvm/Support/raw_ostream.h"

@implementation Codegen

using namespace llvm;

static Module *theModule;
static IRBuilder<> Builder(getGlobalContext());
static NSMutableDictionary *namedValues;

+(Value *) ErrorV:(const char *)str {
	NSLog(@"%s", str);
	return 0;
}

+(Value *) VariableExpr_Codegen:(DSIdentifierString *)expr {
	Value *V = (__bridge Value *)namedValues[expr.name];
	return V ? V : [Codegen ErrorV:"unknown variable name"];
}

+(Value *) IntegerExpr_Codegen:(DSSignedIntegerLiteral *)expr {
	return ConstantInt::get(getGlobalContext(), APInt(32, (int)expr.val));
}

static AllocaInst *CreateEntryBlockAlloca(Function *theFunction, NSString *varName) {
	IRBuilder<> TmpB(&theFunction->getEntryBlock(), theFunction->getEntryBlock().begin());
	
	return TmpB.CreateAlloca(Type::getInt32Ty(getGlobalContext()), 0, [varName cStringUsingEncoding:NSASCIIStringEncoding]);
}

+(void) Declaration_Codegen:(DSDeclaration *)expr function:(Function *)func {
	Value *v = 0;
	
	if ([expr.assignment isKindOfClass:DSBinaryExpression.class]) {
		DSBinaryExpression *temp = (DSBinaryExpression *)expr.assignment;
		v = [self BinaryExp_Codegen:temp.lhs andRHS:temp.rhs andExpr:temp];
	}
	
	//[namedValues setObject:[NSValue valueWithBytes:&v objCType:@encode(Value)] forKey:expr.identifier];
	
	AllocaInst *alloca = CreateEntryBlockAlloca(func, expr.identifier);
	
	Builder.CreateStore(v, alloca);
}

+(Value *) BinaryExp_Codegen:(DSExpr *)LHS andRHS:(DSExpr *)RHS andExpr:(DSBinaryExpression *)expr {
	Value *L = nullptr, *R = nullptr;
	
	if ([LHS isKindOfClass:DSSignedIntegerLiteral.class]) {
		L = [self IntegerExpr_Codegen:(DSSignedIntegerLiteral *)LHS];
	}
	if ([RHS isKindOfClass:DSSignedIntegerLiteral.class]) {
		R = [self IntegerExpr_Codegen:(DSSignedIntegerLiteral *)LHS];
	}
	
	if ([expr.op isEqual: @"+"]) {
		return Builder.CreateAdd(L, R);
	} else if ([expr.op isEqual: @"-"]) {
		return Builder.CreateSub(L, R);
	} else if ([expr.op isEqual: @"*"]) {
		return Builder.CreateMul(L, R);
	} else if ([expr.op isEqual: @"/"]) {
		return Builder.CreateSDiv(L, R);
	}
	
	return [self ErrorV:"invalid binary operator"];
}

+(void) Call_Codegen:(DSCall *)expr {
	if ([expr.identifier.name isEqual:@"print"]) {
		DSStringLiteral *strArgType = (DSStringLiteral *)expr.children[0];
		NSString *strArg = strArgType.val;
		
		Value *string = Builder.CreateGlobalStringPtr([strArg cStringUsingEncoding:NSASCIIStringEncoding]);
		
		std::vector<Type *> putsArgs;
		putsArgs.push_back(Builder.getInt8Ty()->getPointerTo());
		ArrayRef<Type *> argsRef(putsArgs);
		
		FunctionType *putsType = FunctionType::get(Builder.getInt32Ty(), argsRef, false);
		Constant *putsFunc = theModule->getOrInsertFunction("puts", putsType);
		Builder.CreateCall(putsFunc, string);
	} else {
		NSLog(@"Function call not supported");
		exit(1);
	}
}

+(void) DSBody_Codegen:(DSBody *)body {
	LLVMContext &Context = getGlobalContext();
	
	theModule = new Module("myModule", Context);
	
	namedValues = [NSMutableDictionary dictionary];
	
	// Create function
	FunctionType *ft = FunctionType::get(Builder.getInt32Ty(), false);
	
	Function *f = Function::Create(ft, Function::ExternalLinkage, "main", theModule);
	
	BasicBlock *bb = BasicBlock::Create(getGlobalContext(), "entry", f);
	Builder.SetInsertPoint(bb);
	
	for (DSAST *child in body.children) {
		if ([child isKindOfClass:DSBinaryExpression.class]) {
			DSBinaryExpression *temp = (DSBinaryExpression *)child;
			[self BinaryExp_Codegen:temp.rhs andRHS:temp.lhs andExpr:temp];
		} else if ([child isKindOfClass:DSDeclaration.class]) {
			[self Declaration_Codegen:(DSDeclaration *)child function:f];
		} else if ([child isKindOfClass:DSCall.class]) {
			[self Call_Codegen:(DSCall *)child];
		}
	}
	
	Value *retVal = ConstantInt::get(getGlobalContext(), APInt(32, 0));
	Builder.CreateRet(retVal);
	
	
	theModule->dump();
	
	[Codegen writeBitcode];
}

+(void) writeBitcode {
	std::error_code ec;
	
	NSArray *args = [[NSProcessInfo processInfo] arguments];
	
	NSString *outputPath;
	if ([args containsObject:@"-o"]) {
		NSLog(@"Found output arg");
		int index = (int)([args indexOfObject:@"-o"] + 1);
		if (index < args.count) {
			outputPath = args[index];
			NSLog(@"Output: %@", outputPath);
		} else {
			NSLog(@"Missing output argument");
			exit(1);
		}
	} else {
		NSString *filename = nil;
		for (NSString *arg in args) {
			if ([arg hasSuffix:@".ds"]) {
				filename = [arg stringByDeletingPathExtension];
				break;
			}
		}
		
		if (filename != nil) {
			outputPath = [filename stringByAppendingPathExtension:@"bc"];
		}
	}
	
	raw_fd_ostream output([outputPath cStringUsingEncoding:NSUTF8StringEncoding], ec,
						  (sys::fs::OpenFlags)0);
	
	WriteBitcodeToFile(theModule, output);
}

@end
