// Copyright 2024 Northern.tech AS
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

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#endif

#include <filesystem>
#include <string>

#include <common/error.hpp>
#include <common/log.hpp>

namespace mender {
namespace common {
namespace path {

using namespace std;
namespace fs = std::filesystem;
namespace log = mender::common::log;

// Windows doesn't use POSIX permission bits - we simplify to basic read/write
expected::ExpectedInt FileCreate(const string &path, vector<Perms> perms) {
#ifdef _WIN32
	// Determine access mode from permissions
	int mode = _S_IREAD;
	for (const auto &perm : perms) {
		if (perm == Perms::Owner_write || perm == Perms::Group_write || perm == Perms::Others_write) {
			mode |= _S_IWRITE;
			break;
		}
	}

	// Use _open with CREATE_NEW equivalent flags
	int fd = _open(path.c_str(), _O_CREAT | _O_EXCL | _O_WRONLY | _O_TRUNC | _O_BINARY, mode);
	if (fd != -1) {
		return fd;
	}

	int err = errno;
	return expected::unexpected(error::Error(
		std::generic_category().default_error_condition(err),
		"Failed to create file '" + path + "': " + strerror(err)));
#else
	return expected::unexpected(error::Error(
		make_error_condition(errc::not_supported),
		"Windows path implementation called on non-Windows platform"));
#endif
}

error::Error DataSyncRecursively(const string &dir) {
#ifdef _WIN32
	error_code ec;
	for (auto &entry : fs::recursive_directory_iterator(fs::path(dir), ec)) {
		if (!entry.is_directory() && !entry.is_regular_file()) {
			continue;
		}

		// FlushFileBuffers requires GENERIC_WRITE access to flush the file buffers
		HANDLE hFile = CreateFileA(
			entry.path().string().c_str(),
			GENERIC_WRITE,
			FILE_SHARE_READ | FILE_SHARE_WRITE,
			NULL,
			OPEN_EXISTING,
			entry.is_directory() ? FILE_FLAG_BACKUP_SEMANTICS : FILE_ATTRIBUTE_NORMAL,
			NULL);

		if (hFile == INVALID_HANDLE_VALUE) {
			// Skip files we can't open for write (e.g., read-only files)
			// This is best-effort synchronization
			log::Debug("DataSyncRecursively: Skipping file (cannot open for write): " + entry.path().string());
			continue;
		}

		BOOL result = FlushFileBuffers(hFile);
		DWORD err = GetLastError();
		CloseHandle(hFile);

		if (!result && err != ERROR_SUCCESS) {
			// Skip files we can't flush - best-effort sync
			log::Debug("DataSyncRecursively: Skipping file (flush failed): " + entry.path().string());
			continue;
		}
	}
	if (ec) {
		return error::Error(ec.default_error_condition(), "DataSyncRecursively");
	}

	return error::NoError;
#else
	return error::Error(
		make_error_condition(errc::not_supported),
		"Windows path implementation called on non-Windows platform");
#endif
}

} // namespace path
} // namespace common
} // namespace mender
