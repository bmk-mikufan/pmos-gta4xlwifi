# 하드웨어 정보 — gta4xlwifi (Exynos 9611)

Samsung Galaxy Tab S6 Lite Wi-Fi (SM-P610) 검증된 사실만 기록.

## 부트로더
- **현재**: uniLoader (u-boot 기반)
- **S-Boot**: 2020년대 출시 기준
- DTS/패치 적용점: S-Boot는 boot 파티션에서 로드되므로 uniLoader ↔ U-Boot 선택이 ACPM 상태에 영향을 주지 않음

## 메모리 레이아웃

### DRAM (주의: PMIC 전압에 의존)
- 정확한 용량: 다운스트림 디바이스 트리 `exynos9611-gta4xlwifi.dts` 확인 필요

### SRAM (ACPM 전용)
- **베이스**: 0x02039000
- **크기**: 84KB (0x15000)
- **주요 오프셋**:
  - initdata 헤더: 0x02039000 + 0x6f00 = **0x0203FF00**
  - 플러그인 로드: 0x02039000 + 0x9000 = **0x02042000**
  - 로그 버퍼: initdata의 `log_data` 필드에서 읽음

## 레지스터 주소 (DT 노드)

```dts
mbox: mailbox {
    compatible = "samsung,exynos-acpm-ipc";
    interrupts = <0 38 0>;
    reg = <0x11900000 0x1000       /* mbox INTR 레지스터 */
           0x02039000 0x15000>;    /* APM SRAM, 84KB */
};

acpm {
    compatible = "samsung,exynos-acpm";
    reg = <0x11820000 0x1000>;     /* timer_apm — APM 코어 제어? */
    acpm-ipc-channel = <4>;
    fvmap_offset = <0x6000>;
};
```

| 주소 | 용도 | 비고 |
|---|---|---|
| 0x11820000 | timer_apm (APM 코어 관련?) | reset 레지스터 위치 **미확인** |
| 0x11900000 | mbox 인터럽트 | IPC 알림 메커니즘 |
| 0x02039000 | APM SRAM | 펌웨어 + IPC 버퍼 |

### APM 코어 Reset (불명)
**Phase 4-A(로더) 구현 시 필수.** 다운스트림 역추적 필요:
```bash
grep -rn "APM_CPU\|CPU_START\|reset\|RESET" drivers/soc/samsung/acpm/*.c
grep -rn "0x11820000\|timer_apm" arch/arm64/boot/dts/exynos/
```

## 입출력

### USB
- **호스트**: Peripheral 모드만 지원 (OTG 협상 없음 — SM5713 부재)
- **속도**: High-Speed (HS-only)
- **PHY**: `phy-exynos9610` — 미구현 → Exynos 850 참조 권장
- **DTS 노드**:
  ```dts
  usbdrd_dwc3 {
      dr_mode = "peripheral";
      maximum-speed = "high-speed";
      snps,dis_u3_susphy_quirk;
      snps,dis_u2_susphy_quirk;
  };
  ```

### 디스플레이 (참고만)
- **패널**: HX83102E (IPS, 해상도 1200x2000)
- **인터페이스**: MIPI DSI (4-lane)
- **부트로더 핸드오버**: framebuffer 생성 — simple panel 경로 유효
- **타이밍**: APKBUILD 또는 다운스트림 DTS에서 재확인

### 터치
- **칩**: HX83102E (디스플레이와 동일)
- **인터페이스**: I2C
- **의존성**: 디스플레이 드라이버 (Phase 5)

### 충전
- **IC**: SM5713 (다운스트림만 드라이버 보유)
- **메인라인**: 드라이버 없음 → 온도 제어 상실
- ⚠️ **무인 야간 충전 금지.** 하드웨어 보호(배터리 PCM)는 유효하나, 온도 기반 제어 부재로 위험

## 전원 (PMIC)

### 다운스트림 기준값
`cat /d/regulator/regulator_summary` 통해 현재 전압/상태 확인.

**메인라인 작성 시 지켜야 할 것:**
- **DTS에 regulator 노드 추가 금지** (위키 명시 경고)
- 필요하면 `regulator_summary` 실측값으로 `min=max` 고정
- min/max는 물리적 범위지 목표 전압이 아님
- 추정 전압 절대 금지

### USB PHY 전원
- Phase 2-3에서 다운스트림 `devmem` 덤프 필요
- DTS 작성 전 대조: 다운스트림 phy 드라이버와 비교

## 로깅 (Phase 1)

### ramoops 위치

✅ **검증됨** (2026-08-29, `/sys/module/ramoops/parameters/`에서 실측):
```
mem_address = 0xf9d10000
mem_size    = 0x200000   (2MB)
record_size = 0x80000    (512KB)
console_size= 0x80000
pmsg_size   = 0x80000
ftrace_size = 0x80000
ecc         = 0
```

