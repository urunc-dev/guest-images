# unikernel-build

## Images

Each image is described by bunnyfiles, the build files of the
[bunny](https://github.com/nubificus/bunny) BuildKit frontend, laid out as:

```
<app>/
├── src/                          sources and scripts shared by the app's images (optional)
└── <framework>/<monitor>/<rootfs>/
    ├── bunnyfile-<arch>          one per architecture
    └── prebuild.sh               optional
```

| Level | Values |
| --- | --- |
| `<framework>` | The unikernel framework or guest OS, as in the bunnyfile's `platforms.framework`: `linux`, `unikraft`, ... |
| `<monitor>` | The monitor, by its urunc name: `qemu`, `firecracker`, `cloud-hypervisor`, `hvt`, `spt`, ... |
| `<rootfs>` | The rootfs type: `raw`, `block`, `initrd`, or `no_rootfs` for unikernels without one |
| `<arch>` | `amd64` or `arm64` |

Each `<app>/<framework>/<monitor>/<rootfs>` directory is one image, published
as a multi-arch image signed with cosign. The image has an entry for every
`bunnyfile-<arch>` in the directory:

```
<app>/<framework>/<monitor>/<rootfs>/bunnyfile-<arch>  ->  ghcr.io/urunc-dev/guest-images/<app>-<framework>-<monitor>-<rootfs>
```

For example, `chttp/unikraft/qemu/initrd/bunnyfile-amd64` is the amd64 entry
of `chttp-unikraft-qemu-initrd`.

Images of the same app on the same monitor differ only in how their rootfs is
built. That is bunny's job, so their directories differ only in their
bunnyfiles and `prebuild.sh`.

### How an image is built

CI builds each architecture of an image on a native runner, in this order:

1. **Pick the build context:** `<app>/src`, or the image directory if the app
   has no `src`. Paths in the bunnyfile are relative to it, so an app's
   sources live in one place for all its images.
2. **Run `prebuild.sh`**, if the image directory has one. It runs from the
   build context, with `ARCH` set to `amd64` or `arm64`, before bunny starts.
   It can create any file the build needs: files to put in the rootfs, a
   whole prebuilt rootfs, or any other input the bunnyfile refers to. What it
   writes into the build context is available to the bunnyfile; gitignore
   it. For example, `chttp/unikraft/qemu/initrd/prebuild.sh` compiles
   `chttp/src/chttp.c` into the binary that chttp's bunnyfile puts in its
   rootfs. Scripts that several images' `prebuild.sh` share live in
   `scripts/`. For example, bunny cannot build a block rootfs from an image
   yet, so the `prebuild.sh` of a block image calls `scripts/ext4-rootfs.sh`
   with the image and a size, and the bunnyfile takes the resulting
   `rootfs.ext4` (`rootfs: from: local, path: rootfs.ext4, type: block`).
3. **Build `bunnyfile-<arch>`** with bunny, from the build context. Outside
   pull requests, the result is pushed as `<arch>-<commit sha>`.

Outside pull requests, once every architecture is built, CI combines them
into the multi-arch image, tags it with the commit SHA (and `latest` on
`main`) and signs it with cosign.

### What CI builds

On a pull request or a push to `main`, CI builds only the images whose inputs
changed: a file directly in the image directory, or anywhere under
`<app>/src`. A change to `.github/workflows/build.yml`,
`.github/workflows/build_and_manifest.yml` or a script under `scripts/`
rebuilds every image. Pull requests build without publishing.

`build.yml` can also be run by hand, with `mode` (`all`, or `changed` to
build only what changed against `base`) and `filter` (only build image
directories under this path).

Each architecture is built on a native runner. Builds are designed to be
reproducible: every input is pinned by digest, the BuildKit version is pinned
and image timestamps are clamped, so the same inputs should produce the same
image digest.

### Published images

| Tag | Points to |
| --- | --- |
| `latest` | The latest build from `main` |
| `<commit sha>` | The multi-arch image built from that commit |
| `<arch>-<commit sha>` | The image for one architecture built from that commit |

### Building an image locally

Build on a host of the target architecture, with the BuildKit version CI
uses:

```sh
docker buildx create --use --driver docker-container --driver-opt image=moby/buildkit:v0.34.0
DIR=chttp/unikraft/qemu/initrd ARCH=amd64    # the image directory
CTX=${DIR%%/*}/src; [ -d "$CTX" ] || CTX=$DIR
[ -f "$DIR/prebuild.sh" ] && (cd "$CTX" && ARCH=$ARCH bash "$OLDPWD/$DIR/prebuild.sh")
docker buildx build --platform linux/$ARCH -f "$DIR/bunnyfile-$ARCH" \
  --build-arg SOURCE_DATE_EPOCH=0 \
  --output "type=docker,name=${DIR//\//-}:dev,rewrite-timestamp=true" "$CTX"
docker run --rm --runtime io.containerd.urunc.v2 "${DIR//\//-}:dev"
```

## Linux kernels

The guest kernels used by the Linux images are built from defconfigs in
`linux_kernel/<name>/defconfig-<arch>`, where `<arch>` is `amd64` or `arm64`.
A directory can hold one or both. Each directory is one kernel, published as
two images signed with cosign: one with the uncompressed kernel and one with
the compressed kernel, so each guest pulls only the format its monitor boots.
Each image has an entry for every `defconfig-<arch>` file in the directory:

```
linux_kernel/<name>/defconfig-<arch>  ->  ghcr.io/urunc-dev/unikernel-build/linux-kernel:<name>
                                          ghcr.io/urunc-dev/unikernel-build/linux-kernel:<name>-compressed
```

### Kernel version

Pin the kernel version with a `# KVER=x.y.z` line in the defconfig:

```
# KVER=6.12.113
CONFIG_LOCALVERSION="-urunc"
...
```

Without that line the kernel is built from the latest
[longterm release](https://www.kernel.org/category/releases.html) at build
time. All defconfigs in one directory must end up on the same version.
`make savedefconfig` drops comments, so re-add the `# KVER=` line after
regenerating a defconfig.

### Adding or changing a kernel

1. Start from an existing defconfig in a kernel tree of the version you want,
   change the configuration, and save it back as a defconfig. For example,
   for amd64:

   ```sh
   cp linux_kernel/generic/defconfig-amd64 linux-<version>/arch/x86/configs/urunc_defconfig
   cd linux-<version>
   make ARCH=x86_64 urunc_defconfig
   make ARCH=x86_64 menuconfig
   make ARCH=x86_64 savedefconfig    # writes ./defconfig
   ```

   For arm64 use `arch/arm64/configs/` and `ARCH=arm64`.
2. Save the result as `linux_kernel/<name>/defconfig-<arch>`, one file for
   each architecture you need (one or both), and add the `# KVER=` line if you
   want a pinned version.
3. Open a pull request. CI builds every changed directory and comments on the
   pull request with links to the built kernels. Nothing is published.
4. When the pull request is merged, the kernels are published.

### What CI checks

- The kernel.org tarball must carry a valid signature from Linus Torvalds or
  Greg Kroah-Hartman. Their public keys are kept in `linux_kernel/keys/`, and
  the workflow only accepts a signature from the two key fingerprints it
  pins.
- Every symbol the defconfig sets to `=y` must still be `=y` after the
  defconfig is expanded. A symbol whose dependencies are missing fails the
  build, rather than shipping a kernel that cannot mount its root.
- Builds are designed to be reproducible: they run in a compiler image pinned
  by digest with fixed build metadata, and image timestamps are clamped, so
  the same defconfig and kernel version should produce the same image digest.

### Published images

| Tag | Points to |
| --- | --- |
| `<name>` | The latest build from `main` |
| `<name>-<kver>` | The latest build of that kernel version from `main` |
| `<name>-<kver>-<commit sha>` | That kernel version built from that commit |

The compressed images use the same tags with `-compressed` after the name:
`<name>-compressed`, `<name>-compressed-<kver>` and
`<name>-compressed-<kver>-<commit sha>`.

A defconfig without a `# KVER=` line follows the latest LTS, so building the
same commit again after a new release produces a newer kernel. It gets its own
`-<kver>-<commit sha>` tag instead of replacing the earlier one.

| Image | `/.boot/kernel` on amd64 | `/.boot/kernel` on arm64 |
| --- | --- | --- |
| `<name>` | `vmlinux` (uncompressed ELF) | `Image` |
| `<name>-compressed` | `bzImage` | `Image.gz` |

Both images also contain:

| Path | Contents |
| --- | --- |
| `/.boot/config` | The full expanded `.config` |
| `/.boot/COPYING`, `/.boot/LICENSES/` | The kernel license |

The image labels record the kernel version, whether the kernel is compressed
(`com.urunc.kernel.format`), the source tarball URL and its SHA-256, and the
defconfig it was built from.

### Using a kernel in a bunnyfile

Pick the uncompressed or compressed image depending on what the monitor
boots, and reference it by the digest of the image for that architecture,
not by tag or by the multi-arch index:

```sh
docker buildx imagetools inspect ghcr.io/urunc-dev/unikernel-build/linux-kernel:generic
```

```yaml
kernel:
  from: ghcr.io/urunc-dev/unikernel-build/linux-kernel@sha256:<amd64 digest>
  path: /.boot/kernel
```

### Building a kernel locally

Build on a host of the target architecture, so no cross-compiler is needed:

```sh
KVER=6.18.57
curl -LO https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KVER}.tar.xz
tar -xf linux-${KVER}.tar.xz
cp linux_kernel/generic/defconfig-amd64 linux-${KVER}/arch/x86/configs/urunc_defconfig
cd linux-${KVER}
make ARCH=x86_64 urunc_defconfig
make ARCH=x86_64 -j"$(nproc)" bzImage    # also builds vmlinux
```

This produces `vmlinux` and `arch/x86/boot/bzImage`. On arm64 use
`arch/arm64/configs/`, `ARCH=arm64` and the `Image.gz` target, which produces
`arch/arm64/boot/Image` and `arch/arm64/boot/Image.gz`. A local build is not bit-for-bit identical
to the CI one. For that, use the pinned compiler image and the `KBUILD_BUILD_*`
settings from the "Build kernel" step in `.github/workflows/build-linux-kernels.yml`.

## License

The files in this repository are licensed under the [Apache License 2.0](LICENSE).

That license does not extend to:

- The submodules (`mirage-skeleton`, `unikernel-httpreply`, `unikernel-redis`), which keep their own licenses.
- The software inside the published images:
  - The Linux kernels are licensed under `GPL-2.0-only WITH Linux-syscall-note`. Each is built from an unmodified [kernel.org](https://kernel.org) release, using the defconfig under `linux_kernel/` and `.github/workflows/build-linux-kernels.yml`. Each `linux-kernel` image ships the license and the expanded `.config` under `/.boot/`. Its labels name the exact source tarball and its SHA-256 (`com.urunc.kernel.tarball`, `com.urunc.kernel.tarball.sha256`) and the defconfig it was built from (`com.urunc.kernel.defconfig`).
  - The unikernel frameworks, applications and root filesystems in the images are under their own licenses.
