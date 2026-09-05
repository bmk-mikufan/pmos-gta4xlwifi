---
name: qr-log
description: 기기 화면에 QR로 출력된 커널 로그를 생성하거나 복원한다. UART와 USB가 없는 상태에서 dmesg를 회수할 때, 또는 촬영/스캔한 QR 프레임 텍스트를 dmesg로 디코딩할 때 사용.
---

# QR 코드로 dmesg 회수

메인라인에 UART/USB/스토리지가 없을 때의 로그 회수 수단.
화면 출력만 가능한 상태에서 쓴다.

## 기기 측 스크립트 (initramfs init에 삽입)

```sh
#!/bin/sh
# 1) 콘솔 분리 — 안 하면 커널 printk가 화면을 계속 덮어씀
for v in /sys/class/vtconsole/vtcon*/bind; do echo 0 > "$v" 2>/dev/null; done
echo 0 > /proc/sys/kernel/printk

# 2) 인코딩. 필터링하면 1~2프레임으로 끝난다
dmesg | grep -iE "dwc3|phy|usb|regulator|clk|pstore|fail|error" \
  | gzip -9 | base32 -w0 | tr -d '=' > /tmp/d.b32
split -b 2000 /tmp/d.b32 /tmp/p_
N=$(ls /tmp/p_* | wc -l)

# 3) 무한 루프 — 놓친 프레임을 다음 바퀴에 재촬영
while :; do
  i=1
  for f in /tmp/p_*; do
    qrencode -l M -s 5 -m 4 -o /tmp/q.png < "$f"
    tr '\0' '\377' < /dev/zero | dd of=/dev/fb0 bs=1M 2>/dev/null   # 흰 배경
    echo "FRAME $i / $N"
    fbv -f -e -i /tmp/q.png 2>/dev/null
    sleep 5
    i=$((i+1))
  done
done
```

initramfs 필요 패키지: `libqrencode-tools`, `fbv`, `busybox`
스캐너: **Binary Eye** (대용량 페이로드 지원, 결과 파일 내보내기 가능)

## PC 측 복원

```bash
cat frame_*.txt | tr -d '\n' | base32 -d | gunzip > dmesg.txt
```

`=` 패딩을 제거했으므로 `base32 -d`가 실패하면 패딩을 복원한다:
```bash
python3 -c "
import base64,sys,gzip
s=open('frames.txt').read().strip().replace('\n','')
s += '=' * (-len(s) % 8)
sys.stdout.buffer.write(gzip.decompress(base64.b32decode(s)))
" > dmesg.txt
```

## 용량 설계

base32는 QR **영숫자 모드**(대문자+숫자)에 들어가므로 base64보다 21% 효율이 좋다.

| split 크기 | QR 버전 | 전체 dmesg(80KB) 프레임 수 |
|---|---|---|
| 1200 | ~v25 | 16장 |
| 2000 | ~v33 | 10장 |
| 3000 | ~v40 | 6장 (스캔 실패율 상승) |

**2000이 권장 타협점.** 오류정정 M, 모듈 크기 5px, quiet zone 4.

압축비: 텍스트 dmesg 기준 gzip -9로 약 7배 → base32로 1.6배 팽창
→ 원본 × 0.229 ÷ split크기 = 프레임 수

## 콘솔 겹침 문제

로그가 2중으로 출력되면 QR이 깨진다. 원인 진단:
```sh
cat /proc/fb          # 2줄이면 fb 중복
cat /proc/consoles
cat /sys/class/vtconsole/*/name
```
- fb가 두 개 → DT에서 `simple-framebuffer` 또는 DRM 중 하나를 `status = "disabled"`
- cmdline에서 `keep_bootcon` 제거
- `console=tty0`을 빼면 fbcon이 콘솔로 등록되지 않아 더 깨끗하다
  (단 부팅 과정을 눈으로 못 봄)

## 우선순위

QR은 **보조 수단**이다. 가능하면 먼저 시도할 것:
1. ramoops/pstore (`docs/workflow.md` Phase 1) — 전체 로그를 adb로 회수
2. kexec 경유 로그 전달
3. QR — 위 둘이 막혔을 때