`dmesg | grep attached`는 이 커널에서 안 먹힌다 (USB MUIC의 `attached_dev`만 매칭돼서
혼동됨). `/sys/module/ramoops/parameters/`를 직접 읽는 게 확실하다. `/sys/fs/pstore/`에
`console-ramoops-0`/`pmsg-ramoops-0`로 실제 데이터 확인 완료 (root 권한 필요).

상세: `docs/findings/2026-08-29-acpm-usb-ramoops-verified.md`

### 크기/오프셋 (양쪽 커널 동일 필수)
- record-size: 0x20000
- console-size: 0x40000
- pmsg-size: 0x40000

**오프셋이 어긋나면 읽어도 쓰레기 → 초기값은 다운스트림 dmesg에서만 확보**

## ACPM / Firmware

### 상태 판정 (Phase 2-2) — ✅ 확정됨 (2026-08-29)

**코어 동작 중.** dmesg로 확증 (SRAM 직접 read는 시도하지 말 것 — 아래 경고 참조):
```
[    0.842710] exynos-acpm 11820000.acpm: Loading exynos9610_acpm_fvp.fw firmware ...
[    0.842737] exynos-acpm 11820000.acpm: OK
[    0.842820] [ACPM] plugin(id = 2) attach done!
[    0.842842] exynos-acpm 11820000.acpm: Loading exynos9610_acpm_tmu.fw firmware ...
[    0.842959] [ACPM] plugin(id = 4) attach done!
```
다운스트림 Linux 드라이버가 `request_firmware()`로 플러그인을 IPC 전송했고 코어가
"OK" + "attach done"으로 응답 — 코어가 죽어있으면 이 attach 자체가 불가능하므로
**확증**. → Phase 4는 "IPC 드라이버만 작성(중)" 경로로 확정, 로더(대) 불필요.

⚠️ **`/dev/mem`으로 SRAM을 직접 읽지 말 것.** `0x02039000`은 `acpm_ipc` 드라이버가
이미 `request_mem_region`으로 점유 중. `dd`(read())는 커널이 "Bad address"로
거부하는데, 이걸 mmap으로 우회 시도하면 External Abort로 **기기가 재부팅된다**
(실제로 겪음, `docs/findings/2026-08-29-acpm-usb-ramoops-verified.md` 참고).
dmesg 로그만으로 충분히 판정 가능하니 raw 메모리 접근은 불필요.

### 펌웨어 파일 (다운스트림)
```
drivers/soc/samsung/acpm/firmware/
├── exynos9610_acpm_fvp.fw.ihex   (FVP 플러그인, 로드주소 0x9000)
├── exynos9610_acpm_tmu.fw.ihex   (TMU 플러그인)
```

**둘 다 플러그인** — 코어 펌웨어가 아님. 코어는 S-Boot 또는 uniLoader가 올려야 함.

### 플러그인 테이블 구조

```c
struct acpm_framework {         /* SRAM + 0x6f00 */
    u32 plugins;                /* 플러그인 배열 오프셋 */
    u32 num_plugins;            /* 개수 (일반적으로 2) */
    u32 log_data;               /* 로그 버퍼 베이스 */
    u32 fw_size;                /* 펌웨어 크기 */
    struct build_info info;     /* 빌드 문자열 — ASCII */
};

struct plugin {
    u32 id;
    u32 base_addr;              /* 로드 주소 (LSB는 플래그) */
    u32 fw_name;                /* SRAM 오프셋 → "exynos9610_acpm_*.fw" 문자열 */
    ...
};
```

## 시계 (CLK)

### chimac 패치 상태
- **v3** (2026-07-22): clocks 드라이버 + pinctrl + chipid (4/5 별도 제출)
- **DTS v1 (구버전)**: clock ID 매크로 불일치 위험 (0-4-5 확인 필수)

### 클럭 ID 대조 (패치 적용 후)
```bash
# 바인딩 헤더에 정의된 ID 수
grep -c "^#define CLK_" include/dt-bindings/clock/samsung,exynos9610.h

# DTS가 참조하는 ID가 전부 정의되어 있는가?
grep -o "CLK_[A-Z0-9_]*" arch/arm64/boot/dts/exynos/exynos9610*.dts* | sort -u > /tmp/used.txt
grep "^#define CLK_" include/dt-bindings/clock/samsung,exynos9610.h | awk '{print $2}' | sort -u > /tmp/defined.txt
comm -23 /tmp/used.txt /tmp/defined.txt   # 출력이 있으면 버전 불일치
```

**v1 DT 패치를 v3 클럭 위에 얹으면 존재하지 않는 ID 참조 → probe 실패**

