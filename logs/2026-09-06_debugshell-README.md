# 2026-09-06 백업 — 처음으로 디버그 셸까지 도달한 이미지

| 파일 | 내용 |
|---|---|
| `boot.img` | **화면에 디버그 셸까지 도달한 바로 그 이미지.** 커널은 아래와 동일, initramfs만 계측판(`set -x`) |
| `boot-noinstrument.img` | 같은 커널 + 원본 initramfs. **이쪽은 `/init` 진입 직후 리셋된다** |
| `dtbo.img` | 최소 no-op 오버레이 (S-BOOT UFDT 게이트 통과용) |
| `initramfs-instrumented.gz` | `/init` 셰방 뒤에 마커 + `set -x` 삽입, cpio 재포장(소유권 0:0 강제) |
| `initramfs-original.gz` | vendored 원본 |
| `linux-samsung-exynos9610-*.apk` | 이 커널 패키지 (config 다이어트 + reserved-memory + clocks v3 + PSTORE_PMSG) |
| `console-ramoops-reset-9.9s.log` | 계측 전 빌드가 `Run /init`에서 리셋된 로그. 마지막 타임스탬프 9.92초 |
| `GIT-COMMIT` | 이 이미지들을 만든 저장소 커밋 |

두 boot.img의 유일한 차이가 initramfs다 (44,304,384 vs 44,300,288 바이트).
한쪽은 리셋되고 한쪽은 디버그 셸까지 간다 — 원인은 아직 미확인이다.
`set -x`가 `/init`을 느리게 만들어 레이스를 피한 것인지, cpio 재포장의 구조 차이인지
가려야 한다.

플래시:
```sh
fastboot flash boot boot.img
fastboot flash dtbo dtbo.img
```
