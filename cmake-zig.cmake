include_guard()

set(zig_module_dir "${CMAKE_CURRENT_LIST_DIR}")

function(find_zig result)
  find_program(zig NAMES zig REQUIRED)

  set(${result} ${zig})

  return(PROPAGATE ${result})
endfunction()

function(zig_arch result)
  if(APPLE AND CMAKE_OSX_ARCHITECTURES)
    set(arch ${CMAKE_OSX_ARCHITECTURES})
  elseif(MSVC AND CMAKE_GENERATOR_PLATFORM)
    set(arch ${CMAKE_GENERATOR_PLATFORM})
  elseif(ANDROID AND CMAKE_ANDROID_ARCH_ABI)
    set(arch ${CMAKE_ANDROID_ARCH_ABI})
  else()
    set(arch ${CMAKE_SYSTEM_PROCESSOR})
  endif()

  if(NOT arch)
    set(arch ${CMAKE_HOST_SYSTEM_PROCESSOR})
  endif()

  string(TOLOWER "${arch}" arch)

  if(arch MATCHES "arm64|aarch64")
    set(${result} "aarch64")
  elseif(arch MATCHES "armv7-a|armeabi-v7a")
    set(${result} "arm")
  elseif(arch MATCHES "x64|x86_64|amd64")
    set(${result} "x86_64")
  elseif(arch MATCHES "x86|i386|i486|i586|i686")
    set(${result} "x86")
  elseif(arch MATCHES "mipsel")
    set(${result} "mipsel")
  elseif(arch MATCHES "mips(eb)?")
    set(${result} "mips")
  else()
    set(${result} "other")
  endif()

  return(PROPAGATE ${result})
endfunction()

function(zig_os result)
  set(os ${CMAKE_SYSTEM_NAME})

  if(NOT os)
    set(os ${CMAKE_HOST_SYSTEM_NAME})
  endif()

  string(TOLOWER "${os}" os)

  if(os MATCHES "ios|linux|windows")
    set(${result} ${os})
  elseif(os MATCHES "darwin")
    set(${result} "macos")
  elseif(os MATCHES "android")
    set(${result} "linux")
  else()
    set(${result} "other")
  endif()

  return(PROPAGATE ${result})
endfunction()

function(zig_abi result)
  set(os ${CMAKE_SYSTEM_NAME})

  if(NOT os)
    set(os ${CMAKE_HOST_SYSTEM_NAME})
  endif()

  string(TOLOWER "${os}" os)

  if(os MATCHES "android")
    set(${result} ${os})
  elseif(os MATCHES "ios")
    set(sysroot ${CMAKE_OSX_SYSROOT})

    if(sysroot MATCHES "iPhoneSimulator")
      set(${result} "simulator")
    else()
      set(${result} "none")
    endif()
  elseif(os MATCHES "linux")
    set(${result} "gnu")
  elseif(os MATCHES "windows")
    set(${result} "msvc")
  else()
    set(${result} "none")
  endif()

  return(PROPAGATE ${result})
endfunction()

function(zig_target result)
  zig_arch(arch)
  zig_os(os)
  zig_abi(abi)

  set(target ${arch}-${os})

  if(os MATCHES "macos|ios")
    set(target ${target}.${CMAKE_OSX_DEPLOYMENT_TARGET})
  endif()

  set(target ${target}-${abi})

  set(${result} ${target})

  return(PROPAGATE ${result})
endfunction()

function(zig_optimize result)
  if(CMAKE_BUILD_TYPE MATCHES "Debug")
    set(${result} Debug)
  elseif(CMAKE_BUILD_TYPE MATCHES "Release")
    set(${result} ReleaseFast)
  elseif(CMAKE_BUILD_TYPE MATCHES "RelWithDebInfo")
    set(${result} ReleaseSafe)
  elseif(CMAKE_BUILD_TYPE MATCHES "MinSizeRel")
    set(${result} ReleaseSmall)
  else()
    message(FATAL_ERROR "Unknown CMake build type '${CMAKE_BUILD_TYPE}'")
  endif()

  return(PROPAGATE ${result})
endfunction()

function(zig_version result)
  find_zig(zig_exe)

  execute_process(
    COMMAND ${zig_exe} version
    OUTPUT_VARIABLE version
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )

  set(${result} ${version})

  return(PROPAGATE ${result})
