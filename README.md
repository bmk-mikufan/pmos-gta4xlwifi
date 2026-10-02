# pmOS-gta4xlwifi - postmarketOS for Samsung Galaxy Tab S6 Lite (Wi-Fi)

Samsung Galaxy Tab S6 Lite (Wi-Fi) (SM-P610, gta4xlwifi)용 postmarketOS 포팅 프로젝트입니다.

Exynos 9611 SoC 기반으로, Downstream (LineageOS 4.14.356)과 Mainline (linux-for-next 7.2.0-rc1) 커널을 모두 지원합니다.

## 저장소 구조

```
├── downstream/          # Downstream 커널 패키지 (LineageOS 4.14.356)
│   ├── device-samsung-gta4xlwifi/
│   ├── linux-samsung-gta4xlwifi/
│   └── firmware-samsung-gta4xlwifi/
├── packages/            # Mainline 커널 패키지 (linux-for-next 7.2.0-rc1)
│   ├── linux-samsung-exynos9610/          # 메인라인 커널 (패치 0001~0017 + config)
│   ├── device-samsung-gta4xlwifi-mainline/ # Mainline device pkg (no-op dtbo)
│   └── uniloader-exynos9610/             # uniLoader (초경량 부트로더) + vendored initramfs
├── docs/                # 문서 및 작업 기록
├── scripts/             # 빌드 스크립트 (ksetup.sh/kbuild.sh, 절차는 README-build.md)
└── logs/                # 실기기 로그 (console-ramoops, last_kmsg)
```

## 상태 (2026-10-02 기준, HANDOFF.md 10장 참조)

- Downstream 부팅: ✅ 완료 (XFCE4, WiFi 미작동)
- Mainline 부팅: 🟡 디버그 셸까지 도달 (화면). `/init` 직후 하드 리셋은 더 이상 재현 안 됨
- 재부팅: ✅ syscon-reboot (PMU SWRESET `0x0400`/`0x1`) — `reboot -f` warm 리셋 동작, ramoops 보존됨
- USB PHY / dwc3: 🟡 둘 다 `probe 0`, UDC 등록, `g_serial` 바인드까지 성공. 호스트 열거는 실패 (`state=not attached`)
- USB 가젯 (호스트 가시성): ❌ 미해결 — 현재 블로커. 다음 단계는 PHY 레지스터 덤프 실측
- 저장장치(MMC/UFS): ❌ probe 없음 (USB 다음 벽)
- WiFi/GPU/터치: ❌ 미구현

부팅 이미지는 GitHub Releases에서 받는다 (추적 대상 아님):
`boot-debugshell-20260906.img` (디버그 셸 도달 확인본),
`boot-latest-20260906-0505.img` (syscon-reboot + USB 스택 포함 최신본), `dtbo-20260906.img`.

새로 작업을 이어받는다면 **[HANDOFF.md](HANDOFF.md)** 를 먼저 읽을 것.

## 출처

- Mainline kernel patches: Alexandru Chimac (submitter #218332 on patchwork)
- uniLoader: https://github.com/ivoszbg/uniLoader
- pmaports: https://gitlab.postmarketos.org/postmarketOS/pmaports.git
- Downstream kernel: LineageOS android_kernel_samsung_gta4xl

## 라이선스

- 패키지: MIT / GPL-2.0
- 커널 패치: GPL-2.0
- 문서: CC BY-SA 4.0
