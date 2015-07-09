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
#import "OutputUtils.h"

@implementation Codegen

using namespace llvm;

static Module *theModule;
static IRBuilder<> Builder(getGlobalContext());
static std::map<NSString *, AllocaInst *> namedValues;
static std::map<NSString *, NSString *>namedTypes;
static std::map<NSString *, NSString *>functionTypes;

static BOOL printMade = false;
Constant *putsFunc;

+(Value *) ErrorV:(NSString *)str {
	NSLog(@"%@", str);
	return 0;
}

+(Value *) VariableExpr_Codegen:(DSIdentifierString *)expr {
	Value *V = namedValues[expr.name];
	if (V == 0) return [Codegen ErrorV:[NSString stringWithFormat:@"Unknown variable name: %@", expr.name]];
	
	return Builder.CreateLoad(V, [expr.name cStringUsingEncoding:NSUTF8StringEncoding]);
}

+(Value *) IntegerExpr_Codegen:(DSSignedIntegerLiteral *)expr {
	return ConstantInt::get(getGlobalContext(), APInt(32, (int)expr.val));
}

+(NSString *) typeForIdentifier:(DSIdentifierString *)expr {
	return namedTypes[expr.name];
}

+(NSString *) typeForFunction:(DSCall *)expr {
	return functionTypes[expr.identifier.name];
}

static AllocaInst *CreateEntryBlockAlloca(Function *theFunction, DSDeclaration *var) {
	NSString *varName = var.identifier;
	
	IRBuilder<> TmpB(&theFunction->getEntryBlock(), theFunction->getEntryBlock().begin());
	
	// TODO: Better type allocations
	
	if ([var.type.identifier isEqual:@"Int"])
		return TmpB.CreateAlloca(Type::getInt32Ty(getGlobalContext()), 0, [varName cStringUsingEncoding:NSASCIIStringEncoding]);
	else if ([var.type.identifier isEqual:@"String"])
		return TmpB.CreateAlloca(Type::getInt8PtrTy(getGlobalContext()), 0, [varName cStringUsingEncoding:NSUTF8StringEncoding]);
	
	// Int by default
	return TmpB.CreateAlloca(Type::getInt32Ty(getGlobalContext()), 0, [varName cStringUsingEncoding:NSASCIIStringEncoding]);
}

+(Value *) Declaration_Codegen:(DSDeclaration *)expr function:(Function *)func {
	Value *v = 0;
	
	DSType *type = [[DSType alloc] init];
	if ([expr.assignment isKindOfClass:DSBinaryExpression.class]) {
		DSBinaryExpression *temp = (DSBinaryExpression *)expr.assignment;
		v = [self BinaryExp_Codegen:temp.lhs andRHS:temp.rhs andExpr:temp];
		// TODO: Type promotions
	} else if ([expr.assignment isKindOfClass:DSIdentifierString.class]) {
		DSIdentifierString *temp = (DSIdentifierString *)expr.assignment;
		v = [self VariableExpr_Codegen:temp];
		type.identifier = namedTypes[temp.name];
	} else if ([expr.assignment isKindOfClass:DSCall.class]) {
		v = [self Call_Codegen:(DSCall *)expr.assignment];
		DSCall *temp = (DSCall *)expr;
		type.identifier = functionTypes[temp.identifier.name];
	} else if ([expr.assignment isKindOfClass:DSSignedIntegerLiteral.class]) {
		v = [self IntegerExpr_Codegen:(DSSignedIntegerLiteral *)expr.assignment];
		type.identifier = @"Int";
	} else if ([expr.assignment isKindOfClass:DSStringLiteral.class]) {
		DSStringLiteral *temp = (DSStringLiteral *)expr.assignment;
		v = Builder.CreateGlobalStringPtr([temp.val cStringUsingEncoding:NSUTF8StringEncoding]);
		type.identifier = @"String";
	} else if (expr.assignment == nil) {
		assert(expr.type != nil); // If no assignment, variable must have a type
	} else {
		[self ErrorV:[NSString stringWithFormat:@"Unsupported declaration: %@", expr.description]];
		exit(1);
	}
	
	if (expr.type == nil)
		expr.type = type;
	
	AllocaInst *alloca = CreateEntryBlockAlloca(func, expr);
	
	namedValues[expr.identifier] = alloca;
	namedTypes[expr.identifier] = expr.type.identifier;
	
	if (v != 0)
		return Builder.CreateStore(v, alloca);
	else
		return 0;
}

