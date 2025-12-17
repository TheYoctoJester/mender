project(mender-common)

include(CheckCXXSourceCompiles)

# Platform detection
if(WIN32)
  set(PLATFORM windows_x64)
  message(STATUS "Platform detected: Windows x64")
else()
  set(PLATFORM linux_x86)
  message(STATUS "Platform detected: Linux x86")
endif()

set(MENDER_BUFSIZE 16384 CACHE STRING "Size of most internal block buffers.")
option(MENDER_LOG_BOOST "Use Boost as the underlying logging library provider" ON)
option(MENDER_TAR_LIBARCHIVE "Use libarchive as the underlying tar library provider" ON)
option(MENDER_SHA_OPENSSL "Use OpenSSL as the underlying shasum provider" ON)
option(MENDER_CRYPTO_OPENSSL "Use OpenSSL as the underlying cryptography provider" ON)

option(MENDER_ARTIFACT_GZIP_COMPRESSION "Enable GZIP compression support" ON)
option(MENDER_ARTIFACT_LZMA_COMPRESSION "Enable LZMA compression support" ON)
option(MENDER_ARTIFACT_ZSTD_COMPRESSION "Enable Zstd compression support" ON)
option(MENDER_USE_YAML_CPP "Use Yaml CPP as the Yaml library provider" ON)

if (${PLATFORM} STREQUAL linux_x86)
  set(POSIX_DEFAULT ON)
  set(WINDOWS_DEFAULT OFF)
elseif(${PLATFORM} STREQUAL windows_x64)
  set(POSIX_DEFAULT OFF)
  set(WINDOWS_DEFAULT ON)
else()
  set(POSIX_DEFAULT OFF)
  set(WINDOWS_DEFAULT OFF)
endif()

# D-Bus is Linux-only; on Windows we use Named Pipes
if(WIN32)
  option(MENDER_USE_DBUS "Enable DBus for IPC" OFF)
  option(MENDER_USE_ASIO_LIBDBUS "Use Boost ASIO DBus backend" OFF)
  option(MENDER_USE_NAMED_PIPES "Use Windows Named Pipes for IPC" ON)
else()
  option(MENDER_USE_DBUS "Enable DBus for IPC" ${POSIX_DEFAULT})
  option(MENDER_USE_ASIO_LIBDBUS "Use Boost ASIO DBus backend" ${POSIX_DEFAULT})
  option(MENDER_USE_NAMED_PIPES "Use Windows Named Pipes for IPC" OFF)
endif()

option(MENDER_USE_BOOST_ASIO "" ON)
option(MENDER_USE_BOOST_BEAST "" ON)
option(MENDER_USE_LMDB "" ON)
option(MENDER_USE_NLOHMANN_JSON "" ON)
option(MENDER_USE_TINY_PROC_LIB "" ON)

configure_file(config.h.in config.h)

if(${MENDER_USE_TINY_PROC_LIB})
  add_subdirectory(vendor/tiny-process-library)
endif()

include(cmake/boost.cmake)

add_library(common_cpp INTERFACE)
if(MSVC)
  # MSVC options set globally in build_mode.cmake
else()
  target_compile_options(common_cpp INTERFACE
    -Werror -Wall -Wsuggest-override -Wconversion -Wno-sign-conversion
    -Wpacked -Wpointer-arith -Wredundant-decls -Wold-style-cast
  )
endif()
target_include_directories(common_cpp SYSTEM INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/vendor/expected/include)
target_include_directories(common_cpp SYSTEM INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/vendor/optional-lite/include)

add_library(common STATIC common.cpp)
target_include_directories(common PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/..)
target_include_directories(common PUBLIC ${CMAKE_CURRENT_BINARY_DIR}/..)
target_link_libraries(common PUBLIC common_cpp)

add_library(common_device_tier STATIC device_tier.cpp)
target_link_libraries(common_device_tier PUBLIC common)

# Platform-specific setup
if(WIN32)
  add_library(common_setup STATIC setup/platform/windows/setup.cpp)
else()
  add_library(common_setup STATIC setup/platform/posix/setup.cpp)
endif()
target_link_libraries(common_setup PUBLIC common)

add_library(common_error STATIC error.cpp error/platform/c++11/error.cpp)
target_link_libraries(common_error PUBLIC common)

# Platform-specific I/O
add_library(common_io STATIC io/io.cpp io/platform/c++17/io.cpp)
if(WIN32)
  target_sources(common_io PRIVATE io/platform/windows/io.cpp)
else()
  target_sources(common_io PRIVATE io/platform/posix/io.cpp)
endif()
target_compile_options(common_io PRIVATE ${PLATFORM_SPECIFIC_COMPILE_OPTIONS})
target_link_libraries(common_io PUBLIC common)

# Platform-specific path operations
add_library(common_path STATIC path/path.cpp path/platform/c++17/path.cpp)
if(WIN32)
  target_sources(common_path PRIVATE path/platform/windows/path.cpp)
else()
  target_sources(common_path PRIVATE path/platform/posix/path.cpp)
endif()
target_compile_options(common_path PRIVATE ${PLATFORM_SPECIFIC_COMPILE_OPTIONS})
target_link_libraries(common_path PUBLIC common_log)

