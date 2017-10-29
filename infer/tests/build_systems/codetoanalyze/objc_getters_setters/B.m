/*
 * Copyright (c) 2017 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "A.h"
#import "B.h"

@implementation B {
  A* _a;
}

- (int)npe_no_bad_footprint_in_getter:(A*)a {
  int* p = nil;
  NSData* metadata = a.metadata; // Doesn't crash here with Bad_footprint
  return *p; // NPE
}

- (int)npe_no_bad_footprint_in_setter:(A*)a andMetadata:(NSData*)metadata {
  int* p = nil;
  a.metadata = metadata; // Doesn't crash here with Bad_footprint
  return *p; // NPE
}

- (instancetype)infer_field_get_spec:(NSData*)m {
  A* a = [A alloc];
  [a withMetadata:m]; // Doesn't crash here with Precondition_not_met, get
                      // correct spec with a.x=5
  self->_a = a;
  return self;
}

- (int)npe_no_precondition_not_met:(NSData*)m {
  [self infer_field_get_spec:m];
  if ([self->_a getX] == 5) {
    int* p_true = nil;
    return *p_true; // NPE
  } else {
    int* p_false = nil;
    return *p_false; // no NPE, because we know the value of a._x is 5 because
                     // we get the correct spec in the method
                     // infer_field_get_spec
  }
}
@end
