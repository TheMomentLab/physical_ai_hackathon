# 시스템 설정 매핑

이 문서는 LeRobot 프로젝트의 **모든 하드웨어 설정과 ID 매핑**을 통합 관리합니다.

> ⚠️ **중요**: 모든 명령어에서 이 문서에 정의된 값을 **정확히** 사용하세요!

마지막 업데이트: 2026-01-30 20:56

---

## 📌 로봇 팔 포트 매핑

| 구분 | Device Name | 실제 포트 | 캘리브레이션 ID |
|------|-------------|----------|----------------|
| **리더 암** | `/dev/leader_arm_1` | USB 포트 (udev) | `my_so101_leader_1` |
| **팔로워 암** | `/dev/follower_arm_1` | USB 포트 (udev) | `my_so101_follower_1` |

### udev 규칙 설정

자세한 내용: [USB Port Management Guide](./01_getting_started/04_usb_port_management_ko.md)

```bash
# /etc/udev/rules.d/99-lerobot.rules
SUBSYSTEM=="tty", ATTRS{serial}=="LEADER_SERIAL", SYMLINK+="leader_arm_1", MODE="0666"
SUBSYSTEM=="tty", ATTRS{serial}=="FOLLOWER_SERIAL", SYMLINK+="follower_arm_1", MODE="0666"
```

---

## 📷 카메라 매핑

| 디바이스 | 카메라 이름 | 용도 | 상태 | 카메라 ID (권장) |
|----------|------------|------|------|-----------------|
| `/dev/video0` | Integrated Camera | ❌ 노트북 웹캠 (사용 금지) | ✅ 정상 | - |
| `/dev/video1` | Integrated Camera | 메타데이터 | - | - |
| `/dev/video2` | **Innomaker-U20CAM #1** | ✅ **탑뷰 카메라** | ✅ 정상 | `/dev/top_cam_1` |
| `/dev/video3` | Innomaker-U20CAM #1 | 메타데이터 | - | - |
| `/dev/video4` | **Innomaker-U20CAM #2** | ✅ **로봇 카메라** | ✅ 정상 | `/dev/follower_cam_1` |
| `/dev/video5` | Innomaker-U20CAM #2 | 메타데이터 | - | - |

### udev 카메라 규칙 (현재 포트)

```bash
SUBSYSTEM=="video4linux", KERNELS=="1-1.3", ATTR{index}=="0", SYMLINK+="top_cam_1", MODE="0666"
SUBSYSTEM=="video4linux", KERNELS=="1-1.4", ATTR{index}=="0", SYMLINK+="follower_cam_1", MODE="0666"
```

### 📷 카메라 미리보기

카메라가 정상적으로 작동하는지 확인하려면 다음 명령어를 사용하세요:

```bash
# 탑뷰 카메라 (Top View - top_cam_1)
ffplay -f v4l2 -input_format yuyv422 -video_size 640x480 /dev/top_cam_1

# 로봇 카메라 (Robot Camera - follower_cam_1)
ffplay -f v4l2 -input_format yuyv422 -video_size 640x480 /dev/follower_cam_1
```

### ⚠️ 주의사항

- **`/dev/video0`은 절대 사용하지 마세요!** 노트북 내장 웹캠으로 로봇을 볼 수 없습니다.
- **로봇 학습용 카메라**: `/dev/top_cam_1`, `/dev/follower_cam_1` 사용 권장
- **Innomaker 듀얼 카메라**는 OpenCV에서 첫 프레임 읽기 실패가 나올 수 있으므로 `fourcc: MJPG` 사용을 권장합니다.

### 카메라 사양

- 해상도: 640x480
- FPS: 30
- 포맷: YUYV (OpenCV 사용 시 MJPG 권장)

---

## 🎯 통합 설정 (복사해서 사용)

이 설정을 모든 명령어에 일관되게 사용하세요.

### 환경 변수

```bash
# Hugging Face 사용자
export HF_USER="jinhyuk2me"

# 로봇 포트
export LEADER_PORT="/dev/leader_arm_1"
export FOLLOWER_PORT="/dev/follower_arm_1"

# 로봇 ID (캘리브레이션 파일 매칭)
export LEADER_ID="my_so101_leader_1"
export FOLLOWER_ID="my_so101_follower_1"

# 카메라
export CAM_TOP="/dev/top_cam_1"
export CAM_FRONT="/dev/follower_cam_1"
```

### 📝 명령어 템플릿

#### 1. 캘리브레이션

```bash
# 팔로워 캘리브레이션
lerobot-calibrate \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1

# 리더 캘리브레이션
lerobot-calibrate \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1 \
    --teleop.id=my_so101_leader_1
```

#### 2. 텔레오퍼레이션

```bash
lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1 \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1 \
    --teleop.id=my_so101_leader_1
```

