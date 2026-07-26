# Build Instructions

## Prerequisites
- pmbootstrap 3.11+
- Alpine Linux / Arch Linux
- Python 3.14+

## Mainline Kernel Build

```bash
# 1. Build mainline kernel (~60min)
pmbootstrap build linux-samsung-exynos9610 --force

# 2. Build U-Boot (~2min)
pmbootstrap build u-boot-exynos9610 --force

# 3. Build device package
pmbootstrap build device-samsung-gta4xlwifi-mainline --force

# 4. Install and create boot.img
pmbootstrap install --password 1234
pmbootstrap export /tmp/export

# 5. Flash via fastboot
fastboot flash boot boot.img
fastboot flash userdata rootfs.ext4
```

## uniLoader Build (for development)

```bash
git clone https://github.com/ivoszbg/uniLoader
cd uniLoader
cp /path/to/vmlinuz blob/Image
cp /path/to/exynos9610-gta4xl.dtb blob/dtb
cp /path/to/initramfs blob/ramdisk
make ARCH=aarch64 LLVM=1 gta4xl_defconfig
make ARCH=aarch64 LLVM=1
```

## DTBO Format (Samsung S-BOOT compatibility)

```bash
mkdtboimg create output.dtbo --custom0=0x00000000 --custom1=0xff000000 input.dtb
mkbootimg --kernel uniloader --dtb output.dtbo --pagesize 2048 --header_version 2 ...
```

Then fix v2 DTB header:
- dtb_addr at offset 1640 = 0x10000000
- dtb_size at offset 1644 = sizeof(output.dtbo)