+(Value *) BinaryExp_Codegen:(DSExpr *)LHS andRHS:(DSExpr *)RHS andExpr:(DSBinaryExpression *)expr {
	Value *L = nullptr, *R = nullptr;
	
	if ([LHS isKindOfClass:DSAssignment.class] || [RHS isKindOfClass:DSAssignment.class]) {
		[self ErrorV:@"Can't use an assignment in a Binary expression"];
		exit(1);
	}
	
	L = [self Expression_Codegen:LHS];
	R = [self Expression_Codegen:RHS];
	
	if ([expr.op isEqual: @"+"]) {
		return Builder.CreateAdd(L, R);
	} else if ([expr.op isEqual: @"-"]) {
		return Builder.CreateSub(L, R);
	} else if ([expr.op isEqual: @"*"]) {
		return Builder.CreateMul(L, R);
	} else if ([expr.op isEqual: @"/"]) {
		return Builder.CreateSDiv(L, R);
	} else if ([expr.op isEqual: @"%"]) {
		return Builder.CreateSRem(L, R);
	} else if ([expr.op isEqual: @"<"]) {
		L = Builder.CreateICmpSLT(L, R);
		return Builder.CreateUIToFP(L, Type::getDoubleTy(getGlobalContext()));
	} else if ([expr.op isEqual:@">"]) {
		L = Builder.CreateICmpSGT(L, R);
		return Builder.CreateUIToFP(L, Type::getDoubleTy(getGlobalContext()));
	} else if ([expr.op isEqual:@"=="]) {
		L = Builder.CreateICmpEQ(L, R);
		return Builder.CreateUIToFP(L, Type::getDoubleTy(getGlobalContext()));
	} else if ([expr.op isEqual:@"<="]) {
		L = Builder.CreateICmpSLE(L, R);
		return Builder.CreateUIToFP(L, Type::getDoubleTy(getGlobalContext()));
	} else if ([expr.op isEqual:@">="]) {
		L = Builder.CreateICmpSGE(L, R);
		return Builder.CreateUIToFP(L, Type::getDoubleTy(getGlobalContext()));
	} else if ([expr.op isEqual:@"+="]) {
		Value *result = Builder.CreateAdd(L, R);
		Value *var = namedValues[((DSIdentifierString *)LHS).name];
		return Builder.CreateStore(result, var);
	} else if ([expr.op isEqual:@"-="]) {
		Value *result = Builder.CreateSub(L, R);
		Value *var = namedValues[((DSIdentifierString *)LHS).name];
		return Builder.CreateStore(result, var);
	} else if ([expr.op isEqual:@"/="]) {
		Value *result = Builder.CreateMul(L, R);
		Value *var = namedValues[((DSIdentifierString *)LHS).name];
		return Builder.CreateStore(result, var);
	} else if ([expr.op isEqual:@"*="]) {
		Value *result = Builder.CreateSDiv(L, R);
		Value *var = namedValues[((DSIdentifierString *)LHS).name];
		return Builder.CreateStore(result, var);
	}
	
	return [self ErrorV:[NSString stringWithFormat:@"invalid binary operator: %@", expr.op]];
}

+(Value *) IfExpr_Codegen:(DSIfStatement *)expr {
	Value *condv = [self Expression_Codegen:expr.cond];
	if (condv == 0) {
		return 0;
	}
	
	condv = Builder.CreateFCmpONE(condv, ConstantFP::get(getGlobalContext(), APFloat(0.0)), "ifcond");
	
	Function *theFunc = Builder.GetInsertBlock()->getParent();
	
	BasicBlock *thenBB  = BasicBlock::Create(getGlobalContext(), "then", theFunc);
	BasicBlock *elseBB  = BasicBlock::Create(getGlobalContext(), "else");
	BasicBlock *mergeBB = BasicBlock::Create(getGlobalContext(), "ifcont");
	
	Builder.CreateCondBr(condv, thenBB, elseBB);
	
	Builder.SetInsertPoint(thenBB);
	Value *thenV = [self Body_Codegen:expr.body andFunction:theFunc];
	if (thenV == 0) {
		return 0;
	}
	
	Builder.CreateBr(mergeBB);
	
	thenBB = Builder.GetInsertBlock();
	
	theFunc->getBasicBlockList().push_back(elseBB);
	Builder.SetInsertPoint(elseBB);
	
	Value *elseV = 0;
	if (expr.elseBody != nil) {
		 elseV = [self Body_Codegen:expr.elseBody andFunction:theFunc];
		if (elseV == 0)
			return 0;
	} else {
		elseV = ConstantInt::get(getGlobalContext(), APInt(32, 0));
	}
	
	Builder.CreateBr(mergeBB);
	elseBB = Builder.GetInsertBlock();
	
	theFunc->getBasicBlockList().push_back(mergeBB);
	Builder.SetInsertPoint(mergeBB);
	PHINode *PN = Builder.CreatePHI(Type::getInt32Ty(getGlobalContext()), 2, "iftmp");
	
	PN->addIncoming(thenV, thenBB);
	PN->addIncoming(elseV, elseBB);
	
	return PN;
}