#### 3. 데이터셋 기록 (단일 카메라)

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1 \
    --robot.cameras="{ front: {type: opencv, index_or_path: /dev/follower_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG}}" \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1 \
    --teleop.id=my_so101_leader_1 \
    --display_data=true \
    --dataset.repo_id=jinhyuk2me/my_dataset \
    --dataset.num_episodes=5 \
    --dataset.single_task="Pick up the block"
```

#### 4. 데이터셋 기록 (다중 카메라) - 권장

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1 \
    --robot.cameras="{ 
      top: {type: opencv, index_or_path: /dev/top_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG},
      front: {type: opencv, index_or_path: /dev/follower_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG}
    }" \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1 \
    --teleop.id=my_so101_leader_1 \
    --display_data=true \
    --dataset.repo_id=jinhyuk2me/my_dataset \
    --dataset.num_episodes=5 \
    --dataset.single_task="Pick up the block"
```

#### 5. 정책 학습

```bash
lerobot-train \
    --dataset.repo_id=jinhyuk2me/my_dataset \
    --policy.type=act \
    --output_dir=outputs/train/my_policy \
    --job_name=my_policy \
    --policy.device=cuda \
    --wandb.enable=true
```

#### 6. 평가/추론

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1 \
    --robot.cameras="{ 
      top: {type: opencv, index_or_path: /dev/top_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG},
      front: {type: opencv, index_or_path: /dev/follower_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG}
    }" \
    --policy.path=jinhyuk2me/my_policy \
    --display_data=true \
    --dataset.repo_id=jinhyuk2me/eval_my_policy \
    --dataset.num_episodes=10
```

---

## 🔍 검증 명령어

설정이 올바른지 확인:

```bash
# 포트 확인
ls -l /dev/leader_arm_1 /dev/follower_arm_1

# 카메라 확인
v4l2-ctl --list-devices

# 카메라 테스트
ffplay /dev/top_cam_1       # 탑뷰 카메라
ffplay /dev/follower_cam_1  # 로봇 카메라

# LeRobot 카메라 감지
lerobot-find-cameras opencv

# 캘리브레이션 파일 확인
find ~/.cache/huggingface/lerobot/calibration -name "*calibration*.json"

# 로컬 데이터셋 시각화 (rerun)
lerobot-dataset-viz \
  --repo-id jinhyuk2me/record-test \
  --episode-index 0 \
  --root ./outputs/datasets/record-test-03 \
  --display-compressed-images false
```

---

## ❌ 흔한 실수

### 1. 잘못된 ID 사용

```bash
# ❌ 잘못됨 - 다른 ID 사용
--robot.id=my_awesome_follower_arm
--teleop.id=my_awesome_leader_arm

# ✅ 올바름 - 문서의 ID 사용
--robot.id=my_so101_follower_1
--teleop.id=my_so101_leader_1
```

### 2. 잘못된 카메라 사용

```bash
# ❌ 잘못됨 - 노트북 웹캠
--robot.cameras="{ front: {..., index_or_path: /dev/video0, ...}}"

# ✅ 올바름 - 로봇 카메라
--robot.cameras="{ front: {..., index_or_path: /dev/follower_cam_1, ...}}"
```

### 3. ID 불일치

```bash
# ❌ 잘못됨 - 캘리브레이션과 다른 ID
lerobot-calibrate --robot.id=my_so101_follower_1
lerobot-record --robot.id=different_id  # 캘리브레이션 못 찾음!

# ✅ 올바름 - 항상 같은 ID
lerobot-calibrate --robot.id=my_so101_follower_1
lerobot-record --robot.id=my_so101_follower_1  # 캘리브레이션 자동 로드
```

---

## 📚 관련 문서

- [USB Port Management](./01_getting_started/04_usb_port_management_ko.md) - udev rule 상세 설정
- [Cameras Guide](./01_getting_started/03_cameras_ko.md) - 카메라 설정 및 문제 해결
- [SO-101 Setup](./01_getting_started/02_so-101_setup_ko.md) - 로봇 조립 및 초기 설정
- [Imitation Learning Tutorial](./02_tutorials/01_imitation_learning_ko.md) - 모방 학습 전체 워크플로우

---

## 💡 유지보수

### 새 로봇 팔 추가

1. udev rule 추가
2. 이 문서에 매핑 추가
3. 캘리브레이션 수행
4. ID를 문서화

### 새 카메라 추가

1. `v4l2-ctl --list-devices`로 확인
2. 이 문서에 추가
3. `ffplay`로 테스트
4. 카메라 ID 정의

### 수정 시 주의

⚠️ **이 문서의 값을 변경하면 모든 튜토리얼 문서도 함께 업데이트하세요!**

---

**최종 업데이트**: 2026-01-27 by @jinhyuk2me
