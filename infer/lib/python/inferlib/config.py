# Copyright (c) 2015 - present Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the BSD style license found in the
# LICENSE file in the root directory of this source tree. An additional grant
# of patent rights can be found in the PATENTS file in the same directory.

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals

import locale
import os


try:
    locale.setlocale(locale.LC_ALL, '')
    CODESET = locale.getlocale(locale.LC_CTYPE)[1]
except:
    CODESET = None
if CODESET is None:
    CODESET = 'ascii'

# this assumes that this file lives in infer/lib/python/infer/ and the binaries
# are in infer/bin/
INFER_PYTHON_DIRECTORY = os.path.dirname(os.path.realpath(__file__)
                                         .decode(CODESET))
INFER_INFER_DIRECTORY = os.path.join(INFER_PYTHON_DIRECTORY,
                                     os.pardir, os.pardir, os.pardir)
INFER_ROOT_DIRECTORY = os.path.join(INFER_INFER_DIRECTORY, os.pardir)
FCP_DIRECTORY = os.path.join(INFER_ROOT_DIRECTORY, 'facebook-clang-plugins')
LIB_DIRECTORY = os.path.join(INFER_INFER_DIRECTORY, 'lib')
BIN_DIRECTORY = os.path.join(INFER_INFER_DIRECTORY, 'bin')
JAVA_LIB_DIRECTORY = os.path.join(LIB_DIRECTORY, 'java')
MODELS_JAR = os.path.join(JAVA_LIB_DIRECTORY, 'models.jar')
WRAPPERS_DIRECTORY = os.path.join(LIB_DIRECTORY, 'wrappers')

DEFAULT_INFER_OUT = os.path.join(os.getcwd().decode(CODESET), 'infer-out')

JSON_REPORT_FILENAME = 'report.json'
INFER_BUCK_DEPS_FILENAME = 'infer-deps.txt'
BUGS_FILENAME = 'bugs.txt'
JAVAC_FILELISTS_FILENAME = 'filelists'
PMD_XML_FILENAME = 'report.xml'

IOS_CAPTURE_ERRORS = 'errors'
IOS_BUILD_OUTPUT = 'build_output'

LOG_FILE = 'toplevel.log'

BUCK_INFER_OUT = 'infer'

BUCK_OUT = 'buck-out'

TRASH = '.trash'

BUCK_OUT_TRASH = os.path.join(BUCK_OUT, TRASH)

BUCK_OUT_GEN = os.path.join(BUCK_OUT, 'gen')


# list of possible analyzers
ANALYZER_INFER = 'infer'
ANALYZER_CHECKERS = 'checkers'
ANALYZER_CAPTURE = 'capture'
ANALYZER_COMPILE = 'compile'
ANALYZER_CRASHCONTEXT = 'crashcontext'
ANALYZER_LINTERS = 'linters'

ANALYZERS = [
    ANALYZER_CAPTURE,
    ANALYZER_CHECKERS,
    ANALYZER_COMPILE,
    ANALYZER_CRASHCONTEXT,
    ANALYZER_INFER,
    ANALYZER_LINTERS,
]
