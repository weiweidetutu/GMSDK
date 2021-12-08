//
//  GmAsyncSocket.m
//  GMSDK
//
//  Created by yuhan on 2021/11/29.
//
#include <arpa/inet.h>
#include "GMSocket.h"
#include "KququEvent.h"
#include <netdb.h>
#include <sys/event.h>
#include <openssl/ssl.h>
#import "GmAsyncSocket.h"
#include "ring_buffer.h"
#define RING_BUFFER_SUCCESS     0x01
#define RING_BUFFER_ERROR       0x00
#define ErrorDomain @"GmAsyncSocketErrorDomain"
@interface GmAsyncSocket()
//SSL数据接收数组
@property(nonatomic,strong) NSMutableArray * revBuf;
@property(nonatomic,strong) NSMutableArray * sendBuf;
@property(nonatomic) dispatch_queue_t  notifiQueue;
@property(nonatomic) dispatch_queue_t  mainLoopQueue;
@property(nonatomic, weak) GmAsyncSocket * gmAsyncSocket;
@property(nonatomic) Boolean isIPV6;
//ip地址
@property(nonatomic)  struct sockaddr_in6 * ip6;
@property(nonatomic)  struct sockaddr_in * ip4;
@property(nonatomic)  SSL *ssl;
@property(nonatomic)  SSL_CTX * ctx;
@property(nonatomic)   struct kevent *changes;
@property(nonatomic)   struct kevent *events;
@property(nonatomic) NSMutableArray *tempReadArray;
@property(nonatomic) NSArray *readArray;
@property(nonatomic) Boolean status;
@property(nonatomic) ring_buffer* RB ;
@property(nonatomic) ring_buffer* WB ;
@end

@implementation GmAsyncSocket
// 执行对象初始化工作
-(NSMutableArray*)tempReadArray{
    if (!_tempReadArray) {
        _tempReadArray = [[NSMutableArray alloc] init];
    }
    return _tempReadArray;
}
-(instancetype)init{
    GmAsyncSocket * gmAsyncSocket =  [super init];
    gmAsyncSocket.gmAsyncSocket = self;
    //初始化kqueue对象,最大监听2FD
    gmAsyncSocket.changes = (struct kevent *) malloc(sizeof(struct kevent)*2);
    memset( gmAsyncSocket.changes, 0, sizeof(struct kevent)*2);
    gmAsyncSocket.events = (struct kevent *) malloc(sizeof(struct kevent)*2);
    memset( gmAsyncSocket.events, 0, sizeof(struct kevent)*2);
    //初始化ip结构体
    gmAsyncSocket.ip4 = (struct sockaddr_in*)malloc(sizeof(struct sockaddr_in));
    gmAsyncSocket.ip6 = (struct sockaddr_in6*)malloc(sizeof(struct sockaddr_in6));
 
    memset(self.ip6, 0, sizeof(struct sockaddr_in6));
    memset(self.ip4, 0, sizeof(struct sockaddr_in));
    //初始化缓冲区
    gmAsyncSocket.revBuf = [[NSMutableArray alloc] init];
    gmAsyncSocket.sendBuf = [[NSMutableArray alloc] init];
    //添加观察者KVO
    [gmAsyncSocket addObserver:self forKeyPath:@"revBuf" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    [gmAsyncSocket addObserver:self forKeyPath:@"sendBuf" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    //设置工作线程队列避免队列重复
    gmAsyncSocket.notifiQueue = dispatch_queue_create([[NSString stringWithFormat:@"GmAsyncSocketNotifi%@",gmAsyncSocket] UTF8String], DISPATCH_QUEUE_SERIAL);
    gmAsyncSocket.mainLoopQueue = dispatch_queue_create([[NSString stringWithFormat:@"GmAsyncSocketNotifi%@",gmAsyncSocket] UTF8String], DISPATCH_QUEUE_SERIAL);
    return gmAsyncSocket;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"revBuf"]) {
        NSLog(@"%@", change);
    }
    if ([keyPath isEqualToString:@"sendBuf"]) {
        NSLog(@"%@", change);
    }
}

/*
 获取IP地址
 **/
