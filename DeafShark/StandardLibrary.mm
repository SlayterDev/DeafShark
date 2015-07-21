//
//  StandardLibrary.m
//  DeafShark
//
//  Created by Bradley Slayter on 7/18/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#import "StandardLibrary.h"

@implementation StandardLibrary

using namespace llvm;

static std::map<NSString *, Constant *> functions;

+(Constant *) getFunction:(NSString *)functionName withBuilder:(IRBuilder<>)Builder andModule:(Module *)theModule {
	std::map<NSString *, Constant *>::iterator iter = functions.find(functionName);
	if (iter != functions.end()) {
		return functions[functionName];
	}
	
	if ([functionName isEqual:@"random"]) {
		FunctionType *randType = FunctionType::get(Type::getInt32Ty(getGlobalContext()), false);
		
		std::vector<Type *> srandArgs;
		srandArgs.push_back(Builder.getInt32Ty());
		ArrayRef<Type *> argsRef(srandArgs);
		
		FunctionType *srandType = FunctionType::get(Type::getVoidTy(getGlobalContext()), argsRef, false);
		Constant *srandFunc = theModule->getOrInsertFunction("srand", srandType);
		
		std::vector<Type *> timeArgs;
		timeArgs.push_back(Builder.getInt32Ty());
		ArrayRef<Type *> timeArgsRef(timeArgs);
		
		FunctionType *timeType = FunctionType::get(Type::getInt32Ty(getGlobalContext()), argsRef, false);
		Constant *timeFunc = theModule->getOrInsertFunction("time", timeType);
		
		std::vector<Value *> timeCallArgs;
		std::vector<Value *> sRandCallArgs;
		
		timeCallArgs.push_back(Constant::getNullValue(Type::getInt32Ty(getGlobalContext())));
		
		sRandCallArgs.push_back(Builder.CreateCall(timeFunc, timeCallArgs));
		Builder.CreateCall(srandFunc, sRandCallArgs);
		
		functions[functionName] = theModule->getOrInsertFunction("rand", randType);
		
		return functions[functionName];
	} else if ([functionName isEqual:@"intInput"] || [functionName isEqual:@"stringInput"]) {
		std::vector<Type *> scanfArgs;
		scanfArgs.push_back(Builder.getInt8PtrTy());
		ArrayRef<Type *> argsRef(scanfArgs);
		
		FunctionType *scanfType = FunctionType::get(Type::getInt32Ty(getGlobalContext()), argsRef, true);
		functions[functionName] = theModule->getOrInsertFunction("scanf", scanfType);
		
		return functions[functionName];
	}
	
	return nil;
}

@end
