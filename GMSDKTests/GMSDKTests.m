//
//  GMSDKTests.m
//  GMSDKTests
//
//  Created by yuhan on 2021/11/29.
//
/*
 单元测试SDK功能
 **/
#import <XCTest/XCTest.h>
#import <GMSDK/GMSDK.h>
#import <GMSDK/GmAsyncSocket.h>
@interface GMSDKTests : XCTestCase<GmAsyncSocketDelegate>
@property(nonatomic) GmAsyncSocket *gm;
@end

@implementation GMSDKTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.gm = [[GmAsyncSocket alloc]init];
    self.gm.delegate = self;
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    [self.gm connectTo:@"8.136.38.88" port:6789 ca:@"ca.crt" cert:@"client.crt" key:@"Key.key" bufferSize:100];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (void)didDisconnectWithError:(nonnull NSError *)err {
    NSLog(@"%@",err);
}

- (void)didReadData:(nonnull NSData *)data withTag:(int)tag {
    
}

- (void)didWriteDatawithTag:(int)tag err:(nonnull NSError *)err {
    
}

@end