- (NSString *)getIPWithHostName:(NSString*)hostName{
    const char *hostN= [hostName UTF8String];
    struct hostent* phot;
    @try {
        phot = gethostbyname(hostN);
        if (phot == nil) {
            return nil;
        }
    }
    @catch (NSException *exception) {
        return nil;
    }
    switch(phot->h_addrtype)
    {
        case AF_INET:{
            struct in_addr ip_addr;
            memcpy(&ip_addr, phot->h_addr, sizeof(ip_addr));
            char ip[20] = {0};
            const char * output = inet_ntop(AF_INET, &ip_addr, ip, 20);
            if (output == NULL) {
                return NULL;
            }
            return [[NSString alloc] initWithBytes:ip length:sizeof(ip) encoding:NSUTF8StringEncoding];
            break;
        }
        case AF_INET6:{
            struct in6_addr ip_addr;
            memcpy(&ip_addr, phot->h_addr, 4);
            char ip[1024] = {0};
            const char * output = inet_ntop(AF_INET6, &ip_addr, ip, 1024);
            if (output == NULL) {
                return NULL;
            }
            return [[NSString alloc] initWithBytes:ip length:sizeof(ip) encoding:NSUTF8StringEncoding];
            break;
        }
        default:
            return nil;
            break;
    }
    
}
/*
 地址转换判断
 ！=1
 **/
-(int)translateIPV6ADDR:(NSString *)ipStr ip6Addr:(struct sockaddr_in6 *)servaddr6{
    return inet_pton(AF_INET6,[ipStr UTF8String],&servaddr6->sin6_addr);
}
/*
 地址转换判断
 ！=1
 **/
-(int)translateIPV4ADDR:(NSString *)ipStr ip4Addr:(struct sockaddr_in*)servaddr4{
    return inet_pton(AF_INET, [ipStr UTF8String], &servaddr4->sin_addr.s_addr);
}
-(void)connectTo:(NSString*)host port:(uint16)port ca:(NSString*)ca signcert:(NSString*)signCert signkey:(NSString*)signKey codercert:(NSString*)coderCert coderKey:(NSString*)coderKey bufferSize:(int)size{
    memset(self.ip4, 0, sizeof(struct sockaddr_in));
    memset(self.ip6, 0, sizeof(struct sockaddr_in6));
    NSString * decodeHost = [self getIPWithHostName:host];
    if(decodeHost == nil||[decodeHost isEqual:@""]){
        if([self translateIPV4ADDR:host ip4Addr:self.ip4]){
            self.isIPV6 = NO;
        }else{
            if ([self translateIPV6ADDR:host ip6Addr:self.ip6]) {
                self.isIPV6 = YES;
            }else{
                
                [self errorWith:[[NSError alloc] initWithDomain:ErrorDomain code:-1001 userInfo:@{
                    @"errMsg":@"Can not Translate the Host String",
                    @"错误信息":[NSString stringWithFormat: @"不是域名无法解析主机 :%@-decode:%@",host,decodeHost]
                }]];
                return;
            }
        }
    }else{
        if([self translateIPV4ADDR:decodeHost ip4Addr:self.ip4]){
            self.isIPV6 = NO;
        }else{
            if ([self translateIPV6ADDR:decodeHost ip6Addr:self.ip6]) {
                self.isIPV6 = YES;
            }else{
                [self errorWith:[[NSError alloc] initWithDomain:ErrorDomain code:-1001 userInfo:@{
                    @"errMsg":@"Can not Translate the Host String",
                    @"错误信息":[NSString stringWithFormat: @"无法解析主机 :%@-decode:%@",host,decodeHost]
                }]];
                return;
            }
        }
    }
    if (self.isIPV6) {
        //建立ipv6 Socket 连接
        self.ip6->sin6_family = AF_INET6;
        self.ip6->sin6_port = htons((unsigned short)port);
        int sock = Yh_GetClientFd(AF_INET6);
        if(Yh_ConnectSocket((const struct sockaddr *)self.ip6, sock)<0){
            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1002 userInfo:@{
                @"errMsg":@"Can Not Connect Tcp",
                @"错误信息":[NSString stringWithFormat:@"Tcp 连接失败%@:%d",[NSData dataWithBytes:(char *)&self.ip6->sin6_addr length:sizeof(self.ip6->sin6_addr)],self.ip6->sin6_port]
            }]];
            return;
        }
        self.ctx = Yh_CreateGMMethod();
        if (self.ctx == NULL) {
            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1003 userInfo:@{
                @"errMsg":@"Greate GM Method CTX Fail",
                @"错误信息":@"创建国密CTX失败"
            }]];
            return;
        }
        if(Yh_LoadCA((char *)[ca UTF8String], self.ctx)<0){
            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1003 userInfo:@{
                @"errMsg":@"Load CA Cert Error",
                @"错误信息":@"加载CA证书失败"
            }]];
            return;
        }
        int err = Yh_LoadUserCert(self.ctx, (char *)[signCert UTF8String], (char *)[signKey UTF8String]);
        if(err<0){
            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1004 userInfo:@{
                @"errMsg":@"Load Client Cert Error",
                @"错误信息":[NSString stringWithFormat:@"加载客户端签名证书失败%d",err]
            }]];
            return;
        }
        int certerr = Yh_LoadUserCert(self.ctx, (char *)[coderCert UTF8String], (char *)[coderKey UTF8String]);
        if(certerr<0){
            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1004 userInfo:@{
                @"errMsg":@"Load Client Cert Error",
                @"错误信息":[NSString stringWithFormat:@"加载客户端加密证书失败%d",err]
            }]];
            return;
        }
        self.ssl = Yh_NewSSL(sock, self.ctx);
