//
//  CPPWrapper.m
//  DeafShark
//
//  Created by Bradley Slayter on 6/23/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#import "Codegen.h"
#import "DeafShark-Swift.h"
#import "LLVMHelper.h"

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
static std::map<NSString *, AllocaInst *> namedValues;
static std::map<NSString *, NSString *>namedTypes;

static BOOL printMade = false;
Constant *putsFunc;

+(Value *) ErrorV:(const char *)str {
	NSLog(@"%s", str);
	return 0;
}

+(Value *) VariableExpr_Codegen:(DSIdentifierString *)expr {
	Value *V = namedValues[expr.name];
	if (V == 0) return [Codegen ErrorV:"unknown variable name"];
	
	return Builder.CreateLoad(V, [expr.name cStringUsingEncoding:NSUTF8StringEncoding]);
}

+(Value *) IntegerExpr_Codegen:(DSSignedIntegerLiteral *)expr {
	return ConstantInt::get(getGlobalContext(), APInt(32, (int)expr.val));
}

+(NSString *) typeForIdentifier:(DSIdentifierString *)expr {
	return namedTypes[expr.name];
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
	} else if ([expr.assignment isKindOfClass:DSIdentifierString.class]) {
		v = [self VariableExpr_Codegen:(DSIdentifierString *)expr.assignment];
	}
	
	AllocaInst *alloca = CreateEntryBlockAlloca(func, expr.identifier);
	
	namedValues[expr.identifier] = alloca;
	namedTypes[expr.identifier] = expr.type.identifier;
	
	Builder.CreateStore(v, alloca);
}

+(Value *) BinaryExp_Codegen:(DSExpr *)LHS andRHS:(DSExpr *)RHS andExpr:(DSBinaryExpression *)expr {
	Value *L = nullptr, *R = nullptr;
	
	if ([LHS isKindOfClass:DSSignedIntegerLiteral.class]) {
		L = [self IntegerExpr_Codegen:(DSSignedIntegerLiteral *)LHS];
	} else if ([LHS isKindOfClass:DSBinaryExpression.class]) {
		DSBinaryExpression *temp = (DSBinaryExpression *)LHS;
		L = [self BinaryExp_Codegen:temp.lhs andRHS:temp.rhs andExpr:temp];
	} else if ([LHS isKindOfClass:DSIdentifierString.class]) {
		L = [self VariableExpr_Codegen:(DSIdentifierString *)LHS];
	}
	
	
	if ([RHS isKindOfClass:DSSignedIntegerLiteral.class]) {
		R = [self IntegerExpr_Codegen:(DSSignedIntegerLiteral *)RHS];
	} else if ([RHS isKindOfClass:DSBinaryExpression.class]) {
		DSBinaryExpression *temp = (DSBinaryExpression *)RHS;
		R = [self BinaryExp_Codegen:temp.lhs andRHS:temp.rhs andExpr:temp];
	} else if ([RHS isKindOfClass:DSIdentifierString.class]) {
		R = [self VariableExpr_Codegen:(DSIdentifierString *)RHS];
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

+(void) Assignment_Codegen:(DSAssignment *)expr {
	if (![expr.storage isKindOfClass:DSIdentifierString.class]) {
		[self ErrorV:"Cannot make assignment to this expression"];
		exit(0);
	}
	
	DSIdentifierString *store = (DSIdentifierString *)expr.storage;
	
	Value *var = namedValues[store.name];
	if (var == 0) [self ErrorV:"Unknown variable name"];
	
	Value *v = 0;
	
	if ([expr.expression isKindOfClass:DSBinaryExpression.class]) {
		DSBinaryExpression *temp = (DSBinaryExpression *)expr.expression;
		v = [self BinaryExp_Codegen:temp.lhs andRHS:temp.rhs andExpr:temp];
	} else if ([expr.expression isKindOfClass:DSIdentifierString.class]) {
		v = [self VariableExpr_Codegen:(DSIdentifierString *)expr.expression];
	}
	
	Builder.CreateStore(v, var);
}

+(void) Call_Codegen:(DSCall *)expr {
	if ([expr.identifier.name isEqual:@"print"]) {
		if (!printMade) {
			std::vector<Type *> putsArgs;
			putsArgs.push_back(Builder.getInt8Ty()->getPointerTo());
			ArrayRef<Type *> argsRef(putsArgs);
			
			FunctionType *putsType = FunctionType::get(Builder.getInt32Ty(), argsRef, true);
			putsFunc = theModule->getOrInsertFunction("printf", putsType);
		}
		
		// MAKE THE CALL
		NSString *format = [[CompilerHelper sharedInstance] getPrintFormatString:expr];
		NSArray *args = [[CompilerHelper sharedInstance] getMostRecentPrintArgs];
		
		Value *string = Builder.CreateGlobalStringPtr([format cStringUsingEncoding:NSASCIIStringEncoding]);
		
		std::vector<Value *> printArguments;
		printArguments.push_back(string);
		
		for (DSAST *arg in args) {
			if ([arg isKindOfClass:DSIdentifierString.class]) {
				Value *v = [self VariableExpr_Codegen:(DSIdentifierString *)arg];
				printArguments.push_back(v);
				continue;
			}
			
			printArguments.push_back([LLVMHelper valueForArgument:arg]);
		}
		
		Builder.CreateCall(putsFunc, printArguments);
	} else {
		NSLog(@"Function call not supported");
		exit(1);
	}
}

+(void) DSBody_Codegen:(DSBody *)body {
	LLVMContext &Context = getGlobalContext();
	
	theModule = new Module("myModule", Context);
	
	namedValues.clear();
	namedTypes.clear();
	
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
		} else if ([child isKindOfClass:DSAssignment.class]) {
			[self Assignment_Codegen:(DSAssignment *)child];
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
		int index = (int)([args indexOfObject:@"-o"] + 1);
		if (index < args.count) {
			outputPath = args[index];
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
