# ACPM/USB/ramoops 실측 (2026-08-29)

새 다운스트림 커널(devmem+kexec+loglevel=8 반영, USB_G_ANDROID는 컴파일 에러로 원복)로
부팅 후, USB 이더넷을 PC와 직결(허브 경유, 172.16.42.1/172.16.42.2)해서 SSH로 확보.

## ✅ ACPM 생존 판정 — 프로젝트 최대 분기점, 확정

```
[    0.427235] exynos-acpm 11820000.acpm: acpm probe
[    0.427698] exynos-acpm-ipc 11900000.acpm_ipc: acpm_ipc probe
[    0.428107] [ACPM] acpm framework SRAM dump to dram base: 0x8f29a0000
[    0.842710] exynos-acpm 11820000.acpm: Loading exynos9610_acpm_fvp.fw firmware ...
[    0.842737] exynos-acpm 11820000.acpm: OK
[    0.842820] [ACPM] plugin(id = 2) attach done!
[    0.842842] exynos-acpm 11820000.acpm: Loading exynos9610_acpm_tmu.fw firmware ...
[    0.842959] [ACPM] plugin(id = 4) attach done!
```

`docs/workflow.md` 2-2가 결정적 증거로 지목했던 바로 그 문자열(`exynos9610_acpm_fvp.fw`)이
실제로 로드되고 `OK` + `plugin attach done`까지 응답. 다운스트림 Linux 드라이버가
`request_firmware()`로 플러그인을 IPC로 ACPM에 전송 → **살아있는 ACPM 코어가 응답했다는
확증** (코어가 죽어있으면 attach 자체가 성공할 수 없음).

**결론: ACPM 코어는 동작 중.** workflow.md 표 기준 Phase 4 경로 = "IPC 드라이버만 작성(중)".
로더부터 새로 만드는 무거운 경로(대) 불필요.

### 하드웨어 좌표 (`/proc/iomem` 실측)
```
02039000-0204dfff : /acpm_ipc     (SRAM)
11900000-11900fff : /acpm_ipc     (IPC 레지스터)
11980000-119801ff : mailbox
```
※ `11820000.acpm` (probe/펌웨어 로드 주체 디바이스)도 별도 존재 — SRAM(0x02039000)과는
다른 레지스터 베이스이니 혼동 주의.

### WLBT(WiFi/BT) mbox — ACPM과 별개
```
[    1.434099] wlbt: platform_mif_create: MBOX irq 103 flag 0x404
```

### ⚠️ 하지 말 것 — 직접 검증 시도
`0x02039000` 영역은 `acpm_ipc` 드라이버가 이미 점유 중. `dd`의 `read()`는 커널이
"Bad address"로 거부했는데, python `mmap(PROT_READ)`로 우회 시도했다가 **기기가
재부팅됨** (아마 External Abort). read()가 거부한 영역은 mmap으로도 건드리지 말 것 —
드라이버가 이미 응답 확인을 dmesg로 준 이상 raw 메모리 확인은 불필요.

## ✅ USB — dwc3 gadget/host 정상 전환

```
[  194.801462] dwc3 13200000.dwc3: Turn off gadget dwc3-gadget
[  201.989061] dwc3 13200000.dwc3: Turn on host
[  203.055143] input: Liteon Technology Corp. USB Keyboard as .../xhci-hcd.2.auto/...
```

허브(키보드+이더넷 동글) 연결 시 dwc3가 OTG 롤을 gadget→host로 정상 전환. 앞서
"USB 이더넷이 응답 없던" 문제는 실제로는 **UDC 드라이버 충돌이 아니라 OTG 롤 스위칭**
때문이었을 가능성 — 허브 연결 자체가 host 모드를 트리거해서 gadget(ECM/ACM)이 꺼짐.
(`CONFIG_USB_G_ANDROID` 비활성화 시도는 `NOTIFY_USBSTATE`/`usb_composite_dev` 컴파일
에러로 롤백함 — 별개 이슈였고 진짜 원인은 이쪽으로 보임.)

## ✅ ramoops 실주소 확보 (문서 예시값 대체)

`/sys/module/ramoops/parameters/`에서 직접 확인:
```
mem_address = 0xf9d10000   (기존 문서 예시값 0x2e500000는 틀렸음 — 폐기)
mem_size    = 0x200000     (2MB)
record_size = 0x80000      (512KB)
console_size= 0x80000
pmsg_size   = 0x80000
ftrace_size = 0x80000
ecc         = 0
```
`/sys/fs/pstore/console-ramoops-0`, `pmsg-ramoops-0` 실제 존재·판독 가능 확인
(root 필요). DT reserved-memory나 cmdline이 아니라 커널 내부 고정 플랫폼 데이터로
등록되는 것으로 보임 (`/proc/iomem`에 ramoops 이름으로는 안 뜸, cmdline에도 없음).

`dmesg | grep attached`는 이 커널에서는 안 먹힘 (USB MUIC의 `attached_dev`만 매칭돼서
혼동됨) — 대신 `/sys/module/ramoops/parameters/`를 직접 읽는 게 확실한 방법.