+(Value *) Expression_Codegen:(DSExpr *)expr {
	if ([expr isKindOfClass:DSCall.class]) {
		return [self Call_Codegen:(DSCall *)expr];
	} else if ([expr isKindOfClass:DSAssignment.class]) {
		return [self Assignment_Codegen:(DSAssignment *)expr];
	} else if ([expr isKindOfClass:DSBinaryExpression.class]) {
		DSBinaryExpression *temp = (DSBinaryExpression *)expr;
		return [self BinaryExp_Codegen:temp.lhs andRHS:temp.rhs andExpr:temp];
	} else if ([expr isKindOfClass:DSSignedIntegerLiteral.class]) {
		return [self IntegerExpr_Codegen:(DSSignedIntegerLiteral *)expr];
	} else if ([expr isKindOfClass:DSIdentifierString.class]) {
		return [self VariableExpr_Codegen:(DSIdentifierString *)expr];
	} else {
		return 0;
	}
}

+(Value *) Assignment_Codegen:(DSAssignment *)expr {
	if (![expr.storage isKindOfClass:DSIdentifierString.class]) {
		[self ErrorV:@"Cannot make assignment to this expression"];
		exit(0);
	}
	
	DSIdentifierString *store = (DSIdentifierString *)expr.storage;
	
	Value *var = namedValues[store.name];
	if (var == 0) {
		[self ErrorV:[NSString stringWithFormat:@"Unknown variable name: %@", store.name]];
		exit(1);
	}
	
	Value *v = 0;
	
	if ([expr.expression isKindOfClass:DSBinaryExpression.class]) {
		DSBinaryExpression *temp = (DSBinaryExpression *)expr.expression;
		v = [self BinaryExp_Codegen:temp.lhs andRHS:temp.rhs andExpr:temp];
	} else if ([expr.expression isKindOfClass:DSIdentifierString.class]) {
		v = [self VariableExpr_Codegen:(DSIdentifierString *)expr.expression];
	} else if ([expr.expression isKindOfClass:DSCall.class]) {
		v = [self Call_Codegen:(DSCall *)expr.expression];
	} else if ([expr.expression isKindOfClass:DSSignedIntegerLiteral.class]) {
		v = [self IntegerExpr_Codegen:(DSSignedIntegerLiteral *)expr.expression];
	}
	
	return Builder.CreateStore(v, var);
}

+(Value *) Call_Codegen:(DSCall *)expr {
	if ([expr.identifier.name isEqual:@"println"] || [expr.identifier.name isEqual:@"print"]) {
		if (!printMade) {
			std::vector<Type *> putsArgs;
			putsArgs.push_back(Builder.getInt8Ty()->getPointerTo());
			ArrayRef<Type *> argsRef(putsArgs);
			
			FunctionType *putsType = FunctionType::get(Builder.getInt32Ty(), argsRef, true);
			putsFunc = theModule->getOrInsertFunction("printf", putsType);
		}
		
		// MAKE THE CALL
		NSString *format = [[CompilerHelper sharedInstance] getPrintFormatString:expr newline:(([expr.identifier.name isEqual:@"println"]) ? YES : NO)];
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
			[self ErrorV:[NSString stringWithFormat:@"Unknown function: %@", expr.identifier.name]];
			exit(1);
		}
		
		if (calleef->arg_size() != expr.children.count) {
			[self ErrorV:[NSString stringWithFormat:@"Invalid num of arguments to function: %@", expr.identifier.name]];
			exit(1);
		}
		
		std::vector<Value *> ArgsV;
		for (unsigned i = 0, e = (unsigned)expr.children.count; i != e; i++) {
			ArgsV.push_back([LLVMHelper valueForArgument:expr.children[i] symbolTable:namedValues andBuilder:Builder]);
			if (ArgsV.back() == 0) {
				[self ErrorV:@"Argument came back nil"];
				exit(1);
			}
		}
		
		return Builder.CreateCall(calleef, ArgsV, "calltmp");
	}
}

