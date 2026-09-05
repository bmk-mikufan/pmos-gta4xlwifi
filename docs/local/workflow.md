# gta4xlwifi 메인라인 포팅 워크플로 (개정판)

postmarketOS 공식 위키 기준으로 재작성. **UART 시리얼 케이블 제작 불가**를 전제로 한다.

> 출처: Mainlining Guide, Mainlining FAQ, Porting to a new device/Kernel package,
> User:Knuxify/Enabling pstore and ramoops, Category:Samsung Exynos

---

## 0. 전제 조건과 제약

### 확정된 제약
- ❌ **UART 시리얼 불가** (619k 지그 제작 안 함)
- ❌ 메인라인 USB 미동작 → SSH/telnet 불가
- ❌ 메인라인 UFS/SD 미동작 → 파일 저장 불가
- ⚠️ 화면 출력만 가능하나 콘솔 2중 출력 버그 있음

### 위키가 요구하는 것 vs 현재 상태

Mainlining Guide의 체크리스트:

| 요구사항 | 상태 |
|---|---|
| 다운스트림 pmOS 포팅 완료 | ✅ |
| 시리얼 케이블 **또는 적절한 우회책** | ⚠️ 우회책 구축 필요 ← **최우선** |
| debug-shell initramfs | ❌ 미구성 |
| envkernel.sh 동작 확인 | ❌ 미구성 |

> 위키 원문: "It is recommended to have a working serial cable. In case you can not
> make one, it might be possible to use a workaround for retrieving log messages
> but that isn't straight forward. You can also use a framebuffer console."

**우회책이 정식으로 인정된 경로다.** FAQ에 전용 섹션이 있다.

---

## Phase 0 — 도구 구축

### 0-1. envkernel.sh 셋업 (필수, 지금까지 누락)

로컬 git 커널 트리를 직접 빌드하는 공식 방법. chimac 패치를 `git am`으로 적용한
트리를 그대로 쓸 수 있다.

```bash
cd ~/code
git clone https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git
alias pmbootstrap=$PWD/pmbootstrap/pmbootstrap.py
pmbootstrap init          # 기기 선택, UI는 none

# 커널 트리
git clone https://github.com/torvalds/linux.git --depth 1
cd linux
git remote add linux-next https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
git fetch --tags linux-next
git checkout -b device-samsung-gta4xlwifi linux-next/master

# envkernel 활성화 — 이후 make는 Alpine chroot에서 실행됨
source ~/code/pmbootstrap/helpers/envkernel.sh
```

빌드:
```bash
pmbootstrap build --envkernel linux-postmarketos-exynos9610
```

### 0-2. kconfig 수정 — 비대화형 절차 (TUI 없이)

> ⚠️ 위키 경고: `config-*.aarch64` 파일을 직접 편집하면 **의존성이 해결되지 않고
> 변경이 조용히 무시된다.** 반드시 아래 절차를 경유할 것.
>
> 위키는 스크립트를 통한 config 병합을 별도 항목으로 인정한다
> (FAQ "How to merge kernel configs?" → Kernel configuration#Automatically
> merging kernel configuration).

**핵심: envkernel.sh 환경에서는 TUI가 아예 필요 없다.**
커널 트리의 일반 `.config`를 다루므로 `merge_config.sh` + `olddefconfig`로 끝난다.

#### 개발 중 (Phase 1~5) — 전부 자동화 가능

```bash
source ~/code/pmbootstrap/helpers/envkernel.sh

# 1. 베이스 config 확보 (pmaports 것 또는 defconfig)
cp ~/code/pmaports/device/testing/linux-postmarketos-exynos9610/config-*.aarch64 \
   .output/.config
# 또는: make exynos_defconfig

# 2. fragment 작성
cat > /tmp/debug.fragment << 'EOF'
CONFIG_PSTORE=y
CONFIG_PSTORE_CONSOLE=y
CONFIG_PSTORE_RAM=y
CONFIG_PSTORE_PMSG=y
CONFIG_KEXEC=y
CONFIG_DEVMEM=y
# CONFIG_STRICT_DEVMEM is not set
EOF

# 3. 병합 — olddefconfig을 자동 실행하여 의존성 해결
./scripts/kconfig/merge_config.sh -m .output/.config /tmp/debug.fragment
make olddefconfig

# 4. 빌드
make -j$(nproc)
```

#### ★ 3단계 출력을 반드시 확인할 것

`merge_config.sh`는 요청한 심볼이 최종 config에 들어가지 않으면 경고를 낸다.
**위키가 경고한 "silently ignored"를 막아주는 것이 바로 이 검증이다.**

```
Value requested for CONFIG_KEXEC not in final .config
Requested value:  CONFIG_KEXEC=y
Actual value:
```

이게 뜨면 의존성 미충족. 상위 심볼을 찾아 fragment에 추가한다:

```bash
grep -B2 -A12 "^config KEXEC" arch/arm64/Kconfig
grep -B2 -A12 "^config USB_CONFIGFS_ACM" drivers/usb/gadget/Kconfig
# depends on 줄을 보고 상위 심볼을 fragment 앞쪽에 추가
```

예: ACM은 순서대로 전부 필요하다.
```
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_U_SERIAL=y
CONFIG_USB_CONFIGFS_ACM=y
```

#### 최종 확인

```bash
grep -E "^CONFIG_(PSTORE|KEXEC|DEVMEM)" .output/.config
grep "STRICT_DEVMEM" .output/.config
```

#### 패키지에 반영할 때 (Phase 6)

```bash
cp .output/.config \
   ~/code/pmaports/device/testing/linux-postmarketos-exynos9610/config-....aarch64
pmbootstrap checksum linux-postmarketos-exynos9610      # ★ 빼먹지 말 것
pmbootstrap kconfig check linux-postmarketos-exynos9610 # 비대화형 검증
```

> `pmbootstrap kconfig edit`은 종료 시 체크섬을 자동 재생성하지만,
> 수동 경로에서는 `pmbootstrap checksum`을 직접 실행해야 한다.

#### 명령 분류

| 실행 주체 | 명령 |
|---|---|
| **자동화 가능** | `merge_config.sh`, `make olddefconfig`, `pmbootstrap kconfig check`, `pmbootstrap checksum`, `grep` 검증 |
| **금지 (TUI, 행 걸림)** | `pmbootstrap kconfig edit`, `make menuconfig`, `make nconfig` |

