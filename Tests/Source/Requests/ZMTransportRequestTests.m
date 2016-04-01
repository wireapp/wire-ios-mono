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
// along with this program. If not, see <http://www.gnu.org/licenses/>.
// 


@import XCTest;
@import ZMTesting;
@import ZMTransport;
@import ZMCSystem;
@import ZMUtilities;

#if TARGET_OS_IPHONE
@import MobileCoreServices;
#else
@import CoreServices;
#endif

#import "ZMTransportRequest+Internal.h"
#import "XCTestCase+Images.h"


@interface ZMTransportRequestTests : ZMTBaseTest

@end



@implementation ZMTransportRequestTests

-(void)testThatNeedsAuthenticationIsSetByDefault;
{
    XCTAssertTrue([[ZMTransportRequest alloc] initWithPath:@"/bar" method:ZMMethodPOST payload:@{}].needsAuthentication);
    XCTAssertTrue([ZMTransportRequest requestGetFromPath:@"/bar"].needsAuthentication);
    XCTAssertTrue([ZMTransportRequest requestWithPath:@"/bar" method:ZMMethodPOST payload:@{}].needsAuthentication);
}

-(void)testThatCreatesAccessTokenIsNotSetByDefault;
{
    XCTAssertFalse([[ZMTransportRequest alloc] initWithPath:@"/bar" method:ZMMethodPOST payload:@{}].responseWillContainAccessToken);
    XCTAssertFalse([ZMTransportRequest requestGetFromPath:@"/bar"].responseWillContainAccessToken);
    XCTAssertFalse([ZMTransportRequest requestWithPath:@"/bar" method:ZMMethodPOST payload:@{}].responseWillContainAccessToken);
}

- (void)testThatNeedsAuthenticationIsSet
{
    XCTAssertFalse([[ZMTransportRequest alloc] initWithPath:@"/bar" method:ZMMethodPOST payload:@{} authentication:ZMTransportRequestAuthNone].needsAuthentication);
    XCTAssertFalse([[ZMTransportRequest alloc] initWithPath:@"/bar" method:ZMMethodPOST payload:@{} authentication:ZMTransportRequestAuthCreatesCookieAndAccessToken].needsAuthentication);
    XCTAssertTrue([[ZMTransportRequest alloc] initWithPath:@"/bar" method:ZMMethodPOST payload:@{} authentication:ZMTransportRequestAuthNeedsAccess].needsAuthentication);
}

- (void)testThatCreatesAccessTokenIsSet
{
    XCTAssertFalse([[ZMTransportRequest alloc] initWithPath:@"/bar" method:ZMMethodPOST payload:@{} authentication:ZMTransportRequestAuthNone].responseWillContainAccessToken);
    XCTAssertTrue([[ZMTransportRequest alloc] initWithPath:@"/bar" method:ZMMethodPOST payload:@{} authentication:ZMTransportRequestAuthCreatesCookieAndAccessToken].responseWillContainAccessToken);
    XCTAssertFalse([[ZMTransportRequest alloc] initWithPath:@"/bar" method:ZMMethodPOST payload:@{} authentication:ZMTransportRequestAuthNeedsAccess].responseWillContainAccessToken);
}

- (void)testThatResponseWillContainCookieIsSet;
{
    XCTAssertFalse([[ZMTransportRequest alloc] initWithPath:@"/bar" method:ZMMethodPOST payload:@{} authentication:ZMTransportRequestAuthNone].responseWillContainCookie);
    XCTAssertTrue([[ZMTransportRequest alloc] initWithPath:@"/bar" method:ZMMethodPOST payload:@{} authentication:ZMTransportRequestAuthCreatesCookieAndAccessToken].responseWillContainCookie);
    XCTAssertFalse([[ZMTransportRequest alloc] initWithPath:@"/bar" method:ZMMethodPOST payload:@{} authentication:ZMTransportRequestAuthNeedsAccess].responseWillContainCookie);
}

-(void)testThatRequestGetFromPathSetsProperties
{
    // given
    NSString *originalPath = @"foo-bar";
    NSMutableString *path = [NSMutableString stringWithString:originalPath];
    
    // when
    ZMTransportRequest *request = [ZMTransportRequest requestGetFromPath:path];
    [path setString:@"baz"]; // test that it is copied
    
    // then
    XCTAssertEqualObjects(request.path, originalPath);
    XCTAssertEqual(request.method, ZMMethodGET);
    XCTAssertNil(request.payload);
    XCTAssertEqual(request.contentDisposition.count, 0U);
}

