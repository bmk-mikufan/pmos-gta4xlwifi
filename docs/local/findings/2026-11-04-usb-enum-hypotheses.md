# USB 가젯 호스트 열거 실패 — 가설 정리 + 상류 현황 (2026-11-04)

## 전제 (✅ 확인)
- 메인라인 커널: `131d0000.phy` / `13200000.usb` probe 0, UDC 등록, `g_serial ready`.
- 그런데 `state=not attached`, `current_speed=UNKNOWN`.
- **호스트 PC 쪽 반응 전혀 없음** (열거 에러조차 없음, 사용자 확인 2026-11-04).
  → D+ 풀업이 커넥터까지 안 나온다는 뜻. reset/chirp 단계 문제(UTMI 폭 등)는 후순위로 밀림.

이미 배제된 것은 HANDOFF 10장 참조 (클럭 게이팅, role-switch, PHY 오프셋·VBUS 비트 정의, PMU 마스크 0017).

## 가설 (전부 🟡 추정, 우선순위 순)

### H1. SM5713 MUIC 가 D+/D− 아날로그 스위치를 AP USB 로 안 열어 줌 ★
- 다운스트림 config: `CONFIG_MUIC_SM5713=y`, `MUIC_BCD_RESCAN=y`, `MUIC_SUPPORT_CCIC=y` (✅ config 확인).
- Samsung MUIC는 BC1.2 판별 후 DP/DM 경로를 AP USB / UART / open 중 하나로 스위칭한다 (🟡 일반론).
  메인라인엔 드라이버가 없으므로 경로는 S-BOOT가 남긴 상태(또는 리셋 기본 = open)에 고정.
- PHY/dwc3가 레지스터상 완벽해도 증상이 똑같이 나온다 → **0018 덤프로 반증 불가.**
- 검증: 다운스트림에서 SM5713 MUIC 스위치 레지스터(MANUAL_SW/CONTROL 계열) `i2cdump`,
  메인라인에서 같은 레지스터 값 비교. 또는 kexec 상속(workflow 3-2)으로 다운스트림 상태 위에서 USB 확인.

### H2. USB PHY 아날로그 전원(PMIC LDO) 미인가
- PMIC(S2MPU09/10 계열) 메인라인 드라이버 없음 → 부트로더가 켜 둔 LDO에 의존.
- PHY 레지스터(APB, 디지털)는 읽고 쓰기가 되어도 아날로그부(3.3V/0.85V)가 꺼져 있으면 풀업이 안 나온다.
  → **0018 의 "쓰기 = 읽기" 결과로도 배제되지 않는다.**
- 검증: 다운스트림 `regulator_summary`에서 USB PHY consumer LDO와 전압, 다운스트림이 부팅 중
  그 LDO를 토글하는지 확인. DTS 레귤레이터 노드 추가는 금지(CLAUDE.md 규칙 4) — 측정만.

### H3. VBUS/BVALID 세션 신호가 링크까지 안 감
- 비트 정의는 일치 확인했으나 **실제 값은 미측정**.
- UTMI OTG 블록은 보통 bvalid가 서야 DP 풀업을 낸다. PHY 쪽 force-valid 외에 링크 쪽
  (다운스트림 LINKSYSTEM FORCE_VBUSVALID/BVALID 계열) 설정이 850 `phy_ops`와 다를 수 있다.
- 검증: 0018 덤프의 UTMI bit5, LINKSYSTEM/LINKCTRL 값을 다운스트림 devmem 덤프와 대조.

### H4. 9610 ↔ 850 PHY 초기화 시퀀스 차이 (refclk FSEL / PLL lock / sysreg_usb)
- refclk 26 MHz `oscclk` 입력은 맞지만, 다운스트림이 쓰는 기준주파수 선택 필드나
  `sysreg_usb`(0x13010000) 설정을 850 경로가 안 건드릴 수 있다 → PHY PLL 미잠금.
- 검증: 다운스트림 `phy-exynos-usb3p1*.c` init 순서 ↔ 850 `utmi_init` 대조(source-digger),
  sysreg_usb 영역 양쪽 덤프 비교.

### H5. (호스트 무반응이라 후순위) dwc3 `GUSB2PHYCFG` 불일치 (UTMI 8/16bit, USBTRDTIM)
- 풀업은 나오고 chirp에서 깨지는 유형이라 현재 증상과는 덜 맞음.
- 검증(싸다): `/sys/kernel/debug/usb/13200000.usb/regdump`의 `GUSB2PHYCFG(0)`, `GCTL`, `DCTL`, `DSTS`.

### H6. (낮음) 복사해 온 dwc3 quirk 부작용
- `snps,dis-u2-freeclk-exists-quirk` 등. 위가 다 아니면 제거 테스트.

## 다음 실측 계획
1. 0018 플래시 → `console-ramoops-0` 회수 (H3/H4 일부).
2. **같은 세션에서 다운스트림 기준값 확보** — 0018 덤프는 비교 대상 없이는 반쪽:
   - PHY(0x131d0000) / sysreg_usb / PMU 0x704 devmem 덤프 (H3, H4)
   - `regulator_summary` (H2)
   - SM5713 MUIC `i2cdump` (H1)
   - dwc3 debugfs regdump (H5)
3. 테스트 케이블은 USB-A ↔ C. C↔C 는 CC(Rd) 처리 없이는 호스트가 VBUS를 안 줄 수 있음.

## 상류 현황 (lore.kernel.org / GitHub 검색, 2026-11-04)
- **clocks v3 (적용 중인 0005~0010)**: 머지 안 됨. Krzysztof 리뷰(정렬·인덱싱), Peter Griffin 리뷰 후
  chimac이 "처음부터 재작성" 예고(2026-07-23). v4 미게시 → 나오면 클럭 ID 변동 가능, 0012/0013도 갱신 필요.
- **DTS / board binding (0011~0013)**: 2025-09-14 v1이 마지막. 후속 버전 없음.
- **pinctrl / chipid**: 상류 머지 완료.
- **신규**: `dt-bindings: pinctrl: samsung: Require clocks for Exynos9610 pinctrl nodes` (2026-09-22).
  Krzysztof가 ABI 깨짐·TOP pinctrl 문제로 반대, v2 없음. 부팅에 무관 → 미적용.
- **USB / 디스플레이 / MMC·UFS / gta4xl / 9611**: 상류 작업 없음. GitHub도 다운스트림 안드로이드 커널뿐.
- **pmaports**: 업데이트 없음 (사용자 확인).