#### TUI가 필요한 유일한 경우

**심볼 이름을 모르고 메뉴를 탐색해야 할 때.** 이것도 대체로 grep으로 가능하다:
```bash
grep -rn "config.*ACM" drivers/usb/gadget/Kconfig
grep -rn "^config PSTORE" fs/pstore/Kconfig
```
정 안 되면 `pmbootstrap kconfig edit -n` (nconfig, 검색이 더 낫다).

> 참고: 구형 커널에서 `kconfig edit`이 ncurses 부재로 실패하면
> `device/.shared-patches/linux/fix-check-lxdialog.patch` 적용 또는 `-n` 사용.
> 4.14 다운스트림에서 발생 가능.

### 0-3. debug-shell 훅

```bash
pmbootstrap initfs hook_add debug-shell
```

### 0-4. chimac 패치 획득 및 적용

> 이 절차는 반드시 로컬에서 수행해야 한다. patchwork/lkml.org는 봇 차단이 걸려
> 있어 자동 수집이 불가능하다. `b4`가 lore.kernel.org에서 직접 가져온다.

#### 4-1) Message-ID 확보

patchwork에서 시리즈를 연다:
```
https://patchwork.kernel.org/project/linux-samsung-soc/list/?submitter=218332&state=*
```

`[v3,1/5] dt-bindings: clock: samsung: Add Exynos9610 CMU bindings` 클릭 →
페이지 하단 **"Message ID"** 필드를 복사. 형태:
```
20260722-exynos9610-cmu-v3-0-XXXXXXXX@gmail.com
```

> 커버레터(0/5)의 Message-ID를 쓰면 시리즈 전체를 한 번에 가져온다.
> 커버레터가 없으면 1/5의 것을 써도 b4가 스레드를 따라간다.

#### 4-2) b4 설치

```bash
pip install --user b4      # 또는 apt install b4
b4 --version
```

#### 4-3) 시리즈 가져오기

```bash
cd ~/code/linux
git checkout -b device-samsung-gta4xlwifi linux-next/master

# 방법 A: mbox로 받아서 확인 후 적용
b4 am -o /tmp/patches <message-id>
less /tmp/patches/*.mbx        # 내용 확인
git am /tmp/patches/*.mbx

# 방법 B: 받아서 바로 적용 (한 방)
b4 shazam <message-id>
```

`b4 am`은 스레드에서 최신 리비전을 자동 선택하고, 회신에 달린
`Reviewed-by`/`Acked-by` 트레일러도 함께 수집한다.

#### 4-4) 필요한 시리즈 목록

**전부 필요하다. 하나라도 빠지면 빌드 또는 부팅이 안 된다.**

| 시리즈 | 최신 확인 | 역할 |
|---|---|---|
| chipid (2편) | 2025-09-14 v1 | SoC 식별 |
| pinctrl (3편) | 2026-01-02 **v3** | GPIO/핀 설정 |
| **clocks (5편)** | 2026-07-22 **v3** | CMU 드라이버 ← 핵심 |
| **arm64 dts (3편)** | 2025-09-14 v1 ⚠️ | SoC dtsi + gta4xl dts |

각각 patchwork에서 Message-ID를 따로 확보해서 순서대로 적용:
```
chipid → pinctrl → clocks → dts
```

#### ⚠️ 4-5) DT 시리즈 버전 불일치 문제 — 최대 함정

clocks 시리즈가 **v1(8편, DTS 포함) → v3(5편, DTS 분리)** 로 재구성되었다.

v1에 있던 이 세 패치가 v3에서 빠졌다:
```
4/8  arm64: dts: exynos9610: Enable clock support
7/8  arm64: dts: exynos9610: Assign clocks to existing nodes
8/8  arm64: dts: exynos9610-gta4xl: Assign clocks to existing nodes
```

**클럭 ID 매크로(`include/dt-bindings/clock/samsung,exynos9610.h`)가 v1↔v3
사이에 변경되었을 가능성이 높다.** 구 DT 패치를 v3 클럭 위에 얹으면:
- 컴파일은 통과하는데 존재하지 않는 클럭 ID를 참조 → probe 실패
- 또는 `dtc`에서 정의되지 않은 매크로 에러

**적용 후 반드시 대조할 것:**
```bash
# v3 바인딩 헤더에 있는 ID 목록
grep -c "^#define CLK_" include/dt-bindings/clock/samsung,exynos9610.h

# DTS가 참조하는 ID가 전부 존재하는지
grep -o "CLK_[A-Z0-9_]*" arch/arm64/boot/dts/exynos/exynos9610*.dts* \
  | sort -u > /tmp/used.txt
grep -o "^#define \(CLK_[A-Z0-9_]*\)" \
  include/dt-bindings/clock/samsung,exynos9610.h \
  | awk '{print $2}' | sort -u > /tmp/defined.txt
comm -23 /tmp/used.txt /tmp/defined.txt    # 출력이 있으면 불일치
```

출력이 비어야 정상이다. 항목이 나오면 **DT 패치가 구버전**이라는 뜻이므로,
patchwork에서 갱신된 DT 시리즈를 찾거나 chimac에게 확인할 것.

#### 4-6) 적용 실패 시

```bash
git am --abort
b4 am -o /tmp/patches -c <message-id>    # -c: 최신 리비전 강제
```

`linux-next`가 앞서 나가서 충돌하는 경우, 패치의 `base-commit`을 확인하고
그 시점으로 되돌려 적용한 뒤 rebase:
```bash
head -20 /tmp/patches/*.mbx | grep -i "base-commit"
git checkout -b test <base-commit>
git am /tmp/patches/*.mbx
git rebase linux-next/master     # 충돌 해결
```

#### 4-7) 적용 확인

```bash
git log --oneline linux-next/master..HEAD
ls drivers/clk/samsung/clk-exynos9610.c
ls include/dt-bindings/clock/samsung,exynos9610.h
ls arch/arm64/boot/dts/exynos/exynos9610*.dts*
```

네 파일이 모두 존재해야 다음 단계로 갈 수 있다.

#### 4-8) 이 시점에서 Tested-by를 준비할 것

