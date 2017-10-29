/*
 * Copyright (c) 2017 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#include <stdlib.h>

void foo_defined_in_subtarget1();

void goo() {
  foo_defined_in_subtarget1();
  int* s = NULL;
  *s = 42;
}
