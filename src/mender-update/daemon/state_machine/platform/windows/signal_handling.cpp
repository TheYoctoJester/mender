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

// Windows-specific signal handling implementation
// Windows doesn't have POSIX signals like SIGUSR1/SIGUSR2, so we implement
// a simplified version with console control handlers for termination signals.

#include <csignal>
#include <windows.h>

#include <mender-update/daemon/state_machine.hpp>

#include <common/error.hpp>
#include <common/log.hpp>

namespace mender {
namespace update {
namespace daemon {

namespace error = mender::common::error;
namespace log = mender::common::log;

// Static pointer to allow access from the console control handler
static StateMachine* g_state_machine = nullptr;

// Windows console control handler for graceful shutdown
static BOOL WINAPI ConsoleCtrlHandler(DWORD ctrl_type) {
	switch (ctrl_type) {
	case CTRL_C_EVENT:
	case CTRL_BREAK_EVENT:
	case CTRL_CLOSE_EVENT:
	case CTRL_SHUTDOWN_EVENT:
		log::Info("Termination signal received, shutting down gracefully");
		if (g_state_machine) {
			g_state_machine->GetEventLoop().Stop();
		}
		return TRUE;
	default:
		return FALSE;
	}
}

error::Error StateMachine::RegisterSignalHandlers() {
	// Store pointer for console control handler
	g_state_machine = this;

	// Register Windows console control handler for termination signals
	if (!SetConsoleCtrlHandler(ConsoleCtrlHandler, TRUE)) {
		return error::Error(
			make_error_condition(errc::permission_denied),
			"Failed to register Windows console control handler");
	}

	// Note: Windows doesn't have SIGUSR1/SIGUSR2 equivalents
	// These could be implemented using named events, named pipes, or other IPC mechanisms
	// For now, deployment and inventory polling will rely on the regular polling intervals

	return error::NoError;
}

} // namespace daemon
} // namespace update
} // namespace mender
