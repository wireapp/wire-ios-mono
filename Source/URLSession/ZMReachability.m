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


@import SystemConfiguration;
@import ZMCSystem;

#import "ZMReachability.h"
#import <libkern/OSAtomic.h>
#import "ZMTLogging.h"

static char* const ZMLogTag ZM_UNUSED = ZMT_LOG_TAG_NETWORK;


@interface ZMReachability ()
{
    int32_t _tornDown;
}

@property (nonatomic, copy) NSArray *names;
@property (nonatomic, weak) id<ZMReachabilityObserver> reachabilityObserver;
@property (nonatomic) NSOperationQueue *observerQueue; ///< calls to the observer will always be performed on this queue
@property (nonatomic, copy) NSArray *reachabilityReferences;
@property (nonatomic) dispatch_queue_t workQueue;
@property (nonatomic) ZMSDispatchGroup *group;
@property (nonatomic) NSMapTable *referenceToFlag;
@property (nonatomic) NSMapTable *referenceToName;
@property (atomic) BOOL mayBeReachable;
@property (atomic) BOOL isMobileConnection;

@end



@implementation ZMReachability

- (instancetype)initWithServerNames:(NSArray *)names observer:(id<ZMReachabilityObserver>)observer queue:(NSOperationQueue *)observerQueue group:(ZMSDispatchGroup *)group;
{
    self = [super init];
    if (self) {
        self.names = [[NSSet setWithArray:names] allObjects];
        self.reachabilityObserver = observer;
        self.observerQueue = observerQueue;
        self.group = group;
        self.workQueue = dispatch_queue_create("ZMReachability", 0);
        self.referenceToFlag = [NSMapTable strongToStrongObjectsMapTable];
        self.referenceToName = [NSMapTable strongToStrongObjectsMapTable];
        [self setupReachability];
    }
    return self;
}

- (void)tearDown;
{
    if (OSAtomicCompareAndSwap32Barrier(0, 1, &_tornDown)) {
        NSArray *refs = self.reachabilityReferences;
        self.reachabilityReferences = nil;
        self.referenceToFlag = nil;
        [self.group asyncOnQueue:self.workQueue block:^{
            for (id obj in refs) {
                SCNetworkReachabilityRef ref = (__bridge SCNetworkReachabilityRef) obj;
                // Setting the queue to NULL disables the callbacks:
                Require(SCNetworkReachabilitySetDispatchQueue(ref, NULL));
            }
        }];
    } else {
        ZMLogWarn(@"Tearing down <%@: %p> when it's already torn down.", self.class, self);
    }
}

- (void)dealloc;
{
    RequireString(_tornDown != 0, "Object was never torn down.");
}

static void networkReachabilityCallBack(SCNetworkReachabilityRef ref, SCNetworkReachabilityFlags flags, void *info)
{
    ZMReachability *self = (__bridge ZMReachability *) info;
    [self networkAddressChangedForReference:ref flags:flags];
}

static CFStringRef copyDescription(const void *info)
{
    ZMReachability *self = (__bridge ZMReachability *) info;
    return CFBridgingRetain(self.description);
}

- (void)setupReachability;
{
    [self.group asyncOnQueue:self.workQueue block:^{
        NSMutableArray *references = [NSMutableArray array];
        for (NSString *name in self.names) {
            SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithName(NULL, [name UTF8String]);
            id obj = CFBridgingRelease(ref);
            if (obj != nil) {
                [references addObject:obj];
                [self.referenceToName setObject:name forKey:obj];
                SCNetworkReachabilityContext context = {
                    0,
                    (__bridge void *) self,
                    NULL,
                    NULL,
                    copyDescription,
                };
                Require(SCNetworkReachabilitySetCallback(ref, networkReachabilityCallBack, &context));
                Require(SCNetworkReachabilitySetDispatchQueue(ref, self.workQueue));
            }
        }
        self.reachabilityReferences = references;
        
        // Get the initial flags:
        for (id obj in self.reachabilityReferences) {
            SCNetworkReachabilityRef ref = (__bridge SCNetworkReachabilityRef) obj;
            SCNetworkReachabilityFlags flags = 0u;
            if (SCNetworkReachabilityGetFlags(ref, &flags)) {
                [self.referenceToFlag setObject:@(flags) forKey:obj];
            } else {
                [self.referenceToFlag setObject:@0 forKey:obj];
            }
        }
        [self updateStatus];
    }];
}

