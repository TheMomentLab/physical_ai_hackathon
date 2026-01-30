# USB 포트 관리 가이드

## 개요

LeRobot 로봇 팔을 사용할 때 USB 포트가 재부팅 시마다 바뀌는 문제를 해결하기 위한 가이드입니다. udev rule을 사용하여 persistent device name을 설정하면, 항상 동일한 디바이스 이름으로 로봇에 접근할 수 있습니다.

## 문제 상황

기본적으로 Linux에서 USB 장치를 연결하면 `/dev/ttyACM0`, `/dev/ttyACM1` 같은 이름이 자동으로 할당됩니다. 하지만 이 이름들은:

- 🔴 재부팅 시마다 바뀔 수 있음
- 🔴 USB 포트 연결 순서에 따라 달라짐
- 🔴 여러 로봇 팔을 사용할 때 혼란 발생

## 해결 방법: udev Rule 설정

### 현재 프로젝트의 포트 매핑

`port.txt`에 정의된 persistent device name:

```
리더암1: /dev/leader_arm_1
팔로워암1: /dev/follower_arm_1
```

### 1. 디바이스 정보 확인

먼저 현재 연결된 USB 장치의 정보를 확인합니다:

```bash
# 모든 USB 시리얼 장치 확인
ls -l /dev/ttyACM* /dev/ttyUSB*

# udev 정보 확인 (예: /dev/ttyACM0)
udevadm info -a -n /dev/ttyACM0 | grep -E 'KERNELS|ATTRS{serial}|ATTRS{idVendor}|ATTRS{idProduct}'
```

**예시 출력:**
```
KERNELS=="1-1.1"
ATTRS{idVendor}=="0403"
ATTRS{idProduct}=="6001"
ATTRS{serial}=="A50285BI"
```

### 2. udev Rule 파일 생성

프로젝트 루트에 있는 `99-lerobot.rules` 파일을 확인하거나 새로 생성합니다:

```bash
# 파일 위치 (이미 존재할 수 있음)
cat /home/jinhyuk2me/dev_ws/mt_lerobot/99-lerobot.rules
```

**udev rule 예시:**

```bash
# LeRobot 리더 암
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{serial}=="LEADER_SERIAL", SYMLINK+="leader_arm_1", MODE="0666"

# LeRobot 팔로워 암
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{serial}=="FOLLOWER_SERIAL", SYMLINK+="follower_arm_1", MODE="0666"
```

**주의**: `LEADER_SERIAL`과 `FOLLOWER_SERIAL`은 실제 디바이스의 시리얼 번호로 교체해야 합니다.

### 3. udev Rule 설치

```bash
# udev rule 파일을 시스템 디렉터리로 복사
sudo cp 99-lerobot.rules /etc/udev/rules.d/

# udev 규칙 다시 로드
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### 4. 확인

USB를 다시 연결하거나 재부팅 후 확인:

```bash
# 심볼릭 링크 확인
ls -l /dev/leader_arm_1 /dev/follower_arm_1

# 예상 출력:
# lrwxrwxrwx 1 root root 7 Jan 27 20:00 /dev/follower_arm_1 -> ttyACM0
# lrwxrwxrwx 1 root root 7 Jan 27 20:00 /dev/leader_arm_1 -> ttyACM1
```

### 5. 권한 설정 (선택사항)

sudo 없이 포트에 접근하려면 사용자를 `dialout` 그룹에 추가:

```bash
sudo usermod -a -G dialout $USER

# 로그아웃 후 다시 로그인하거나 재부팅
```

## 사용 예시

udev rule이 적용되면 매뉴얼의 모든 명령어에서 persistent device name을 사용할 수 있습니다:

### 모터 설정

```bash
# 팔로워 암
lerobot-setup-motors \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1

# 리더 암
lerobot-setup-motors \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1
```

### 텔레오퍼레이션

```bash
lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1
```

## 문제 해결

### Q1: 심볼릭 링크가 생성되지 않음

```bash
# 규칙 파일 문법 확인
sudo udevadm test /sys/class/tty/ttyACM0

# 로그 확인
sudo journalctl -f
```

### Q2: 권한 오류 (Permission Denied)

```bash
# 임시 해결 (재부팅 시 초기화)
sudo chmod 666 /dev/follower_arm_1 /dev/leader_arm_1

# 영구 해결: udev rule에 MODE="0666" 추가 확인
# 또는 사용자를 dialout 그룹에 추가
```

### Q3: 여러 개의 동일 모델 구분

시리얼 번호가 같은 경우 USB 포트 경로 사용:

```bash
# 물리적 USB 포트 경로 확인
udevadm info -a -n /dev/ttyACM0 | grep KERNELS

# KERNELS 속성으로 구분하는 rule
SUBSYSTEM=="tty", KERNELS=="1-1.1", SYMLINK+="leader_arm_1", MODE="0666"
SUBSYSTEM=="tty", KERNELS=="1-1.2", SYMLINK+="follower_arm_1", MODE="0666"
```

## 📷 카메라 udev 규칙

로봇 팔과 마찬가지로 카메라도 `/dev/video0`, `/dev/video2` 등의 이름이 바뀔 수 있습니다. 이를 고정하기 위해 udev rule을 사용할 수 있습니다.

### 1. 카메라 정보 확인

```bash
# 카메라 장치 확인
ls -l /dev/video*

# 상세 정보 확인 (예: /dev/video2)
udevadm info -a -n /dev/video2 | grep -E 'KERNELS|ATTRS{serial}|ATTRS{idVendor}|ATTRS{idProduct}'
```

### 2. 카메라 규칙 예시

카메라는 보통 `video4linux` 서브시스템을 사용합니다.

```bash
# /etc/udev/rules.d/99-lerobot.rules

# Top View Camera (Video 2)
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="xxxx", ATTRS{serial}=="xxxx", SYMLINK+="top_cam_1", MODE="0666"

# Robot Camera (Video 4)
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="xxxx", ATTRS{serial}=="xxxx", SYMLINK+="follower_cam_1", MODE="0666"
```

**참고**: 저가형 웹캠은 고유 시리얼 번호가 없을 수 있습니다. 이 경우 `KERNELS`(물리적 포트 경로)를 사용해야 합니다.

```bash
# 포트 경로 기반 구분
SUBSYSTEM=="video4linux", KERNELS=="1-2.1:1.0", SYMLINK+="top_cam_1", MODE="0666"
```

## 추가 장치 설정

더 많은 로봇 팔을 추가하려면:

1. **port.txt에 추가**:
   ```
   리더암2: /dev/leader_arm_2
   팔로워암2: /dev/follower_arm_2
   ```

2. **99-lerobot.rules에 규칙 추가**:
   ```bash
   SUBSYSTEM=="tty", ATTRS{serial}=="LEADER2_SERIAL", SYMLINK+="leader_arm_2", MODE="0666"
   SUBSYSTEM=="tty", ATTRS{serial}=="FOLLOWER2_SERIAL", SYMLINK+="follower_arm_2", MODE="0666"
   ```

3. **udev 규칙 재로드**:
   ```bash
   sudo cp 99-lerobot.rules /etc/udev/rules.d/
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

## 참고 자료

- [udev 공식 문서](https://www.freedesktop.org/software/systemd/man/udev.html)
- [Persistent device naming](https://wiki.archlinux.org/title/Udev#Setting_static_device_names)
- LeRobot 프로젝트의 `99-lerobot.rules` 파일
