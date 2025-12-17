# Windows platform-specific CMake configuration for Mender

if(WIN32)
    message(STATUS "Configuring for Windows platform")

    # Define Windows platform macro
    add_compile_definitions(MENDER_PLATFORM_WINDOWS=1)
    add_compile_definitions(_WIN32_WINNT=0x0A00)  # Windows 10+
    add_compile_definitions(NOMINMAX)  # Prevent Windows.h min/max macros
    add_compile_definitions(WIN32_LEAN_AND_MEAN)  # Reduce Windows.h bloat

    # Disable Linux-specific features on Windows
    set(MENDER_USE_DBUS OFF CACHE BOOL "Disable D-Bus on Windows" FORCE)
    set(MENDER_USE_ASIO_LIBDBUS OFF CACHE BOOL "Disable ASIO D-Bus on Windows" FORCE)

    # Enable embedded authentication (required since D-Bus is disabled)
    set(MENDER_EMBED_MENDER_AUTH ON CACHE BOOL "Embed mender-auth into mender-update on Windows" FORCE)

    # Use Named Pipes for IPC on Windows
    add_compile_definitions(MENDER_USE_NAMED_PIPES=1)

    # Windows socket library
    link_libraries(ws2_32 wsock32)

    # Set default paths for Windows
    if(NOT DEFINED MENDER_DATA_DIR)
        set(MENDER_DATA_DIR "$ENV{ProgramData}/Mender" CACHE PATH "Mender data directory")
    endif()
    if(NOT DEFINED MENDER_CONF_DIR)
        set(MENDER_CONF_DIR "$ENV{ProgramData}/Mender/conf" CACHE PATH "Mender config directory")
    endif()

    message(STATUS "  Data directory: ${MENDER_DATA_DIR}")
    message(STATUS "  Config directory: ${MENDER_CONF_DIR}")
endif()