- (void)networkAddressChangedForReference:(SCNetworkReachabilityRef)ref flags:(SCNetworkReachabilityFlags)flags;
{
    // This method is called on the workQueue.
    id obj = (__bridge id) ref;
    [self.referenceToFlag setObject:@(flags) forKey:obj];
    [self updateStatus];
}

- (void)updateStatus;
{
    ZMLogDebug(@"UpdateStatus: %@", self);
    // This method is called on the workQueue.
    static SCNetworkReachabilityFlags const flagsofInterest = (kSCNetworkReachabilityFlagsReachable |
                                                               kSCNetworkReachabilityFlagsConnectionRequired |
                                                               kSCNetworkReachabilityFlagsConnectionOnTraffic |
                                                               kSCNetworkReachabilityFlagsConnectionOnDemand |
                                                               kSCNetworkReachabilityFlagsIsLocalAddress |
                                                               kSCNetworkReachabilityFlagsIsDirect |
                                                               kSCNetworkReachabilityFlagsIsWWAN |
                                                               0);
    
    BOOL globalReachable = YES;
    BOOL isMobileConnection = NO;
    
    for(id obj in self.referenceToFlag.keyEnumerator) {
        NSString *name = [self.referenceToName objectForKey:obj];
        NSNumber *flagsNumber = [self.referenceToFlag objectForKey:obj];
        SCNetworkReachabilityFlags flags = (SCNetworkReachabilityFlags) [flagsNumber unsignedIntValue];
        BOOL serverReachable = (0 != (flags & flagsofInterest));
        if(!serverReachable) {
            ZMLogWarn(@"REACHABILITY: %@ NOT reachable!", name);
        }
        else {
            ZMLogInfo(@"REACHABILITY: %@ reachable", name);
        }
        if (0 != (flags & kSCNetworkReachabilityFlagsIsWWAN)) {
            isMobileConnection = YES;
        }
        globalReachable &= serverReachable;
        ZMLogInfo(@"FINAL REACHABILITY: %d", globalReachable);
    }
    
    [self.group enter];
    [self.observerQueue addOperationWithBlock:^{
        self.mayBeReachable = globalReachable;
        self.isMobileConnection = isMobileConnection;
        [self.reachabilityObserver reachabilityDidChange:self];
        [self.group leave];
    }];
}

- (NSString *)description;
{
    // This is (intentionally) not thread safe:
    NSMutableArray *nameInfo = [NSMutableArray array];
    for (id obj in self.reachabilityReferences) {
        NSString *name = [self.referenceToName objectForKey:obj];
        NSNumber *flagsNumber = [self.referenceToFlag objectForKey:obj];
        SCNetworkReachabilityFlags flags = (SCNetworkReachabilityFlags) [flagsNumber unsignedIntValue];
        NSMutableArray *flagNames = [NSMutableArray array];
        if ((flags & kSCNetworkReachabilityFlagsTransientConnection) != 0) {
            [flagNames addObject:@"TransientConnection"];
        }
        if ((flags & kSCNetworkReachabilityFlagsReachable) != 0) {
            [flagNames addObject:@"Reachable"];
        }
        if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0) {
            [flagNames addObject:@"ConnectionRequired"];
        }
        if ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0) {
            [flagNames addObject:@"ConnectionOnTraffic"];
        }
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) != 0) {
            [flagNames addObject:@"InterventionRequired"];
        }
        if ((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) {
            [flagNames addObject:@"ConnectionOnDemand"];
        }
        if ((flags & kSCNetworkReachabilityFlagsIsLocalAddress) != 0) {
            [flagNames addObject:@"IsLocalAddress"];
        }
        if ((flags & kSCNetworkReachabilityFlagsIsDirect) != 0) {
            [flagNames addObject:@"IsDirect"];
        }
#if	TARGET_OS_IPHONE
        if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
            [flagNames addObject:@"IsWWAN"];
        }
#endif
        [nameInfo addObject:[NSString stringWithFormat:@"[%@]: {%@}",
                             name, [flagNames componentsJoinedByString:@"; "]]];
        
    }
    return [NSString stringWithFormat:@"<%@: %p> Names: (%@) %@",
            self.class, self,
            [self.names componentsJoinedByString:@", "],
            [nameInfo componentsJoinedByString:@", "]];
}

@end
