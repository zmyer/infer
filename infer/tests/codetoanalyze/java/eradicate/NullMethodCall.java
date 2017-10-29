/*
 * Copyright (c) 2013 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

package codetoanalyze.java.eradicate;

import com.google.common.base.Preconditions;

import java.lang.System;
import javax.annotation.Nullable;
import com.facebook.infer.annotation.Assertions;

import java.util.Map;
import java.util.HashMap;
import java.util.concurrent.ConcurrentHashMap;

public class NullMethodCall {

  void callOnNull() {
    String s = null;
    int n = s.length();
  }

  void callOnEmptyString() {
    String s = "";
    int n = s.length();
  }

  void callAfterYodaCondition(@Nullable String s) {
    if (null != s) {
      int n = s.length();
    }
  }

  int objectLength(@Nullable Object o) {
    if (o instanceof String) {
      String s = (String) o;
      return s.length(); // OK: s cannot be null because of instanceof
    }
    return 0;
  }

  int testCheckState(@Nullable String s1, @Nullable String s2) {
    Preconditions.checkState(s1 != null && s2 != null, "bad");
    return s1.length() + s2.length();
  }

  int testPrivateStaticInnerClassField() {
    String s;
    S.sfld = "abc";
    s = S.sfld;
    return s.length();
  }

  private static class S {
    private static
    @Nullable
    String sfld;
  }

  @Nullable
  String fld;
  private
  @Nullable
  String pfld;

  public class Inner {
    int outerField() {
      String s = fld;
      return s.length();
    }

    int outerFieldInitialized() {
      fld = "abc";
      String s = fld;
      return s.length();
    }

    int outerPrivateField() {
      String s = pfld;
      return s.length();
    }

    int outerPrivateFieldInitialized() {
      pfld = "abc";
      String s = pfld;
      return s.length();
    }

    int outerPrivateFieldCheckNotNull() {
      Preconditions.checkNotNull(pfld);
      String s = pfld;
      return s.length();
    }

    int outerPrivateFieldCheckState() {
      Preconditions.checkState(pfld != null);
      String s = pfld;
      return s.length();
    }

    int outerPrivateFieldAssertNotNull() {
      Assertions.assertNotNull(pfld);
      String s = pfld;
      return s.length();
    }

    int outerPrivateFieldAssumeNotNull() {
      Assertions.assumeNotNull(pfld);
      String s = pfld;
      return s.length();
    }

    int outerPrivateFieldAssertCondition() {
      Assertions.assertCondition(pfld != null, "explanation");
      String s = pfld;
      return s.length();
    }

    int outerPrivateFieldAssumeCondition() {
      Assertions.assumeCondition(pfld != null, "explanation");
      String s = pfld;
      return s.length();
    }

    int outerPrivateFieldCheckStateYoda() {
      Preconditions.checkState(null != pfld);
      String s = pfld;
      return s.length();
    }

    String outerFieldGuardPrivate() {
      if (pfld != null) return pfld.toString();
      return "";
    }

    String outerFieldGuardPublic() {
      if (fld != null) return fld.toString();
      return "";
    }

    public class InnerInner {
      int outerouterPrivateFieldInitialized() {
        pfld = "abc";
        String s = pfld;
        return s.length();
      }
    }
  }

  @Nullable
  String getNullable() {
    return null;
  }

  void testVariableAssigmentInsideConditional() {
    String s = null;
    if ((s = getNullable()) != null) {
      int n = s.length();
    }
  }

  void testFieldAssigmentInsideConditional() {
    if ((fld = getNullable()) != null) {
      int n = fld.length();
    }
  }

  String abc = "abc";

  void testFieldAssignmentIfThenElse(String name) {
    String s = (name.length() == 0) ? null : abc;
    int n = s.length();
  }

  static String throwsExn() throws java.io.IOException {
    throw new java.io.IOException();
  }

  void testExceptionPerInstruction(int z) throws java.io.IOException {
    String s = null;

    try {
      s = throwsExn();
    } finally {
      int n = s.length();
    }
  }

  public class InitializeAndExceptions {
    String s;

    String bad() throws java.io.IOException {
      throw new java.io.IOException();
    }

    InitializeAndExceptions() throws java.io.IOException {
      s = bad(); // should not report field not initialized
    }
  }

  public class InitializeViaPrivateMethod {
    String name;

    private void reallyInitName(String s) {
      name = s;
    }

    private void initName(String s) {
      reallyInitName(s);
    }

    InitializeViaPrivateMethod() {
      initName("abc");
    }
  }

  class CheckNotNullVararg {
    void checkNotNull(String msg, Object ... objects) {
    }

    void testCheckNotNullVaratg(@Nullable String s1, @Nullable String s2) {
      checkNotNull("hello", s1, s2);
      s1.isEmpty();
      s2.isEmpty();
    }

    void testRepeatedCheckNotNull(@Nullable String s) {
      checkNotNull("abc", s);
      checkNotNull("abc", s.toString());
      s.toString().isEmpty();
    }
  }

  public void testSystemGetPropertyReturn() {
    String s = System.getProperty("");
    int n = s.length();
  }

  int testSystemGetenvBad() {
    String envValue = System.getenv("WHATEVER");
    return envValue.length();
  }

  class SystemExitDoesNotReturn {
    native boolean whoknows();

    void testOK() {
      String s = null;
      if (whoknows()) {
        s = "a";
      }
      else {
        System.exit(1);
      }
      int n = s.length();
    }
  }

  public void testMapGetBad
      (Map<String, String> m,
       HashMap<String, String> hm,
       ConcurrentHashMap<String, String> chm) {
      m.get("foo").toString();
      hm.get("foo").toString();
      chm.get("foo").toString();
  }

  public void testMapRemoveBad
      (Map<String, String> m,
       HashMap<String, String> hm,
       ConcurrentHashMap<String, String> chm) {
      m.remove("foo").toString();
      hm.remove("foo").toString();
      chm.remove("foo").toString();
  }

}
