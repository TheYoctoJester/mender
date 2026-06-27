// Copyright 2026 Northern.tech AS
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

// Unit tests for http::GetRemainingTime (Retry-After parsing). Kept in a small,
// network-free target so it builds and runs on every platform, including the
// MSVC/Windows port where the parser uses std::get_time instead of strptime.

#include <common/http.hpp>

#include <chrono>
#include <string>

#include <gtest/gtest.h>

namespace http = mender::common::http;

TEST(HttpRetryAfterTest, AcceptsDeltaSeconds) {
	auto res = http::GetRemainingTime("120");
	ASSERT_TRUE(res) << res.error().String();
	EXPECT_EQ(res.value().count(), 120);
}

TEST(HttpRetryAfterTest, ParsesImfFixdateInTheFuture) {
	// Far-future HTTP-date: must parse and leave a positive remaining time.
	auto res = http::GetRemainingTime("Fri, 31 Dec 2099 23:59:59 GMT");
	ASSERT_TRUE(res) << res.error().String();
	EXPECT_GT(res.value().count(), 0);
}

TEST(HttpRetryAfterTest, ParsesImfFixdateInThePastAsZero) {
	// Valid date in the past: parses fine, remaining time clamps to zero.
	auto res = http::GetRemainingTime("Wed, 21 Oct 2015 07:28:00 GMT");
	ASSERT_TRUE(res) << res.error().String();
	EXPECT_EQ(res.value().count(), 0);
}

TEST(HttpRetryAfterTest, RejectsGarbage) {
	auto res = http::GetRemainingTime("definitely not a date");
	EXPECT_FALSE(res);
}
