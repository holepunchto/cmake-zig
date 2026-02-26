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
    OUTPUT_VARIABLE version_output
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )

  set(${result} ${version_output})
  return(PROPAGATE ${result})
endfunction()

function(add_zig_module)
  set(options SHARED)
  set(oneValueArgs NAME PATH TARGET BUILD_MODE ARTIFACT_NAME)
  set(multiValueArgs BUILD_OPTIONS)
  cmake_parse_arguments(ZIG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ZIG_NAME)
    message(FATAL_ERROR "add_zig_module: NAME is required")
  endif()

  if(NOT ZIG_PATH)
    set(ZIG_PATH ${CMAKE_CURRENT_SOURCE_DIR})
  endif()

  if(NOT ZIG_TARGET)
    set(ZIG_TARGET ${ZIG_NAME})
  endif()

  if(NOT ZIG_BUILD_MODE)
    zig_optimize(ZIG_BUILD_MODE)
  endif()

  set(build_zig_path "${ZIG_PATH}/build.zig")
  if(NOT EXISTS ${build_zig_path})
    message(FATAL_ERROR "add_zig_module: build.zig not found at ${build_zig_path}")
  endif()

  find_zig(zig_exe)

  zig_target(target_triple)

  set(zig_build_dir "${CMAKE_CURRENT_BINARY_DIR}/zig-build/${ZIG_NAME}")
  set(zig_cache_dir "${zig_build_dir}/zig-cache")
  set(zig_out_dir "${zig_build_dir}/zig-out")

  set(zig_build_command
    ${zig_exe} build
    --cache-dir ${zig_cache_dir}
    --prefix ${zig_out_dir}
    -Dtarget=${target_triple}
    -Doptimize=${ZIG_BUILD_MODE}
  )

  foreach(option ${ZIG_BUILD_OPTIONS})
    list(APPEND zig_build_command ${option})
  endforeach()

  set(build_zig_zon_path "${ZIG_PATH}/build.zig.zon")
  set(fetch_command)
  if(EXISTS ${build_zig_zon_path})
    set(fetch_command COMMAND ${CMAKE_COMMAND} -E chdir ${ZIG_PATH} ${zig_exe} build --fetch)
  endif()

  if(NOT ZIG_ARTIFACT_NAME)
    set(ZIG_ARTIFACT_NAME ${ZIG_NAME})
  endif()

  set(lib_name "lib${ZIG_ARTIFACT_NAME}")
  if(WIN32)
    if(ZIG_SHARED)
      set(lib_suffix ".dll")
      set(import_suffix ".lib")
    else()
      set(lib_suffix ".lib")
    endif()
  else()
    if(ZIG_SHARED)
      if(APPLE)
        set(lib_suffix ".dylib")
      else()
        set(lib_suffix ".so")
      endif()
    else()
      set(lib_suffix ".a")
    endif()
  endif()
  set(lib_path "${zig_out_dir}/lib/${lib_name}${lib_suffix}")

  add_custom_command(
    OUTPUT ${lib_path}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${zig_build_dir}
    ${fetch_command}
    COMMAND ${CMAKE_COMMAND} -E chdir ${ZIG_PATH} ${zig_build_command}
    COMMENT "Building Zig module ${ZIG_NAME}"
    VERBATIM
  )

  add_custom_target(${ZIG_NAME}_build DEPENDS ${lib_path})

  if(ZIG_SHARED)
    add_library(${ZIG_TARGET} SHARED IMPORTED GLOBAL)
  else()
    add_library(${ZIG_TARGET} STATIC IMPORTED GLOBAL)
  endif()
  add_dependencies(${ZIG_TARGET} ${ZIG_NAME}_build)

  set_target_properties(${ZIG_TARGET} PROPERTIES
    IMPORTED_LOCATION ${lib_path}
  )

  if(EXISTS "${ZIG_PATH}/include")
    set_property(TARGET ${ZIG_TARGET} APPEND PROPERTY
      INTERFACE_INCLUDE_DIRECTORIES "${ZIG_PATH}/include"
    )
  endif()

  if(EXISTS "${zig_out_dir}/include")
    set_property(TARGET ${ZIG_TARGET} APPEND PROPERTY
      INTERFACE_INCLUDE_DIRECTORIES "${zig_out_dir}/include"
    )
  endif()

  if(WIN32 AND ZIG_SHARED)
    set_target_properties(${ZIG_TARGET} PROPERTIES
      IMPORTED_IMPLIB "${zig_out_dir}/lib/${lib_name}${import_suffix}"
    )
  endif()

  set_target_properties(${ZIG_TARGET} PROPERTIES
    ZIG_MODULE_NAME ${ZIG_NAME}
    ZIG_MODULE_PATH ${ZIG_PATH}
    ZIG_BUILD_DIR ${zig_build_dir}
    ZIG_OUT_DIR ${zig_out_dir}
    ZIG_ARTIFACT_NAME ${ZIG_ARTIFACT_NAME}
  )
endfunction()
