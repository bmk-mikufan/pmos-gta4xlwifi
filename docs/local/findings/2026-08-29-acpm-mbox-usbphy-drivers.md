# ACPM/mbox/USB2 PHY 메인라인 드라이버 작성 (2026-08-29)

계획 문서: `~/.claude/plans/iridescent-sniffing-fox.md` (동일 세션)

## 배경

전날 확보한 실측 데이터(ACPM 코어 생존 확인, USB dwc3 정상 동작, 다운스트림
소스 3건 — acpm_ipc, phy-exynos-usb3p1, phy-exynos5-usbdrd 계열)를 바탕으로
실제 mainline 드라이버 패치 3개 + DTS 확장을 작성. **처음부터 새 드라이버를
쓴 게 아니라, mainline에 이미 있던 범용 프레임워크를 확장하는 방식**으로
끝남 — 예상보다 훨씬 적은 코드로 해결됨.

## 핵심 발견 — mainline에 이미 있던 것

- `drivers/firmware/samsung/exynos-acpm.c` — gs101/exynosautov9용으로 이미
  업스트림된 범용 ACPM IPC 프로토콜 드라이버. SoC별로 `initdata_base`만
  다른 `acpm_match_data` 테이블 구조라 exynos9610 항목 하나만 추가하면 됨.
- `drivers/mailbox/exynos-mailbox.c` — 범용 Exynos 도어벨 mailbox 드라이버.
  단, INTMR0/INTGR1 오프셋이 gs101(0x28/0x40)과 exynos9610(다운스트림 실측
  0x10/0x1c)에서 달라서 **레지스터 오프셋을 match_data로 분리하는 리팩터**가
  필요했음(이건 재사용만으론 안 되고 실제 코드 변경 필요했던 부분).
- `drivers/phy/samsung/phy-exynos5-usbdrd.c` — exynos5/7870/850/990/autov920/
  gs101 전 세대 USB DRD combo PHY를 하나로 통합한 3000줄짜리 드라이버.
  `exynos990_usbdrd_phy`가 정확히 필요한 패턴(`phy_cfg_exynos850`/
  `exynos850_usbdrd_phy_ops` 재사용, SoC별 tune 테이블만 새로 정의)이라
  그대로 따라감. **레지스터 오프셋과 tune 필드 비트 위치가 exynos9610과
  mainline의 EXYNOS850_DRD_* 정의가 완전히 일치**함을 다운스트림
  `phy-exynos-usb3p1-reg.h`와 비트 단위로 대조해서 확인함 (TXVREF@31:28,
  TXPREEMPAMP@19:18, TXPREEMPPULSE@20, TXRISE@25:24, TXRES@22:21,
  TXHSXV@17:16, TXFSLS@15:12, SQRX@10:8, OTG@6:4, COMPDIS@2:0 — 전부 일치).

## 정정된 것

- 처음엔 USB2 PHY 튜닝값으로 `usb3_hs_tune`(콤보 PHY의 내장 USB2 서브블록,
  SS 절연되어 미사용) 값을 쓰려다가, dwc3가 실제로 물리는 건 독립
  `usbdrd_phy`(0x131D0000)이고 그 튜닝값은 **`usb_hs_tune`**(다른 노드)임을
  발견해서 정정함. 최종 사용값(device role): `tx_vref=0xf, otg=0x2,
  tx_pre_emp=0x3, tx_pre_emp_plus=0x0, tx_res=0x3, tx_rise=0x3, tx_hsxv=0x3,
  tx_fsls=0x3, rx_sqrx=0x7, compdis=0x7`.
- `tx_pre_emp`/`tx_pre_emp_plus` → mainline `TXPREEMPAMP`/`TXPREEMPPULSE`
  매핑은 처음엔 불확실(🟡)했으나, 다운스트림 `phy-exynos-usb3p1-reg.h`의
  `HSP_TUNE_TXPREEMPA_MASK=(0x3<<18)`/`HSP_TUNE_TXPREEMPA_PLUS=(0x1<<20)`가
  mainline과 비트 단위로 정확히 일치함을 확인해서 ✅로 격상.
- mailbox 리팩터 중 `EXYNOS_MBOX_INTMR0` 매크로를 match_data로 옮기면서
  interrupt-mask 초기화 줄 하나를 못 고쳐서 컴파일 에러가 났음 —
  `make ARCH=arm64 LLVM=1 drivers/mailbox/exynos-mailbox.o`로 실제 컴파일
  해봐서 잡음 (추측이 아니라 실제 빌드 테스트가 중요했던 사례).

## 확인 안 된 것 (건드리지 않음)

- 다운스트림 acpm_ipc DT 노드엔 `clocks` 프로퍼티가 없었음 — mainline
  드라이버는 `devm_clk_get_enabled(dev, "pclk")`(필수)라 그대로 두면 probe
  실패. 어떤 클럭인지 추측하지 않고 `devm_clk_get_optional_enabled`로
  바꿔서 안전하게 우회.
- USB2 PHY용 vbus/vbus-boost 레귤레이터 — SM5713 차저 쪽 실제 서플라이
  이름 미확인. `vbus-supply` 프로퍼티 자체를 생략 (레귤레이터 코어가
  더미로 처리, CLAUDE.md 규칙상 새 레귤레이터 노드 추가 금지와 일치).
- USB3/SuperSpeed 경로, OTG 자동 롤 스위치(SM5713 MUIC 연동), PMIC LDO
  실제 전압값 — 계획대로 스코프 밖.

## 검증

전부 실제로 처음부터(fresh tarball 재추출) 재현해서 확인함:
- 16개 패치(기존 13 + 신규 3) 전부 `patch -p1` 클린 적용
- `exynos-acpm.o`, `exynos-mailbox.o`, `phy-exynos5-usbdrd.o` 전부 `make
  ARCH=arm64 LLVM=1`로 무경고 컴파일 성공
- `exynos9610-gta4xl.dtb` 무경고 DTC 컴파일 성공 (최초엔 `apm_sram` 노드의
  reg/ranges가 gs101 스타일(2-address-cell)을 잘못 베껴서 경고 났었음 —
  우리 dtsi는 1-address-cell 컨벤션이라 수정함)
- `pmbootstrap build linux-samsung-exynos9610 --force`로 최종 확인 진행 중

## 새로 추가된 파일

`packages/linux-samsung-exynos9610/`:
- `0014-mailbox-exynos-mailbox-Add-per-SoC-doorbell-offsets.patch`
- `0015-firmware-samsung-exynos-acpm-Add-Exynos9610-support.patch`
- `0016-phy-samsung-phy-exynos5-usbdrd-Add-Exynos9610-suppo.patch`
- `0012-...patch` 수정 (apm_sram, ap2apm_mailbox, firmware/acpm_ipc, usbdrd_phy, udc/dwc3 노드 추가)
- `exynos9610.config` 수정 (MAILBOX/EXYNOS_MBOX/EXYNOS_ACPM_PROTOCOL/USB_DWC3*/PHY_EXYNOS5_USBDRD/USB_GADGET)
