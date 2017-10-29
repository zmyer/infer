# Copyright (c) 2016 - present Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the BSD style license found in the
# LICENSE file in the root directory of this source tree. An additional grant
# of patent rights can be found in the PATENTS file in the same directory.

ROOT_DIR = $(TESTS_DIR)/../..
include $(ROOT_DIR)/Makefile.config

# The relative path from infer/tests/ to the directory containing the current Makefile. This is
# computed in a hacky way and might not always be a relative path, so only use this for cosmetic
# reasons.
TEST_REL_DIR = $(patsubst $(abspath $(TESTS_DIR))/%,%,$(abspath $(CURDIR)))

define check_no_duplicates
  grep "DUPLICATE_SYMBOLS" $(1); test $$? -ne 0 || \
  (echo '$(TEST_ERROR)Duplicate symbols found in $(CURDIR).' \
   'Please make sure all the function names in all the source test files are different.$(TEST_RESET)';\
   exit 1)
endef

define check_no_diff
  diff -u $(1) $(2) >&2 || \
  (printf '\n' >&2; \
   printf '$(TERM_ERROR)Test output ($(2)) differs from expected test output $(1)$(TERM_RESET)\n' >&2; \
   printf '$(TERM_ERROR)Run the following command to replace the expected test output with the new output:$(TERM_RESET)\n' >&2; \
   printf '\n' >&2; \
   printf '$(TERM_ERROR)  make -C $(TEST_REL_DIR) replace\n$(TERM_RESET)' >&2; \
   printf '\n' >&2; \
   exit 1)
endef
