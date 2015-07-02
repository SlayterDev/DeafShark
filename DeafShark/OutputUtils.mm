//
//  OutputUtils.m
//  DeafShark
//
//  Created by Bradley Slayter on 7/2/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#import "OutputUtils.h"

using namespace llvm;

@implementation OutputUtils

+(void) writeBitcode:(Module *)theModule {
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
	
	[self writeAssembly:outputPath];
}

+(void) writeAssembly:(NSString *)bitcodePath {
	NSString *asmPath = [[bitcodePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"s"];
	NSString *binaryPath = [asmPath stringByDeletingPathExtension];
	
	NSTask *task = [[NSTask alloc] init];
	
	task.launchPath = @"/usr/local/DeafShark/compileandlink.sh";
	task.arguments = @[bitcodePath, asmPath, binaryPath];
	
	[task launch];
	//[task waitUntilExit];
	
	/*NSError *error;
	[[NSFileManager defaultManager] removeItemAtPath:bitcodePath error:&error];
	
	if (error) {
		NSLog(@"%@", error.description);
	}*/
}

+(void) makeBinary:(NSString *)asmPath {
	NSString *binaryPath = [asmPath stringByDeletingPathExtension];
	
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = @"/usr/local/bin/llc";
	task.arguments = @[asmPath, @"-o", binaryPath];
}

@end
