// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


@import ZMTesting;
@import ZMUtilities;

#import "ZMDataBuffer.h"

@interface ZMDataBufferTests : XCTestCase

@property (nonatomic) ZMDataBuffer *sut;

@end

@implementation ZMDataBufferTests

- (void)setUp {
    self.sut = [[ZMDataBuffer alloc] init];
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
    self.sut = nil;
}

- (void)testThatItStartsEmpty
{
    XCTAssertNotNil(self.sut.data);
    XCTAssertEqual(dispatch_data_get_size(self.sut.data), 0u);
}

- (void)testThatItAppendsDataFromEmpty
{
    // given
    dispatch_data_t data = [@"test foo bar" dataUsingEncoding:NSUTF8StringEncoding].dispatchData;
    
    // when
    [self.sut addData:data];
    dispatch_data_t bufferData = self.sut.data;
    
    // then
    XCTAssertEqualObjects(data, bufferData);
}

- (void)testThatItAppendsDataWithPreviousData
{
    // given
    dispatch_data_t data1 = [@"111" dataUsingEncoding:NSUTF8StringEncoding].dispatchData;
    dispatch_data_t data2 = [@"222" dataUsingEncoding:NSUTF8StringEncoding].dispatchData;
    dispatch_data_t expectedData = [@"111222" dataUsingEncoding:NSUTF8StringEncoding].dispatchData;
    
    [self.sut addData:data1];
    
    // when
    [self.sut addData:data2];
    dispatch_data_t bufferData = self.sut.data;
    
    // then
    XCTAssertEqualObjects(expectedData, bufferData);
    
}

- (void)testThatItClearsUntilOffset
{
    // given
    dispatch_data_t data1 = [@"aaaabbcc" dataUsingEncoding:NSUTF8StringEncoding].dispatchData;
    dispatch_data_t expectedData = [@"cc" dataUsingEncoding:NSUTF8StringEncoding].dispatchData;
    
    [self.sut addData:data1];
    
    // when
    [self.sut clearUntilOffset:4];
    [self.sut clearUntilOffset:2];
    dispatch_data_t bufferData = self.sut.data;
    
    // then
    XCTAssertEqualObjects(expectedData, bufferData);
}


@end
