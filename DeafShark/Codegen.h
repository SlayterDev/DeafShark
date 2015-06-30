//
//  CPPWrapper.h
//  DeafShark
//
//  Created by Bradley Slayter on 6/23/15.
//  Copyright © 2015 Flipped Bit. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DSBody;
@class DSIdentifierString;

@interface Codegen : NSObject

+(void) DSBody_Codegen:(DSBody *)body;
+(NSString *) typeForIdentifier:(DSIdentifierString *)expr;


@end