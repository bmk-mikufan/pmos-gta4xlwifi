# 다운스트림 debug shell 조사 (2026-08-28)

## 배경
`--single-partition`으로 다운스트림 재빌드 후 fastboot로 boot/dtbo/userdata 플래시.
userdata는 의도적으로 지운 상태(테스트 목적)에서 부팅 → initramfs debug shell 진입.
이 상태에서 picocom(/dev/ttyACM0)으로 접속해 `/pmOS_init.log`, `/tmp/logs.img`
(dmesg.txt 13469줄 등)를 확보해 분석.

## ✅ 검증됨

### USB gadget UDC 충돌 — 원인 확정
커널 부팅 초반, **내장 legacy 컴포지트 가젯이 UDC를 먼저 점유**한다:
```
[   13.230017] g_cdc gadget: high-speed config #1: CDC Composite (ECM + ACM)
```
그 직후 initramfs가 자기 configfs 가젯(`/sys/kernel/config/usb_gadget/g1`,
NCM+ACM+mass_storage)을 만들려다 전부 `ash: write error: Resource busy` /
`Couldn't write new UDC`로 실패.

원인 kconfig: `CONFIG_USB_G_ANDROID=y` + `CONFIG_USB_ANDROID_SAMSUNG_COMPOSITE=y`가
`CONFIG_USB_CONFIGFS=y`와 동시에 켜져 있던 것. postmarketOS wiki(USB Network 문서)의
"두 시스템 중 하나만" 원칙과 정확히 일치 (`!1462` linux-postmarketos-qcom 사례와 동종 문제).

**결과**: ACM(picocom)은 g_cdc 쪽이라 항상 살아있었지만, initramfs의 172.16.42.1
DHCP 서버 설정은 실패한 configfs 가젯에 묶여 있어 한 번도 실행되지 않음 →
USB 이더넷 인터페이스는 호스트에 보이는데(carrier=1) 응답이 전혀 없었던 이유.

**조치**: `CONFIG_USB_G_ANDROID` 비활성화 (fragment로 merge, olddefconfig 검증 완료,
diff 7줄 → 1줄, configfs 계열 미변경). `config-samsung-gta4xlwifi.aarch64` 반영,
재빌드 진행 중.

### 파티션 테이블 (blkid.txt, partitions.txt 전수 확보)
- `sda25` = `super` (Android dynamic partitions, 6.1GB) — system/vendor/product/odm/system_ext가
  dm-0~dm-4로 매핑됨. 이 dm 매핑은 **부팅 시점에 이미 존재**한 상태(초기화 스크립트가
  새로 만들려다 `Resource busy`) — fastbootd 자신이 부트스트랩 때 매핑해놓고 정리 안 한 것으로 추정.
  userdata를 지운 것과는 무관한 별개 현상.
- `sda32` = `userdata` — UUID/TYPE 없음, 완전히 빈 상태 확인 (의도한 대로).
- 전체 PARTLABEL 목록은 blkid.txt 참고 (efs, sec_efs, param, boot, dtbo, recovery, vbmeta,
  vbmeta_samsung, keystorage, misc, keydata, keyrefuge, dqmdbg, nad_refer, radio, cp_debug,
  steady, bota, persistent, uhcfg, uh, blcmd, up_param, metadata, cache, optics, prism, omr,
  spu, nad_fw, super, userdata).

### 커널 상태
- 패닉/Oops/BUG: dmesg.txt 13469줄 전수 검사, **0건**.
- dwc3 USB PHY: `dwc3_gadget_conndone_interrupt speed:HS`까지 정상 진행 — High-Speed 링크업 자체는 됨.

## ❌ 확인 못 함 (devmem 없는 상태의 한계)

- **ramoops 주소**: dmesg에 `attached`/`ram_console` 문자열 자체가 없음 (0건).
  `docs/hardware.md`의 `0x2e500000`은 여전히 미검증 예시값 — 실측 재시도 필요.
- **ACPM/mbox, PMIC/regulator 정보**: dmesg 0건. 원인은 `cmdline.txt`에 박혀있던
  **`loglevel=4`** (S-Boot가 강제) — INFO 레벨 driver-probe 메시지가 전부 필터링됨.
  devmem 없이는 SRAM 직접 판독(`docs/workflow.md` 2-2 ①②)도 불가능.
- `regulator_summary`: 이 debug shell은 initramfs 미니멀 환경이라 debugfs 자체가 마운트 안 됨
  (전체 rootfs로 부팅해야 확인 가능).

## 조치 (진행 중)
1. `deviceinfo_kernel_cmdline="loglevel=8 ignore_loglevel initcall_debug"` 추가
   (`docs/workflow.md` 1-8 권장값) — S-Boot의 loglevel=4를 우리 값으로 덮어써서
   ACPM/PMIC/regulator probe 로그가 나오게 시도.
2. `CONFIG_USB_G_ANDROID` 비활성화 — USB gadget UDC 충돌 해소 시도.
3. devmem/kexec 설정은 이미 반영되어 있던 상태 유지 (`CONFIG_DEVMEM=y`, `CONFIG_KEXEC=y`).
4. 재빌드 후 재플래시 → 부팅 완료 시 USB eth/picocom 정상 작동 여부, loglevel 상향으로
   ramoops/ACPM/regulator 정보 재확인 필요.