clocks v3는 2026-07-22 제출 후 **5주간 A/R/T 전부 0**이다. 리뷰 정체의
한 원인이 테스터 부재일 수 있다. 빌드/부팅 결과를 스레드에 회신하는 것이
지금 할 수 있는 가장 즉각적인 기여다. (Phase 7 참조)

```bash
b4 mbox <message-id>       # 회신할 스레드 받기
```

### 0-5. DTS Makefile 등록

`arch/arm64/boot/dts/exynos/Makefile`에 항목 추가:
```makefile
dtb-$(CONFIG_ARCH_EXYNOS) += \
	exynos9610-gta4xlwifi.dtb \
```

### 0-6. DTS 검증 (플래시 전 필수)

```bash
pmbootstrap chroot -- apk add git python3-dev py3-pip swig
pmbootstrap chroot -- pip3 install dtschema
make exynos/exynos9610-gta4xlwifi.dtb
```
경고 중 자기 DTS 관련된 것만 골라서 확인.

---

## Phase 1 — 로깅 인프라 (UART 없는 경우의 핵심)

**이 단계가 전체 프로젝트의 병목이다.** 여기가 안 되면 이후 모든 디버깅이 장님 상태.

### 1-1. ramoops 주소를 추측하지 말고 로그에서 읽어라

지금까지 devmem으로 주소를 뒤졌는데, **위키에 정확한 방법이 있다:**

```bash
# 다운스트림에서 (adb)
dmesg | grep attached
# → ramoops: attached 0x100000@0x2e500000, ecc: 0/0
#              크기       주소

# 구형 ram_console인 경우
dmesg | grep ram_console
# → ram_console: got buffer at 2e600000, size 100000
```

**이 한 줄이 주소와 크기를 모두 알려준다.** 이걸 먼저 실행할 것.

출력이 없다면 다운스트림이 삼성 `sec_debug` 전용 포맷을 쓰는 것이므로,
**별도 주소에 표준 ramoops 영역을 새로 잡아야 한다.**

### 1-2. 왜 지금까지 ramoops가 전부 실패했는가 — 유력 원인

위키 FAQ에 명시된 함정:

> **Note:** the documentation for the cmdline settings doesn't mention the fact
> that you have to set `ramoops.mem_size` as well.

**cmdline으로 설정할 때 `mem_address`만 주고 `mem_size`를 빠뜨리면 동작하지 않는다.**
이게 과거 실패의 원인일 가능성이 높다.

```
ramoops.mem_address=0x... ramoops.mem_size=0x00100000
```

### 1-3. 양쪽 커널 설정

> 위키: "This setup has to be done on **both** the downstream and mainline kernel."
> "Make sure that the memory address you reserve and its size is the same in your
> downstream and mainline configuration, or else you won't be able to read the information."

**커널 config (양쪽 동일):**
```
CONFIG_PSTORE=y
CONFIG_PSTORE_CONSOLE=y      ← 전체 커널 로그에 필수
CONFIG_PSTORE_RAM=y
CONFIG_PSTORE_PMSG=y
```
메뉴 위치: `File systems → Miscellaneous filesystems → Persistent store support`

**DT (양쪽 동일 주소):**
```dts
reserved-memory {
    #address-cells = <2>;
    #size-cells = <1>;
    ranges;

    ramoops@<1-1에서 확인한 주소> {
        compatible = "ramoops";
        reg = <0x0 0xADDRESS 0x00100000>;
        no-map;
        record-size  = <0x20000>;
        console-size = <0x40000>;
        pmsg-size    = <0x40000>;
    };
};
```

⚠️ **record/console/pmsg 크기도 양쪽이 같아야 한다.** 오프셋이 어긋나면 읽어도
쓰레기가 나온다.

### 1-4. 읽기

```bash
# 표준
cat /sys/fs/pstore/console-ramoops-0

# 또는 명시적 마운트 (위키 권장)
mkdir /tmp/pstore
mount -t pstore -o kmsg_bytes=16000 - /tmp/pstore
ls /tmp/pstore
```

### 1-5. 검증 절차

```
① 다운스트림 부팅 → dmesg | grep attached → 주소 확보
② 양쪽 커널에 config + DT 적용, 재빌드
③ 다운스트림에서 echo test > /dev/pmsg0 → 재부팅 → 읽히는지 확인
   ← 여기서 실패하면 다운스트림 설정 문제. 메인라인 가기 전에 해결할 것
④ 메인라인 부팅 → 자동으로 dmesg > /dev/pmsg0
⑤ 다운스트림 복귀 → 읽기
```

**③을 건너뛰지 말 것.** 다운스트림끼리 먼저 검증해야 변수가 하나로 줄어든다.

### 1-6. 재부팅 방식 주의

DRAM 유지가 전제이므로:
- ✅ 소프트웨어 재부팅 (`reboot`), 패닉 후 자동 리셋
- ⚠️ 전원+볼륨다운 강제 리셋 → PMIC 레벨, DRAM 소실 가능

메인라인 cmdline에 `panic=10`을 넣어 자동 웜리셋을 유도.

### 1-7. 보조 수단 — framebuffer 콘솔 + QR

ramoops가 끝내 안 되거나, 부팅 초기 단계를 봐야 할 때.

**먼저 콘솔 2중 출력 해결:**
```sh
cat /proc/fb          # 2줄이면 fb 중복이 원인
cat /proc/consoles
for v in /sys/class/vtconsole/vtcon*/bind; do echo 0 > "$v"; done
echo 0 > /proc/sys/kernel/printk
```
cmdline에서 `keep_bootcon` 제거. fb가 두 개면 DT에서 `simple-framebuffer` 또는
DRM 중 하나를 `status = "disabled"`.

**QR 출력 (initramfs init에 삽입):**
```sh
dmesg | grep -iE "dwc3|phy|usb|regulator|clk|pstore|fail|error" \
  | gzip -9 | base32 -w0 | tr -d '=' > /tmp/d.b32
split -b 2000 /tmp/d.b32 /tmp/p_
N=$(ls /tmp/p_* | wc -l)
while :; do
  i=1
  for f in /tmp/p_*; do
    qrencode -l M -s 5 -m 4 -o /tmp/q.png < "$f"
    tr '\0' '\377' < /dev/zero | dd of=/dev/fb0 bs=1M 2>/dev/null
    echo "FRAME $i / $N"; fbv -f -e -i /tmp/q.png 2>/dev/null
    sleep 5; i=$((i+1))
  done
done
```
복원: `cat frame_*.txt | tr -d '\n' | base32 -d | gunzip`
initramfs 필요 패키지: `libqrencode-tools`, `fbv`, `busybox`. 스캐너: Binary Eye.