- (void)testThatRequestWithBinaryDataSetsProperties;
{
    // given
    NSString * const path = @"/some/path";
    ZMTransportRequestMethod const method = ZMMethodPOST;
    NSData * const data = [NSData dataWithBytes:((const char []){'z', 'q'}) length:2];
    NSDictionary * const disposition = @{@"zasset": [NSNull null], @"conv_id": [NSUUID createUUID].transportString};
    
    // when
    ZMTransportRequest *request = [[ZMTransportRequest alloc] initWithPath:path method:method binaryData:data type:(__bridge id) kUTTypePNG contentDisposition:disposition];
    
    // then
    XCTAssertNotNil(request);
    XCTAssertNil(request.payload);
    XCTAssertEqualObjects(request.path, path);
    XCTAssertEqual(request.method, method);
    XCTAssertEqualObjects(request.contentDisposition, disposition);
    XCTAssertEqualObjects(request.binaryData, data);
    XCTAssertEqualObjects(request.binaryDataType, (__bridge id) kUTTypePNG);
}

- (void)testThatEmptyPUTRequestSetsProperties;
{
    // given
    NSString * const path = @"/some/path";
    ZMTransportRequestMethod const method = ZMMethodPUT;
    
    // when
    ZMTransportRequest *request = [ZMTransportRequest emptyPutRequestWithPath:path];
    NSMutableURLRequest *httpRequest = [[NSMutableURLRequest alloc] init];
    [request setBodyDataAndMediaTypeOnHTTPRequest:httpRequest];
    
    // when

    // then
    XCTAssertNotNil(request);
    XCTAssertNil(request.payload);
    XCTAssertEqualObjects(request.path, path);
    XCTAssertEqual(request.method, method);
    XCTAssertNil(request.contentDisposition);
    XCTAssertEqualObjects(request.binaryData, [NSData data]);
    XCTAssertEqualObjects([httpRequest valueForHTTPHeaderField:@"Content-Type"], @"application/json");
}

- (void)testThatImagePostRequestSetsProperties;
{
    // given
    NSString * const path = @"/some/path";
    NSData * const data = [self verySmallJPEGData];
    NSDictionary * const disposition = @{@"zasset": [NSNull null], @"conv_id": [NSUUID createUUID].transportString};
    
    // when
    ZMTransportRequest *request = [ZMTransportRequest postRequestWithPath:path imageData:data contentDisposition:disposition];
    
    // then
    XCTAssertNotNil(request);
    XCTAssertNil(request.payload);
    XCTAssertEqualObjects(request.path, path);
    XCTAssertEqual(request.method, ZMMethodPOST);
    XCTAssertEqualObjects(request.contentDisposition, disposition);
    XCTAssertEqualObjects(request.binaryData, data);
    XCTAssertEqualObjects(request.binaryDataType, (__bridge id) kUTTypeJPEG);
}

- (void)testThatImagePostRequestIsNilForNonImageData
{
    // given
    NSData * const textData = [self dataForResource:@"Lorem Ipsum" extension:@"txt"];
    XCTAssertNotNil(textData);
    
    // when
    ZMTransportRequest *request = [ZMTransportRequest postRequestWithPath:@"/some/path" imageData:textData contentDisposition:@{}];
    
    // then
    XCTAssertNil(request);
}

- (void)testThatMultipartImagePostRequestSetsProperties;
{
    // given
    NSString * const path = @"/some/path";
    NSData * const data = [self verySmallJPEGData];
    NSDictionary * const disposition = @{@"zasset": [NSNull null], @"conv_id": [NSUUID createUUID].transportString};

    NSString *boundary = @"frontier";
    NSData *metaDataData = [NSJSONSerialization dataWithJSONObject:disposition options:0 error:NULL];

    // when
    ZMTransportRequest *request = [ZMTransportRequest multipartRequestWithPath:path imageData:data metaData:disposition];
    
    // then
    XCTAssertNotNil(request);
    XCTAssertNil(request.payload);
    XCTAssertEqualObjects(request.path, path);
    XCTAssertEqual(request.method, ZMMethodPOST);
    XCTAssertNil(request.contentDisposition);
    NSArray *items = [request multipartBodyItems];
    XCTAssertEqual(items.count, 2u);

    ZMMultipartBodyItem *metadataItem = items.firstObject;
    XCTAssertEqualObjects(metadataItem.contentType, @"application/json; charset=utf-8");
    XCTAssertEqualObjects(metadataItem.data, metaDataData);

    ZMMultipartBodyItem *imageItem = items.lastObject;
    XCTAssertEqualObjects(imageItem.contentType, @"image/jpeg");
    XCTAssertEqualObjects(imageItem.headers, @{@"Content-MD5": [[data zmMD5Digest] base64EncodedStringWithOptions:0]});
    XCTAssertEqualObjects(imageItem.data, data);
    
    NSString *expectedContentType = [NSString stringWithFormat:@"multipart/mixed; boundary=%@", boundary];
    XCTAssertEqualObjects(request.binaryDataType, expectedContentType);
}

