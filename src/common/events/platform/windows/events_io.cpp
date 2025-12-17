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

// Windows-specific implementation of async file descriptor I/O
// Uses Windows Named Pipes with overlapped I/O for async operations.

#include <common/events_io.hpp>

#include <vector>
#include <cassert>

#include <windows.h>
#include <io.h>

namespace mender {
namespace common {
namespace events {
namespace io {

// Windows implementation using overlapped I/O with named pipes or files
// opened with FILE_FLAG_OVERLAPPED.

AsyncFileDescriptorReader::AsyncFileDescriptorReader(events::EventLoop &loop, int fd) :
	pipe_(GetAsioIoContext(loop)),
	destroying_ {make_shared<bool>(false)} {
	// Convert C file descriptor to Windows HANDLE
	// Note: The handle must have been opened with FILE_FLAG_OVERLAPPED
	HANDLE h = reinterpret_cast<HANDLE>(_get_osfhandle(fd));
	if (h != INVALID_HANDLE_VALUE) {
		// Duplicate handle so we own it (assign() takes ownership)
		HANDLE dup_h;
		if (DuplicateHandle(
				GetCurrentProcess(),
				h,
				GetCurrentProcess(),
				&dup_h,
				0,
				FALSE,
				DUPLICATE_SAME_ACCESS)) {
			pipe_.assign(dup_h);
		}
	}
}

AsyncFileDescriptorReader::AsyncFileDescriptorReader(events::EventLoop &loop) :
	pipe_(GetAsioIoContext(loop)),
	destroying_ {make_shared<bool>(false)} {
}

AsyncFileDescriptorReader::~AsyncFileDescriptorReader() {
	*destroying_ = true;
	Cancel();
}

error::Error AsyncFileDescriptorReader::Open(const string &path) {
	// Check if this is a named pipe path (starts with \.\pipe\)
	// Named pipes must be opened with GENERIC_READ and FILE_FLAG_OVERLAPPED
	HANDLE h = CreateFileA(
		path.c_str(),
		GENERIC_READ,
		0, // No sharing
		NULL,
		OPEN_EXISTING,
		FILE_FLAG_OVERLAPPED,
		NULL);

	if (h == INVALID_HANDLE_VALUE) {
		DWORD err = GetLastError();
		return error::Error(
			make_error_condition(errc::io_error),
			"Cannot open " + path + ": error code " + std::to_string(err));
	}

	if (pipe_.is_open()) {
		pipe_.close();
	}
	pipe_.assign(h);
	return error::NoError;
}

error::Error AsyncFileDescriptorReader::AsyncRead(
	vector<uint8_t>::iterator start,
	vector<uint8_t>::iterator end,
	mender::common::io::AsyncIoHandler handler) {
	if (end < start) {
		return error::Error(
			make_error_condition(errc::invalid_argument), "AsyncRead: end cannot precede start");
	}
	if (!handler) {
		return error::Error(
			make_error_condition(errc::invalid_argument), "AsyncRead: handler cannot be nullptr");
	}

	auto destroying {destroying_};

	asio::mutable_buffer buf {&start[0], size_t(end - start)};
	pipe_.async_read_some(buf, [destroying, handler](boost::system::error_code ec, size_t n) {
		if (*destroying) {
			return;
		} else if (ec == make_error_code(asio::error::operation_aborted)) {
			handler(expected::unexpected(error::Error(
				make_error_condition(errc::operation_canceled), "AsyncRead cancelled")));
		} else if (ec == make_error_code(asio::error::eof) || ec == make_error_code(asio::error::broken_pipe)) {
			// On Windows, broken_pipe can indicate EOF for named pipes
			// n should always be zero for EOF
			handler(0);
		} else if (ec) {
			handler(expected::unexpected(
				error::Error(ec.default_error_condition(), "AsyncRead failed: " + ec.message())));
		} else {
			handler(n);
		}
	});

	return error::NoError;
}

void AsyncFileDescriptorReader::Cancel() {
	if (pipe_.is_open()) {
		pipe_.cancel();
	}
}

AsyncFileDescriptorWriter::AsyncFileDescriptorWriter(events::EventLoop &loop, int fd) :
	pipe_(GetAsioIoContext(loop)),
	destroying_ {make_shared<bool>(false)} {
	// Convert C file descriptor to Windows HANDLE
	HANDLE h = reinterpret_cast<HANDLE>(_get_osfhandle(fd));
	if (h != INVALID_HANDLE_VALUE) {
		HANDLE dup_h;
		if (DuplicateHandle(
				GetCurrentProcess(),
				h,
				GetCurrentProcess(),
				&dup_h,
				0,
				FALSE,
				DUPLICATE_SAME_ACCESS)) {
			pipe_.assign(dup_h);
		}
	}
}

AsyncFileDescriptorWriter::AsyncFileDescriptorWriter(events::EventLoop &loop) :
	pipe_(GetAsioIoContext(loop)),
	destroying_ {make_shared<bool>(false)} {
}

AsyncFileDescriptorWriter::~AsyncFileDescriptorWriter() {
	*destroying_ = true;
	Cancel();
}

error::Error AsyncFileDescriptorWriter::Open(const string &path, Append append) {
	DWORD creation = OPEN_EXISTING;
	DWORD flags = FILE_FLAG_OVERLAPPED;

	// Check if this looks like a named pipe
	bool is_pipe = (path.find("\\\\.\\pipe\\") == 0) || (path.find("//./pipe/") == 0);

	if (!is_pipe) {
		// Regular file - need different creation flags
		if (append == Append::Enabled) {
			creation = OPEN_ALWAYS;
			flags |= FILE_APPEND_DATA;
		} else {
			creation = CREATE_ALWAYS;
		}
	}

	HANDLE h = CreateFileA(
		path.c_str(),
		is_pipe ? GENERIC_WRITE : (GENERIC_WRITE | (append == Append::Enabled ? FILE_APPEND_DATA : 0)),
		0, // No sharing
		NULL,
		creation,
		flags,
		NULL);

	if (h == INVALID_HANDLE_VALUE) {
		DWORD err = GetLastError();
		return error::Error(
			make_error_condition(errc::io_error),
			"Cannot open " + path + ": error code " + std::to_string(err));
	}

	if (pipe_.is_open()) {
		pipe_.close();
	}
	pipe_.assign(h);
	return error::NoError;
}

error::Error AsyncFileDescriptorWriter::AsyncWrite(
	vector<uint8_t>::const_iterator start,
	vector<uint8_t>::const_iterator end,
	mender::common::io::AsyncIoHandler handler) {
	if (end < start) {
		return error::Error(
			make_error_condition(errc::invalid_argument), "AsyncWrite: end cannot precede start");
	}
	if (!handler) {
		return error::Error(
			make_error_condition(errc::invalid_argument), "AsyncWrite: handler cannot be nullptr");
	}

	auto destroying {destroying_};

	asio::const_buffer buf {&start[0], size_t(end - start)};
	pipe_.async_write_some(buf, [destroying, handler](boost::system::error_code ec, size_t n) {
		if (*destroying) {
			return;
		} else if (ec == make_error_code(asio::error::operation_aborted)) {
			handler(expected::unexpected(error::Error(
				make_error_condition(errc::operation_canceled), "AsyncWrite cancelled")));
		} else if (ec == make_error_code(asio::error::broken_pipe)) {
			handler(expected::unexpected(
				error::Error(make_error_condition(errc::broken_pipe), "AsyncWrite failed")));
		} else if (ec) {
			handler(expected::unexpected(
				error::Error(ec.default_error_condition(), "AsyncWrite failed: " + ec.message())));
		} else {
			handler(n);
		}
	});

	return error::NoError;
}

void AsyncFileDescriptorWriter::Cancel() {
	if (pipe_.is_open()) {
		pipe_.cancel();
	}
}

} // namespace io
} // namespace events
} // namespace common
} // namespace mender
