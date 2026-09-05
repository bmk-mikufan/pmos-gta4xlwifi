# 커널 빌드

## 빠른 반복 (권장) — 증분 빌드

`pmbootstrap build`는 `abuild`가 매번 srcdir을 지우고 다시 풀기 때문에 DTS 한 줄만
고쳐도 풀빌드다. 대신 커널 트리를 하나 두고 증분으로 돌린다. pmbootstrap의
`helpers/envkernel.sh`와 같은 원리(트리를 네이티브 chroot에 bind-mount)인데,
envkernel.sh는 gcc 크로스컴파일러를 하드코딩하고 이 커널은 clang/lld(`LLVM=1`)로
빌드하므로 make를 직접 호출한다.

```sh
./scripts/ksetup.sh                              # 트리 생성 (패치 적용 포함)
cd ~/gta4xlwifi/kernel/linux-for-next
~/gta4xlwifi/pmos-gta4xlwifi/scripts/kbuild.sh defconfig exynos9610.config
~/gta4xlwifi/pmos-gta4xlwifi/scripts/kbuild.sh              # 전체
~/gta4xlwifi/pmos-gta4xlwifi/scripts/kbuild.sh dtbs         # DTS만 -- 수 초
JOBS=8 ~/gta4xlwifi/pmos-gta4xlwifi/scripts/kbuild.sh       # 병렬도 조절
```

패키지로 포장:
```sh
cd ~/gta4xlwifi/kernel/linux-for-next
pmbootstrap build --envkernel linux-samsung-exynos9610
```

주의:
- **`00NN-*.patch`를 고쳤으면 `ksetup.sh`를 다시 돌려야 한다.** 트리는 그냥 풀어놓은
  타르볼이라 패치가 자동으로 다시 적용되지 않는다.
- 트리에 in-tree 빌드 산출물이 생기면 `O=.output` 빌드가 "The source tree is not
  clean"으로 거부한다. 호스트에서 그냥 `make` 돌리지 말 것. 꼬였으면 `ksetup.sh`.
- chroot의 `pmos` 사용자와 호스트 uid가 달라서 `.output`은 chroot 쪽 소유가 된다.
  소스 트리 자체는 읽기만 하므로 문제없다.

## 풀빌드 (릴리스/검증용)

```sh
nohup pmbootstrap build linux-samsung-exynos9610 --force > /tmp/k.log 2>&1 < /dev/null & disown
```

`run_in_background`로 돌리는 Bash 툴 호출은 긴 세션에서 임의로 kill되므로
`nohup ... & disown`으로 떼어 놓고 PID를 폴링할 것.

빌드가 kill되면 qemu 바인드마운트가 남아 다음 빌드가 exit 32로 실패한다:
```sh
sudo pkill -9 -f qemu-aarch64-static
```

## boot.img 만들기

```sh
pmbootstrap install --zap --password <pw>
```

`--password` 없이 돌리면 rootfs `user` 계정 비밀번호를 대화형으로 묻다가
비대화형 실행에서는 그냥 죽는다. 산출물은
`~/.local/var/pmbootstrap/chroot_rootfs_samsung-gta4xlwifi-mainline/boot/`의
`boot.img` / `dtbo.img`.