### 1-8. 출력이 아예 없을 때

위키 FAQ "Kernel is stuck during boot without any output":
- 커널 cmdline으로 디버그 출력 활성화 (`loglevel=8 ignore_loglevel initcall_debug`)
- `printk` 문을 직접 삽입해 어디서 멈추는지 좁힐 것

---

## Phase 2 — 측정

Phase 1이 완료되어 로그가 나오기 시작하면 실행.

### 2-1. 다운스트림 defconfig 보강

`arch/arm64/configs/exynos9611-gta4xlwifi_defconfig` — 현재 진단 수단이 막혀 있음:
```
# CONFIG_KEXEC is not set     ← kexec 불가
# CONFIG_DEVMEM is not set    ← 레지스터 덤프 불가
```

fragment로 병합 (직접 편집 금지, 위키 경고):
```
CONFIG_KEXEC=y
CONFIG_DEVMEM=y
# CONFIG_STRICT_DEVMEM is not set
CONFIG_PSTORE=y
CONFIG_PSTORE_CONSOLE=y
CONFIG_PSTORE_RAM=y
CONFIG_PSTORE_PMSG=y
```

### 2-2. ACPM 생존 판정 — 프로젝트 최대 분기점

이 측정 하나가 **Phase 4의 작업량을 몇 배 단위로 결정한다.**

#### 왜 이게 미해결인가

| 주장 | 근거 |
|---|---|
| chimac: "S-Boot가 ACPM 펌웨어를 안 올린다 (2020년 S-Boot)" | 이 SoC로 실제 작업한 경험 |
| 코드 분석: "다운스트림 Linux도 코어를 안 올리므로 S-Boot가 올렸을 것" | `acpm_ipc.c`가 ioremap+read만 수행 |

**충돌 상태. 실측으로만 해결된다.**

#### 결정적 증거 — 플러그인 테이블은 문자열 포인터를 갖는다

`acpm.c:plugins_init()`:
```c
plugins = (struct plugin *)(acpm_srambase + acpm_initdata->plugins);

for (i = 0; i < acpm_initdata->num_plugins; i++) {
    fw_name = (const char *)(acpm_srambase + plugins[i].fw_name);
    fw_base_addr = acpm_srambase + (plugins[i].base_addr & ~0x1);
    ...
    firmware_update(dev, fw_base_addr, name);
}
```

`fw_name`은 **SRAM 내부 오프셋**이고, 그 위치에 `"exynos9610_acpm_fvp.fw"` 같은
ASCII 문자열이 들어 있다. 이 테이블을 채운 주체가 곧 코어 펌웨어를 올린 주체다.

**→ SRAM에서 읽을 수 있는 ASCII 문자열이 나오면 ACPM 코어가 로드되어 있다는 확증.**

바이트가 0인지 보는 것보다 훨씬 확실한 판정법이다.

#### struct 레이아웃 (`fw_header/common.h`, `framework.h`)

```c
struct acpm_framework {          /* SRAM + 0x6f00 */
    u32 plugins;                 /* [0x00] 플러그인 배열 오프셋 */
    u32 num_plugins;             /* [0x04] 플러그인 개수 */
    u32 ipc_channels;            /* [0x08] */
    u32 num_ipc_channels;        /* [0x0c] */
    u32 pid_framework;           /* [0x10] */
    u32 pid_max;                 /* [0x14] */
    ...
    u32 log_data;                /* 로그 버퍼 베이스 */
    u32 ipc_base;                /* IPC 버퍼 베이스 */
    u32 total_size;
    u32 fw_size;                 /* ACPM 프레임워크 크기 */
    u32 intr_flag_offset;        /* mbox pending 레지스터 필드 오프셋 */
    struct build_info info;      /* 빌드 문자열 — 여기도 ASCII */
};

struct plugin {                  /* CONFIG_EXYNOS_ACPM 빌드 기준 */
    u32 id;
    u32 base_addr;               /* LSB는 플래그 → & ~0x1 */
    u32 acpm_ops;
    u32 plugin_ops;
    u32 secure_func_mask;
    u32 extern_func_mask;
    struct timer_desc timer;
    u8  is_attached;
    u32 size;
    u8  stay_attached;
    u32 fw_name;                 /* SRAM 오프셋 → ASCII 문자열 */
};
```

#### 판정 절차

```sh
# ① initdata 헤더 (num_plugins가 합리적인 값(1~16)인지 확인)
for i in $(seq 0 4 60); do
  printf "+%02x: " $i; busybox devmem $((0x0203FF00+i)) 32
done

# ② ASCII 스캔 — 가장 확실한 판정
#    CONFIG_DEVMEM=y 필요. dd로 SRAM 전체를 떠서 strings
dd if=/dev/mem bs=4096 skip=$((0x02039000/4096)) count=21 2>/dev/null \
  | strings | grep -iE "acpm|fvp|tmu|\.fw" | head
```

| ② 결과 | 판정 | Phase 4 경로 |
|---|---|---|
| `exynos9610_acpm_*.fw` 등 ASCII | ✅ **코어 동작 중** | IPC 드라이버만 (중) |
| 전부 쓰레기/0 | ❌ 코어 정지 | 로더부터 (대) |

#### 세 시점 비교

| 시점 | 확인하는 것 |
|---|---|
| 다운스트림 부팅 후 | 기준값 (코어 + 플러그인 모두 로드됨) |
| uniLoader → 메인라인 | 코어 생존? 플러그인은? |
| 다운스트림 → kexec → 메인라인 | 플러그인까지 상속되는가 |

**세 번째가 특히 중요하다.** 메인라인은 플러그인을 로드하지 않으므로
(`request_firmware` 호출이 없음), kexec 경로만 플러그인을 물려받을 수 있다.
FVP 플러그인은 주파수-전압 맵이므로 이게 없으면 DVFS/전압 제어가 성립하지 않는다.