- (void)testThatMultipartImagePostRequestIsNilForNonImageData
{
    // given
    NSData * const textData = [self dataForResource:@"Lorem Ipsum" extension:@"txt"];
    XCTAssertNotNil(textData);
    
    // when
    ZMTransportRequest *request = [ZMTransportRequest multipartRequestWithPath:@"/some/path" imageData:textData metaData:@{}];
    
    // then
    XCTAssertNil(request);
}


- (void)testThatItCallsTheCompletionHandler
{
    // given
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler called"];
    ZMTransportRequest *transportRequest = [ZMTransportRequest requestWithPath:@"/something" method:ZMMethodPUT payload:@{}];

    [transportRequest addCompletionHandler:
     [ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *response ZM_UNUSED){
        [expectation fulfill];
    }]];

    // when
    [transportRequest completeWithResponse:nil];

    // then
    XCTAssert([self waitForCustomExpectationsWithTimeout:0.5]);
}

- (void)testThatItCallsMultipleCompletionHandlers
{
    // given
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Completion 1 handler called"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Completion 2 handler called"];

    ZMTransportRequest *transportRequest = [ZMTransportRequest requestWithPath:@"/something" method:ZMMethodPUT payload:@{}];
    
    [transportRequest addCompletionHandler:
     [ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *response ZM_UNUSED){
        [expectation1 fulfill];
    }]];
    
    [transportRequest addCompletionHandler:
     [ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *response ZM_UNUSED){
        [expectation2 fulfill];
    }]];
    
    // when
    [transportRequest completeWithResponse:nil];
    
    // then
    XCTAssert([self waitForCustomExpectationsWithTimeout:0.5]);
}


- (void)testThatItDoesNotAttemptToCallACompletionHandlerIfNoneIsSet
{
    // given
    ZMTransportRequest *transportRequest = [ZMTransportRequest requestWithPath:@"/something" method:ZMMethodPUT payload:@{}];

    // when
    XCTAssertNoThrow([transportRequest completeWithResponse:nil]);
}


- (void)testThatCompletionHandlerIsExecutedWithTheResponse;
{
    // given
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler called"];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:@{@"name":@"foo"} HTTPstatus:213 transportSessionError:nil];
    __block ZMTransportResponse *receivedResponse;
    
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"" method:ZMMethodGET payload:nil];
    [request addCompletionHandler:
     [ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *actualResponse){
        receivedResponse = actualResponse;
        [expectation fulfill];
    }]];
    
    // when
    [request completeWithResponse:response];
    
    // then
    XCTAssert([self waitForCustomExpectationsWithTimeout:0.5]);
    XCTAssertEqualObjects(response, receivedResponse);
}


- (void)testThatCompletionHandlersAreExecutedFromFirstToLast
{
    // given
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Completion 1 handler called"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Completion 2 handler called"];
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Completion 3 handler called"];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:@{} HTTPstatus:200 transportSessionError:nil];

    __block NSMutableString *responses = [[NSMutableString alloc] init];


    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"" method:ZMMethodGET payload:nil];

    [request addCompletionHandler:[ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *resp) {
        NOT_USED(resp);
        [responses appendString:@"a"];
        [expectation1 fulfill];
    }]];

    [request addCompletionHandler:[ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *resp) {
        NOT_USED(resp);
        [responses appendString:@"b"];
        [expectation2 fulfill];
    }]];

    [request addCompletionHandler:[ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *resp) {
        NOT_USED(resp);
        [responses appendString:@"c"];
        [expectation3 fulfill];
    }]];

    // when
    [request completeWithResponse:response];

    // then
    XCTAssert([self waitForCustomExpectationsWithTimeout:0.5]);
    XCTAssertEqualObjects(responses, @"abc");
}