//        if(self.ssl == NULL){
//            perror("ssl");
//            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1004 userInfo:@{
//                @"errMsg":@"Create SSL Error",
//                @"错误信息":@"创建SSL连接失败"
//            }]];
//            return;
//        }
        self.status = YES;
        int kq = Yh_Kqeue(sock, self.changes);
        //初始化读写缓冲区
        uint8_t bufferR[size*1024] ;
        uint8_t bufferW[size*1024] ;
        ring_buffer RB ;
        ring_buffer WB ;
        Ring_Buffer_Init(&RB, bufferR, size);
        Ring_Buffer_Init(&WB, bufferW, size);
        self.RB = &RB;
        self.WB = &WB;
        __weak typeof(self) weakSelf = self;
        dispatch_async(self.mainLoopQueue, ^{
            while (weakSelf.status) {
                if(Yh_KqueueOnceLoop(kq, weakSelf.events, weakSelf.ssl,weakSelf.RB,weakSelf.WB,dataInput,(__bridge void *)(self))<0)
                    weakSelf.status = NO;
            }
        });
        Yh_CloseSSL(sock, self.ssl, self.ctx);
        
    }else{
        //建立ipv4 Socket 连接
        self.ip4->sin_family = AF_INET;
        self.ip4->sin_port = htons((unsigned short)port);
        int sock = Yh_GetClientFd(AF_INET);
        int err = Yh_ConnectSocket((const struct sockaddr *)self.ip4, sock);
        if(err<0){
            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1002 userInfo:@{
                @"errMsg":@"Can Not Connect Tcp",
                @"错误信息":[NSString stringWithFormat:@"Tcp 连接失败%@:%d--错误代码%d",[NSData dataWithBytes:(char *)&self.ip4->sin_addr.s_addr length:sizeof(self.ip4->sin_addr.s_addr)],self.ip4->sin_port,err]
            }]];
            return;
        }
        self.ctx = Yh_CreateGMMethod();
        if (self.ctx == NULL) {
            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1003 userInfo:@{
                @"errMsg":@"Greate GM Method CTX Fail",
                @"错误信息":@"创建国密CTX失败"
            }]];
            return;
        }
        if(Yh_LoadCA((char *)[ca UTF8String], self.ctx)<0){
            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1003 userInfo:@{
                @"errMsg":@"Load CA Cert Error",
                @"错误信息":@"加载CA证书失败"
            }]];
            return;
        }
        if(Yh_LoadUserCert(self.ctx, (char *)[signCert UTF8String], (char *)[signKey UTF8String])<0){
            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1004 userInfo:@{
                @"errMsg":@"Load Client Cert Error",
                @"错误信息":@"加载签名客户端证书失败"
            }]];
            return;
        }
        if(Yh_LoadUserCert(self.ctx, (char *)[coderCert UTF8String], (char *)[coderKey UTF8String])<0){
            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1004 userInfo:@{
                @"errMsg":@"Load Client Cert Error",
                @"错误信息":@"加载加密客户端证书失败"
            }]];
            return;
        }
        self.ssl = Yh_NewSSL(sock, self.ctx);
        if(self.ssl == NULL){
            perror("ssl");
            [self errorWith:[NSError errorWithDomain:ErrorDomain code:-1004 userInfo:@{
                @"errMsg":@"Create SSL Error",
                @"错误信息":@"创建SSL连接失败"
            }]];
            return;
        }
        self.status = YES;
        int kq = Yh_Kqeue(sock, self.changes);
        //初始化读写缓冲区
        uint8_t bufferR[size] ;
        uint8_t bufferW[size] ;
        ring_buffer RB ;
        ring_buffer WB ;
        Ring_Buffer_Init(&RB, bufferR, size);
        Ring_Buffer_Init(&WB, bufferW, size);
        self.RB = &RB;
        self.WB = &WB;
        
        
        __weak typeof(self) weakSelf = self;
        dispatch_async(self.mainLoopQueue, ^{
            while (weakSelf.status) {
                if(Yh_KqueueOnceLoop(kq, weakSelf.events, weakSelf.ssl,weakSelf.RB,weakSelf.WB,dataInput,(__bridge void *)(self))<0)
                    weakSelf.status = NO;
            }
        });
        Yh_CloseSSL(sock, self.ssl, self.ctx);
        
    }
}
void dataInput(void *Self){
    printf("收到GMSSL返回的数据");
    GmAsyncSocket *gm = (__bridge GmAsyncSocket *)Self;
    dispatch_sync(gm.notifiQueue, ^{
        NSString * string = gm.tempReadArray[0];
        NSArray *arr = [string componentsSeparatedByString:@","];
        if(Ring_Buffer_Get_Lenght(gm.RB)>=[arr[0] intValue]){
            UInt8 buf[[arr[0] intValue]];
            if(Ring_Buffer_Read_String(gm.RB, buf, [arr[0] intValue])==RING_BUFFER_SUCCESS){
                [gm didReadDataWithData:[[NSData alloc]initWithBytes:buf length:[arr[0] intValue]] withTag:[arr[1]intValue]];
                [gm.tempReadArray removeObjectAtIndex:0];
            }
        }
        
    });
    
}
-(void)readDataWithLength:(int)length withTag:(int)tag{
    dispatch_sync(self.notifiQueue, ^{
    if(Ring_Buffer_Get_Lenght(self.RB)>=length){
        uint8 buf[length];
        memset(buf, 0, length);
        
        if(RING_BUFFER_SUCCESS == Ring_Buffer_Read_String(self.RB, buf, length)){
        [self didReadDataWithData:[[NSData alloc]initWithBytes:buf length:length] withTag:tag];
        }
    }else{
            [self.tempReadArray addObject:[NSString stringWithFormat:@"%d,%d",length,tag]];
    }
    });
}
-(void)writeData:(NSData*)data WithTag:(int)tag{
    if (Ring_Buffer_Get_FreeSize(self.WB)>data.length) {
        Ring_Buffer_Write_String(self.WB, (uint8_t *)[data bytes], (uint32_t)[data length]);
        [self didWriteData:tag err:nil];
    }else{
        [self didWriteData:tag err:[NSError errorWithDomain:ErrorDomain code:-1005 userInfo:@{
            @"errMsg":@"Buf is full",
            @"错误信息":@"写缓冲区已满"
        }]];
       
    }
}