check_cxx_source_compiles("#include <filesystem>
  int main() { std::filesystem::path p; return 0; }" STD_FILESYSTEM_AVAILABLE)
if(NOT "${STD_FILESYSTEM_AVAILABLE}" STREQUAL 1)
  if(NOT "${STD_FILESYSTEM_LIB_NAME}" STREQUAL "")
    target_link_libraries(common_path PUBLIC ${STD_FILESYSTEM_LIB_NAME})
  endif()
endif()

add_library(common_json STATIC json/json.cpp)
target_compile_options(common_json PRIVATE ${PLATFORM_SPECIFIC_COMPILE_OPTIONS})
if(MENDER_USE_NLOHMANN_JSON)
  target_sources(common_json PRIVATE json/platform/nlohmann/nlohmann_json.cpp)
  target_include_directories(common_json PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/vendor/json/include/)
  target_link_libraries(common_json PUBLIC common common_io common_error)
endif()

add_library(common_key_value_database STATIC key_value_database.cpp)
target_compile_options(common_key_value_database PRIVATE ${PLATFORM_SPECIFIC_COMPILE_OPTIONS})
if(MENDER_USE_LMDB)
  target_sources(common_key_value_database PRIVATE key_value_database/platform/lmdb/lmdb.cpp)
  target_include_directories(common_key_value_database SYSTEM PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/vendor/lmdbxx/include)
  if(WIN32)
    find_package(unofficial-lmdb CONFIG REQUIRED)
    target_link_libraries(common_key_value_database PUBLIC unofficial::lmdb::lmdb common common_log)
  else()
    target_link_libraries(common_key_value_database PUBLIC lmdb common common_log)
  endif()
endif()

add_library(common_events STATIC events/events_io.cpp events/platform/boost/events.cpp)
if(WIN32)
  target_sources(common_events PRIVATE events/platform/windows/events_io.cpp)
else()
  target_sources(common_events PRIVATE events/platform/boost/events_io.cpp)
endif()
target_compile_options(common_events PRIVATE ${PLATFORM_SPECIFIC_COMPILE_OPTIONS})
target_link_libraries(common_events PUBLIC common_error common_log Boost::asio)

find_package(OpenSSL REQUIRED)

if ("${OPENSSL_VERSION}" VERSION_LESS 3.0.0)
  set(MENDER_CRYPTO_OPENSSL_LEGACY 1)
else()
  set(MENDER_CRYPTO_OPENSSL_LEGACY 0)
endif()

configure_file(crypto/platform/openssl/openssl_config.h.in crypto/platform/openssl/openssl_config.h)

add_library(common_http STATIC http/http.cpp http/platform/beast/http.cpp)
target_compile_options(common_http PRIVATE ${PLATFORM_SPECIFIC_COMPILE_OPTIONS})
target_link_libraries(common_http PUBLIC Boost::beast common common_crypto common_events common_error common_log OpenSSL::SSL OpenSSL::Crypto)
if(WIN32)
  target_link_libraries(common_http PUBLIC ws2_32 crypt32)
endif()

add_library(common_log STATIC log/platform/boost/boost_log.cpp)
target_compile_options(common_log PRIVATE ${PLATFORM_SPECIFIC_COMPILE_OPTIONS})
target_link_libraries(common_log PUBLIC common_error Boost::log)

add_library(common_processes STATIC processes/processes.cpp)
target_compile_options(common_processes PRIVATE ${PLATFORM_SPECIFIC_COMPILE_OPTIONS})
target_link_libraries(common_processes PUBLIC common_error common_events common_log common)
if(MENDER_USE_TINY_PROC_LIB)
  target_sources(common_processes PRIVATE processes/platform/tiny_process_library/tiny_process_library.cpp)
  target_include_directories(common_processes PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/vendor/tiny-process-library)
  target_link_libraries(common_processes PUBLIC tiny-process-library::tiny-process-library common_path)
endif()

add_library(common_key_value_parser STATIC key_value_parser/key_value_parser.cpp)
target_link_libraries(common_key_value_parser PUBLIC common_error)

add_library(common_crypto STATIC crypto/crypto.cpp crypto/platform/openssl/crypto.cpp)
if(MSVC)
  target_compile_options(common_crypto PRIVATE ${PLATFORM_SPECIFIC_COMPILE_OPTIONS} /wd4996)
else()
  target_compile_options(common_crypto PRIVATE ${PLATFORM_SPECIFIC_COMPILE_OPTIONS} -Wno-deprecated-declarations)
endif()
target_link_libraries(common_crypto PUBLIC common_log common_io common_path sha OpenSSL::SSL OpenSSL::Crypto)

if(MENDER_USE_DBUS)
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(dbus REQUIRED dbus-1)
  add_library(common_dbus STATIC platform/dbus/dbus.cpp platform/dbus/asio_libdbus/dbus.cpp)
  target_link_libraries(common_dbus PUBLIC common_log common_error common_events ${dbus_LDFLAGS})
  target_compile_options(common_dbus PUBLIC ${dbus_CFLAGS})
  if(MENDER_USE_ASIO_LIBDBUS)
    target_link_libraries(common_dbus PUBLIC OpenSSL::SSL OpenSSL::Crypto)
  endif()
endif()

add_library(common_state_machine INTERFACE)

if(MENDER_USE_YAML_CPP)
  add_subdirectory(vendor/yaml-cpp)
  add_library(common_yaml STATIC yaml/yaml.cpp yaml/platform/yaml-cpp/yaml.cpp)
  target_link_libraries(common_yaml PUBLIC common common_io common_error yaml-cpp::yaml-cpp)
  target_compile_options(common_yaml PRIVATE ${PLATFORM_SPECIFIC_COMPILE_OPTIONS})
endif()

add_library(mender_http_resumer STATIC http/http_resumer.cpp)
target_link_libraries(mender_http_resumer PUBLIC common_http)