- (void)testThatARequestShouldBeExecutedOnlyOnForegroundSessionByDefault
{
    // given
    ZMTransportRequest *request = [ZMTransportRequest requestGetFromPath:@"Foo"];
    
    // then
    XCTAssertFalse(request.shouldUseOnlyBackgroundSession);
}

- (void)testThatARequestShouldUseOnlyBackgroundSessionWhenForced
{
    // given
    ZMTransportRequest *request = [ZMTransportRequest requestGetFromPath:@"Foo"];

    // when
    [request forceToBackgroundSession];
    
    // then
    XCTAssertTrue(request.shouldUseOnlyBackgroundSession);
}

@end



@implementation ZMTransportRequestTests (ResponseMediaTypes)

- (void)testThatItSetsAcceptsImageData;
{
    // given
    ZMTransportRequest *sut = [ZMTransportRequest imageGetRequestFromPath:@"/foo/bar"];
    
    // then
    XCTAssertEqual(sut.acceptedResponseMediaTypes, ZMTransportAcceptImage);
}

- (void)testThatItSetsAcceptsTransportData;
{
    // (1) given
    ZMTransportRequest *sut = [ZMTransportRequest requestGetFromPath:@"/foo/bar"];
    
    // then
    XCTAssertEqual(sut.acceptedResponseMediaTypes, ZMTransportAcceptTransportData);
    
    // (2) given
    sut = [ZMTransportRequest requestWithPath:@"/foo2" method:ZMMethodPOST payload:@{@"f": @2}];
    
    // then
    XCTAssertEqual(sut.acceptedResponseMediaTypes, ZMTransportAcceptTransportData);

    // (3) given
    sut = [[ZMTransportRequest alloc] initWithPath:@"/hello" method:ZMMethodPUT binaryData:[@"asdf" dataUsingEncoding:NSUTF8StringEncoding] type:@"image/jpeg" contentDisposition:@{@"asdf": @42}];
    
    // then
    XCTAssertEqual(sut.acceptedResponseMediaTypes, ZMTransportAcceptTransportData);

    // (4) given
    sut = [[ZMTransportRequest alloc] initWithPath:@"/hello" method:ZMMethodPUT payload:@{@"A": @3} authentication:ZMTransportRequestAuthNeedsAccess];

    // then
    XCTAssertEqual(sut.acceptedResponseMediaTypes, ZMTransportAcceptTransportData);
}

@end



@implementation ZMTransportRequestTests (HTTPHeaders)

- (void)testThatItSetsBodyDataAndMediaTypeForTransportData;
{
    // given
    NSDictionary *payload = @{@"A": @2};
    ZMTransportRequest *sut = [[ZMTransportRequest alloc] initWithPath:@"/foo" method:ZMMethodPOST payload:payload];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    // when
    [sut setBodyDataAndMediaTypeOnHTTPRequest:request];
    
    // then
    XCTAssertNotNil(request.HTTPBody);
    NSDictionary *body = (id) [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:NULL];
    AssertEqualDictionaries(body, payload);
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Content-Type"], @"application/json");
}