> ℹ️ U-Boot vs uniLoader는 이 문제와 **무관**하다. 둘 다 boot 파티션에서 S-Boot가
> 로드하므로 위치가 동일하다. 부트로더 선택이 ACPM 상태 차이를 만들 수 없다.

### 2-3. USB PHY 레지스터 덤프

다운스트림, USB 연결 상태에서. PHY 베이스 주소는 DTS에서 재확인할 것.

### 2-4. 레귤레이터 실측

```sh
cat /d/regulator/regulator_summary > baseline.txt
```

---

## Phase 3 — USB (최우선 목표)

### ⚠️ 위키의 레귤레이터 경고 — 반드시 준수

> "Finally, if you see regulators defined in your dts, **remove them**. They most
> likely won't work on your device, and **can potentially damage your
> device/peripherals if set to the wrong values**."

**공식 문서가 DTS에 레귤레이터를 넣지 말라고 명시한다.** 앞서 논의한
`regulator-always-on` 접근은 위험하다. 필요한 경우에만, `regulator_summary`
실측값으로 `min=max` 고정할 것. 추정치 금지.

### 3-1. clocks v3 적용 후 재확인

```sh
dmesg | grep -E "dwc3|phy|usbdrd|clk.*usb"
```
클럭이 생기면서 저절로 풀릴 가능성이 있다. 먼저 확인.

### 3-2. kexec 상속 부팅 — 원인 이분법 도구

#### 원리

**kexec은 하드웨어를 리셋하지 않는다.** 다운스트림이 완전히 부팅해서 초기화한
모든 상태를 메인라인이 그대로 물려받는다. 다운스트림을 2단계 부트로더처럼 쓰는 셈.

| 상속되는 것 | 메인라인에서의 의미 |
|---|---|
| ACPM 플러그인 (FVP/TMU) | `request_firmware`로 로드된 것이 SRAM에 잔존 |
| 모든 클럭 게이트 | 미완성 클럭 드라이버 우회 |
| PMIC LDO 전압 | USB PHY 전원이 이미 인가된 상태 |
| USB PHY 초기화 | dwc3가 훨씬 멀리 진행 가능 |
| 디스플레이 패널 | 켜진 상태로 인계 |
| DRAM 내용 | ramoops가 S-Boot 개입 없이 보존됨 |

#### 전제 조건

다운스트림 defconfig에 `# CONFIG_KEXEC is not set` → **재빌드 필수** (Phase 2-1).

```
CONFIG_KEXEC=y
```
kexec-tools 패키지를 다운스트림 rootfs에 설치.

#### 실행

```sh
# 다운스트림에서 (완전 부팅 후)
kexec -l /path/to/mainline/Image \
      --dtb=/path/to/exynos9610-gta4xlwifi.dtb \
      --initrd=/path/to/initramfs \
      --command-line="clk_ignore_unused pd_ignore_unused loglevel=8 \
                      ignore_loglevel initcall_debug panic=10 \
                      ramoops.mem_address=0x... ramoops.mem_size=0x00100000"
kexec -e
```

#### ⚠️ `clk_ignore_unused`를 빼먹으면 전부 무의미하다

Linux는 부팅 후반에 **아무도 참조하지 않는 클럭을 전부 끈다**(`clk_disable_unused`).
상속받은 상태를 스스로 파괴하는 것이다. 전력 도메인도 마찬가지(`pd_ignore_unused`).

레귤레이터도 미사용 판정으로 꺼질 수 있으므로, USB가 여전히 안 뜨면
`regulator_summary`를 확인해 LDO가 살아 있는지 볼 것.

#### 판정

| 결과 | 해석 | 다음 작업 |
|---|---|---|
| dwc3 probe 성공 | 클럭/전원 문제 | 클럭 드라이버 + PHY 전원 경로 |
| dwc3 여전히 실패 | 드라이버 문제 | `phy_cfg_exynos9610` 작성 |

**원인이 두 갈래로 딱 갈린다.** 이게 이 도구의 유일하고 충분한 가치다.

#### 부수 효과 — 로그 회수가 쉬워진다

kexec은 DRAM을 보존하므로 강제 리셋으로 ramoops가 날아가던 문제가 사라진다.

```
다운스트림 (adb 정상)
  → kexec 메인라인
  → 메인라인 initramfs가 자동으로: dmesg > /dev/pmsg0; sync
  → reboot (소프트) 또는 다시 kexec으로 다운스트림 복귀
  → adb shell cat /sys/fs/pstore/pmsg-ramoops-0
```

**QR 없이 전체 dmesg를 뽑을 수 있다.** Phase 1이 막혔을 때의 우회로이기도 하다.

#### ⚠️ 한계 — 반드시 인지할 것

1. **업스트림 근거가 될 수 없다.** kexec 상속 상태에서 USB가 동작한다고 해서
   클럭 드라이버가 고쳐진 것이 아니다. LKML에 제출할 수 있는 결과가 아니다.

2. **진짜 버그를 가린다.** 메인라인 드라이버가 무엇을 빠뜨렸는지 보이지 않게 되어,
   원인 규명이 오히려 어려워질 수 있다.

3. **다운스트림이 kexec 후 안 뜰 수 있다** (역방향 사용 시). 삼성 다운스트림은
   S-Boot가 남긴 상태에 의존한다. `androidboot.*` cmdline을 원본 그대로 전달할 것.

4. **PSCI 의존.** secondary CPU park에 PSCI가 필요하다. 실패하면 메인라인
   cmdline에 `nr_cpus=1`로 우회.

#### 올바른 사용법

```
kexec 상속 부팅 → "이 레지스터/전원 상태에서 동작한다" 확인
      ↓
uniLoader 부팅 → 그 상태를 메인라인 드라이버가 직접 만들도록 구현
      ↓
검증 → 이것만 업스트림 대상
```

**정답을 컨닝하는 용도로 쓰고, 정답 자체로 삼지 말 것.**

#### 단계적 검증 (한 번에 하지 말 것)

| 단계 | 내용 | 확인 |
|---|---|---|
| 1 | 다운스트림 → 다운스트림 kexec | kexec 경로 자체가 동작하는가 |
| 2 | `echo t > /dev/pmsg0` → kexec → pstore 읽기 | ramoops가 kexec을 건너 생존하는가 |
| 3 | 다운스트림 → 메인라인 kexec | 상속 부팅 성립 |
| 4 | 상속 상태에서 USB 확인 | 본 목적 |

