include_guard()

set(zig_module_dir "${CMAKE_CURRENT_LIST_DIR}")

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