+(Function *) Prototype_Codegen:(DSFunctionPrototype *)expr {
	std::vector<Type *> argsVec;
	
	for (DSDeclaration *argument in expr.parameters) {
		argsVec.push_back([LLVMHelper typeForArgument:argument.type withBuilder:Builder]);
	}
	
	FunctionType *FT = FunctionType::get(Type::getInt32Ty(getGlobalContext()), argsVec, false);
	
	Function *F = Function::Create(FT, Function::ExternalLinkage, [expr.identifier cStringUsingEncoding:NSUTF8StringEncoding], theModule);
	
	if (F->getName() != [expr.identifier cStringUsingEncoding:NSUTF8StringEncoding]) {
		F->eraseFromParent();
		F = theModule->getFunction([expr.identifier cStringUsingEncoding:NSUTF8StringEncoding]);
		
		if (!F->empty()) {
			[self ErrorV:[NSString stringWithFormat:@"Redefinition of function: %@", expr.identifier]];
			exit(1);
		}
	}
	
	functionTypes[expr.identifier] = expr.type.identifier;
	
	unsigned Idx = 0;
	for (Function::arg_iterator AI = F->arg_begin(); Idx != expr.parameters.count; AI++, Idx++) {
		AI->setName([expr.parameters[Idx].identifier cStringUsingEncoding:NSUTF8StringEncoding]);
	}
	
	return F;
}

+(void) CreateArgumentAlloca:(Function *)F withPrototype:(DSFunctionPrototype *)expr {
	Function::arg_iterator AI = F->arg_begin();
	for (unsigned Idx = 0, e = (unsigned)expr.parameters.count; Idx != e; Idx++, AI++) {
		AllocaInst *alloca = CreateEntryBlockAlloca(F, expr.parameters[Idx]);
		
		Builder.CreateStore(AI, alloca);
		
		namedValues[expr.parameters[Idx].identifier] = alloca;
		namedTypes[expr.parameters[Idx].identifier] = expr.parameters[Idx].type.identifier;
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
		
		verifyFunction(*theFunction);
		
		return theFunction;
	}
	
	theFunction->eraseFromParent();
	return 0;
}

+(Value *) WhileLoop_Codegen:(DSWhileStatement *)expr {
	Function *theFunc = Builder.GetInsertBlock()->getParent();
	BasicBlock *loopBB = BasicBlock::Create(getGlobalContext(), "loop", theFunc);
	BasicBlock *afterBB = BasicBlock::Create(getGlobalContext(), "afterLoop", theFunc);
	
	Value *cond = [Codegen Expression_Codegen:expr.cond];
	if (cond == 0)
		return 0;
	
	cond = Builder.CreateFCmpONE(cond, ConstantFP::get(getGlobalContext(), APFloat(0.0)), "loopcond");
	
	Builder.CreateCondBr(cond, loopBB, afterBB);
	Builder.SetInsertPoint(loopBB);
	
	if ([Codegen Body_Codegen:expr.body andFunction:theFunc] == 0)
		return 0;
	
	cond = [Codegen Expression_Codegen:expr.cond];
	
	cond = Builder.CreateFCmpONE(cond, ConstantFP::get(getGlobalContext(), APFloat(0.0)), "loopcond");
	
	Builder.CreateCondBr(cond, loopBB, afterBB);
	Builder.SetInsertPoint(afterBB);
	
	return Constant::getNullValue(Type::getDoubleTy(getGlobalContext()));
}

