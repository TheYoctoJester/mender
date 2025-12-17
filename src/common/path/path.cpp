// Copyright 2025 Northern.tech AS
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

#include <common/path.hpp>

#include <filesystem>
#include <string>
#include <unordered_set>

#include <common/error.hpp>

namespace mender {
namespace common {
namespace path {

using namespace std;

expected::ExpectedBool IsWithinOrEqual(const string &check_path, const string &target_dir) {
	namespace fs = std::filesystem;

	auto exp_canonical_check_path = WeaklyCanonical(check_path);
	if (!exp_canonical_check_path.has_value()) {
		return expected::unexpected(exp_canonical_check_path.error().WithContext(
			"Error creating canonical path, path to check: '" + check_path));
	}

	auto exp_canonical_target_dir = WeaklyCanonical(target_dir);
	if (!exp_canonical_target_dir.has_value()) {
		return expected::unexpected(exp_canonical_target_dir.error().WithContext(
			"Error creating canonical path, target directory: '" + target_dir));
	}

	// Use std::filesystem for proper cross-platform path comparison
	fs::path canonical_check = exp_canonical_check_path.value();
	fs::path canonical_target = exp_canonical_target_dir.value();

	// Check if check_path starts with target_dir by comparing path components
	// This properly handles both Windows backslashes and Unix forward slashes
	auto check_it = canonical_check.begin();
	auto target_it = canonical_target.begin();

	while (target_it != canonical_target.end()) {
		if (check_it == canonical_check.end()) {
			// check_path is shorter than target_dir, so cannot be within
			return false;
		}
		if (*check_it != *target_it) {
			// Paths diverge, check_path is not within target_dir
			return false;
		}
		++check_it;
		++target_it;
	}
	// All components of target_dir matched at the start of check_path
	return true;
}

} // namespace path
} // namespace common
} // namespace mender
