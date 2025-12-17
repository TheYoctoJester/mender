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
// Note: On Windows, boost::asio::windows::stream_handle requires overlapped I/O
// which doesn't work well with regular file handles. For now, we provide stub
// implementations that return errors, as Windows uses different IPC mechanisms.

#include <common/events_io.hpp>

#include <vector>

namespace mender {
namespace common {
namespace events {
namespace io {

// Windows implementation - stub for now
// Windows async file I/O is fundamentally different from POSIX and requires
// overlapped I/O handles. For IPC on Windows, Named Pipes should be used instead.

AsyncFileDescriptorReader::AsyncFileDescriptorReader(events::EventLoop &loop, int fd) :
	pipe_(GetAsioIoContext(loop)),
	destroying_ {make_shared<bool>(false)} {
	// Note: On Windows, we'd need to use _get_osfhandle(fd) and ensure the handle
	// was opened with FILE_FLAG_OVERLAPPED for async operations
	(void)fd; // Unused in stub
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
	// On Windows, async file I/O requires FILE_FLAG_OVERLAPPED
	// This is a stub - real implementation would use CreateFile with OVERLAPPED
	(void)path;
	return error::Error(
		make_error_condition(errc::function_not_supported),
		"AsyncFileDescriptorReader::Open not implemented on Windows");
}

error::Error AsyncFileDescriptorReader::AsyncRead(
	vector<uint8_t>::iterator start,
	vector<uint8_t>::iterator end,
	mender::common::io::AsyncIoHandler handler) {
	(void)start;
	(void)end;
	(void)handler;
	return error::Error(
		make_error_condition(errc::function_not_supported),
		"AsyncFileDescriptorReader::AsyncRead not implemented on Windows");
}

void AsyncFileDescriptorReader::Cancel() {
	if (pipe_.is_open()) {
		pipe_.cancel();
	}
}

AsyncFileDescriptorWriter::AsyncFileDescriptorWriter(events::EventLoop &loop, int fd) :
	pipe_(GetAsioIoContext(loop)),
	destroying_ {make_shared<bool>(false)} {
	(void)fd; // Unused in stub
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
	(void)path;
	(void)append;
	return error::Error(
		make_error_condition(errc::function_not_supported),
		"AsyncFileDescriptorWriter::Open not implemented on Windows");
}

error::Error AsyncFileDescriptorWriter::AsyncWrite(
	vector<uint8_t>::const_iterator start,
	vector<uint8_t>::const_iterator end,
	mender::common::io::AsyncIoHandler handler) {
	(void)start;
	(void)end;
	(void)handler;
	return error::Error(
		make_error_condition(errc::function_not_supported),
		"AsyncFileDescriptorWriter::AsyncWrite not implemented on Windows");
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
