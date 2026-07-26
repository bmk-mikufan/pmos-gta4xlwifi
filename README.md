# pmOS-gta4xlwifi - postmarketOS for Samsung Galaxy Tab S6 Lite (Wi-Fi)

Samsung Galaxy Tab S6 Lite (Wi-Fi) (SM-P610, gta4xlwifi)용 postmarketOS 포팅 프로젝트입니다.

Exynos 9611 SoC 기반으로, Downstream (LineageOS 4.14.356)과 Mainline (linux-for-next 7.2.0-rc1) 커널을 모두 지원합니다.

## 저장소 구조

```
├── downstream/          # Downstream 커널 패키지 (LineageOS 4.14.356)
│   ├── device-samsung-gta4xlwifi/
│   ├── linux-samsung-gta4xlwifi/
│   └── firmware-samsung-gta4xlwifi/
├── packages/            # Mainline 커널 패키지 (linux-for-next 7.0.0-rc1)
│   ├── linux-samsung-exynos9610/          # chimac의 mainline kernel
│   ├── device-samsung-gta4xlwifi-mainline/ # Mainline device pkg
│   ├── u-boot-exynos9610/                # U-Boot with FIT images
│   └── uniloader-exynos9610/             # uniLoader (초경량 부트로더)
├── patches/
│   ├── chimac/          # Alexandru Chimac의 LKML 패치 (9개)
│   └── bmk/             # 추가 패치 (USB DWC3 등)
├── docs/                # 문서 및 작업 기록
├── scripts/             # 빌드 스크립트
└── boot-images/         # 생성된 부트 이미지
```

## 상태

- Downstream 부팅: ✅ 완료 (XFCE4, WiFi 미작동)
- Mainline 부팅: ✅ 성공 (debug shell + framebuffer)
- USB DWC3: ❌ PHY probe 실패
- UFS: 🟡 드라이버 추가됨 (테스트 필요)
- WiFi/GPU/터치: ❌ 미구현

## 출처

- Mainline kernel patches: Alexandru Chimac (submitter #218332 on patchwork)
- uniLoader: https://github.com/ivoszbg/uniLoader
- pmaports: https://gitlab.postmarketos.org/postmarketOS/pmaports.git
- Downstream kernel: LineageOS android_kernel_samsung_gta4xl

## 라이선스

- 패키지: MIT / GPL-2.0
- 커널 패치: GPL-2.0
- 문서: CC BY-SA 4.0
