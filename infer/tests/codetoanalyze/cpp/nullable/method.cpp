/*
 * Copyright (c) 2017 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */
bool star();

class T {
 public:
  int x;
  T* field;

 public:
  int* _Nullable mayReturnNullPointer() {
    if (star()) {
      return nullptr;
    } else {
      return new int;
    }
  }

 public:
  T* _Nullable mayReturnNullObject() {
    if (star()) {
      return nullptr;
    } else {
      return this;
    }
  }

 public:
  void doSomething() {}
};

void assignNullableValueBad(T* t) {
  int* p = t->mayReturnNullPointer();
  *p = 42;
}

void FP_reAssigningNullableValueOk(T* t) {
  int* p = t->mayReturnNullPointer();
  p = new int;
  *p = 42;
}

void callMethodOnNullableObjectBad(T* t) {
  t->mayReturnNullObject()->doSomething();
}

void callMethodOnNullableObjectOk(T* t) {
  T* p = t->mayReturnNullObject();
  if (p != nullptr) {
    p->doSomething();
  }
}

void dereferenceFieldOfNullableObjectBad(T* t) {
  T* p = t->mayReturnNullObject();
  p->x = 42;
}

void methodCallOnFieldOfNullableObjectBad(T* t) {
  T* p = t->mayReturnNullObject();
  p->field->doSomething();
}

void avoidDoubleReportingBad(T* t) {
  T* p = t->mayReturnNullObject();
  p->doSomething(); // should report here
  p->doSomething(); // should not report here
}