- (void)testThatItSetsCompressedBodyDataAndMediaTypeForLargeTransportData;
{
    // given
    NSMutableArray *payload = [NSMutableArray array];
    for (int i = 0; i < 250; ++i) {
        NSMutableData *data = [NSMutableData dataWithLength:sizeof(uuid_t)];
        NSUUID *uuid = [NSUUID createUUID];
        [uuid getUUIDBytes:data.mutableBytes];
        NSDictionary *a = @{@"card": @(i),
                            @"data": [data base64EncodedStringWithOptions:0],};
        [payload addObject:a];
    }
    // The encoded transport data is approximately 46k bytes.
    ZMTransportRequest *sut = [ZMTransportRequest requestWithPath:@"/foo" method:ZMMethodPOST payload:payload shouldCompress:YES];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *expected = @"H4sIAAAAAAAAA4XaS08qWRhG4f/C1DMoLlVQJzkD+yjeFRCvn"
    @"R5wEwUUBRS10/+9k056sNdgffM9eJLlpeqt/effldFgNa78zH5UxoPNoPKzMpwUeWc2and"
    @"7O+t5b5GV/eXubvfXr8o/P/4/XPXD0+RwzQ9vk8N1PfzHbnK44YdTc+6HU3Phh1NzUw//T"
    @"s0tP5yaSz+cmque8HeKrnrDvVRd9Yh7+PHwintwe8Y9uL3jPtwech9uL7kPt6fch9tbtlN"
    @"3zVu2U3fNW7bx++gt26m75i0P4PaWB3B7ywO4veUB3N7yEG5veQi3tzxM3XVveYg/gN7yK"
    @"HXXveVR6q57yyO4veUR3N7yGG5veQy3tzyG21sew+0tT/Afx1uepO6GtzxJ3Q1veZK6G97"
    @"yFG5veQq3tzyF21uewu0tz+D2lmdwe8uz1J17y7PUnXvL89Sde8tzPJp4y3O4veU53N7yA"
    @"m5veQG3t7yA21tewO0tO6m78Jad1F14yw6eBb1lJ3UX3rILt7fswu0tu3B7yy7c3rIHt7f"
    @"swe0te6m76S17ePj2lpepu+ktL1N301tewu0tL+H2ln24vWUfbm/Zh9tb9uH2lld42/GWV"
    @"6m75S2vUnfLW16l7pa3vIbbW17D7S2v4faW13B7yxu4veUN3N7yJnWX3vImdZfe8jZ1l97"
    @"yFq/F3vIWbm95C7e3vIPbW97B7S3v4PaWd3B7y3u8F2ce8x4vxpnXvOcS4Tnv8Wqcec8B7"
    @"R50QLsXHdDuSQe0e9Mh7R51SLtXHcIeTEBDTkBedQR7MAKNYA9WoBHtXnVEu1cd0+5Vx7R"
    @"71THtXnVMu1edcHvzqhPYgzVoAnswB01gD/agB9q96gPtXvWBdq/6QLtXndLuVae0e9Up7"
    @"MEsNIU92IUeYQ+GoUcOtl71kXav+ki7V32i3as+0e5Vn2j3qk+0e9UZ7MFANIM9WIhmXMq"
    @"96gz2YCOa0+5V57R71TntXnVOu1dd0O5VF7R71QXswVS04CcKr/oMezAWPcMerEXPtHvVZ"
    @"9q96gvtXvWFdq/6QrtXfaHdqy75bcirLmEPVqMl7MFstIQ92I1eafeqr7R71Vfaveor7V7"
    @"1jXav+ka7V32DPZiP3mAP9qMV7MGAtOIHRa+6ot2rrmj3qmvaveqadq+6pt2rrmn3qhvYg"
    @"yFpA3uwJG34JderbmAPtqR32r3qO+1e9Z12r/pOu1f9oN2rftDuVT9gDyalD35C96pb2IN"
    @"RaQt7sCptafeqW9q96iftXvWTdq/6SbtX/aTdq37x7oJX/cLH9GBb+sItgGBb+sI1gGBb+"
    @"qbdq37T7lW/afeq37R71Yx2r5rR7lUz2INtKYM92JaqsAfbUpUXXrxqlXavWqXdq9Zo96o"
    @"12r1qjXavWqPdq9ZhD7alOuzBtlTnTSOvWoc92JYatHvVBu1etUG7V23Q7lVz2r1qTrtXz"
    @"WEPtqWcV7y8agF7sC0VsAfbUkG7Vy1o96pN2r1qk3av2qTdqzZp96ot3q3zqi3Yg22pBXu"
    @"wLbVgD7alknavWtLuVUvavWpJu1fdod2r7tDuVXf+s//1L0rK7jh5LQAA";
    NSData *expectedBody = [[NSData alloc] initWithBase64EncodedString:expected options:0];
    
    // when
    [sut setBodyDataAndMediaTypeOnHTTPRequest:request];
    
    // then
    XCTAssertNotNil(request.HTTPBody);
    AssertEqualData(request.HTTPBody, expectedBody);
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Content-Type"], @"application/json");
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Content-Encoding"], @"gzip");
}

- (void)testThatItSetsBodyDataAndMediaTypeForImageRequest;
{
    // given
    NSData *data = [@"jhasdhjkadshjklad" dataUsingEncoding:NSUTF8StringEncoding];
    ZMTransportRequest *sut = [[ZMTransportRequest alloc] initWithPath:@"/foo" method:ZMMethodPOST binaryData:data type:(__bridge NSString *) kUTTypeJPEG contentDisposition:nil];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    // when
    [sut setBodyDataAndMediaTypeOnHTTPRequest:request];
    
    // then
    XCTAssertEqualObjects(request.HTTPBody, data);
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Content-Type"], @"image/jpeg");
}