endfunction()

function(add_zig_module name)
  set(option_keywords
    SHARED
  )

  set(one_value_keywords
    PATH
    TARGET
    OPTIMIZE
    ARTIFACT_NAME
  )

  set(multi_value_kewords
    BUILD_OPTIONS
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "${option_keywords}" "${one_value_keywords}" "${multi_value_keywords}"
  )

  if(ARGV_PATH)
    cmake_path(ABSOLUTE_PATH ARGV_PATH BASE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" NORMALIZE)
  else()
    set(ARGV_PATH "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  if(NOT ARGV_TARGET)
    set(ARGV_TARGET ${name})
  endif()

  if(DEFINED ARGV_OPTIMIZE)
    set(optimize ${ARGV_OPTIMIZE})
  else()
    zig_optimize(optimize)
  endif()

  set(build_zig_path "${ARGV_PATH}/build.zig")

  if(NOT EXISTS ${build_zig_path})
    message(FATAL_ERROR "No build.zig file found at '${build_zig_path}'")
  endif()

  find_zig(zig)

  zig_target(target)

  set(build_dir "${CMAKE_CURRENT_BINARY_DIR}/_zig/${name}")
  set(cache_dir "${build_dir}/cache")
  set(out_dir "${build_dir}/out")

  set(build_command
    "${zig}" build
    --cache-dir "${cache_dir}"
    --prefix "${out_dir}"
    -Dtarget=${target}
    -Doptimize=${optimize}
  )

  if(DEFINED ARGV_BUILD_OPTIONS)
    list(APPEND build_command ${ARGV_BUILD_OPTIONS})
  endif()

  set(fetch_command "${zig}" build --fetch)

  if(NOT ARGV_ARTIFACT_NAME)
    set(ARGV_ARTIFACT_NAME ${name})
  endif()

  set(lib_name "lib${ARGV_ARTIFACT_NAME}")

  if(WIN32)
    if(ARGV_SHARED)
      set(lib_suffix ".dll")
      set(import_suffix ".lib")
    else()
      set(lib_suffix ".lib")
    endif()
  elseif(ARGV_SHARED)
    if(APPLE)
      set(lib_suffix ".dylib")
    else()
      set(lib_suffix ".so")
    endif()
  else()
    set(lib_suffix ".a")
  endif()

  set(lib_path "${out_dir}/lib/${lib_name}${lib_suffix}")

  add_custom_command(
    OUTPUT "${lib_path}"
    COMMAND ${fetch_command}
    COMMAND ${build_command}
    WORKING_DIRECTORY "${ARGV_PATH}"
    VERBATIM
  )

  add_custom_target(${name}_build DEPENDS "${lib_path}")

  if(ARGV_SHARED)
    add_library(${ARGV_TARGET} SHARED IMPORTED GLOBAL)
  else()
    add_library(${ARGV_TARGET} STATIC IMPORTED GLOBAL)
  endif()

  add_dependencies(${ARGV_TARGET} ${name}_build)

  set_target_properties(
    ${ARGV_TARGET}
    PROPERTIES
    IMPORTED_LOCATION "${lib_path}"
  )

  if(EXISTS "${ARGV_PATH}/include")
    target_include_directories(
      ${ARGV_TARGET}
      INTERFACE
        "${ARGV_PATH}/include"
    )
  endif()

  if(EXISTS "${out_dir}/include")
    target_include_directories(
      ${ARGV_TARGET}
      INTERFACE
        "${out_dir}/include"
    )
  endif()

  if(WIN32 AND ARGV_SHARED)
    set_target_properties(
      ${ARGV_TARGET}
      PROPERTIES
      IMPORTED_IMPLIB "${out_dir}/lib/${lib_name}${import_suffix}"
    )
  endif()

  set_target_properties(
    ${ARGV_TARGET}
    PROPERTIES
    ZIG_MODULE_NAME ${name}
    ZIG_MODULE_PATH "${ARGV_PATH}"
    ZIG_BUILD_DIR "${build_dir}"
    ZIG_OUT_DIR "${out_dir}"
    ZIG_ARTIFACT_NAME ${ARGV_ARTIFACT_NAME}
  )
endfunction()
