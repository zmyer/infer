/*
 * Copyright (c) 2017 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */
import javax.annotation.concurrent.ThreadSafe;

// Fields must encapsulate the class they are declared in, not
// the class they are potentially inherited into.

@ThreadSafe
class SuperFld {

  private int f = 0;
  public int getF() {
    return f; // should *not* report read/write race with SubFld.setF()
  }

  protected int g = 0;
  public int getG() {
    return g; // must report read/write race with SubFld.setG()
  }

}

@ThreadSafe
public class SubFld extends SuperFld {

  private int f = 0;
  synchronized public void setF() {
    f = 5; // should *not* report
  }

  synchronized public void setG() {
    g = 5; // must report
  }
}