- (void)testThatItDoesNotSetMediaTypeForRequestWithoutPayload;
{
    // given
    ZMTransportRequest *sut = [[ZMTransportRequest alloc] initWithPath:@"/foo" method:ZMMethodGET payload:nil];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    // when
    [sut setBodyDataAndMediaTypeOnHTTPRequest:request];
    
    // then
    XCTAssertNil(request.HTTPBody);
    XCTAssertNil([request valueForHTTPHeaderField:@"Content-Type"]);
}

- (void)testThatItSetsTheContentDispositionForImageRequest;
{
    // given
    NSData *data = [@"jhasdhjkadshjklad" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *disposition = @{@"A": @YES, @"b": @1, @"c": @"foo bar", @"d": @"z", @"e": [NSNull null]};
    ZMTransportRequest *sut = [[ZMTransportRequest alloc] initWithPath:@"/foo" method:ZMMethodPOST binaryData:data type:(__bridge NSString *) kUTTypeJPEG contentDisposition:disposition];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    // when
    [sut setContentDispositionOnHTTPRequest:request];
    
    // then
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Content-Disposition"], @"e;A=true;b=1;c=\"foo bar\";d=z");
}

- (void)testThatItDoesNotSetTheContentDispositionHeaderWhenNoDispostionIsSpecified;
{
    // given
    NSData *data = [@"jhasdhjkadshjklad" dataUsingEncoding:NSUTF8StringEncoding];
    ZMTransportRequest *sut = [[ZMTransportRequest alloc] initWithPath:@"/foo" method:ZMMethodPOST binaryData:data type:(__bridge NSString *) kUTTypeJPEG contentDisposition:nil];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    // when
    [sut setContentDispositionOnHTTPRequest:request];
    
    // then
    XCTAssertNil([request valueForHTTPHeaderField:@"Content-Disposition"]);
}

- (void)testThatItSetsAnExpirationDate;
{
    // given
    ZMTransportRequest *sut = [[ZMTransportRequest alloc] initWithPath:@"/foo" method:ZMMethodGET payload:nil];
    NSTimeInterval interval = 35;
    
    // when
    [sut expireAfterInterval:interval];
    NSDate *expirationDate = sut.expirationDate;
    
    // then
    NSDate *then = [NSDate dateWithTimeIntervalSinceNow:interval];
    float timePrecision = 10.0f;
    XCTAssertTrue(fabs(then.timeIntervalSinceReferenceDate - expirationDate.timeIntervalSinceReferenceDate) < timePrecision);
    
}

@end



@implementation ZMTransportRequestTests (Payload)

- (void)testThatPOSTWithPayloadHasRequiredPayload
{
    // given
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"foo" method:ZMMethodPOST payload:@{}];
    
    // then
    XCTAssertTrue(request.hasRequiredPayload);
}

- (void)testThatPOSTWithNoPayloadHasRequiredPayload
{
    // given
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"foo" method:ZMMethodPOST payload:nil];
    
    // then
    XCTAssertTrue(request.hasRequiredPayload);
}

- (void)testThatDELETEWithPayloadHasRequiredPayload
{
    // given
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"Foo" method:ZMMethodDELETE payload:@{}];
    
    // then
    XCTAssertTrue(request.hasRequiredPayload);
}

- (void)testThatDELETEWithNoPayloadHasRequiredPayload
{
    // given
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"Foo" method:ZMMethodDELETE payload:nil];
    
    // then
    XCTAssertTrue(request.hasRequiredPayload);
}

- (void)testThatGETWithoutPayloadHasRequiredPayload
{
    // given
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"Foo" method:ZMMethodGET payload:nil];
    
    // then
    XCTAssertTrue(request.hasRequiredPayload);
}

- (void)testThatHEADHasRequiredPayload
{
    // given
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"foo" method:ZMMethodHEAD payload:nil];
    
    // then
    XCTAssertTrue(request.hasRequiredPayload);
}

@end


@implementation ZMTransportRequestTests (Debugging)

- (void)testThatItPrintsDebugInformation
{
    // given
    NSString *info1 = @"....xxxXXXxxx....";
    NSString *info2 = @"32432525245345435";
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"foo" method:ZMMethodHEAD payload:nil];
    
    // when
    [request appendDebugInformation:info1];
    [request appendDebugInformation:info2];
    
    // then
    NSString *description = request.description;
    XCTAssertNotEqual([description rangeOfString:info1].location, NSNotFound);
    XCTAssertNotEqual([description rangeOfString:info2].location, NSNotFound);

}

@end
