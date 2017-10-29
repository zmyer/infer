/*
 * Copyright (c) 2013 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

package codetoanalyze.java.checkers;

import com.facebook.infer.annotation.NoAllocation;
import com.facebook.infer.annotation.IgnoreAllocations;

public class NoAllocationExample {

  @NoAllocation
  void directlyAllocatingMethod() {
    new Object();
  }

  void allocates() {
    new Object();
  }

  @NoAllocation
  void indirectlyAllocatingMethod() {
    allocates();
  }

  void doesNotAllocate() {
    // does noting
  }

  @NoAllocation
  void notAllocatingMethod() {
    doesNotAllocate();
  }

  void allocatingIsFine() {
    new Object();
  }

  @NoAllocation
  void throwsException() {
    throw new RuntimeException();
  }

  @NoAllocation
  void creatingExceptionIsFine() {
    throwsException();
  }

  @NoAllocation
  void thowingAThrowableIsFine() {
    throw new AssertionError();
  }

  @IgnoreAllocations
  void acceptableAllocation() {
    new Object();
  }

  @NoAllocation
  void onlyAllocatesInAcceptableWay() {
    acceptableAllocation();
  }

  native boolean rareCase();

  @NoAllocation
  void onlyAllocatesUsingUnlikely() {
    if (Branch.unlikely(rareCase())) {
      allocates();
    }
  }

  native boolean anotherRareCase();

  @NoAllocation
  void nestedUnlikely() {
    if (Branch.unlikely(rareCase())) {
      if (!Branch.unlikely(anotherRareCase())) {
        allocates();
      }
    }
  }

}
