# Building reac-transport

reac-transport is an OpenWrt package: config files, uci-defaults shims and an
nftables fragment, packaged as an `.apk`. The build runs the OpenWrt SDK inside a
Fedora container, so the host needs nothing but a container engine.

## Requirements

- **podman** (default) or **docker**
- network access: the first build downloads the OpenWrt SDK for the chosen
  release and target, and the container installs its build dependencies

## Build

    ./scripts/build.sh                          # latest stable OpenWrt, mediatek/filogic
    OPENWRT_RELEASE=24.10.2 ./scripts/build.sh  # pin a release

The apk lands in `.build/out/`, next to a `.openwrt-release` file naming the
release it was built against.

## Options

All options are environment variables read by `scripts/build.sh`:

| variable | default | what it sets |
| --- | --- | --- |
| `OPENWRT_RELEASE` | latest stable | the OpenWrt release whose SDK builds the package |
| `OPENWRT_TARGET` | `mediatek/filogic` | the target board, e.g. `ramips/mt7621` |
| `CONTAINER_ENGINE` | `podman` | the container engine, e.g. `docker` |
| `BUILD_IMAGE` | `docker.io/library/fedora:42` | the container image the build runs in |

## What the build leaves behind

Everything goes under `.build/` (gitignored):

- `.build/out/` holds the built apks
- `.build/sdk-cache/` holds the downloaded SDK archive, so later builds skip the
  download
- `.build/sdk-<release>-<target>/` holds the unpacked SDK

To start clean, delete `.build/`.

On SELinux hosts the container runs with `--security-opt label=disable` so that it
can read the bind-mounted repo and work directory.

Installing the result is covered in the [README](README.md#install).
