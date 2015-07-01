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
	} else if ([expr.assignment isKindOfClass:DSCall.class]) {
		v = [self Call_Codegen:(DSCall *)expr.assignment];
	} else if ([expr.assignment isKindOfClass:DSSignedIntegerLiteral.class]) {
		v = [self IntegerExpr_Codegen:(DSSignedIntegerLiteral *)expr.assignment];
	} else {
		[self ErrorV:"Unsupported declaration"];
		exit(1);
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
	} else if ([expr.expression isKindOfClass:DSCall.class]) {
		v = [self Call_Codegen:(DSCall *)expr.expression];
	}
	
	Builder.CreateStore(v, var);
}

+(Value *) Call_Codegen:(DSCall *)expr {
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
			
			printArguments.push_back([LLVMHelper valueForArgument:arg symbolTable:namedValues andBuilder:Builder]);
		}
		
		 return Builder.CreateCall(putsFunc, printArguments);
	} else {
		Function *calleef = theModule->getFunction([expr.identifier.name cStringUsingEncoding:NSUTF8StringEncoding]);
		
		if (calleef == 0) {
			[self ErrorV:"Unknown function"];
			exit(1);
		}
		
		if (calleef->arg_size() != expr.children.count) {
			[self ErrorV:"Invalid num of arguments"];
		}
		
		std::vector<Value *> ArgsV;
		for (unsigned i = 0, e = (unsigned)expr.children.count; i != e; i++) {
			ArgsV.push_back([LLVMHelper valueForArgument:expr.children[i] symbolTable:namedValues andBuilder:Builder]);
			if (ArgsV.back() == 0) {
				[self ErrorV:"Argument came back nil"];
				exit(1);
			}
		}
		
		return Builder.CreateCall(calleef, ArgsV, "calltmp");
	}
}

+(Function *) Prototype_Codegen:(DSFunctionPrototype *)expr {
	std::vector<Type *> Ints(expr.parameters.count, Type::getInt32Ty(getGlobalContext()));
	
	FunctionType *FT = FunctionType::get(Type::getInt32Ty(getGlobalContext()), Ints, false);
	
	Function *F = Function::Create(FT, Function::ExternalLinkage, [expr.identifier cStringUsingEncoding:NSUTF8StringEncoding], theModule);
	
	if (F->getName() != [expr.identifier cStringUsingEncoding:NSUTF8StringEncoding]) {
		F->eraseFromParent();
		F = theModule->getFunction([expr.identifier cStringUsingEncoding:NSUTF8StringEncoding]);
		
		if (!F->empty()) {
			[self ErrorV:"Redefinition of function"];
			exit(1);
		}
	}
	
	
	unsigned Idx = 0;
	for (Function::arg_iterator AI = F->arg_begin(); Idx != expr.parameters.count; AI++, Idx++) {
		AI->setName([expr.parameters[Idx].identifier cStringUsingEncoding:NSUTF8StringEncoding]);
	}
	
	return F;
}

+(void) CreateArgumentAlloca:(Function *)F withPrototype:(DSFunctionPrototype *)expr {
	Function::arg_iterator AI = F->arg_begin();
	for (unsigned Idx = 0, e = (unsigned)expr.parameters.count; Idx != e; Idx++, AI++) {
		AllocaInst *alloca = CreateEntryBlockAlloca(F, expr.parameters[Idx].identifier);
		
		Builder.CreateStore(AI, alloca);
		
		namedValues[expr.parameters[Idx].identifier] = alloca;
	}
}

+(Function *) Function_Codegen:(DSFunctionDeclaration *)expr {
	namedValues.clear();
	
	Function *theFunction = [self Prototype_Codegen:expr.prototype];
	if (theFunction == 0)
		return 0;
	
	BasicBlock *BB = BasicBlock::Create(getGlobalContext(), "entry", theFunction);
	Builder.SetInsertPoint(BB);
	
	[self CreateArgumentAlloca:theFunction withPrototype:expr.prototype];
	
	if (Value *RetValue = [self Body_Codegen:expr.body andFunction:theFunction]) {
		Builder.CreateRet(RetValue);
		
		// TODO: Verify function
		
		return theFunction;
	}
	
	theFunction->eraseFromParent();
	return 0;
}

+(Value *) Body_Codegen:(DSBody *)body andFunction:(Function *)f {
	Value *returnVal = 0;
	
	for (DSAST *child in body.children) {
		if ([child isKindOfClass:DSReturnStatement.class]) {
			DSReturnStatement *temp = (DSReturnStatement *)child;
			
			if ([temp.statement isKindOfClass:DSBinaryExpression.class]) {
				DSBinaryExpression *binTemp = (DSBinaryExpression *)temp.statement;
				returnVal = [self BinaryExp_Codegen:binTemp.rhs andRHS:binTemp.lhs andExpr:binTemp];
			} else if ([temp.statement isKindOfClass:DSIdentifierString.class]) {
				returnVal = [self VariableExpr_Codegen:(DSIdentifierString *)temp.statement];
			}
		} else if ([child isKindOfClass:DSDeclaration.class]) {
			[self Declaration_Codegen:(DSDeclaration *)child function:f];
		} else if ([child isKindOfClass:DSCall.class]) {
			[self Call_Codegen:(DSCall *)child];
		} else if ([child isKindOfClass:DSAssignment.class]) {
			[self Assignment_Codegen:(DSAssignment *)child];
		}
	}
	
	return returnVal;
}

+(void) DSBody_Codegen:(DSBody *)body {
	LLVMContext &Context = getGlobalContext();
	
	theModule = new Module("myModule", Context);
	
	namedValues.clear();
	namedTypes.clear();
	
	for (DSAST *child in body.children) {
		if ([child isKindOfClass:DSFunctionDeclaration.class]) {
			[self Function_Codegen:(DSFunctionDeclaration *)child];
		}
	}
	
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
