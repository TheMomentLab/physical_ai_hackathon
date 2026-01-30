# 카메라

LeRobot은 휴대폰 카메라, 노트북 내장 카메라, 외장 웹캠, Intel RealSense 카메라 등 다양한 비디오 캡처 옵션을 제공합니다. 대부분의 카메라는 `OpenCVCamera` 또는 `RealSenseCamera` 클래스로 효율적으로 프레임을 기록할 수 있습니다. `OpenCVCamera`의 추가 호환성 정보는 [Video I/O with OpenCV Overview](https://docs.opencv.org/4.x/d0/da7/videoio_overview.html)를 참고하세요.

<a id="setup-cameras"></a>

## 카메라 찾기

카메라 인스턴스를 생성하려면 카메라 식별자가 필요합니다. 이 식별자는 컴퓨터를 재부팅하거나 카메라를 다시 연결하면 변경될 수 있으며, 이는 대부분 운영체제에 따라 달라집니다.

시스템에 연결된 카메라의 인덱스를 찾으려면 다음 스크립트를 실행하세요:

```bash
lerobot-find-cameras opencv # Intel RealSense 카메라라면 realsense
```

카메라가 두 대 연결되어 있다면 출력은 다음과 비슷합니다:

```
--- Detected Cameras ---
Camera #0:
  Name: OpenCV Camera @ 0
  Type: OpenCV
  Id: 0
  Backend api: AVFOUNDATION
  Default stream profile:
    Format: 16.0
    Width: 1920
    Height: 1080
    Fps: 15.0
--------------------
(more cameras ...)
```

> [!WARNING]
> `macOS`에서 Intel RealSense 카메라를 사용할 때 [이 오류](https://github.com/IntelRealSense/librealsense/issues/12307)인 `Error finding RealSense cameras: failed to set power state`가 발생할 수 있습니다. 이 경우 같은 명령을 `sudo` 권한으로 실행하면 해결됩니다. 다만 `macOS`에서 RealSense 카메라 사용은 안정적이지 않습니다.

## 카메라 사용하기

아래는 API 사용 예시 두 가지입니다.

- OpenCV 기반 카메라로 **비동기 프레임 캡처**
- Intel RealSense 카메라로 **컬러 및 깊이(depth) 캡처**

```python
from lerobot.cameras.opencv.configuration_opencv import OpenCVCameraConfig
from lerobot.cameras.opencv.camera_opencv import OpenCVCamera
from lerobot.cameras.configs import ColorMode, Cv2Rotation

# 원하는 FPS, 해상도, 컬러 모드, 회전을 지정해 `OpenCVCameraConfig`를 구성합니다.
config = OpenCVCameraConfig(
    index_or_path=0,
    fps=15,
    width=1920,
    height=1080,
    color_mode=ColorMode.RGB,
    rotation=Cv2Rotation.NO_ROTATION
)

# `OpenCVCamera`를 생성하고 연결합니다(기본으로 워밍업 읽기 수행).
camera = OpenCVCamera(config)
camera.connect()

# `async_read(timeout_ms)`로 비동기 프레임을 읽습니다.
try:
    for i in range(10):
        frame = camera.async_read(timeout_ms=200)
        print(f"Async frame {i} shape:", frame.shape)
finally:
    camera.disconnect()
```

```python
from lerobot.cameras.realsense.configuration_realsense import RealSenseCameraConfig
from lerobot.cameras.realsense.camera_realsense import RealSenseCamera
from lerobot.cameras.configs import ColorMode, Cv2Rotation

# 카메라 시리얼 번호를 지정하고 depth를 활성화하는 `RealSenseCameraConfig`를 생성합니다.
config = RealSenseCameraConfig(
    serial_number_or_name="233522074606",
    fps=15,
    width=640,
    height=480,
    color_mode=ColorMode.RGB,
    use_depth=True,
    rotation=Cv2Rotation.NO_ROTATION
)

# `RealSenseCamera`를 생성하고 연결합니다(기본으로 워밍업 읽기 수행).
camera = RealSenseCamera(config)
camera.connect()

# `read()`로 컬러 프레임을, `read_depth()`로 깊이 맵을 캡처합니다.
try:
    color_frame = camera.read()
    depth_map = camera.read_depth()
    print("Color frame shape:", color_frame.shape)
    print("Depth map shape:", depth_map.shape)
finally:
    camera.disconnect()
```

## 휴대폰 사용하기

macOS에서 iPhone을 카메라로 사용하려면 Continuity Camera 기능을 활성화하세요:

- Mac은 macOS 13 이상, iPhone은 iOS 16 이상이어야 합니다.
- 두 기기 모두 동일한 Apple ID로 로그인되어 있어야 합니다.
- USB 케이블로 연결하거나, 무선 연결을 위해 Wi-Fi와 Bluetooth를 켜세요.

자세한 내용은 [Apple 지원 문서](https://support.apple.com/en-gb/guide/mac-help/mchl77879b8a/mac)를 참고하세요.

다음 섹션의 카메라 설정 스크립트를 실행하면 iPhone이 자동으로 감지됩니다.

Linux에서 휴대폰을 카메라로 사용하려면 다음 순서로 가상 카메라를 설정하세요.

1. _`v4l2loopback-dkms`와 `v4l-utils` 설치_. 이 패키지들은 가상 카메라 장치(`v4l2loopback`)를 만들고, `v4l-utils`의 `v4l2-ctl`로 설정을 확인하는 데 필요합니다. 다음 명령으로 설치합니다:

```bash
sudo apt install v4l2loopback-dkms v4l-utils
```

2. _휴대폰에 [DroidCam](https://droidcam.app) 설치_. iOS와 Android 모두 지원됩니다.
3. _[OBS Studio](https://obsproject.com) 설치_. 카메라 피드를 관리하는 데 사용합니다. [Flatpak](https://flatpak.org)으로 설치하세요:

```bash
flatpak install flathub com.obsproject.Studio
```

4. _DroidCam OBS 플러그인 설치_. OBS Studio와 DroidCam을 연동합니다. 다음 명령으로 설치합니다:

```bash
flatpak install flathub com.obsproject.Studio.Plugin.DroidCam
```

5. _OBS Studio 실행_. 다음 명령으로 실행합니다:

```bash
flatpak run com.obsproject.Studio
```

6. _휴대폰을 소스로 추가_. [여기](https://droidcam.app/obs/usage)의 안내를 따르세요. 해상도는 반드시 `640x480`으로 설정합니다.
7. _해상도 설정 조정_. OBS Studio에서 `File > Settings > Video`로 이동해 `Base(Canvas) Resolution`과 `Output(Scaled) Resolution`을 모두 `640x480`으로 직접 입력합니다.
8. _가상 카메라 시작_. OBS Studio에서 [가상 카메라 가이드](https://obsproject.com/kb/virtual-camera-guide)를 따라 시작합니다.
9. _가상 카메라 확인_. `v4l2-ctl`로 장치를 확인합니다:

```bash
v4l2-ctl --list-devices
```

다음과 같은 항목이 보일 것입니다:

```
VirtualCam (platform:v4l2loopback-000):
/dev/video1
```

10. _카메라 해상도 확인_. `v4l2-ctl`로 가상 카메라 출력 해상도가 `640x480`인지 확인합니다. 아래 명령에서 `/dev/video1`을 `v4l2-ctl --list-devices` 결과에 맞게 변경하세요.

```bash
v4l2-ctl -d /dev/video1 --get-fmt-video
```

다음과 같은 출력이 보여야 합니다:

```
>>> Format Video Capture:
>>>    Width/Height      : 640/480
>>>    Pixel Format      : 'YUYV' (YUYV 4:2:2)
```

문제 해결: 해상도가 올바르지 않다면 가상 카메라 포트를 삭제하고 다시 시도해야 합니다. 가상 카메라는 생성 후 해상도를 변경할 수 없습니다.

모든 설정이 완료되면, 튜토리얼의 나머지 단계로 진행할 수 있습니다.

## 일반적인 카메라 문제 해결

### 카메라가 감지되지 않음

```bash
# 모든 비디오 디바이스 확인
v4l2-ctl --list-devices

# LeRobot으로 카메라 찾기
lerobot-find-cameras opencv
```

**해결 방법:**
- USB 케이블 재연결
- 다른 USB 포트 시도
- `sudo dmesg | tail`로 시스템 로그 확인

### 까만 화면 또는 읽기 실패

**체크리스트:**
1. ✅ **렌즈 캡 제거 확인** - 가장 흔한 원인!
2. ✅ 카메라가 밝은 곳을 향하는지 확인
3. ✅ USB 케이블이 제대로 연결되었는지 확인
4. ✅ 카메라에 전원이 들어오는지 확인 (LED 확인)

**진단 명령어:**

```bash
# 지원 포맷 확인
v4l2-ctl -d /dev/video0 --list-formats-ext

# 다른 포맷으로 테스트
ffplay -f v4l2 -input_format mjpeg -video_size 640x480 /dev/video0
ffplay -f v4l2 -input_format yuyv422 -video_size 640x480 /dev/video0

# GUI 앱으로 테스트
cheese
```

### 권한 오류 (Permission Denied)

```bash
# 사용자를 video 그룹에 추가
sudo usermod -a -G video $USER

# 로그아웃 후 재로그인 또는 재부팅

# 임시 해결 (재부팅 시 초기화)
sudo chmod 666 /dev/video0
```

### 여러 /dev/videoX 디바이스

하나의 카메라가 여러 디바이스 노드를 생성할 수 있습니다:

```bash
# 예시 출력
Integrated Camera (usb-xxx):
    /dev/video0  # 실제 비디오 스트림
    /dev/video1  # 메타데이터

Innomaker USB Camera (usb-xxx):
    /dev/video2  # 실제 비디오 스트림
    /dev/video3  # 메타데이터
```

**일반적으로**:
- 짝수 번호(video0, video2, video4) = 실제 비디오
- 홀수 번호(video1, video3, video5) = 메타데이터

각 디바이스를 테스트하여 작동하는 것을 사용하세요.

### 해상도 또는 FPS 문제

```bash
# 지원 해상도 확인
v4l2-ctl -d /dev/video0 --list-framesizes=YUYV

# 지원 FPS 확인
v4l2-ctl -d /dev/video0 --list-frameintervals=width=640,height=480,pixelformat=YUYV
```

LeRobot에서 지원하지 않는 해상도/FPS를 설정하면 에러가 발생합니다. 지원되는 값을 사용하세요.

### 카메라가 느리거나 끊김

**원인:**
- USB 대역폭 부족
- 너무 높은 해상도/FPS

**해결 방법:**
1. 해상도 낮추기 (1920x1080 → 640x480)
2. FPS 낮추기 (30 → 15)
3. USB 3.0 포트 사용
4. 다른 USB 디바이스 분리

### 추가 도움

문제가 계속되면 [LeRobot Discord](https://discord.com/invite/s3KuuzsPFb)에서 도움을 받으세요.
