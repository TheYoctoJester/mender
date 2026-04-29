// Copyright 2023 Northern.tech AS
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

#include <common/common.hpp>

#include <system_error>

#include <gtest/gtest.h>

using namespace std;

namespace common = mender::common;

TEST(CommonTests, StringToLongLongParsesValidNumber) {
  auto value = common::StringToLongLong("12345");
  ASSERT_TRUE(value);
  EXPECT_EQ(value.value(), 12345);
}

TEST(CommonTests, StringToLongLongRejectsTrailingCharacters) {
  auto value = common::StringToLongLong("123abc");
  ASSERT_FALSE(value);
  EXPECT_EQ(value.error().code, make_error_condition(errc::invalid_argument));
  EXPECT_EQ(value.error().message, "123abc had trailing non-numeric data");
}
