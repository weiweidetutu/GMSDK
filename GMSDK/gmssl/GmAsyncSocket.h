//
//  GmAsyncSocket.h
//  GMSDK
//
//  Created by 葳葳的涂涂 on 2021/12/31.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol GmAsyncSocketDelegate <NSObject>
-(void)didDisconnectWithError:(NSError*)err;
-(void)didReadData:(NSData*)data withTag:(int)tag;
-(void)didWriteDatawithTag:(int)tag err:(NSError*)err;
@end

@interface GmAsyncSocket : NSObject
@property(nonatomic,weak) id<GmAsyncSocketDelegate> delegate;

-(void)connectTo:(NSString*)host port:(uint16)port ca:(NSString*)ca cert:(NSString*)cert key:(NSString*)key bufferSize:(int)size;
-(void)readDataWithLength:(int)length withTag:(int)tag;
-(void)writeData:(NSData*)data WithTag:(int)tag;
@end

NS_ASSUME_NONNULL_END
