# SETUP — 새 PC 환경 구축 가이드

이 저장소만 있으면 다른 PC에서 빌드를 이어갈 수 있다. 전체 소요: 첫 풀빌드 포함 1시간 내외.

## 0. 호스트 요구사항

- Linux x86_64 (pmbootstrap 호스트로 동작하는 배포판)
- sudo 가능할 것 (chroot 마운트·apk 캐시 정리 때 필요)
- 디스크 여유 30GB 이상, RAM 8GB 이상 (16코어/14GB 기준 풀빌드 ~30분)
- pmbootstrap 3.11.1 (이 프로젝트가 검증된 버전. 설치는 postmarketOS 위키의
  pmbootstrap 설치 절차를 따를 것)

## 1. pmbootstrap 초기 설정

```sh
pmbootstrap init
```

대화형 질문에는 이렇게 답한다 (현재 PC의 실제 설정값):

| 질문 | 답 |
|---|---|
| work 경로 | 기본값 (`~/.local/var/pmbootstrap`) |
| channel | edge (testing 패키지를 쓰므로 edge 필요) |
| device | `samsung-gta4xlwifi-mainline` (목록에 없으면 3단계 먼저) |
| UI | `xfce4` |
| 그 외 (hostname, keymap, extra packages 등) | 기본값 |

확인:
```sh
pmbootstrap config device   # samsung-gta4xlwifi-mainline
pmbootstrap config ui       # xfce4
```

`pmbootstrap init`은 한 번이면 된다. 답은 `~/.config/pmbootstrap_v3.cfg`에 저장된다.

## 2. pmaports에 이 저장소의 패키지 배치

`packages/`는 pmaports `device/testing/`의 미러다. **빌드는 pmaports 쪽을 보므로**
반드시 덮어써야 한다. `pmbootstrap init`이 pmaports를 `cache_git`에 받아온 뒤:

```sh
PM=~/.local/var/pmbootstrap/cache_git/pmaports/device/testing
for p in linux-samsung-exynos9610 device-samsung-gta4xlwifi-mainline uniloader-exynos9610; do
  rsync -a --delete ~/pmos-gta4xlwifi/packages/$p/ "$PM/$p/"
done
# 동기화 확인 — 출력이 없어야 정상
for p in linux-samsung-exynos9610 device-samsung-gta4xlwifi-mainline uniloader-exynos9610; do
  diff -rq "$PM/$p" ~/pmos-gta4xlwifi/packages/$p
done
```

주의: `pmbootstrap pull`이나 pmaports 업데이트를 하면 이 덮어쓰기가 날아간다.
업데이트 후에는 위 rsync를 다시 실행할 것.

## 3. 커널 스냅샷 고정 (중요)

커널 소스는 롤링 스냅샷 URL에서 받는다:

```
https://git.kernel.org/pub/scm/linux/kernel/git/krzk/linux.git/snapshot/linux-for-next.tar.gz
```

URL은 고정이라도 **내용이 계속 바뀐다.** `APKBUILD`의 `sha512sums`가 특정 스냅샷에
고정되어 있으므로, 새 PC에서 처음 받을 때 두 가지를 확인할 것:

1. 체크섬이 APKBUILD와 일치하는지 (빌드가 시작되면 일치하는 것이다)
2. `Makefile`의 버전이 `7.2.0-rc1`인지 (`VERSION/PATCHLEVEL/SUBLEVEL/EXTRAVERSION`)

스냅샷이 앞으로 가서 체크섬이 깨지면 `pmbootstrap checksum`으로 **묻지 말고**
그대로 두지 말 것 — 새 베이스에서는 패치 18개가 어긋날 수 있다. 이 경우 베이스
이동 작업을 별도로 하고 HANDOFF에 기록한다.

## 4. 첫 빌드 (풀)

```sh
cd ~/pmos-gta4xlwifi
./scripts/ksetup.sh                              # 타르볼 전개 + 패치 18개 적용
./scripts/kbuild.sh defconfig exynos9610.config  # 최초 1회
./scripts/kbuild.sh                              # 풀빌드 (~30분)
cd ~/gta4xlwifi/kernel/linux-for-next            # KERNEL_DIR 변경 시 경로 주의
pmbootstrap build --envkernel linux-samsung-exynos9610   # apk 포장 (~10초)
pmbootstrap install --password 147147            # rootfs + boot.img 생성 (3~4분)
```

