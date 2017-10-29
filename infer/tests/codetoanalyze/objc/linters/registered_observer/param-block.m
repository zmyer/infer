/*
 * Copyright (c) 2016 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@interface AA : NSObject

@property(strong) NSNotificationCenter* nc;

- (void)my_method:(double)d
      block_param:(double (^)(double time))myblock
               st:(int)numSteps;

@end

@implementation AA

- (void)foo {
  [self.nc addObserver:self selector:@selector(foo:) name:nil object:nil];
}

- (void)my_method:(double)d
      block_param:(double (^)(double time))myblock
               st:(int)num {
  for (int i = 1; i <= num; i++) {
    if (myblock)
      myblock(i * d * num);
  }
}

- (void)boo {

  [self my_method:5.3
      block_param:^(double time) {
        [self.nc removeObserver:self];
        return time + 7.4;
      }
               st:30];
}

@end
