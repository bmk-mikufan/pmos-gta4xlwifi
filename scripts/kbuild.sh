#!/bin/sh
# Incremental in-tree kernel build, the fast alternative to
# `pmbootstrap build linux-samsung-exynos9610` (which wipes srcdir every time
# and so always does a full rebuild).
#
# Same trick as pmbootstrap's helpers/envkernel.sh -- bind-mount the kernel
# tree into the native chroot and run make there -- except envkernel.sh
# hardcodes a gcc cross-compiler and this kernel is built with clang/lld
# (LLVM=1), so we drive make ourselves.
#
#   ./scripts/kbuild.sh                 # incremental build
#   ./scripts/kbuild.sh dtbs            # dtbs only (seconds)
#   ./scripts/kbuild.sh defconfig exynos9610.config
#
# Afterwards, package the result:
#   cd "$KERNEL_TREE" && pmbootstrap build --envkernel linux-samsung-exynos9610
set -e

KERNEL_TREE="${KERNEL_TREE:-$HOME/gta4xlwifi/kernel/linux-for-next}"
JOBS="${JOBS:-$(nproc)}"

[ -e "$KERNEL_TREE/Kbuild" ] || { echo "not a kernel tree: $KERNEL_TREE" >&2; exit 1; }
chroot_dir="$(pmbootstrap config work)/chroot_native"

sudo mkdir -p "$chroot_dir/mnt/linux"
# Remount only when it is not already this tree.
if [ ! -e "$chroot_dir/mnt/linux/Kbuild" ]; then
	sudo mount --bind "$KERNEL_TREE" "$chroot_dir/mnt/linux"
fi
# `pmbootstrap install --zap` wipes the native chroot, taking the toolchain
# with it. apk add is idempotent and cheap, so just make sure every time.
pmbootstrap -q chroot -- apk -q add \
	abuild bash bc binutils bison clang diffutils elfutils-dev findutils flex \
	g++ gmp-dev linux-headers lld llvm make mpc1-dev mpfr-dev openssl-dev \
	pahole perl python3 sed >/dev/null

mkdir -p "$KERNEL_TREE/.output"
pmbootstrap -q chroot -- chown -R pmos:pmos /mnt/linux/.output

# DTC_FLAGS: S-BOOT rejects a main dtb without a __symbols__ node, and dtc only
# emits one with -@. Same override as the APKBUILD.
exec pmbootstrap -q chroot --user -- \
	ARCH=arm64 make -C /mnt/linux O=/mnt/linux/.output \
	LLVM=1 -j"$JOBS" \
	DTC_FLAGS_exynos9610-gta4xl=-@ \
	"$@"
