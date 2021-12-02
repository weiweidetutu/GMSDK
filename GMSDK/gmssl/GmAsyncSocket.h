//
//  GmAsyncSocket.h
//  GMSDK
//
//  Created by yuhan on 2021/11/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol GmAsyncSocketDelegate <NSObject>
-(void)didDisconnectWithError:(NSError*)err;

@end

@interface GmAsyncSocket : NSObject
@property(nonatomic,weak) id<GmAsyncSocketDelegate> delegate;
-(void)connectTo:(NSString*)host port:(int)port ca:(NSString*)ca cert:(NSString*)cert key:(NSString*)key bufferSize:(int)size;

@end

NS_ASSUME_NONNULL_END
