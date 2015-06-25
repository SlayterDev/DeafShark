//
//  CPPWrapper.h
//  DeafShark
//
//  Created by Bradley Slayter on 6/23/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DSBody;

@interface CPPWrapper : NSObject

+(void) DSBody_Codegen:(DSBody *)body;

@end
