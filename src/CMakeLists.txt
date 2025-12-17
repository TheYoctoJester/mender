# Get version from git - cross-platform approach
find_package(Git QUIET)
if(GIT_FOUND)
  # Try to get exact tag first
  execute_process(
    COMMAND ${GIT_EXECUTABLE} describe --tags --dirty --exact-match
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    OUTPUT_VARIABLE MENDER_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
    RESULT_VARIABLE GIT_TAG_RESULT
  )
  # If no tag, fall back to short commit hash
  if(NOT GIT_TAG_RESULT EQUAL 0)
    execute_process(
      COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
      WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
      OUTPUT_VARIABLE MENDER_VERSION
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_VARIABLE GIT_CMD_ERROR
      RESULT_VARIABLE GIT_HASH_RESULT
    )
    if(NOT GIT_HASH_RESULT EQUAL 0)
      message(WARNING "Git command failed: ${GIT_CMD_ERROR}")
      set(MENDER_VERSION "unknown")
    endif()
  endif()
else()
  message(WARNING "Git not found, using 'unknown' as version")
  set(MENDER_VERSION "unknown")
endif()

message(STATUS "Mender version: ${MENDER_VERSION}")

configure_file(mender-version.h.in mender-version.h)

set(MENDER_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(MENDER_BINARY_SRC_DIR ${CMAKE_CURRENT_BINARY_DIR})

add_subdirectory(common)
add_subdirectory(api)
add_subdirectory(client_shared)
add_subdirectory(mender-update)
add_subdirectory(mender-auth)
add_subdirectory(artifact)
