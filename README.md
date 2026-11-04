# pmOS-gta4xlwifi

**Samsung Galaxy Tab S6 Lite Wi-Fi** (SM-P610, `gta4xlwifi`, Exynos 9611)에 **메인라인 리눅스 + postmarketOS**를 올리는 포팅 프로젝트.

| | |
|---|---|
| SoC | Exynos 9611 (9610 계열, A73×4 + A53×4) |
| 커널 | `linux-for-next` 스냅샷 + 패치 18개 (`packages/linux-samsung-exynos9610/`) |
| 부트로더 | [uniLoader](https://github.com/ivoszbg/uniLoader) (Samsung boot.img payload) |
| 빌드 | Windows + WSL2, pmbootstrap |
| 최종 갱신 | 2026-11-04 |

---

## 현재 상태

> **한 줄 요약**: 화면 디버그 셸까지 부팅된다. **USB 가젯이 호스트에 전혀 안 보이는 것**이 현재 블로커.

| 항목 | 상태 | 비고 |
|---|:---:|---|
| 부팅 (S-BOOT → uniLoader → Linux) | 🟢 | 디버그 셸 도달. `/init` 직후 하드 리셋 해소 |
| 재부팅 | 🟢 | syscon-reboot (PMU SWRESET), warm 리셋이라 ramoops 보존 |
| 로그 (ramoops / pmsg) | 🟢 | `console-ramoops-0`, `[pmOS-rd]:` 유저스페이스 로그 |
| clocks / pinctrl | 🟢 | chimac clocks v3, pinctrl은 상류 머지 |
| USB PHY / dwc3 probe | 🟢 | 둘 다 probe 0, UDC 등록, `g_serial` 바인드 |
| **USB 호스트 열거** | 🔴 | `state=not attached`. **호스트 PC 반응 전혀 없음** |
| 저장장치 (MMC/UFS) | 🔴 | probe 없음 — USB 다음 벽 |
| PMIC / 충전 (SM5713) | 🔴 | 메인라인 드라이버 없음 ⚠️ 무인 충전 금지 |
| 디스플레이 / 터치 / WiFi / GPU | ⚪ | 미착수 (부트로더 framebuffer만) |
| 다운스트림 4.14 (참조용) | 🟢 | XFCE4 부팅, WiFi 미동작 |

🟢 동작 · 🟡 부분 · 🔴 블로커/미동작 · ⚪ 미착수

### 지금 하고 있는 것 — USB

호스트가 아무 반응도 안 한다 = D+ 풀업이 커넥터까지 안 나온다. 가설(전부 🟡 추정):

1. **SM5713 MUIC**가 D+/D− 스위치를 AP USB로 안 열어 줌 ★ 1순위
2. USB PHY **아날로그 전원(PMIC LDO)** 미인가
3. VBUS/BVALID 세션 신호가 링크까지 안 감
4. 9610 ↔ 850 PHY 초기화 시퀀스 차이 (refclk / PLL / sysreg_usb)

1·2는 PHY 레지스터 덤프로 반증되지 않는다. 상세·검증 방법:
[`docs/local/findings/2026-11-04-usb-enum-hypotheses.md`](docs/local/findings/2026-11-04-usb-enum-hypotheses.md)

**다음 순서**
1. 패치 0018(PHY 레지스터 readback 덤프) 이미지 빌드 → 플래시 → `console-ramoops-0` 회수
2. 같은 세션에서 다운스트림 기준값 확보: PHY/sysreg devmem, `regulator_summary`, SM5713 MUIC `i2cdump`

### 상류 현황 (2026-11-04 확인)

| 시리즈 | 상태 |
|---|---|
| chipid, pinctrl | ✅ 머지 완료 |
| clocks v3 | 🟡 리뷰 반려, chimac이 **재작성 예고** — v4 나오면 0005~0013 갱신 필요 |
| SoC/board DTS | 🟡 2025-09 v1이 마지막 |
| pinctrl clocks 필수화 바인딩 (09-22) | 반대 의견, 부팅 무관 → 미적용 |
| USB / 디스플레이 / 저장장치 | 상류 작업 없음 |
| pmaports | 업데이트 없음 |

---

## 문서 읽기 순서

1. **[HANDOFF.md](HANDOFF.md)** — 인수인계 요약. 부트 체인, 배제된 가설, 지뢰 목록
2. **[SETUP.md](SETUP.md)** — 새 PC 환경 구축 → 빌드 → 플래시
3. [`docs/포팅_작업_기록.md`](docs/포팅_작업_기록.md) — 날짜별 전체 기록
4. [`docs/local/workflow.md`](docs/local/workflow.md) — Phase별 절차·명령 / [`hardware.md`](docs/local/hardware.md) — 검증된 하드웨어 사실
5. [`docs/local/findings/`](docs/local/findings/) — 측정 결과

## 저장소 구조

```
packages/                    ★ pmaports device/testing/ 의 미러 (원본은 pmaports 쪽)
  linux-samsung-exynos9610/    메인라인 커널: 패치 0001~0018 + exynos9610.config + APKBUILD
  device-samsung-gta4xlwifi-mainline/   device pkg (no-op dtbo, S-BOOT 게이트 통과용)
  uniloader-exynos9610/        uniLoader + vendored initramfs
downstream/                  참조 전용. LineageOS 4.14 기반 구 패키지 — 건드리지 말 것
docs/                        작업 기록·하드웨어·절차·측정 결과
scripts/                     ksetup.sh / kbuild.sh 증분 빌드 (scripts/README-build.md)
logs/                        실기기 로그 (console-ramoops, last_kmsg)
CLAUDE.md                    에이전트 작업 규칙
```

`packages/`는 단방향 동기화 (pmaports → repo):
```sh
PM=~/.local/var/pmbootstrap/cache_git/pmaports/device/testing
rsync -a --delete "$PM/<pkg>/" packages/<pkg>/
```

## 부팅 이미지

GitHub Releases `boot-20260906-0505` 태그:
- `boot-debugshell-20260906.img` — 디버그 셸 도달 확인본
- `boot-latest-20260906-0505.img`
- `dtbo-20260906.img` — 모든 boot 이미지 공통

`boot-0018-phy-regdump-20261002.img`(최신, 덤프 포함)는 **미업로드** — SETUP.md 4장대로 빌드해야 한다 (첫 1회 풀빌드 ~30분).

## 출처

- 메인라인 패치: Alexandru Chimac ([patchwork](https://patchwork.kernel.org/project/linux-samsung-soc/list/?submitter=218332))
- 커널 스냅샷: [krzk/linux.git `for-next`](https://git.kernel.org/pub/scm/linux/kernel/git/krzk/linux.git/snapshot/linux-for-next.tar.gz)
- uniLoader: https://github.com/ivoszbg/uniLoader
- pmaports: https://gitlab.postmarketos.org/postmarketOS/pmaports
- 다운스트림 커널: LineageOS `android_kernel_samsung_gta4xl`

## 라이선스

패키지 MIT / GPL-2.0 · 커널 패치 GPL-2.0 · 문서 CC BY-SA 4.0