산출물: `~/.local/var/pmbootstrap/chroot_rootfs_samsung-gta4xlwifi-mainline/boot/boot.img`.
`--password`는 개발용 rootfs 임시값이다. `install`이 대화형으로 멈추면 이 플래그가
빠진 것이다.

빠른 반복(증분)은 `scripts/README-build.md` 참조. 요약:
`kbuild.sh dtbs`(수 초) → `--envkernel`(10초) → `install`(3~4분).
단 **새 패치 파일 추가는 `ksetup.sh` 재생성 = 풀빌드를 강제**한다.
`.c` 실험은 트리를 직접 고치고 증분 빌드한 뒤, 굳어지면 패치 파일로 만들 것.

## 5. 플래시와 로그 회수

```sh
fastboot flash boot boot.img
fastboot flash dtbo dtbo.img
fastboot reboot
```

- `boot` 파티션 실측 59.0 MiB, `dtbo` 8.0 MiB. 50MB 넘는 boot.img는 의심할 것.
- 기기는 화면 디버그 셸로 들어간다 (기대값). initramfs의 90초 타이머가 warm 리셋을 건다.
- 리셋 후 recovery에서: `adb pull /sys/fs/pstore/console-ramoops-0`
- 하드 전원 차단(볼륨키 강제종료)은 DRAM을 날려 ramoops를 잃는다. 금지.

빌드 없이 바로 시험하려면 Releases의 이미지(`boot-debugshell-20260906.img` 등)를
받아 위 순서대로 플래시하면 된다. 덤프 포함 최신본(0018)은 릴리즈에 없으므로
4장의 절차로 직접 빌드하거나, `gh auth login` 후
`gh release upload boot-20260906-0505 boot-0018-phy-regdump-20261002.img`로 올린다.

## 6. vendored initramfs 안내

`packages/uniloader-exynos9610/gta4xlwifi.initramfs`(13MB, git 추적 중)는 pmOS
initramfs에 `/init` 진단핵을 박은 것이다. 현재 들어있는 핵 (`diff`로 전수 확인됨):

1. 첫머리 `PMOSMARK init-entered` 마커
2. 90초 뒤 UDC 상태 6종(`state/current_speed/soft_connect/function/is_a_peripheral/`
   `maximum_speed`)을 `PMOSDIAG2`로 kmsg에 찍고 `sync` 후 `reboot -f`
3. `setup_log` 뒤 UDC/configfs 존재 여부를 `PMOSDIAG`로 출력

(`set -x`는 ramoops를 밀어내서 제거된 상태다.)

재생성 절차 (핵을 고쳐야 할 때):

```sh
mkdir newroot && cd newroot
zcat ../gta4xlwifi.initramfs | cpio -idm
# init 수정
find . | cpio -o -H newc | gzip -9 > ../gta4xlwifi.initramfs
pmbootstrap checksum uniloader-exynos9610   # sha512sums 재생성
```

이 핵들은 USB가 붙으면 제거하는 게 맞다 (장기 bootargs의 `clk_ignore_unused` 포함).

## 7. 함정 모음

- `pmbootstrap install --zap`은 네이티브 chroot를 날려 `make`가 사라진다.
  `kbuild.sh`가 툴체인을 매번 `apk add`로 복구하므로 그대로 쓰면 된다.
- 빌드가 kill되면 qemu 바인드마운트가 남아 다음 빌드가 exit 32로 실패한다:
  `sudo pkill -9 -f qemu-aarch64-static` 후 재시도.
- `~/.local/var/pmbootstrap/packages/`(apk)와 `cache_git/pmaports`는 살아남지만
  `/tmp`와 chroot 내용은 언제든 날아간다.
- apk 캐시(`cache_apk_*`, `cache_ccache_*`)는 root 소유 파일이 섞여 있어 정리할 때
  `sudo rm`이 필요하다. 지워도 되는 재생성 캐시다.
- `patch` 파일에 줄을 추가하면 hunk 헤더 `@@ -A,B +C,D @@`의 카운트를 정확히
  맞출 것. 틀리면 `patch`가 뒤를 조용히 잘라먹거나 `malformed patch`로 죽는다.
  안전策: 트리에 직접 적용 후 `diff -u`로 패치를 뽑아낸다.
- `sha512sums`는 손으로 계산하지 말 것. `pmbootstrap checksum <pkg>`.