**1·2단계가 이 계획의 생사를 가른다. 먼저 할 것.**

### 3-3. DTS

```dts
&usbdrd_dwc3 {
    dr_mode = "peripheral";        /* SM5713 없음 → OTG 협상 skip */
    maximum-speed = "high-speed";  /* 기기가 HS-only */
    snps,dis_u3_susphy_quirk;
    snps,dis_u2_susphy_quirk;
};
```

PHY compatible은 `samsung,exynos850-usbdrd-phy`부터 시도.
안 되면 다운스트림 `phy-exynos-usb3p1-reg.h` + 2-3 덤프 대조하여
`phy_cfg_exynos9610` 작성.

> 위키(Category:Samsung Exynos): "A good reference might be **Exynos 850**, and
> its vendor kernel."

### 3-4. USB 시리얼 gadget — 이게 졸업 시점

FAQ "How to get serial output over USB?":
```
CONFIG_USB_G_SERIAL=y
```
cmdline:
```
console=ttyGS0,115200
```

**커널 로그가 USB로 직접 나온다.** UART 케이블과 거의 동등한 편의성.
ramoops/QR 단계를 졸업하는 지점.

### 3-5. USB 네트워크

FAQ "What options are needed to get USB network?": `CONFIG_USB_ETH`.
`linux-postmarketos-mainline`의 defconfig 참조.

RNDIS가 뜨면 SSH/telnet 접속 → **대화형 셸 확보 → 개발 속도 급상승.**

### 3-6. OpenRC 로그

```
/etc/rc.conf 에서 RC_LOGGING=true
```

---

## Phase 4 — ACPM / mbox

chimac이 직접 지목했고("needs mbox working") 아무도 작업하지 않는 영역.
**협업 충돌 없음.** 그리고 PMIC/DVFS/DPU가 전부 여기에 막혀 있으므로,
성공하면 그의 다음 병목을 뚫어주는 셈이 된다.

### 4-0. 배경 — ACPM과 mbox가 무엇인가

Exynos에는 Cortex-A 클러스터(Linux) 외에 **별도의 소형 코어(APM)** 가 있다.
전용 SRAM 84KB를 갖고, 메인 CPU가 꺼져 있어도 동작한다.
**ACPM**(Alive Clock and Power Manager)은 그 코어 위에서 도는 **펌웨어**다.

통신 구조:
```
1. AP가 공유 SRAM에 메시지 기록          (내용)
2. AP가 mbox 레지스터를 두드림            (초인종)
3. APM에 인터럽트 → 메시지 처리
4. APM이 응답을 SRAM에 기록
5. APM이 mbox로 AP에 인터럽트
```
**mbox는 데이터를 나르지 않는다.** 알림만 담당하고 내용은 SRAM에 있다.
그래서 `acpm_ipc` DT 노드에 주소가 두 개다.

왜 분리했는가: CPU 전압을 바꾸는 주체가 그 전압으로 동작하면 전환 중 정지 시
복구가 불가능하다. 그래서 전력 제어를 독립 코어로 격리했다.
**Linux는 전압을 직접 바꾸지 못하고, mbox로 요청만 보낸다.**

→ PMIC → DPU 순서인 이유가 이것이다. 디스플레이 전원을 켜려면 PMIC를 제어해야
하고, PMIC는 APM을, APM은 mbox를 경유한다.

### 4-1. 하드웨어 좌표 (`exynos9610.dts` 확인 완료)

```dts
acpm_ipc {
    compatible = "samsung,exynos-acpm-ipc";
    interrupts = <0 38 0>;
    reg = <0x11900000 0x1000       /* mbox INTR 레지스터 */
           0x02039000 0x15000>;    /* APM SRAM, 84KB */
    initdata-base = <0x6f00>;
    dump-base = <0x203c000>;
    dump-size = <0x12000>;
};

acpm {
    compatible = "samsung,exynos-acpm";
    reg = <0x11820000 0x1000>;     /* timer_apm */
    acpm-ipc-channel = <4>;
    fvmap_offset = <0x6000>;
};

acpm_dvfs { acpm-ipc-channel = <5>; };
```

계산된 주소:
- initdata: `0x02039000 + 0x6f00` = **0x0203FF00**
- 플러그인 로드 영역: `0x02039000 + 0x9000` = **0x02042000**

펌웨어 파일 (다운스트림 트리 내):
```
firmware/exynos9610_acpm_fvp.fw.ihex   (324줄, ~5KB, Thumb, 로드주소 0x9000)
firmware/exynos9610_acpm_tmu.fw.ihex   (323줄, ~5KB)
```
**둘 다 플러그인이며 코어 펌웨어가 아니다.** 코어라면 오프셋 0에 훨씬 크게 위치한다.

### 4-2. 분기 — Phase 2-2 결과에 따라

| 2-2 결과 | 작업 범위 | 난이도 |
|---|---|---|
| ASCII 문자열 발견 (코어 동작) | mbox + IPC 드라이버 | 중 |
| 쓰레기/0 (코어 정지) | 로더 + 위 전부 | 대 |

---

### 4-A. 코어가 정지한 경우 — uniLoader 로더

**uniLoader가 U-Boot보다 유리한 이유:**
펌웨어를 바이너리에 임베드할 수 있어 스토리지 드라이버가 불필요하다.
메인라인에 UFS 드라이버가 없는 현 상황에서 U-Boot의 파티션 읽기는 오히려 불리.

수행할 일 (베어메탈 200~300줄 수준):
```
1. ihex → 바이너리 변환 (빌드 타임에 objcopy -I ihex -O binary)
2. ACPM SRAM(0x02039000)에 memcpy
3. APM 코어 reset 해제
4. mbox 핸드셰이크 대기
```

⚠️ **3번의 reset 레지스터 오프셋이 불명이다.** 다운스트림에서 역추적할 것:
```bash
grep -rn "APM_CPU\|CPU_START\|reset\|RESET" drivers/soc/samsung/acpm/*.c
grep -rn "0x11820000\|timer_apm\|APM" arch/arm64/boot/dts/exynos/exynos9610.dts
# PMU 레지스터 쪽도 확인
grep -rn "APM" drivers/soc/samsung/pmu/ 2>/dev/null
```

