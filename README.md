# cmake-zig

CMake integration for building Zig libraries. Provides functions to locate Zig, detect target platforms, and build Zig modules that can be linked into CMake projects.

```
npm i cmake-zig
```

## Usage

In your `CMakeLists.txt`:

```cmake
find_package(cmake-zig REQUIRED PATHS node_modules/cmake-zig)

add_zig_module(my_zig_lib)

target_link_libraries(my_target PRIVATE my_zig_lib)
```

## API

### `add_zig_module`

Builds a Zig project and creates an imported CMake library target.

```cmake
add_zig_module(
  <name>
  [PATH <path>]
  [TARGET <target>]
  [OPTIMIZE <mode>]
  [ARTIFACT_NAME <artifact>]
  [BUILD_OPTIONS <options>...]
  [SHARED]
)
```

#### Arguments

| Argument        | Required | Default                               | Description                                           |
| --------------- | -------- | ------------------------------------- | ----------------------------------------------------- |
| `name`          | Yes      | -                                     | Name of the Zig module (used for build target naming) |
| `PATH`          | No       | `CMAKE_CURRENT_LIST_DIR`              | Path to directory containing `build.zig`              |
| `TARGET`        | No       | Same as `name`                        | CMake target name for the imported library            |
| `OPTIMIZE`      | No       | Auto-detected from `CMAKE_BUILD_TYPE` | Zig optimization mode                                 |
| `ARTIFACT_NAME` | No       | Same as `name`                        | Name of the output library artifact                   |
| `BUILD_OPTIONS` | No       | -                                     | Additional options passed to `zig build`              |
| `SHARED`        | No       | Off                                   | Build as shared library instead of static             |

#### Build Mode Mapping

| CMake Build Type | Zig Optimize Mode |
| ---------------- | ----------------- |
| `Debug`          | `Debug`           |
| `Release`        | `ReleaseFast`     |
| `RelWithDebInfo` | `ReleaseSafe`     |
| `MinSizeRel`     | `ReleaseSmall`    |

#### Example

```cmake
add_zig_module(
  bare_addon_zig
  BUILD_OPTIONS -Dsome_option=value
)
```

### `find_zig`

Locates the Zig executable.

```cmake
find_zig(result)

message(STATUS "Zig found at: ${result}")
```

### `zig_target`

Returns the Zig target triple for the current build configuration.

```cmake
zig_target(triple)
# e.g., "aarch64-macos.14.0-none" or "x86_64-linux-gnu"
```

### `zig_arch`

Returns the Zig architecture name.

```cmake
zig_arch(arch)
# e.g., "aarch64", "x86_64", "arm"
```

Supported architectures:

- `aarch64` (arm64)
- `arm` (armv7-a, armeabi-v7a)
- `x86_64` (x64, amd64)
- `x86` (i386, i486, i586, i686)
- `mipsel`, `mips`

### `zig_os`

Returns the Zig OS name.

```cmake
zig_os(os)
# e.g., "macos", "linux", "windows", "ios"
```

### `zig_abi`

Returns the Zig ABI name.

```cmake
zig_abi(abi)
# e.g., "none", "gnu", "msvc", "android", "simulator"
```

### `zig_optimize`

Returns the Zig optimization mode for the current CMake build type.

```cmake
zig_optimize(mode)
# e.g., "Debug", "ReleaseFast", "ReleaseSafe", "ReleaseSmall"
```

### `zig_version`

Returns the installed Zig version.

```cmake
zig_version(ver)
message(STATUS "Zig version: ${ver}")
```

## Target Properties

After calling `add_zig_module`, the following properties are set on the target:

| Property            | Description            |
| ------------------- | ---------------------- |
| `ZIG_MODULE_NAME`   | The module name        |
| `ZIG_MODULE_PATH`   | Path to the Zig source |
| `ZIG_BUILD_DIR`     | Zig build directory    |
| `ZIG_OUT_DIR`       | Zig output directory   |
| `ZIG_ARTIFACT_NAME` | Output artifact name   |

## Build Outputs

The Zig module is built to:

```
${CMAKE_CURRENT_BINARY_DIR}/_zig/${name}/out/lib/lib${name}.a
```

For shared libraries (`SHARED` option):

- Linux: `lib${name}.so`
- macOS: `lib${name}.dylib`
- Windows: `${name}.dll` + `${name}.lib` (import library)

## Cross-Compilation

The module automatically detects the target platform from CMake variables:

- **macOS/iOS**: Uses `CMAKE_OSX_ARCHITECTURES` and `CMAKE_OSX_DEPLOYMENT_TARGET`
- **Android**: Uses `CMAKE_ANDROID_ARCH_ABI`
- **Windows**: Uses `CMAKE_GENERATOR_PLATFORM`
- **Others**: Uses `CMAKE_SYSTEM_PROCESSOR` and `CMAKE_SYSTEM_NAME`

## Requirements

- CMake 4.0+
- Zig 0.14+

## Related

- [bare-zig](https://github.com/holepunchto/bare-zig) - Zig bindings for Bare
- [bare-addon-zig](https://github.com/holepunchto/bare-addon-zig) - Zig addon template
- [cmake-cargo](https://github.com/holepunchto/cmake-cargo) - Similar CMake integration for Rust

## License

Apache-2.0
