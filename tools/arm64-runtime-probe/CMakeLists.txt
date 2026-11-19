cmake_minimum_required(VERSION 3.24)
project(GT4PublicARM64RuntimeProbe LANGUAGES CXX)

# This diagnostic never builds or packages game data. It is not the GT4 Android build.
if(NOT ANDROID)
  message(FATAL_ERROR "This smoke test requires the Android NDK toolchain.")
endif()
if(NOT ANDROID_ABI STREQUAL "arm64-v8a")
  message(FATAL_ERROR "This smoke test is exclusively for arm64-v8a.")
endif()
if(NOT DEFINED GT4_PUBLIC_DONOR OR NOT EXISTS "${GT4_PUBLIC_DONOR}/runtime/include/ps2/generated.hpp")
  message(FATAL_ERROR "GT4_PUBLIC_DONOR must reference the pinned public ps2-web-recomp checkout.")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Use the upstream public donor unchanged. Neither its generated game code nor
# private GT4 runtime capsules are present in this diagnostic.
set(PS2_GENERATED "" CACHE PATH "No guest code for public smoke probe" FORCE)
add_subdirectory("${GT4_PUBLIC_DONOR}" "${CMAKE_BINARY_DIR}/donor" EXCLUDE_FROM_ALL)

add_library(gt4_runtime_probe SHARED runtime_probe.cpp)
target_include_directories(gt4_runtime_probe PRIVATE "${GT4_PUBLIC_DONOR}/runtime/include")
target_compile_options(gt4_runtime_probe PRIVATE -ffp-contract=off -fno-strict-aliasing -fsigned-char)
# WHOLE_ARCHIVE is essential: link every donor runtime object, not an empty .so.
target_link_libraries(gt4_runtime_probe PRIVATE "$<LINK_LIBRARY:WHOLE_ARCHIVE,ps2runtime>" android log dl m)
target_link_options(gt4_runtime_probe PRIVATE
  -Wl,--no-undefined
  -Wl,--fatal-warnings
  -Wl,-z,max-page-size=16384
  -Wl,-z,common-page-size=16384
)
set_target_properties(gt4_runtime_probe PROPERTIES
  OUTPUT_NAME "gt4_runtime_probe"
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN ON
)