참고 소스:
```
drivers/soc/samsung/acpm/acpm.c              (firmware_load 구현)
drivers/soc/samsung/acpm/acpm_ipc.c          (IPC 초기화, SRAM ioremap)
drivers/soc/samsung/acpm/fw_header/framework.h  (struct acpm_framework)
drivers/soc/samsung/acpm/fw_header/common.h     (struct plugin)
```

**로더 성공 여부는 로그 없이도 판정 가능하다** — mbox 핸드셰이크 결과가
레지스터 값 하나로 나오므로, Phase 1이 막혀 있어도 진행할 수 있는 유일한 작업이다.

---

### 4-B. IPC 드라이버 포팅 (두 경우 모두 필요)

메인라인 `drivers/firmware/samsung/exynos-acpm.c`는 현재 gs101 전용:
```c
{ .compatible = "google,gs101-acpm-ipc" }   /* 이것뿐 */
#define ACPM_GS101_INITDATA_BASE  0xa000
```

**펌웨어 로더가 아니라 IPC 클라이언트다.** `request_firmware` 호출이 없고,
이미 동작 중인 ACPM의 공유메모리를 읽는 구조 — 다운스트림과 동일한 가정.

추가할 것:
```c
#define ACPM_EXYNOS9610_INITDATA_BASE  0x6f00

static const struct acpm_match_data acpm_exynos9610 = {
    .initdata_base = ACPM_EXYNOS9610_INITDATA_BASE,
};

{ .compatible = "samsung,exynos9610-acpm-ipc",
  .data = &acpm_exynos9610 },
```

**검증 포인트:** gs101과 9610의 `struct acpm_framework` 레이아웃이 호환되는가.
같은 삼성 IP 계열이라 상당 부분 공유될 가능성이 있으나, 필드 순서/개수가
다를 수 있다. 다운스트림 `framework.h`와 메인라인 `exynos-acpm.h`를 대조할 것.

동반 작업: mbox 드라이버. `drivers/mailbox/`의 gs101용을 9610 좌표
(`0x11900000`, IRQ 38, `intr_flag_offset`)에 맞춘다.

### 4-3. 성공 판정

```sh
dmesg | grep -i acpm
ls /sys/firmware/    # ACPM 노드 등장 여부
```
IPC 채널이 열리면 PMIC 제어 → DVFS → DPU 전원 순으로 길이 열린다.

### 4-4. chimac에게 물어볼 것

코드에서 발견한 모순을 그대로 제시하면 된다:

> 다운스트림 `acpm_ipc.c`가 SRAM에서 initdata를 읽기만 하고 코어 펌웨어 로드는
> 하지 않던데, S-Boot가 안 올린다면 다운스트림에선 누가 올리는 건가요?
> 로더를 새로 써야 하는지 판단하려고 합니다.

**추측 확인이 아니라 코드상의 모순을 묻는 질문**이므로, 그가 7월에 요구했던
"actually wanna do any work"에 정확히 부합한다. 답이 곧 4-A 착수 여부를 결정한다.

---

## Phase 5 — 디스플레이 (장기)

⚠️ **Phase 3 완료 전 착수 금지.** 화면이 유일한 출력 수단인 동안 DECON을 건드리면
디버깅 수단을 잃는다. USB 확보 후에 시작할 것.

### 유리한 조건

FAQ "Can I use the simple panel driver?":
> "If your device shows the boot splash with mainline, simple panel should work"

**현재 부트로더 핸드오버 framebuffer로 화면이 나온다** → simple panel 경로가
유효할 가능성이 높다. 패널 타이밍(hfp/hbp 등)을 넣고 플래그에:
```c
MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_VIDEO_HSE
```

### 순서
```
DISPAUD 클럭 → 패널 드라이버 변종 (panel-himax-hx83102.c) → DECON/DSI → 터치
```

터치는 HX83102E 동일 칩이므로 디스플레이에 의존.

---

## Phase 6 — 프로덕션 패키지화

위키 "Prepare for production" 절차:

```
1. device-samsung-gta4xlwifi/APKBUILD 의 pkgrel +1
   → pmbootstrap checksum device-samsung-gta4xlwifi
2. linux-samsung-gta4xlwifi → linux-samsung-gta4xlwifi-downstream 로 rename
3. pmbootstrap aportgen linux-postmarketos-exynos9610
4. aportgen 프롬프트에서 mainline 패키지 선택
5. downstream APKBUILD에서 필요한 정보를 새 APKBUILD로 이전
   5a. ⚠️ 다운스트림 패치는 절대 복사하지 말 것 (메인라인에서 동작 안 함)
   5c. 커널 7.1 이하면 build()의 LLVM=1 → LLVM=1 HOSTLDFLAGS="-fuse-ld=lld"
       (package()의 LLVM=1은 건드리지 말 것)
6. deviceinfo에 boot-deploy-functions.sh 관련 변수 확인
7. LINUX 폴더의 config 파일을 .config로 교체 (파일명 동일하게)
8. pmbootstrap checksum linux-postmarketos-exynos9610
9. pmbootstrap kconfig check → (0-2의 fragment 절차로 수정) → check 반복
   ⚠️ kconfig edit(TUI) 대신 merge_config.sh 사용. 0-2 참조
10. pmbootstrap build linux-postmarketos-exynos9610
11. downstream 패키지는 삭제 또는 device/archived/ 이동
    (이동 시 APKBUILD 최상단에 "# Archived: superseded by mainline")
12. device-* APKBUILD의 depends= 를 메인라인 커널 패키지로 변경
```

> 위키: 메인라인 커널 패키지는 SoC 단위 공유 패키지다
> (`linux-postmarketos-<socvendor>-<soc>`). 기기별이 아님.

빌드/플래시:
```bash
pmbootstrap install
pmbootstrap flasher flash_kernel
pmbootstrap zap -p      # 재빌드 시
```

---

## Phase 7 — 업스트림 기여

### 즉시 가능 (충돌 없음)

