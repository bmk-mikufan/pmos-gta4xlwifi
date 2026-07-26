# postmarketOS 문제 해결 (Troubleshooting)

> 출처: https://wiki.postmarketos.org/wiki/Troubleshooting
> 하위 페이지 포함: Troubleshooting on-device issues, Troubleshooting downstream kernel compilation, Troubleshooting package dependency issues

---

## Troubleshooting 개요

> If you get stuck or need assistance, you can join our Matrix/IRC chats (use the #postmarketOS channel for general support questions).

### 문제 유형별 페이지

| 문제 | 페이지 |
|---|---|
| 기기 문제 (부팅 안 됨, 소프트웨어 문제 등) | Troubleshooting on-device issues (아래) |
| 특정 구성 요소 문제 (디스플레이, 터치스크린, 오디오 등) | Troubleshooting on-device issues#Issues with particular components |
| pmbootstrap 문제 | pmbootstrap/Troubleshooting |
| 패키지 의존성 오류 | Troubleshooting package dependency issues (아래) |
| Downstream 커널 컴파일 문제 | Troubleshooting downstream kernel compilation (아래) |

---

## Troubleshooting on-device issues (기기 문제 해결)

> 이 페이지는 커널이 컴파일되지만 화면에 출력이 없거나, telnet/SSH 요청에 응답하지 않거나, 전혀 부팅되지 않는 새로운 postmarketOS 포트를 디버깅하는 방법을 설명합니다.

### 부팅 실패 여부 확인

**자동 재부팅 현상:**
- 커널이 로드되지 않거나 치명적인 버그가 있음
- **OEM 로고나 검은 화면만 표시되는 경우에도 커널이 로드되었을 수 있음**

**커널 로드 확인 방법:**
1. USB 연결 후 `dmesg` 또는 `lsusb` 실행 -> 기기가 나타나면 부팅 성공
2. `pmbootstrap initfs hook_add maximum-attention` 후 `pmbootstrap flasher boot` 실행 -> initramfs에서 LED/진동 확인

**부팅 실패 시:**
- `/proc/last_kmsg` 또는 `/sys/fs/pstore/console-ramoops` 확인 (TWRP에서 접근 가능)
- `console-ramoops`가 손상된 경우 기기를 식히거나 냉장고에 넣었다가 재시도
- TWRP를 boot 파티션에, 커널을 recovery 파티션에 플래싱하는 방법도 있음
- `boot.img`에 특수 문자열이 필요한 경우 hex 에디터로 확인

**microSD 부팅 시:**
- initramfs가 부트 파티션을 찾지 못하면 에러 화면 표시 후 대기 -> 디스플레이 드라이버가 없으면 SSH도 안 됨
- `bad boot image header` 에러 시 `fastboot boot boot.img`로 recovery 이미지 부팅 시도

### 부팅 실패 시 확인 사항

### 장치 설정 확인

- 올바른 defconfig 사용 중인지 확인
- APKBUILD의 `arch=` 값 확인 (armhf는 ARMv6 + FPU 필요)
- `pmbootstrap bootimg_analyze`로 부트 이미지 분석, deviceinfo와 비교
- TWRP 이미지가 있다면 `unpackbootimg`으로 추출하여 initramfs rc 파일 확인
- 유사 기기의 postmarketOS 포트 참고
- QCDT 기기인 경우 `extract-dtb`로 dtb 파일 추출하여 비교

### CONFIG_VT 관련 커널 패닉

일부 Qualcomm 기기(4.4 커널)에서 `CONFIG_VT=y`로 부팅 시 커널 패닉 발생.
해결: `CONFIG_VT=n`으로 테스트, VT가 필요하다면 특정 커널 커밋 revert 필요.

### 프리빌트 커널로 테스트

커널이 작동하지 않을 경우 기존 프리빌트 커널로 initramfs를 로드하여 디버깅.
이후 `kexec`로 postmarketOS 커널 로드 가능.

### 다른 코드베이스 시도

LineageOS 커널이 작동하지 않으면 다른 브랜치나 AOSP 배포판 시도.
(XDA Forums, GitHub, GitLab에서 호환 ROM 검색)

---

## Troubleshooting downstream kernel compilation (커널 컴파일 문제)

### 커널 패치 적용

문제를 패치로 해결하는 경우:

1. `.patch` 파일을 `device/category/linux-vendor-codename/` 폴더에 배치
2. `APKBUILD`의 `source` 변수에 패치 파일명 추가
3. `pmbootstrap checksum linux-vendor-codename`으로 체크섬 재계산
4. `pmbootstrap build linux-vendor-codename`으로 커널 재빌드

**Git 커밋에서 패치 생성:**
- GitHub/GitLab: 커밋 URL에 `.patch` 추가
- `git format-patch -1 <commit>` 사용

### 커널 부팅 인자 설정

`CONFIG_CMDLINE`을 `kconfig edit`으로 설정.
- `CONFIG_CMDLINE_EXTEND`: 부트로더 CMDLINE에 추가
- `CONFIG_CMDLINE_FORCE`: 부트로더 CMDLINE 덮어쓰기

fastboot 또는 pmbootstrap으로 부팅 시 변경:
```
$ fastboot boot -c "console=ttyHSL0,115200,n8"
$ pmbootstrap flasher boot --cmdline "quiet"
```

### TLS (SSL/HTTPS) 문제

오래된 커널(3.17 미만)에서 `getrandom` syscall이 없어 발생.
해결: getrandom syscall 백포트 (pmaports!69 참고).

### 일반적인 컴파일 오류

#### PTY allocation request failed
- `CONFIG_DEVTMPFS` 누락 -> 커널 설정에서 활성화

#### CROSS_COMPILE_ARM32 not defined
- `CONFIG_COMPAT_VDSO` 비활성화

#### (header file): No such file or directory
- Busybox `zip`이 심볼릭 링크를 추출하지 못함 -> `.tar.gz` 사용하거나 `unzip`을 makedepends에 추가

#### linux/types.h: No such file or directory
- `linux-headers`를 makedepends에 추가

#### thumb conditional instruction should be in IT block
- `CONFIG_CRYPTO_AES_ARM_BS` 비활성화
- 또는 `CONFIG_CRYPTO_{...}_ARM` 플래그 모두 비활성화

```
pmbootstrap kconfig edit
```
-> Cryptographic API -> Bit sliced AES using NEON instructions 비활성화

#### BusyBox lzma compression fails
- `xz`를 makedepends에 추가 (권장)
- 또는 압축률 낮추는 패치 적용
- 또는 gzip 등 다른 압축 알고리즘 사용

#### xz: not found
- `xz`를 makedepends에 추가

#### Error: .err encountered in assembler messages
- 이전 버전 GCC 사용

#### Android kernel -Werror 문제
APKBUILD `prepare()`에서 -Werror 제거 코드 추가:
```bash
local makefiles="$(find . -type f -name Makefile)
$(find . -type f -name Kbuild)"
for i in $makefiles; do
  sed -i 's/-Werror-/-W/g' "$i"
  sed -i 's/-Werror//g' "$i"
done
```

추가 플래그:
```bash
sed -i 's/=strict-prototypes//g' $i
sed -i 's/=implicit-function-declaration//g' $i
sed -i 's/=implicit-int//g' $i
sed -i 's/=return-type//g' $i
sed -i 's/=date-time//g' $i
```

섹션 불일치 경고:
```bash
sed -i 's/CONFIG_SECTION_MISMATCH_WARN_ONLY=n/CONFIG_SECTION_MISMATCH_WARN_ONLY=y/g' $builddir/.config
```

#### Error: selected processor does not support ARM mode `smc #0'
https://github.com/imoseyon/leanKernel-galaxy-nexus/pull/6 참고

### 제조사별 커널 문제

#### Mediatek

**../tools/dct/DrvGen: No such file or directory**
- `python3dct.patch` 적용 (DrvGen을 python3로 대체)

#### Qualcomm

**undefined reference to kgsl_iommu_sync_lock**
- `gpu-msm-fix-gcc5-compile.patch` 적용

**X11 does not work**
- 관련 패치 적용

**MSM framebuffer doesn't work**
- `CONFIG_MSM_KGSL=n` 설정

### Android 빌드 시스템으로 커널 빌드

LineageOS 빌드 가이드 참고:
```
mkdir -p ~/bin
mkdir -p ~/android/lineage
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
cd ~/android/lineage
~/bin/repo init -u https://github.com/LineageOS/android.git -b cm-14.1
~/bin/repo sync
source build/envsetup.sh
breakfast titan
mka kernel
mka bootimage
```

생성된 파일:
- `boot.img` (플래싱 가능)
- `dt.img` (device tree)
- `kernel` (Linux 이미지)
- `ramdisk.img` (initramfs)

---

## Troubleshooting package dependency issues (패키지 의존성 문제)

### 원인

`Could not find dependency` 또는 `unsatisfiable constraints` 오류 발생 시:
- pmOS Edge는 Alpine edge 저장소 기반이므로 일부 의존성 깨짐이 예상됨
- 라이브러리 soname bump 발생 시 해당 라이브러리에 의존하는 패키지가 재빌드되지 않은 경우

**Alpine Linux:** 패키지 메인테이너가 rebuild 트리거
**postmarketOS:** 수동 rebuild 필요 (보통 1일 내로 해결)

### 패키지 인덱스 업데이트

```bash
$ pmbootstrap update
```
postmarketOS 내부:
```bash
$ sudo apk update
```

### 문제 패키지 찾기

**apk 오류 메시지:** 낮은 버전 라이브러리에 의존하는 패키지 확인

**pmbootstrap 오류:**
```bash
$ pmbootstrap -v install
$ pmbootstrap log
```
로그에서 `so:libcrypto.so.42` 같은 패턴을 포함한 줄 검색.

### 패키지 출처 확인

- https://pkgs.postmarketos.org/ 에서 검색 (postmarketOS)
- https://pkgs.alpinelinux.org/ 에서 검색 (Alpine Linux)
- 로컬에서도 확인: `find cache_git/pmaports -name "<package>"`

### Rebuild 트리거

**postmarketOS:**
```bash
$ git pull  # 최신 master 반영
$ pmbootstrap pkgrel_bump --auto  # 의존성 깨진 패키지 rebuild
```

**크로스 컴파일러 (`gcc-armhf` 등):**
```bash
$ pmbootstrap aportgen gcc-armhf
```

**Alpine Linux 패키지:**
Alpine 패키지 저장소 클론 후 pmbootstrap으로 빌드:
```bash
$ cd ~/code
$ git clone https://git.alpinelinux.org/cgit/aports
$ find -name <package>  # 패키지 위치 확인
$ cp -r ./testing/<package> ~/code/pmbootstrap/cache_git/pmaports/temp/
$ pmbootstrap build <package> --arch=armhf
$ rm -r ~/code/pmbootstrap/cache_git/pmaports/temp/<package>
```

---

## Troubleshooting:boot (부팅 디버깅)

> Troubleshooting on-device issues의 하위 페이지

- `rc_logger=YES`를 `/etc/rc.conf`에 추가하여 openrc 로그 활성화 (`/var/log/rc.log`)
- `pmOS_init.log` 파일을 기기 루트 디렉토리에서 확인

---

## 관련 링크

- pmbootstrap/Troubleshooting
- Troubleshooting on-device issues#Issues_with_particular_components
- Troubleshooting package dependency issues
- Troubleshooting downstream kernel compilation
