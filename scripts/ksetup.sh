#!/bin/sh
# (Re)create the kernel tree that scripts/kbuild.sh builds incrementally:
# extract the cached linux-for-next tarball, apply the package's patches, and
# drop the config fragment where `make defconfig exynos9610.config` finds it.
#
# Run this after changing any of the 00NN-*.patch files -- the tree is a plain
# extracted tarball, so patches are not re-applied automatically.
#
# The tree must stay clean of in-tree build artifacts: kbuild.sh builds with
# O=.output and refuses to run otherwise ("The source tree is not clean").
# So never run a bare `make` in it from the host.
set -e

PMAPORTS="${PMAPORTS:-$(pmbootstrap config aports)}"
PKG="$PMAPORTS/device/testing/linux-samsung-exynos9610"
TARBALL="${TARBALL:-$(pmbootstrap config work)/cache_distfiles/linux-for-next.tar.gz}"
KERNEL_DIR="${KERNEL_DIR:-$HOME/gta4xlwifi/kernel}"
TREE="$KERNEL_DIR/linux-for-next"

[ -e "$TARBALL" ] || { echo "missing tarball: $TARBALL" >&2; exit 1; }

chroot_dir="$(pmbootstrap config work)/chroot_native"
if [ -e "$chroot_dir/mnt/linux/Kbuild" ]; then
	sudo umount "$chroot_dir/mnt/linux"
fi

mkdir -p "$KERNEL_DIR"
sudo rm -rf "$TREE"
tar -xzf "$TARBALL" -C "$KERNEL_DIR"

cd "$TREE"
for f in "$PKG"/00*.patch; do
	patch -p1 --forward -s < "$f" || { echo "FAILED: $(basename "$f")" >&2; exit 1; }
done
cp "$PKG/exynos9610.config" arch/arm64/configs/
echo "kernel tree ready: $TREE"
