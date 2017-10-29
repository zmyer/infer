/*
 * Copyright (c) 2017 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */
#include <chrono>
#include <mutex>

void alarm1(std::timed_mutex& m) {
  m.lock();
  m.lock();
}

void try_lock_bad(std::timed_mutex& m) {
  m.try_lock();
  m.lock();
}

void try_lock_for_bad_FN(std::timed_mutex& m) {
  m.try_lock_for(std::chrono::seconds(123));
  m.lock();
}

void try_lock_until_bad_FN(std::timed_mutex& m) {
  std::chrono::time_point<std::chrono::steady_clock> timeout;
  m.try_lock_until(timeout);
  m.lock();
}
