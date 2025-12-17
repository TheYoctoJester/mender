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
// Uses named events for IPC (equivalent to POSIX SIGUSR1/SIGUSR2) and
// console control handlers for termination signals.

#include <csignal>
#include <thread>
#include <atomic>
#include <windows.h>

#include <mender-update/daemon/state_machine.hpp>

#include <common/error.hpp>
#include <common/log.hpp>

namespace mender {
namespace update {
namespace daemon {

namespace error = mender::common::error;
namespace log = mender::common::log;

// Named event names - must match those in cli/actions.cpp
static const char *MENDER_CHECK_UPDATE_EVENT = "Global\\MenderCheckUpdate";
static const char *MENDER_SEND_INVENTORY_EVENT = "Global\\MenderSendInventory";

// Static pointer to allow access from handlers
static StateMachine* g_state_machine = nullptr;

// Event handles for IPC
static HANDLE g_check_update_event = NULL;
static HANDLE g_send_inventory_event = NULL;
static HANDLE g_shutdown_event = NULL;

// Background thread for event monitoring
static std::thread g_event_thread;
static std::atomic<bool> g_running{false};

// Windows console control handler for graceful shutdown
static BOOL WINAPI ConsoleCtrlHandler(DWORD ctrl_type) {
    switch (ctrl_type) {
    case CTRL_C_EVENT:
    case CTRL_BREAK_EVENT:
    case CTRL_CLOSE_EVENT:
    case CTRL_SHUTDOWN_EVENT:
        log::Info("Termination signal received, shutting down gracefully");
        g_running = false;
        if (g_shutdown_event) {
            SetEvent(g_shutdown_event);
        }
        if (g_state_machine) {
            g_state_machine->GetEventLoop().Stop();
        }
        return TRUE;
    default:
        return FALSE;
    }
}

error::Error StateMachine::RegisterSignalHandlers() {
    // Store pointer for handlers
    g_state_machine = this;

    // Register Windows console control handler for termination signals
    if (!SetConsoleCtrlHandler(ConsoleCtrlHandler, TRUE)) {
        return error::Error(
            make_error_condition(errc::permission_denied),
            "Failed to register Windows console control handler");
    }

    // Create named events for IPC
    // Using manual-reset events so we can handle them properly
    g_check_update_event = CreateEventA(NULL, TRUE, FALSE, MENDER_CHECK_UPDATE_EVENT);
    if (g_check_update_event == NULL) {
        return error::Error(
            make_error_condition(errc::permission_denied),
            "Failed to create check update event: " + std::to_string(GetLastError()));
    }

    g_send_inventory_event = CreateEventA(NULL, TRUE, FALSE, MENDER_SEND_INVENTORY_EVENT);
    if (g_send_inventory_event == NULL) {
        CloseHandle(g_check_update_event);
        g_check_update_event = NULL;
        return error::Error(
            make_error_condition(errc::permission_denied),
            "Failed to create send inventory event: " + std::to_string(GetLastError()));
    }

    // Internal shutdown event (not named, just for thread coordination)
    g_shutdown_event = CreateEventA(NULL, TRUE, FALSE, NULL);
    if (g_shutdown_event == NULL) {
        CloseHandle(g_check_update_event);
        CloseHandle(g_send_inventory_event);
        g_check_update_event = NULL;
        g_send_inventory_event = NULL;
        return error::Error(
            make_error_condition(errc::permission_denied),
            "Failed to create shutdown event: " + std::to_string(GetLastError()));
    }

    // Start the background thread to wait for events
    g_running = true;
    g_event_thread = std::thread([this]() {
        HANDLE events[] = {g_check_update_event, g_send_inventory_event, g_shutdown_event};
        const int num_events = 3;

        while (g_running) {
            DWORD result = WaitForMultipleObjects(num_events, events, FALSE, INFINITE);

            if (!g_running) {
                break;
            }

            switch (result) {
            case WAIT_OBJECT_0: // Check update event
                log::Info("Check update event received, triggering deployments check");
                ResetEvent(g_check_update_event);
                this->runner_.PostEvent(StateEvent::DeploymentPollingTriggered);
                break;

            case WAIT_OBJECT_0 + 1: // Send inventory event
                log::Info("Send inventory event received, triggering inventory update");
                ResetEvent(g_send_inventory_event);
                this->runner_.PostEvent(StateEvent::InventoryPollingTriggered);
                break;

            case WAIT_OBJECT_0 + 2: // Shutdown event
                log::Debug("Shutdown event received in event wait thread");
                return;

            case WAIT_FAILED:
                log::Error("WaitForMultipleObjects failed: " + std::to_string(GetLastError()));
                return;

            default:
                break;
            }
        }
    });

    log::Info("Windows IPC events registered for check-update and send-inventory commands");
    return error::NoError;
}

} // namespace daemon
} // namespace update
} // namespace mender
