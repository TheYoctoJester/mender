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

#include <common/setup.hpp>

#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>
#pragma comment(lib, "ws2_32.lib")
#endif

namespace mender {
namespace common {
namespace setup {

void GlobalSetup() {
#ifdef _WIN32
	// Initialize Winsock for network operations
	WSADATA wsaData;
	WSAStartup(MAKEWORD(2, 2), &wsaData);

	// Windows doesn't have SIGPIPE - broken pipe errors are handled
	// through return values from send/recv calls
#endif
}

} // namespace setup
} // namespace common
} // namespace mender
