/*
 * Copyright (c) 2013 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

package codetoanalyze.java.infer;

import com.facebook.infer.annotation.SuppressLint;

import java.io.IOException;
import java.io.File;
import java.io.FileInputStream;


// @SuppressLint("Suppressing all the warnings in a class is not supported yet")
class SuppressAllWarnigsInTheClass {

  void shouldNotReportNPE() {
    Object object = null;
    object.toString();
  }

  void shouldNotReportResourceLeak() {
    try {
      FileInputStream fis = new FileInputStream(new File("whatever.txt"));
    } catch (IOException e) {}
  }

}

public class SuppressLintExample {

  @SuppressLint("Suppressing by warning type not supported yet")
  SuppressLintExample() {
    Object object = null;
    object.toString();
  }

  void shouldReportNPE() {
    Object object = null;
    object.toString();
  }

  @SuppressLint("Suppressing by warning type not supported yet")
  void shouldNotReportNPE() {
    Object object = null;
    object.toString();
  }

}