| 항목 | 비고 |
|---|---|
| **clocks v3 Tested-by** | 5주째 A/R/T 전부 0. 테스터 부재 |
| **USB PHY 덤프 공유** | chimac이 USB에서 막혀 있음 |
| **ACPM 측정 결과** | 그의 가정 검증/반증 |

⚠️ **실제로 테스트하지 않고 Tested-by를 달지 말 것.**

### b4 워크플로 (위키 기재)

```bash
b4 prep -n <label> -f <tag>
b4 trailers -u
b4 prep --edit-cover
b4 send -o /tmp/tosend
./scripts/checkpatch.pl /tmp/tosend/*
b4 prep --compare-to v1
b4 prep --auto-to-cc
b4 prep --check
b4 send --reflect        # 자기 자신에게 먼저
b4 send
```

### 협업 경계
- **USB**: chimac 작업 중 → 착수 전 조율
- **ACPM**: 비어 있음 → 자유
- **pmaports**: 그도 작성 중 → 확인 필요

---

## 안전 수칙

**레귤레이터 (위키 명시 경고):**
- DTS에 레귤레이터를 정의하지 않는 것이 기본. 정의 시 하드웨어 손상 위험
- 필요하면 `regulator_summary` 실측값으로 `min=max` 고정
- min/max는 물리적 범위지 목표 전압이 아님

**충전:**
- 메인라인에 SM5713 charger 드라이버 없음 → 온도 기반 충전 제어 상실
- 하드웨어 보호(배터리 PCM, 충전 IC 리밋)는 유효 → 위험도 자체는 낮음
- ⚠️ 무인 야간 충전 방치 금지. 50~80% 구간, PC USB 포트 사용 권장

**DVFS/OPP:** 후반 작업. USB 단계에서 손대지 말 것.

---

## 의존 관계 요약

```
Phase 0 (도구)
    ↓
Phase 1 (로깅) ← ★ 최대 병목. 여기가 안 되면 이후 전부 장님
    ↓
Phase 2 (측정) → ACPM 판정, USB 원인 특정
    ↓
Phase 3 (USB) → ttyGS0/RNDIS 확보 → 로깅 문제 영구 해결
    ↓
   ├─→ Phase 4 (ACPM)
   └─→ Phase 5 (디스플레이)
    ↓
Phase 6 (패키지화) → Phase 7 (업스트림)
```

---

## 즉시 착수 3항목

```
① dmesg | grep attached     ← 다운스트림에서. ramoops 주소 확보. 5분
② envkernel.sh 셋업          ← 빌드 환경. 30분
③ b4로 chimac 시리즈 4종 획득 → 적용 → 클럭 ID 대조 (0-4)
```

**①이 제일 먼저다.** 지금까지 ramoops 주소를 추측으로 다뤘는데, 이 명령 한 줄이
정답을 알려준다. 그리고 `ramoops.mem_size` 누락이 과거 실패의 원인일 가능성이 높다.

---

## 링크

**업스트림**
- chimac patchwork (submitter 218332):
  https://patchwork.kernel.org/project/linux-samsung-soc/list/?submitter=218332&state=*
- clocks v1 커버레터 (참고): https://lkml.org/lkml/2025/9/14/470
- pinctrl v3: https://lkml.org/lkml/2026/1/2/233
- Exynos 커널 위키: https://exynos.wiki.kernel.org/
- b4 문서: https://b4.docs.kernel.org/en/latest/

**프로젝트**
- 사용자 저장소: https://github.com/bmk-mikufan/pmos-gta4xlwifi
- 다운스트림 커널: https://github.com/LineageOS/android_kernel_samsung_gta4xl (`lineage-20`)

**postmarketOS**
- pmaports: https://gitlab.postmarketos.org/postmarketOS/pmaports
- pmbootstrap: https://gitlab.postmarketos.org/postmarketOS/pmbootstrap
- 설치 문서: https://docs.postmarketos.org/pmbootstrap/main/installation.html
- Windows FAQ: https://wiki.postmarketos.org/index.php?title=Windows_FAQ

---

## 미해결 사항 (측정 또는 확인 필요)

| # | 항목 | 해결 방법 | 영향 | 상태 |
|---|---|---|---|---|
| 1 | ACPM 코어를 누가 로드하는가 | Phase 2-2 dmesg 확증 (2026-08-29) | Phase 4 작업량 (중↔대) | ✅ 해결 — 코어 동작 중, IPC 드라이버만(중) |
| 2 | APM 코어 reset 레지스터 오프셋 | 다운스트림 역추적 (4-A) | 로더 구현 가능 여부 | 코어가 이미 동작 중이므로 로더 자체가 불필요해짐 |
| 3 | DT 시리즈 최신 버전 존재 여부 | patchwork/b4 확인 (2026-08-28) | 빌드 성립 여부 | ✅ 해결 — v3 dts 없음 확인, cmu_cpucl1 fix로 v3 clocks 빌드 성공 |
| 4 | 클럭 ID v1↔v3 변경 여부 | 0-4-5 대조 스크립트 (2026-08-28) | DTS probe 실패 | ✅ 해결 — cmu_cpucl1 노드/클럭 제거로 해결, 빌드 성공 확인 |
| 5 | 다운스트림 ramoops가 표준인가 sec_debug인가 | `/sys/module/ramoops/parameters/` (2026-08-29) | Phase 1 경로 | ✅ 해결 — 표준 ramoops, 실주소 0xf9d10000 확보 |
| 6 | 메인라인 콘솔 2중 출력 원인 | `cat /proc/fb`, `/proc/consoles` | QR 판독률 | 미해결 |
| 7 | gs101↔9610 `acpm_framework` 레이아웃 호환 | 헤더 대조 | IPC 드라이버 난이도 | 미해결 (코어 동작 확인으로 우선순위 낮아짐) |
| 8 | USB PHY 베이스 주소 | 다운스트림 DTS 재확인 | 2-3 덤프 | 미해결 (dwc3 gadget/host 전환은 정상 동작 확인) |
| 9 | pmaports에서 chimac과 겹치는가 | 본인 확인 | Phase 6 충돌 | 미해결 |

**1·3·4·5 전부 해결됨 (2026-08-28~29).** 남은 건 6·7·8·9.
상세 근거: `docs/findings/2026-08-28-downstream-debug-shell.md`,
`docs/findings/2026-08-29-acpm-usb-ramoops-verified.md`
