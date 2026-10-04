# pmOS-gta4xlwifi - postmarketOS for Samsung Galaxy Tab S6 Lite (Wi-Fi)

Samsung Galaxy Tab S6 Lite (Wi-Fi) (SM-P610, gta4xlwifi)용 postmarketOS 포팅 프로젝트입니다.
Exynos 9611 SoC 기반. 주력 계열은 Mainline (linux-for-next 스냅샷 기반)이다.

## 문서 읽기 순서

1. **[HANDOFF.md](HANDOFF.md)** — 인수인계 요약. 현재 상태·막힌 지점·다음 실험이 여기 있다
2. **[SETUP.md](SETUP.md)** — 새 PC 환경 구축부터 빌드·플래시까지의 전체 절차
3. `docs/포팅_작업_기록.md` — 날짜별 전체 작업 기록 (가장 상세)
4. `docs/local/workflow.md` — Phase별 절차·명령·주소, `docs/local/hardware.md` — 검증된 하드웨어 사실

## 저장소 구조

```
├── packages/            # ★ pmaports device/testing/ 의 미러. 빌드 원본은 여기가 아니라
│   │                      pmaports 쪽이다 (SETUP.md 참조). 커널 7.2.0-rc1 스냅샷 + 패치 0001~0018
│   ├── linux-samsung-exynos9610/          # 메인라인 커널 (패치 + exynos9610.config + APKBUILD)
│   ├── device-samsung-gta4xlwifi-mainline/ # device pkg (no-op dtbo, S-BOOT 게이트 통과용)
│   └── uniloader-exynos9610/             # uniLoader + vendored initramfs (13MB, /init 진단핵 포함)
├── downstream/          # 참조 전용. LineageOS 4.14 기반 구 패키지 (부팅 성공한 쪽). 건드리지 말 것
├── docs/                # 작업 기록·하드웨어·절차 문서
├── scripts/             # ksetup.sh(트리 생성)/kbuild.sh(증분 빌드). 절차는 scripts/README-build.md
├── logs/                # 실기기 로그 (console-ramoops, last_kmsg)
├── CLAUDE.md            # 에이전트 작업 규칙
└── SETUP.md             # 환경 구축 가이드
```

`packages/`를 고칠 때는 **pmaports 쪽이 원본**이다 (양방향이 아니라 pmaports → repo):
```sh
PM=~/.local/var/pmbootstrap/cache_git/pmaports/device/testing
rsync -a --delete "$PM/<pkg>/" packages/<pkg>/
```

## 상태 (2026-10-04 기준, HANDOFF.md 9·10장 참조)

- Mainline 부팅: 🟡 디버그 셸까지 도달 (화면). `/init` 직후 하드 리셋은 해소됨
- 재부팅: ✅ syscon-reboot (PMU SWRESET `0x0400`/`0x1`) — warm 리셋, ramoops 보존
- USB PHY / dwc3: 🟡 둘 다 `probe 0`, UDC 등록, `g_serial` 바인드. 호스트 열거 실패 (`state=not attached`)
- USB 가젯 (호스트 가시성): ❌ 현재 블로커. PHY 레지스터 덤프 패치(0018) 빌드 완료, 플래시 대기 중
- 저장장치(MMC/UFS): ❌ probe 없음 (USB 다음 벽)
- WiFi/GPU/터치: ❌ 미구현
- Downstream (4.14): ✅ 참조용으로 부팅 성공 (XFCE4, WiFi 미작동)

부팅 이미지는 GitHub Releases (`boot-20260906-0505` 태그, 추적 대상 아님):
`boot-0018-phy-regdump-20261002.img` (덤프 포함 최신·미검증 — 먼저 플래시할 것),
`boot-debugshell-20260906.img` (디버그 셸 도달 확인본),
`boot-latest-20260906-0505.img`, `dtbo-20260906.img` (dtbo는 전부 공통).

## 출처

- Mainline kernel patches: Alexandru Chimac (submitter #218332 on patchwork)
- Kernel snapshot: https://git.kernel.org/pub/scm/linux/kernel/git/krzk/linux.git/snapshot/linux-for-next.tar.gz
- uniLoader: https://github.com/ivoszbg/uniLoader
- pmaports: https://gitlab.postmarketos.org/postmarketOS/pmaports.git
- Downstream kernel: LineageOS android_kernel_samsung_gta4xl

## 라이선스

- 패키지: MIT / GPL-2.0
- 커널 패치: GPL-2.0
- 문서: CC BY-SA 4.0
