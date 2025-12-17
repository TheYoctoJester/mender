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

#include <mender-update/update_module/v3/update_module.hpp>

#include <cerrno>
#include <fstream>

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <atomic>
#define open _open
#define close _close
#define O_RDONLY _O_RDONLY
#define O_NONBLOCK 0  // Windows doesn't have O_NONBLOCK for files
#else
#include <unistd.h>
#endif

#include <filesystem>

#include <client_shared/conf.hpp>
#include <common/events_io.hpp>
#include <common/io.hpp>
#include <common/log.hpp>
#include <common/path.hpp>
#include <mender-update/context.hpp>

namespace mender {
namespace update {
namespace update_module {
namespace v3 {

using namespace std;

namespace error = mender::common::error;
namespace events = mender::common::events;
namespace expected = mender::common::expected;
namespace conf = mender::client_shared::conf;
namespace context = mender::update::context;
namespace io = mender::common::io;
namespace log = mender::common::log;
namespace path = mender::common::path;

namespace fs = std::filesystem;

#ifdef _WIN32
// Global counter for unique pipe names within a process
static std::atomic<int> g_pipe_counter{0};

// Helper to generate unique Windows named pipe paths
static string GenerateWindowsPipePath(const string &base_name) {
	int counter = g_pipe_counter.fetch_add(1);
	return "\\\\.\\pipe\\mender-" + base_name + "-" + std::to_string(GetCurrentProcessId()) + "-" + std::to_string(counter);
}
#endif

error::Error CreateDataFile(
	const fs::path &file_tree_path, const string &file_name, const string &data) {
	string fpath = (file_tree_path / file_name).string();
	auto ex_os = io::OpenOfstream(fpath);
	if (!ex_os) {
		return ex_os.error();
	}
	ofstream &os = ex_os.value();
	if (data != "") {
		auto err = io::WriteStringIntoOfstream(os, data);
		return err;
	}
	return error::NoError;
}

error::Error UpdateModule::PrepareFileTreeDeviceParts(const string &path) {
	// make sure all the required data can be gathered first before creating
	// directories and files
	auto ex_provides = ctx_.LoadProvides();
	if (!ex_provides) {
		return ex_provides.error();
	}

	auto ex_device_type = ctx_.GetDeviceType();
	if (!ex_device_type) {
		return ex_device_type.error();
	}

	const fs::path file_tree_path {path};

	const fs::path tmp_subdir_path = file_tree_path / "tmp";
	auto err = path::CreateDirectories(tmp_subdir_path.string());
	if (err != error::NoError) {
		return err;
	}

	auto provides = ex_provides.value();
	auto write_provides_into_file = [&](const string &key) {
		return CreateDataFile(
			file_tree_path,
			"current_" + key,
			(provides.count(key) != 0) ? provides[key] + "\n" : "");
	};

	err = CreateDataFile(file_tree_path, "version", "3\n");
	if (err != error::NoError) {
		return err;
	}

	err = write_provides_into_file("artifact_name");
	if (err != error::NoError) {
		return err;
	}
	err = write_provides_into_file("artifact_group");
	if (err != error::NoError) {
		return err;
	}

	auto device_type = ex_device_type.value();
	err = CreateDataFile(file_tree_path, "current_device_type", device_type + "\n");
	if (err != error::NoError) {
		return err;
	}

	return error::NoError;
}

error::Error UpdateModule::CleanAndPrepareFileTree(
	const string &path, artifact::PayloadHeaderView &payload_meta_data) {
	const fs::path file_tree_path {path};

	std::error_code ec;
	fs::remove_all(file_tree_path, ec);
	if (ec) {
		return error::Error(
			ec.default_error_condition(), "Could not clean File Tree for Update Module");
	}

	auto err = PrepareFileTreeDeviceParts(path);
	if (err != error::NoError) {
		return err;
	}

	//
	// Header
	//

	const fs::path header_subdir_path = file_tree_path / "header";
	err = path::CreateDirectories(header_subdir_path.string());
	if (err != error::NoError) {
		return err;
	}

	err = CreateDataFile(
		header_subdir_path, "artifact_group", payload_meta_data.header.artifact_group);
	if (err != error::NoError) {
		return err;
	}

	err =
		CreateDataFile(header_subdir_path, "artifact_name", payload_meta_data.header.artifact_name);
	if (err != error::NoError) {
		return err;
	}

	err = CreateDataFile(header_subdir_path, "payload_type", payload_meta_data.header.payload_type);
	if (err != error::NoError) {
		return err;
	}

	err = CreateDataFile(
		header_subdir_path, "header-info", payload_meta_data.header.header_info.verbatim.Dump());
	if (err != error::NoError) {
		return err;
	}

	err = CreateDataFile(
		header_subdir_path, "type-info", payload_meta_data.header.type_info.verbatim.Dump());
	if (err != error::NoError) {
		return err;
	}

	err =
		CreateDataFile(header_subdir_path, "meta-data", payload_meta_data.header.meta_data.Dump());
	if (err != error::NoError) {
		return err;
	}

	// Make sure all changes are permanent, even across spontaneous reboots. We don't want to
	// have half a tree when trying to recover from that.
	return path::DataSyncRecursively(path);
}

error::Error UpdateModule::EnsureRootfsImageFileTree(const string &path) {
	// Historical note: Versions of the client prior to 4.0 had the rootfs-image module built
	// in. Because of this it has no Update Module File Tree. So if we are upgrading, we might
	// hit an on-going upgrade without a File Tree. It's too late to create a complete one with
	// all the artifact content by the time we get here, but at least we can create one which
	// has the current Provides information, as well as a folder for the Update Module to run
	// in.
	ifstream payload_type(path::Join(path, "header", "payload_type"));
	if (payload_type.good()) {
		string type;
		payload_type >> type;
		if (payload_type.good() && type == "rootfs-image") {
			// If we have a File Tree with the rootfs-image type, we assume we are
			// fine. This is actually not completely safe in an upgrade situation,
			// because the old <4.0 client will not have cleaned the tree, and it could
			// be old. However, this will *only* happen in an upgrade situation from
			// <4.0 to >=4.0, and I can't think of a way it could be exploited. Also,
			// the rootfs-image module does not use any of the information ATM.
			return error::NoError;
		}
	}

	return PrepareFileTreeDeviceParts(path);
}

error::Error UpdateModule::DeleteFileTree(const string &path) {
	try {
		fs::remove_all(fs::path {path});
	} catch (const fs::filesystem_error &e) {
		return error::Error(
			e.code().default_error_condition(),
			"Failed to recursively remove directory '" + path + "': " + e.what());
	}

	return error::NoError;
}

expected::ExpectedStringVector DiscoverUpdateModules(const conf::MenderConfig &config) {
	vector<string> ret {};
	fs::path file_tree_path = fs::path(config.paths.GetDataStore()) / "modules/v3";

	try {
		for (auto entry : fs::directory_iterator(file_tree_path)) {
			const fs::path file_path = entry.path();
			const string file_path_str = file_path.string();
			if (!fs::is_regular_file(file_path)) {
				log::Warning("'" + file_path_str + "' is not a regular file");
				continue;
			}

			const fs::perms perms = entry.status().permissions();
			if ((perms & (fs::perms::owner_exec | fs::perms::group_exec | fs::perms::others_exec))
				== fs::perms::none) {
				log::Warning("'" + file_path_str + "' is not executable");
				continue;
			}

			ret.push_back(file_path_str);
		}
	} catch (const fs::filesystem_error &e) {
		auto code = e.code();
		if (code.value() == ENOENT) {
			// directory not found is not an error, just return an empty vector
			return ret;
		}
		// everything (?) else is an error
		return expected::unexpected(error::Error(
			code.default_error_condition(),
			"Failed to discover update modules in '" + file_tree_path.string() + "': " + e.what()));
	}

	return ret;
}

error::Error UpdateModule::PrepareStreamNextPipe() {
#ifdef _WIN32
	// On Windows, use a named pipe instead of a POSIX FIFO.
	download_->stream_next_path_ = GenerateWindowsPipePath("stream-next");
	return error::NoError;
#else
	download_->stream_next_path_ = path::Join(update_module_workdir_, "stream-next");

	if (::mkfifo(download_->stream_next_path_.c_str(), 0600) != 0) {
		int err = errno;
		return error::Error(
			generic_category().default_error_condition(err),
			"Unable to create `stream-next` at " + download_->stream_next_path_);
	}
	return error::NoError;
#endif
}

error::Error UpdateModule::OpenStreamNextPipe(ExpectedWriterHandler open_handler) {
	auto opener = make_shared<AsyncFifoOpener>(download_->event_loop_);
	download_->stream_next_opener_ = opener;
	return opener->AsyncOpen(download_->stream_next_path_, open_handler);
}

error::Error UpdateModule::PrepareAndOpenStreamPipe(
	const string &path, ExpectedWriterHandler open_handler) {
#ifdef _WIN32
	// On Windows, generate a Windows named pipe path from the POSIX-style path.
	fs::path fs_path(path);
	string pipe_name = fs_path.filename().string();
	string pipe_path = GenerateWindowsPipePath(pipe_name);

	auto opener = make_shared<AsyncFifoOpener>(download_->event_loop_);
	download_->current_stream_opener_ = opener;
	return opener->AsyncOpen(pipe_path, open_handler);
#else
	auto fs_path = fs::path(path);
	std::error_code ec;
	if (!fs::create_directories(fs_path.parent_path(), ec) && ec) {
		return error::Error(
			ec.default_error_condition(),
			"Could not create stream directory at " + fs_path.parent_path().string());
	}

	if (::mkfifo(path.c_str(), 0600) != 0) {
		int err = errno;
		return error::Error(
			generic_category().default_error_condition(err),
			"Could not create stream FIFO at " + path);
	}

	auto opener = make_shared<AsyncFifoOpener>(download_->event_loop_);
	download_->current_stream_opener_ = opener;
	return opener->AsyncOpen(path, open_handler);
#endif
}

error::Error UpdateModule::PrepareDownloadDirectory(const string &path) {
	auto fs_path = fs::path(path);
	std::error_code ec;
	if (!fs::create_directories(fs_path, ec) && ec) {
		return error::Error(
			ec.default_error_condition(), "Could not create `files` directory at " + path);
	}

	return error::NoError;
}

error::Error UpdateModule::DeleteStreamsFiles() {
#ifdef _WIN32
	// On Windows, named pipes are automatically cleaned up when closed.
	download_->stream_next_path_.clear();
#else
	try {
		fs::path p {download_->stream_next_path_};
		fs::remove_all(p);

		p = fs::path(update_module_workdir_) / "streams";
		fs::remove_all(p);
	} catch (fs::filesystem_error &e) {
		return error::Error(
			e.code().default_error_condition(), "Could not remove " + download_->stream_next_path_);
	}
#endif

	return error::NoError;
}

AsyncFifoOpener::AsyncFifoOpener(events::EventLoop &loop) :
	event_loop_ {loop},
	cancelled_ {make_shared<bool>(true)},
	destroying_ {make_shared<bool>(false)} {
}

AsyncFifoOpener::~AsyncFifoOpener() {
	*destroying_ = true;
	Cancel();
}

error::Error AsyncFifoOpener::AsyncOpen(const string &path, ExpectedWriterHandler handler) {
	// We want to open the pipe to check if a process is going to read from it. But we cannot do
	// this in a blocking fashion, because we are also waiting for the process to terminate,
	// which happens for Update Modules that want the client to download the files for them. So
	// we need this AsyncFifoOpener class, which does the work in a thread.

	if (!*cancelled_) {
		return error::Error(
			make_error_condition(errc::operation_in_progress), "Already running AsyncFifoOpener");
	}

	*cancelled_ = false;
	path_ = path;

#ifdef _WIN32
	// On Windows, create a named pipe server and wait for a client to connect.
	thread_ = thread([this, handler]() {
		HANDLE hPipe = CreateNamedPipeA(
			path_.c_str(),
			PIPE_ACCESS_OUTBOUND | FILE_FLAG_OVERLAPPED,
			PIPE_TYPE_BYTE | PIPE_WAIT,
			1, 65536, 65536, 0, NULL);

		if (hPipe == INVALID_HANDLE_VALUE) {
			DWORD err = GetLastError();
			auto &cancelled = cancelled_;
			auto &destroying = destroying_;
			event_loop_.Post([handler, err, cancelled, destroying]() {
				if (*destroying || *cancelled) return;
				handler(expected::unexpected(error::Error(
					make_error_condition(errc::io_error),
					"CreateNamedPipe failed: error code " + std::to_string(err))));
			});
			return;
		}

		BOOL connected = ConnectNamedPipe(hPipe, NULL);
		DWORD connectErr = GetLastError();
		if (!connected && connectErr != ERROR_PIPE_CONNECTED) {
			CloseHandle(hPipe);
			auto &cancelled = cancelled_;
			auto &destroying = destroying_;
			event_loop_.Post([handler, connectErr, cancelled, destroying]() {
				if (*destroying || *cancelled) return;
				handler(expected::unexpected(error::Error(
					make_error_condition(errc::io_error),
					"ConnectNamedPipe failed: error code " + std::to_string(connectErr))));
			});
			return;
		}

		int fd = _open_osfhandle(reinterpret_cast<intptr_t>(hPipe), 0);
		if (fd == -1) {
			CloseHandle(hPipe);
			auto &cancelled = cancelled_;
			auto &destroying = destroying_;
			event_loop_.Post([handler, cancelled, destroying]() {
				if (*destroying || *cancelled) return;
				handler(expected::unexpected(error::Error(
					make_error_condition(errc::io_error), "_open_osfhandle failed")));
			});
			return;
		}

		auto writer = make_shared<events::io::AsyncFileDescriptorWriter>(event_loop_, fd);
		io::ExpectedAsyncWriterPtr exp_writer = writer;

		auto &cancelled = cancelled_;
		auto &destroying = destroying_;
		event_loop_.Post([handler, exp_writer, cancelled, destroying]() {
			if (*destroying) return;
			if (*cancelled) {
				handler(expected::unexpected(error::Error(
					make_error_condition(errc::operation_canceled), "AsyncFifoOpener cancelled")));
				return;
			}
			handler(exp_writer);
		});
	});
#else
	thread_ = thread([this, handler]() {
		auto writer = make_shared<events::io::AsyncFileDescriptorWriter>(event_loop_);
		auto err = writer->Open(path_);

		io::ExpectedAsyncWriterPtr exp_writer;
		if (err != error::NoError) {
			exp_writer = expected::unexpected(err);
		} else {
			exp_writer = writer;
		}

		auto &cancelled = cancelled_;
		auto &destroying = destroying_;
		event_loop_.Post([handler, exp_writer, cancelled, destroying]() {
			if (*destroying) return;
			if (*cancelled) {
				handler(expected::unexpected(error::Error(
					make_error_condition(errc::operation_canceled), "AsyncFifoOpener cancelled")));
				return;
			}
			handler(exp_writer);
		});
	});
#endif

	return error::NoError;
}

void AsyncFifoOpener::Cancel() {
	if (*cancelled_) {
		return;
	}

	*cancelled_ = true;

#ifdef _WIN32
	// On Windows, connect to the pipe as a client to unblock ConnectNamedPipe.
	HANDLE hClient = CreateFileA(path_.c_str(), GENERIC_READ, 0, NULL, OPEN_EXISTING, 0, NULL);
	thread_.join();
	if (hClient != INVALID_HANDLE_VALUE) {
		CloseHandle(hClient);
	}
#else
	// Open the other end of the pipe to jerk the first end loose.
	int fd = ::open(path_.c_str(), O_RDONLY | O_NONBLOCK);
	if (fd < 0) {
		int errnum = errno;
		log::Error(string("Cancel::open() returned error: ") + strerror(errnum));
	}
	thread_.join();
	::close(fd);
#endif
}

} // namespace v3
} // namespace update_module
} // namespace update
} // namespace mender