+(Value *) ForLoop_Codegen:(DSForStatement *)expr {
	Function *theFunc = Builder.GetInsertBlock()->getParent();
	
	Value *startVal;
	AllocaInst *oldVal = nullptr;
	if ([expr.initial isKindOfClass:DSDeclaration.class]) {
		DSDeclaration *temp = (DSDeclaration *)(expr.initial);
		
		AllocaInst *alloca = CreateEntryBlockAlloca(theFunc, temp);
		
		startVal = [self Expression_Codegen:temp.assignment];
		Builder.CreateStore(startVal, alloca);
		
		oldVal = namedValues[temp.identifier];
		namedValues[temp.identifier] = alloca;
	} else {
		startVal = [self Expression_Codegen:(DSExpr *)(expr.initial)];
	}
	if (startVal == 0) {
		[self ErrorV:@"An error occured in the start of a for loop"];
		return 0;
	}
	
	Value *endCond = [self Expression_Codegen:expr.cond];
	if (endCond == 0)
		return 0;
	
	endCond = Builder.CreateFCmpONE(endCond, ConstantFP::get(getGlobalContext(), APFloat(0.0)), "loopCond");
	
	BasicBlock *loopBB = BasicBlock::Create(getGlobalContext(), "loop", theFunc);
	BasicBlock *afterBB = BasicBlock::Create(getGlobalContext(), "afterloop", theFunc);
	
	Builder.CreateCondBr(endCond, loopBB, afterBB);
	
	Builder.SetInsertPoint(loopBB);
	
	if ([self Body_Codegen:expr.body andFunction:theFunc] == 0)
		return 0;
	
	Value *stepVal;
	if (expr.increment) {
		stepVal = [self Expression_Codegen:expr.increment];
		if (stepVal == 0)
			return 0;
	} else {
		stepVal = ConstantInt::get(getGlobalContext(), APInt(32, 1));
	}
	
	endCond = [self Expression_Codegen:expr.cond];
	
	/*Value *curVar = Builder.CreateLoad(alloca, [expr.initial.identifier cStringUsingEncoding:NSUTF8StringEncoding]);
	Value *nextVar = Builder.CreateAdd(curVar, stepVal, "nextVar");
	Builder.CreateStore(nextVar, alloca);*/
	//[self Expression_Codegen:expr.increment];
	
	endCond = Builder.CreateFCmpONE(endCond, ConstantFP::get(getGlobalContext(), APFloat(0.0)), "loopCond");
	
	Builder.CreateCondBr(endCond, loopBB, afterBB);
	Builder.SetInsertPoint(afterBB);
	
	if ([expr.initial isKindOfClass:DSDeclaration.class]) {
		DSDeclaration *temp = (DSDeclaration *)(expr.initial);
		if (oldVal) {
			namedValues[temp.identifier] = oldVal;
		} else {
			namedValues.erase(temp.identifier);
		}
	}
	
	return Constant::getNullValue(Type::getDoubleTy(getGlobalContext()));
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
			
			//Builder.CreateRet(returnVal);
		} else if ([child isKindOfClass:DSDeclaration.class]) {
			[self Declaration_Codegen:(DSDeclaration *)child function:f];
		} else if ([child isKindOfClass:DSCall.class]) {
			[self Call_Codegen:(DSCall *)child];
		} else if ([child isKindOfClass:DSAssignment.class]) {
			[self Assignment_Codegen:(DSAssignment *)child];
		} else if ([child isKindOfClass:DSIfStatement.class]) {
			[self IfExpr_Codegen:(DSIfStatement *)child];
		} else if ([child isKindOfClass:DSWhileStatement.class]) {
			[self WhileLoop_Codegen:(DSWhileStatement *)child];
		} else if ([child isKindOfClass:DSForStatement.class]) {
			[self ForLoop_Codegen:(DSForStatement *)child];
		} else if ([child isKindOfClass:DSBinaryExpression.class]) {
			DSBinaryExpression *temp = (DSBinaryExpression *)child;
			if ([[CompilerHelper sharedInstance] isValidBinaryAssignment:temp]) {
				[self BinaryExp_Codegen:temp.lhs andRHS:temp.rhs andExpr:temp];
			}
		}
	}
	
	if (returnVal == 0)
		returnVal = ConstantInt::get(getGlobalContext(), APInt(32, 0));
	
	return returnVal;
}

+(void) TopLevel_Codegen:(DSBody *)body {
	LLVMContext &Context = getGlobalContext();
	
	NSString *moduleName = [[CompilerHelper sharedInstance] getModuleName];
	
	theModule = new Module([moduleName cStringUsingEncoding:NSUTF8StringEncoding], Context);
	
	namedValues.clear();
	namedTypes.clear();
	
	for (DSAST *child in body.children) {
		if ([child isKindOfClass:DSFunctionDeclaration.class]) {
			[self Function_Codegen:(DSFunctionDeclaration *)child];
		}
	}
	
	// Create main function
	FunctionType *ft = FunctionType::get(Builder.getInt32Ty(), false);
	
	Function *f = Function::Create(ft, Function::ExternalLinkage, "main", theModule);
	
	BasicBlock *bb = BasicBlock::Create(getGlobalContext(), "entry", f);
	Builder.SetInsertPoint(bb);
	
	[self Body_Codegen:body andFunction:f];
	
	Value *retVal = ConstantInt::get(getGlobalContext(), APInt(32, 0));
	Builder.CreateRet(retVal);
	
	verifyFunction(*f);
	
	[OutputUtils doOptimization:theModule];
}

@end
