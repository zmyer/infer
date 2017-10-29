/*
 * Copyright (c) 2015 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

package codetoanalyze.java.quandary;

import android.content.SharedPreferences;
import android.location.Location;
import android.telephony.TelephonyManager;
import android.util.Log;

public class LoggingPrivateData {

  private native int rand();

  public void logAllSourcesBad(Location l, TelephonyManager t) {
    String source = null;
    switch (rand()) {
    case 1:
      source = String.valueOf(l.getAltitude());
      break;
    case 2:
      source = String.valueOf(l.getBearing());
      break;
    case 3:
      source = String.valueOf(l.getLatitude());
      break;
    case 4:
      source = String.valueOf(l.getLongitude());
      break;
    case 5:
      source = String.valueOf(l.getSpeed());
      break;
    case 6:
      source = t.getDeviceId();
      break;
    case 7:
      source = t.getLine1Number();
      break;
    case 8:
      source = t.getSimSerialNumber();
      break;
    case 9:
      source = t.getSubscriberId();
      break;
    case 10:
      source = t.getVoiceMailNumber();
      break;
    }

    String TAG = "tag";
    Log.e(TAG, source);
    Log.println(0, TAG, source);
    Log.w(TAG, source);
    Log.wtf(TAG, source); // 10 sources * 4 sinks = 40 expected reports
  }

}