// 执行对象清理工作,释放openssl的内存
-(void)dealloc
{
    //清理KVO
    [self.gmAsyncSocket removeObserver:self forKeyPath:@"revBuf"];
    [self.gmAsyncSocket removeObserver:self forKeyPath:@"sendBuf"];
    //清除代理
    self.gmAsyncSocket.delegate = nil;
    //清理malloc
    free(self.gmAsyncSocket.changes);
    free(self.gmAsyncSocket.events);
    free(self.gmAsyncSocket.ip4);
    free(self.gmAsyncSocket.ip6);
    
}



//代理模式
-(void)errorWith:(NSError*)error{
    if(self.delegate){
        if([self.delegate respondsToSelector:@selector(didDisconnectWithError:)]){
            [self.delegate didDisconnectWithError:error];
        }
    }
}
-(void)didReadDataWithData:(NSData*)data withTag:(int)tag{
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(didReadData:withTag:)]) {
            [self.delegate didReadData:data withTag:tag];
        }
    }
}
-(void)didWriteData:(int)Tag err:(NSError*)err{
    if(self.delegate){
        if ([self.delegate respondsToSelector:@selector(didWriteDatawithTag:err:)]) {
            [self.delegate didWriteDatawithTag:Tag err:err];
        }
    }
}

@end
