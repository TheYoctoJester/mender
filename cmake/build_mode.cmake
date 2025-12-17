# See comment about CMAKE_BUILD_TYPE in the top-level `CMakeLists.txt`.

if(MSVC)
  # MSVC compiler flags - use C++20 for designated initializers support
  if ("${CMAKE_BUILD_TYPE}" MATCHES "Rel")
    add_compile_definitions(NDEBUG=1)
    add_compile_options(/std:c++20)
    add_compile_definitions(MENDER_CXX_STANDARD=20)
    set(PLATFORM_SPECIFIC_COMPILE_OPTIONS "")
  else()
    # In Debug mode use C++20 on MSVC for designated initializers
    add_compile_options(/std:c++20)
    add_compile_definitions(MENDER_CXX_STANDARD=20)
    set(PLATFORM_SPECIFIC_COMPILE_OPTIONS /std:c++20)
  endif()

  # MSVC warning flags (equivalent to GCC -Wall -Werror)
  add_compile_options(
    /W4           # High warning level
    /permissive-  # Strict conformance mode
    /Zc:__cplusplus  # Report correct __cplusplus value
    /EHsc         # Exception handling
    /utf-8        # Source and execution charset
  )

  # Disable some noisy MSVC warnings for now (can be re-enabled later)
  add_compile_options(
    /wd4100  # Unreferenced formal parameter
    /wd4244  # Conversion from 'type1' to 'type2', possible loss of data
    /wd4267  # Conversion from 'size_t' to 'type', possible loss of data
    /wd4127  # Conditional expression is constant
    /wd4702  # Unreachable code
    /wd4458  # Declaration hides class member
    /bigobj  # Increase number of sections in object file (needed for beast/template-heavy code)
  )

else()
  # GCC/Clang compiler flags (original code)
  if ("${CMAKE_BUILD_TYPE}" MATCHES "Rel")
    add_compile_definitions(NDEBUG=1)
    # The ABI is not guaranteed to be compatible between C++11 and C++17, so in release mode, let's
    # not take that risk, and compile everything under C++17 instead. We still use C++11 in debug mode
    # below.
    add_compile_options(-std=c++17)
    add_compile_definitions(MENDER_CXX_STANDARD=17)
    # No need for it in release mode, we compile everything with the same options.
    set(PLATFORM_SPECIFIC_COMPILE_OPTIONS "")
  else()
    # In Debug mode use C++11 by default, so that we catch C++11 violations.
    add_compile_options(-std=c++11)
    add_compile_definitions(MENDER_CXX_STANDARD=11)
    # Use this with target_compile_options for platform specific components that need it.
    set(PLATFORM_SPECIFIC_COMPILE_OPTIONS -std=c++17)
  endif()
endif()
