# HANDOFF — 새 에이전트 인수인계 문서

최종 갱신: 2026-10-04 (0018 덤프 빌드 완료·미플래시 상태 반영. 1·5·9장 갱신)

이 문서 하나만 읽어도 작업을 이어받을 수 있도록 정리한 요약본이다.
세부는 `CLAUDE.md`(작업 규칙), `docs/local/workflow.md`(전체 절차),
`docs/포팅_작업_기록.md`(날짜별 전체 기록), `docs/local/findings/`(측정 결과)에 있다.

---

## 1. 한 줄 요약

Galaxy Tab S6 Lite Wi-Fi(SM-P610, Exynos 9611)에 메인라인 리눅스를 올리는 중이다.
2026-09-06 심야 세션에서 **`/init` 직후 하드 리셋은 더 이상 재현되지 않고 디버그 셸까지 도달**했다.
현재 블로커는 **USB 가젯 호스트 열거 실패 (`state=not attached`)** — 10장 참조.
2026-10-02에 PHY 레지스터 readback 덤프 패치(0018)까지 넣고 빌드·부트 이미지 생성까지
끝냈다. **플래시 + ramoops 회수가 다음 순서**다 (9장).

---

## 2. 하드웨어 / 소프트웨어 좌표

| 항목 | 값 |
|---|---|
| 기기 | Samsung Galaxy Tab S6 Lite Wi-Fi, SM-P610, 코드네임 `gta4xlwifi` |
| SoC | Exynos 9611 (9610 계열, A73×4 + A53×4, PSCI v0.1) |
| 커널 | `linux-for-next` 7.2.0-rc1 스냅샷 + 패치 16개 |
| 부트로더 | **uniLoader** (https://github.com/ivoszbg/uniLoader) — Samsung boot.img 안에 payload로 들어감 |
| 빌드 | pmbootstrap, 작업 트리는 `~/.local/var/pmbootstrap/cache_git/pmaports/device/testing/` |
| 이 저장소 | 위 작업 트리의 **미러/백업**. `packages/`가 pmaports 쪽과 rsync로 동기화된다 |
| 상류 협업자 | Alexandru Chimac — clocks/pinctrl/USB 담당. 경계는 `docs/local/upstream.md` |

### 파티션 크기 (fastbootd에서 실측 ✅, 2026-09-06)
`fastboot getvar partition-size:<part>`로 확인:

| 파티션 | 크기 |
|---|---|
| `boot` | `0x3B00000` = 61,865,984 B = **59.0 MiB** |
| `dtbo` | `0x800000` = 8.0 MiB |

다이어트 이전 boot.img가 57.5 MiB였으니 **여유가 1.47 MiB뿐이었다.** 추측하던 64 MiB가
아니다. `CONFIG_FUNCTION_TRACER`(+2~3MB)를 켰으면 파티션을 넘겨서 플래시가 실패했을 것이다.
config 다이어트로 Image가 46MB -> 29.4MB가 되면서 여유가 확보됐다.

기기는 fastbootd로 붙는다 (`fastboot devices` -> `R54N900QNNR fastbootd`,
`getvar product` -> `gta4xlwifi`). Odin/heimdall 없이 fastboot로 플래시 가능하다.

### 빌드 환경 제약 (중요)
- 빌드 머신 RAM 14GB, 16코어 (2026-09-06에 7.5GB에서 증설). APKBUILD의 `build()`는 `-j8`.
- **풀빌드를 반복 작업에 쓰지 말 것.** `abuild`는 매번 srcdir을 지우고 다시 풀어서 DTS 한 줄만
  고쳐도 30분이 걸린다. 대신 `scripts/kbuild.sh`(증분, `O=.output`) +
  `pmbootstrap build --envkernel`을 쓴다 — DTS만이면 수 초, 포장 10초.
  절차와 함정은 `scripts/README-build.md`.

---

## 3. 부트 체인 — 반드시 이해하고 시작할 것

세 단계에서 각각 다른 DTB가 쓰인다. 여기서 여러 번 헛발질했다.

```
S-BOOT (Samsung)
  └─ boot.img(v2 헤더) 안의 "main dtb" + 별도 dtbo 파티션의 오버레이를
     UFDT로 합쳐본다. 이게 실패하면 커널 payload로 점프조차 안 한다.  ← 하드 게이트
  └─ 성공하면 boot.img의 kernel payload = uniLoader 로 점프
uniLoader
  └─ boot.img의 dtb와 /chosen/bootargs를 전부 무시한다.
     자기 빌드 시점에 정적으로 링크한 blob/dtb 를 x0에 넣고 커널로 점프.
     (arch/aarch64/start.S 에서 x0를 자기 dtb 포인터로 덮어씀 — 소스 확인 ✅)
Linux
  └─ 따라서 실제로 커널이 보는 bootargs 는
     0013-...-Samsung-Galaxy.patch 안 /chosen 의 `bootargs = "...";` 문자열이다.
     `deviceinfo_kernel_cmdline` 은 아무 효과가 없다. ✅
```

이 구조에서 나온 두 가지 해결책:
- **dtbo**: 다운스트림 stock dtbo는 `dsim_0` 같은 다운스트림 전용 노드를 참조해서 메인라인 dtb에
  안 붙는다. 대신 `device-samsung-gta4xlwifi-mainline`의 `package()`가 **빈 no-op 오버레이**
  (`fragment@0` / `target-path = "/"` / 빈 `__overlay__ {}`)를 만들어 넣는다. 형식 검사만 통과하면
  되므로 이걸로 S-BOOT 게이트를 통과한다. ✅
- **`-@` 심볼 테이블**: main dtb에 `__symbols__`가 없으면 S-BOOT가 "No node __symbols__ in main dtb"로
  거부한다. APKBUILD의 `DTC_FLAGS_exynos9610-gta4xl=-@`가 그걸 강제한다. 지우지 말 것. ✅

---

## 4. 현재 증상 — 정확히 어디서 죽는가

유일하게 확보한 메인라인 부팅 로그는 `logs/console-ramoops-0.log` (4018줄, `initcall_debug` 켠 상태).
마지막 두 줄:

```
[  132.834164] Run /init as init process
[  132.910118] calling  init_module+0x0/0xfd0 [libcomposite] @ 97
[  132.917883] initcall init_module+0x0/0xfd0 [libcomposite] returned 0 after 22 usecs
```

그 뒤로 아무것도 없고 기기가 리셋된다.

`libcomposite` modprobe는 pmOS initramfs의 `init_functions.sh` → `mount_proc_sys_dev()` 안에 있다.
그 직후에 실행되는 것은 **셸 명령 5~6개뿐**이고, 전부 하드웨어를 건드리지 않는다:

```sh
modprobe libcomposite          # ← 여기까지 로그에 찍힘
mount -t configfs ...
mkdir -p /dev/pts ; mount -t devpts ...
ln -s /proc/self/fd /dev/fd
parse_cmdline < /proc/cmdline
setup_log                      # exec > >(tee ... | logger)
echo "  ❬❬ PMOS STAGE 1 ❭❭"    # ← 이 줄이 로그에 절대 안 나온다
```

즉 **`Run /init` 이후 1초 안에, 커널이 아무 printk도 못 남기고 죽는다.**
oops/panic 로그가 전혀 없다 = 소프트웨어 예외가 아니라 **외부 리셋(하드웨어)** 일 가능성이 높다.

### 로그를 읽을 때 주의
이 로그의 cmdline에는 `boot_delay=30`이 들어 있다. printk 한 줄마다 30ms를 넣으므로
4018줄 × 30ms ≈ 120초가 순수 지연이다. **132초는 실제 부팅 시간이 아니라 ~12초짜리 부팅이
늘어난 것**이다. 현재 DTS의 bootargs에서는 `boot_delay`가 빠져 있다.

---

## 5. 배제된 가설 (다시 파지 말 것)

| 가설 | 결론 | 근거 |
|---|---|---|
| 하드웨어 워치독 (CPUCL0 `0x10050000` / CPUCL1 `0x10060000`) | ❌ 원인 아님 | 두 인스턴스 모두 DTS에 추가 → dmesg에 `watchdog inactive, reset disabled, irq disabled` 확인. 그래도 리셋 동일. (수정 자체는 옳으므로 유지) |
| ACPM / mailbox 드라이버 | ❌ 원인 아님 | 해당 DT 노드를 `status = "disabled"`로 완전히 죽이고 재빌드해도 **동일 지점에서 동일하게** 리셋 |
| genpd (power domain) | ❌ 원인 아님 | 트리에 등록된 power-domain provider 노드가 0개. `genpd_power_off_unused()`가 돌 대상이 없음 (로그 줄은 장식) |
| chimac clocks 드라이버 v3 vs v1 | ❌ 원인 아님 | v1으로 되돌려 빌드/플래시했으나 **v1도 동일하게 리부팅** (2026-09-06 확인). 원인이 아니므로 **LKML에 올라간 v3로 다시 복귀했다.** v1 백업은 git history에만 보존. |
| dtbo/bootargs 전달 문제 | ✅ 해결됨 | 위 3장 참조. 이제 bootargs가 실제로 커널에 도달한다 |
| initramfs에 `/init` 없음 | ✅ 해결됨 | 실제 pmbootstrap이 만든 initramfs를 `uniloader-exynos9610/gta4xlwifi.initramfs`로 vendoring |

---

## 6. 남은 가설 — 다음 세션에서 검증할 것 (우선순위 순)

### (A) 리셋이 "시간 기반"인지 "`/init` 도달 기반"인지부터 가른다 ★ 최우선
지금 있는 로그 하나로는 구분이 안 된다. 132.9초에 죽은 게
- 부팅이 `/init`에 도달해서인지,
- 아니면 그냥 전원 인가 후 ~133초라는 절대 시각에 외부 감시자가 리셋한 것인지

모른다. **현재 DTS에는 `boot_delay`가 없으므로 부팅이 ~10초 만에 `/init`에 도달한다.**
그러니 지금 플래시되어 있는 v1 빌드의 `console-ramoops-0`를 한 번만 뽑으면 즉시 갈린다:

- 마지막 타임스탬프가 **~10초대**이고 여전히 `libcomposite` 직후 → **`/init` 도달이 트리거**
- 마지막 타임스탬프가 여전히 **~130초대**이고 훨씬 더 진행한 상태 → **고정 타임아웃(외부 감시자)**

이 한 번의 로그 수집이 앞으로의 방향을 전부 결정한다. 다른 건 다 이거 다음이다.

로그 수집 방법: 기기를 recovery(TWRP)로 부팅해서
```sh
adb pull /sys/fs/pstore/console-ramoops-0
```
(`dmesg-ramoops`는 panic이 나야 생기므로 없을 것이다. `pmsg`는 이 커널에 `CONFIG_PSTORE_PMSG`가
꺼져 있어 `/dev/pmsg0`가 아예 없다 — 확인됨 ✅)

### (A-2) reserved-memory 누락 — 2026-09-06 신규, 현재 1순위 가설 ★
다운스트림 `exynos9610-rmem.dtsi` + 실기기 `last_kmsg`를 대조한 결과, **메인라인 DTS가
펌웨어가 런타임에 계속 쓰는 영역들을 리눅스 페이지 할당자에 그대로 넘기고 있었다.** ✅

| 영역 | 주소 | 메인라인 상태(수정 전) |
|---|---|---|
| `sec_debug_magic` | `0x80000000` +0x1000 | 미예약 |
| `seclog` (EL3 보안 로그) | `0xC0000000` +0x80000 | 미예약, usable RAM 한복판 |
| `modem_if` (CP) | `0xED000000` +0x8A00000 | 미예약 |
| `cp_ram_logging` | `0xF5A00000` +0x1E00000 | 미예약 |
| debug-snapshot(DSS) | `0xF9000000`..`0xFA710000` | ramoops로 쓰는 pstore 슬롯 2MB만 예약 |
| `gnss_if` | `0xFB000000` +0x800000 | 미예약 |
| `chub_rmem` (센서허브) | `0xFD000000` +0x80000 | 미예약 |

결정적으로 부팅 로그의 `software IO TLB: mapped [mem 0xfa000000-0xfe000000]` (64MB SWIOTLB)가
**DSS kevents + gnss_if + chub_rmem 위에 그대로 얹혀 있다.** CHUB/GNSS/APM 같은 코프로세서는
S-BOOT가 켜 둔 채로 리눅스와 무관하게 계속 돌기 때문에, 서로 메모리를 덮어쓰면 로그 한 줄 없이
SoC가 리셋된다 — 지금 증상과 정확히 일치한다.

또한 ramoops 주소 `0xF9D10000`은 우연이 아니라 다운스트림 DSS의 `log_pstore` 슬롯과 정확히
같은 자리다(계산으로 확인 ✅). 즉 ramoops 배치 자체는 옳다.

**조치**: `0012-...-Exynos9610.patch`의 `reserved-memory`에 위 영역들을 `no-map`으로 추가했다
(2026-09-06). DSS는 ramoops 슬롯을 비켜 `0xf9000000+0xd10000` / `0xf9f10000+0x800000` 두 덩이로
쪼갰다. `dtc` 컴파일까지는 검증했고 **실기기 테스트는 아직 안 했다.**

### (B) APM/ACPM 펌웨어의 AP 감시 (🟡 추정, 가장 유력)
Exynos의 APM 코어에서 도는 ACPM 펌웨어는 AP가 살아있는지 감시한다. 다운스트림 리눅스는
ACPM IPC로 주기적으로 핑을 보낸다. 메인라인은 안 보낸다 → 일정 시간 뒤 APM이 SoC를 리셋.
- 이게 맞다면 (A)에서 "고정 타임아웃" 쪽으로 나온다.
- 리눅스 쪽 ACPM **드라이버**를 끄는 실험(이미 함)으로는 반증되지 않는다. 감시자는 APM 펌웨어 쪽이라
  리눅스가 뭘 하든 상관없이 돌기 때문이다. 앞선 "ACPM 배제" 실험이 이 가설을 배제하지 **못한다**.

### (C) 저장장치 드라이버가 하나도 없다 (✅ 사실, 리셋 원인은 아닐 수 있으나 진행을 막음)
로그에 MMC/UFS 드라이버 probe가 전혀 없다. 즉 `/init`이 `mount_subpartitions` →
`wait_boot_partition`까지 가면 무한 대기한다. 리셋이 해결돼도 이게 다음 벽이다.

### (D) TMU 하드웨어 온도 트립 (🟡 낮음)
부트로더가 무장해 둔 TMU 긴급 트립이 남아 있을 수 있다. 다만 `boot_delay` 보정 후 실제 부팅이
~12초뿐이라 발열로 트립할 시간이 안 된다 → 가능성 낮음. (A)에서 시간 기반으로 나오면 재고.

### (E) 확인 안 된 사실 메모
- PSCI는 v0.1 (`compatible = "arm,psci"`, `cpu_suspend/cpu_off/cpu_on` function ID만 있음).
  `cpu-idle-states`가 DTS에 없으므로 CPU idle은 그냥 WFI다. 여기가 원인일 근거는 아직 없다.
- 부팅 초기에 `/soc@0/clock-controller@12100000: Unable to get CMU sysreg` 경고가 있다. 미조사.
- `exynos-clkout ... probe ... failed with error -22`. 미조사.

---

## 7. 저장소 구조

```
CLAUDE.md                     작업 규칙 (절대 규칙 7개 — 반드시 먼저 읽을 것)
HANDOFF.md                    이 문서 (10장에 9/6 심야 세션 결과)
README.md                     저장소 개요
.claude/
  agents/                     source-digger, build-triage 서브에이전트 정의
  skills/                     kernel-tree, kconfig, qr-log 스킬
packages/                     ★ pmaports 작업 트리의 미러 (메인라인)
  linux-samsung-exynos9610/     패치 0001~0017 + exynos9610.config + APKBUILD
  device-samsung-gta4xlwifi-mainline/   deviceinfo + no-op dtbo 생성
  uniloader-exynos9610/         uniLoader + vendored initramfs
downstream/                   다운스트림(LineageOS 4.14) 패키지 — 부팅 성공한 쪽
logs/                         실기기에서 뽑은 로그 (console-ramoops, last_kmsg)
docs/
  포팅_작업_기록.md            ★ 날짜별 전체 작업 기록 (가장 상세)
  local/workflow.md            Phase 0~7 전체 절차/명령/주소
  local/hardware.md            검증된 하드웨어 사실
  local/upstream.md            chimac 협업 경계
  local/findings/              날짜별 측정 결과
scripts/                      ksetup.sh/kbuild.sh + README-build.md (증분 빌드)
```

삭제된 것 (2026-10-02 정리, git history에 보존):
`docs/local/wiki/` (오프라인 위키 사본 9개),
`docs/pmos_*.md` 5개 (`docs/local/`과 중복),
`patches/chimac/` (LKML 원본 — `packages/`의 17개 패치로 진화),
`packages/u-boot-exynos9610/` (부트 체인은 uniLoader라 미사용),
`packages/.../v1-backup/` (clocks v1 백업),
`scripts/build-kernel.sh` (`kbuild.sh`로 대체).

`packages/`를 고칠 때는 **pmaports 쪽이 원본**이다:
```sh
PM=~/.local/var/pmbootstrap/cache_git/pmaports/device/testing
# 편집은 $PM/<pkg>/ 에서 → 그다음 이 저장소로 동기화
rsync -a --delete "$PM/<pkg>/" packages/<pkg>/
```

---

## 8. 자주 밟는 지뢰 (실제로 다 밟았음)

1. **`sha512sums`는 절대 손으로 계산하지 말 것.** `source=` 파일을 하나라도 고쳤으면
   `pmbootstrap checksum <pkgname>`. 이걸 안 해서 빌드 여러 번 날렸다.
2. **patch 파일의 hunk 헤더 `@@ -0,0 +1,N @@`의 N을 직접 세서 고칠 것.**
   patch 파일 안에 줄을 추가했는데 N을 안 고치면 `patch`가 **조용히 뒤를 잘라먹고** 에러도 안 낸다.
   나중에 엉뚱하게 `dtc` 문법 오류로 튀어나온다.
3. **패치 편집 후에는 풀빌드 전에 로컬 드라이런.** 캐시된 `linux-for-next.tar.gz`를 풀고
   패치 16개를 `patch -p1 --forward`로 적용 → `clang -E` 전처리 → `dtc -@` 컴파일.
   25~40분짜리 빌드를 돌리기 전에 2분이면 끝난다.
4. **`run_in_background: true`인 Bash 호출이 긴 세션에서 임의로 kill된다.** 자원과 무관하게
   10초짜리 빌드도 죽었다. 대신 이렇게:
   ```sh
   nohup pmbootstrap build <pkg> > /tmp/b.log 2>&1 < /dev/null & disown
   echo $!   # 이 PID를 Monitor 도구에서 kill -0 로 폴링
   ```
5. **빌드가 kill되면 qemu 바인드마운트가 남는다.** 다음 빌드가
   `umount .../qemu-aarch64-static` exit 32로 실패한다 →
   `sudo pkill -9 -f qemu-aarch64-static` 후 재시도.
6. **`/tmp` 스크래치는 세션 중에도 날아갈 수 있다.** 반면
   `~/.local/var/pmbootstrap/packages/edge/aarch64/*.apk`(빌드 산출물)와
   `cache_git/pmaports`(소스)는 살아남는다. 그러니 이미지가 사라졌으면
   **재컴파일 없이** `pmbootstrap install --zap`만 다시 돌리면 boot.img/dtbo.img가 복원된다.

---

## 9. 지금 상태에서 바로 할 일

1. Releases에서 `boot-0018-phy-regdump-20261002.img` — 릴리즈 미업로드 상태이므로
   SETUP.md 4장 절차로 직접 빌드하거나 `gh auth login` 후 업로드 — 와
   `dtbo-20260906.img`를 받아
   `fastboot flash boot` / `fastboot flash dtbo` 후 부팅 — 화면 디버그 셸 도달이 기대값.
   이 이미지의 커널은 PHY init 직후 `usbdrd-phy readback:` 한 줄과 매 PMU 격리 변경마다
   `usbdrd-phy PMU ...` 한 줄을 kmsg에 남긴다 (패치 0018, upstream 제외용).
2. 90초 뒤 자동 warm 리셋 후 recovery에서 `adb pull /sys/fs/pstore/console-ramoops-0`.
   읽을 것: `readback:` 줄의 UTMI 비트 5(VBUS force-valid)와 HSP 비트 12·13,
   `PMU 0x704 ... readback=` 값, `PMOSDIAG2` UDC 상태 6종.
   - 쓰기 값 ≈ 읽기 값인데도 `not attached` → DWC3 풀업/세션 쪽(가설 2) 또는 tune 값(가설 3)
   - 읽기 값이 0 또는 쓰기와 다름 → 전원/클럭 미인가(가설 1). power domain·게이트 추적
3. 반복 주기: `scripts/kbuild.sh dtbs`(수 초) → `pmbootstrap build --envkernel`
   (10초) → `pmbootstrap install --zap` (3~4분). 풀빌드는 쓰지 말 것.
   단 **새 패치 파일 추가는 트리 재생성(=풀빌드)을 강제**하므로, `.c` 실험은 트리를
   직접 고치고 증분 빌드한 뒤 결과만 패치로 굳힐 것 (10/02에 30분 날린 교훈).

## 10. 2026-09-06 심야 세션 결과 (이 HANDOFF 작성 이후 진행분)

6장 (A) 실험 결과: 계측 전 빌드의 ramoops 마지막 타임스탬프 **9.92초**
(`logs/console-ramoops-reset-9.9s.log`). 즉 리셋은 고정 타임아웃이 아니라
**`/init` 도달이 방아쇠**였다. APM 감시 가설 (B)도 약화. reserved-memory 수정은
SWIOTLB 재배치(`0xfa000000` → `0xe5400000`)까지 의도대로 먹었으나 리셋은 그대로라
가설에서 배제 (수정은 유지).

그 뒤 `set -x` 계측 initramfs를 넣은 빌드가 **디버그 셸까지 도달**했다. 커널은
동일하고 initramfs만 달라서 (44,304,384 vs 44,300,288 B), `set -x` 타이밍 효과인지
cpio 재포장 차이인지는 미확정. `~/gta4xlwifi/backup/2026-09-06_debugshell/`에 양쪽
이미지·initramfs·apk·리셋 로그 보존.

이후 확정된 것:
- **재부팅 수단 없음 → 해결.** PSCI v0.1이라 `SYSTEM_RESET`이 없고 WDT restart도
  9610 PMU 오프셋 불일치로 불발. 다운스트림 `exynos-reboot.c`에서 검증한
  PMU SWRESET `0x0400`/`0x1` `syscon-reboot` 노드 추가로 `reboot: Restarting
  system` 동작. warm 리셋이라 ramoops가 손상 없이 남는다.
- **PSTORE_PMSG 동작.** `[pmOS-rd]:` 유저스페이스 줄이 ramoops에 들어온다.
- **USB 컨트롤러 올라옴.** `usbdrd_phy`/`udc` `status disabled` 해제,
  `compatible` → `samsung,exynos850-dwusb3`, refclk → `&oscclk` 26 MHz (드라이버가
  49,968,750 Hz 거부), `samsung,pmu-syscon` 추가, `USB_LIBCOMPOSITE`/`CONFIGFS` +
  `USB_G_SERIAL` + `U_SERIAL_CONSOLE` built-in. 결과:
  `probe of 131d0000.phy returned 0`, `probe of 13200000.usb returned 0`,
  `g_serial ready`, `PMOSDIAG udc=[13200000.usb]`.
- **호스트 열거는 실패.** `state=not attached`, `current_speed=UNKNOWN`.
  소스/실측으로 배제한 것: 클럭 게이팅 (`clk_ignore_unused`로도 동일),
  role-switch 우회 (노드에 `orientation-switch` 없음),
  PHY 레지스터 오프셋·VBUS valid 비트 정의 (다운스트림과 전부 일치),
  PMU enable 마스크 (패치 0017, 효과 없음).
- 빌드: config 다이어트로 심볼 4639 → 2716, Image ~46MB → 29.4MB (현재 ~31MB,
  `g_serial` 포함). `boot` 파티션 실측 59.0 MiB 대비 여유 확보.
  증분 `kbuild.sh` + `--envkernel`로 커널 45초 / 전체 사이클 5분.

주의: 이 세션의 initramfs 진단 핵 (`set -x`, `PMOSMARK` 90초 auto-reboot 타이머,
`PMOSDIAG` UDC/configfs 덤프, `rd.info`·`clk_ignore_unused` bootargs)은
**재포장 테스트용이라 `packages/`·pmaports에 커밋되지 않았다.**
재현하려면 `scripts/README-build.md` 절차로 initramfs를 풀어 `/init`에 삽입.
`clk_ignore_unused`는 진단용이므로 장기 bootargs에 남기지 말 것.
