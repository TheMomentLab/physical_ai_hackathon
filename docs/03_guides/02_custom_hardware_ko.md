# Bring Your Own Hardware (커스텀 하드웨어 연동)

이 튜토리얼은 여러분의 로봇 설계를 LeRobot 생태계에 통합하고, 데이터 수집, 제어 파이프라인, 정책 학습 및 추론 등 모든 도구를 활용하는 방법을 설명합니다.

이를 위해 LeRobot은 물리 로봇 통합을 위한 표준 인터페이스인 [`Robot`](https://github.com/huggingface/lerobot/blob/main/src/lerobot/robots/robot.py) 베이스 클래스를 제공합니다. 구현 방법을 단계별로 살펴보겠습니다.

## 사전 준비

- 통신 인터페이스를 제공하는 로봇(예: 시리얼, CAN, TCP)
- 센서 데이터를 읽고 모터 명령을 전송하는 방법(제조사 SDK/API 또는 직접 구현한 프로토콜)
- LeRobot 설치 완료. [설치 가이드](./01_installation_ko.md)를 참고하세요.

## 모터 선택하기

Feetech 또는 Dynamixel 모터를 사용한다면, LeRobot에 내장된 버스 인터페이스를 사용할 수 있습니다:

- [`FeetechMotorsBus`](https://github.com/huggingface/lerobot/blob/main/src/lerobot/motors/feetech/feetech.py) – Feetech 서보 제어
- [`DynamixelMotorsBus`](https://github.com/huggingface/lerobot/blob/main/src/lerobot/motors/dynamixel/dynamixel.py) – Dynamixel 서보 제어

API는 [`MotorsBus`](https://github.com/huggingface/lerobot/blob/main/src/lerobot/motors/motors_bus.py) 추상 클래스를 참고하세요.
좋은 예시로는 [SO101 follower 구현](https://github.com/huggingface/lerobot/blob/main/src/lerobot/robots/so_follower/so101_follower/so101_follower.py)을 확인해 볼 수 있습니다.

호환된다면 위 버스를 사용하세요. 그렇지 않다면 Python 인터페이스를 찾거나 직접 작성해야 합니다(이 튜토리얼 범위 밖):

- Python SDK를 찾기(또는 C/C++ 바인딩 사용)
- 기본 통신 래퍼 구현(pyserial, socket, CANopen 등)

혼자만의 길이 아닙니다. 커뮤니티 기여의 상당수는 커스텀 보드나 펌웨어를 사용합니다.

현재 Feetech/Dynamixel에서 지원하는 서보는 다음과 같습니다:

- Feetech:
  - STS & SMS 시리즈 (protocol 0): `sts3215`, `sts3250`, `sm8512bl`
  - SCS 시리즈 (protocol 1): `scs0009`
- Dynamixel (protocol 2.0만 지원): `xl330-m077`, `xl330-m288`, `xl430-w250`, `xm430-w350`, `xm540-w270`, `xc430-w150`

이 목록에 없는 Feetech/Dynamixel 서보를 사용한다면 [Feetech table](https://github.com/huggingface/lerobot/blob/main/src/lerobot/motors/feetech/tables.py) 또는 [Dynamixel table](https://github.com/huggingface/lerobot/blob/main/src/lerobot/motors/dynamixel/tables.py)에 추가할 수 있습니다. 모델에 따라 모델별 정보 추가가 필요하지만, 대부분의 경우 변경량은 많지 않습니다.

이후 예시는 `FeetechMotorsBus`를 사용합니다. 필요에 따라 모터 인터페이스를 교체하고 코드를 맞춰 주세요.

## Step 1: `Robot` 인터페이스 상속

먼저 로봇의 설정 클래스와 문자열 식별자(`name`)를 정의합니다. 로봇에 쉽게 변경하고 싶은 설정(예: 포트/주소, 보드레이트 등)이 있다면 여기에 추가하세요.

여기서는 포트 이름과 기본 카메라 하나를 포함합니다:

```python
from dataclasses import dataclass, field

from lerobot.cameras import CameraConfig
from lerobot.cameras.opencv import OpenCVCameraConfig
from lerobot.robots import RobotConfig

@RobotConfig.register_subclass("my_cool_robot")
@dataclass
class MyCoolRobotConfig(RobotConfig):
    port: str
    cameras: dict[str, CameraConfig] = field(
        default_factory={
            "cam_1": OpenCVCameraConfig(
                index_or_path=2,
                fps=30,
                width=480,
                height=640,
            ),
        }
    )
```

카메라 감지/추가 방법은 [카메라 튜토리얼](./cameras_ko.md)을 참고하세요.

다음으로 `Robot`을 상속한 실제 로봇 클래스를 구현합니다. 이 추상 클래스는 LeRobot 도구들이 로봇을 사용할 수 있게 하는 계약을 정의합니다.

여기서는 카메라 하나를 가진 5-자유도(5-DoF) 로봇을 가정합니다. 단, `Robot`은 로봇 형태를 제한하지 않으므로 자유롭게 설계할 수 있습니다.

```python
from lerobot.cameras import make_cameras_from_configs
from lerobot.motors import Motor, MotorNormMode
from lerobot.motors.feetech import FeetechMotorsBus
from lerobot.robots import Robot

class MyCoolRobot(Robot):
    config_class = MyCoolRobotConfig
    name = "my_cool_robot"

    def __init__(self, config: MyCoolRobotConfig):
        super().__init__(config)
        self.bus = FeetechMotorsBus(
            port=self.config.port,
            motors={
                "joint_1": Motor(1, "sts3250", MotorNormMode.RANGE_M100_100),
                "joint_2": Motor(2, "sts3215", MotorNormMode.RANGE_M100_100),
                "joint_3": Motor(3, "sts3215", MotorNormMode.RANGE_M100_100),
                "joint_4": Motor(4, "sts3215", MotorNormMode.RANGE_M100_100),
                "joint_5": Motor(5, "sts3215", MotorNormMode.RANGE_M100_100),
            },
            calibration=self.calibration,
        )
        self.cameras = make_cameras_from_configs(config.cameras)
```

## Step 2: 관측과 액션 feature 정의

이 두 속성은 로봇과 이를 사용하는 도구(데이터 수집, 학습 파이프라인 등) 간의 인터페이스 계약을 정의합니다.

> [!WARNING]
> 로봇이 아직 연결되지 않은 상태에서도 이 속성들은 호출 가능해야 합니다. 따라서 하드웨어 런타임 상태에 의존하지 않도록 주의하세요.

### `observation_features`

로봇 센서 출력의 구조를 설명하는 딕셔너리를 반환해야 합니다. 키는 `get_observation()`의 결과와 동일해야 하며, 값은 배열/이미지의 shape 또는 단순 값의 타입을 나타냅니다.

예시(5-DoF 팔 + 카메라 1대):

```python
@property
def _motors_ft(self) -> dict[str, type]:
    return {
        "joint_1.pos": float,
        "joint_2.pos": float,
        "joint_3.pos": float,
        "joint_4.pos": float,
        "joint_5.pos": float,
    }

@property
def _cameras_ft(self) -> dict[str, tuple]:
    return {
        cam: (self.cameras[cam].height, self.cameras[cam].width, 3) for cam in self.cameras
    }

@property
def observation_features(self) -> dict:
    return {**self._motors_ft, **self._cameras_ft}
```

이 경우 관측은 각 모터의 위치와 카메라 이미지로 구성된 딕셔너리입니다.

### `action_features`

`send_action()`이 기대하는 명령 구조를 설명합니다. 키는 입력 형식과 일치해야 하며, 값은 각 명령의 shape/type을 나타냅니다.

아래는 `observation_features`와 동일한 관절 proprioceptive feature를 사용합니다. 즉, 액션은 각 모터의 목표 위치를 의미합니다.

```python
def action_features(self) -> dict:
    return self._motors_ft
```

## Step 3: 연결/해제 처리

이 메서드들은 하드웨어와의 통신을 열고 닫는 역할을 합니다(시리얼 포트, CAN 인터페이스, USB 장치, 카메라 등).

### `is_connected`

하드웨어 통신이 확립되었는지 나타내야 합니다. `True`일 때 `get_observation()`과 `send_action()`이 정상 동작해야 합니다.

```python
@property
def is_connected(self) -> bool:
    return self.bus.is_connected and all(cam.is_connected for cam in self.cameras.values())
```

### `connect()`

하드웨어 통신을 시작합니다. 또한 보정이 필요하고 아직 보정되지 않았다면 기본적으로 보정 절차를 시작해야 합니다. 로봇에 필요한 설정이 있다면 여기서 수행하세요.

```python
def connect(self, calibrate: bool = True) -> None:
    self.bus.connect()
    if not self.is_calibrated and calibrate:
        self.calibrate()

    for cam in self.cameras.values():
        cam.connect()

    self.configure()
```

### `disconnect()`

하드웨어 통신을 정상 종료하고 리소스를 해제합니다(스레드/프로세스 정리, 포트 닫기 등).

여기서는 `MotorsBus`와 `Camera`가 자체 `disconnect()`를 제공하므로 그대로 호출합니다:

```python
def disconnect(self) -> None:
    self.bus.disconnect()
    for cam in self.cameras.values():
        cam.disconnect()
```

## Step 4: 보정(calibration)과 구성(configure) 지원

LeRobot은 보정 데이터를 자동으로 저장/로드합니다. 이는 관절 오프셋, 제로 포지션, 센서 정렬 등에 유용합니다.

> 하드웨어 특성상 필요 없으면 아래 메서드를 no-op으로 두어도 됩니다:

```python
@property
def is_calibrated(self) -> bool:
    return True

def calibrate(self) -> None:
    pass
```

### `is_calibrated`

필요한 보정이 로드되어 있는지 나타냅니다.

```python
@property
def is_calibrated(self) -> bool:
    return self.bus.is_calibrated
```

### `calibrate()`

보정의 목적은 두 가지입니다:

- 각 모터의 물리적 가동 범위를 파악해 그 범위 안에서만 명령을 전송하기
- 모터 원시 값을 임의의 불연속 값 대신 의미 있는 연속 값(퍼센트, 각도 등)으로 정규화하기

보정 로직을 구현하고 `self.calibration`을 업데이트해야 합니다. Feetech/Dynamixel 버스를 사용한다면 관련 메서드가 이미 제공됩니다.

```python
def calibrate(self) -> None:
    self.bus.disable_torque()
    for motor in self.bus.motors:
        self.bus.write("Operating_Mode", motor, OperatingMode.POSITION.value)

    input(f"Move {self} to the middle of its range of motion and press ENTER....")
    homing_offsets = self.bus.set_half_turn_homings()

    print(
        "Move all joints sequentially through their entire ranges "
        "of motion.\nRecording positions. Press ENTER to stop..."
    )
    range_mins, range_maxes = self.bus.record_ranges_of_motion()

    self.calibration = {}
    for motor, m in self.bus.motors.items():
        self.calibration[motor] = MotorCalibration(
            id=m.id,
            drive_mode=0,
            homing_offset=homing_offsets[motor],
            range_min=range_mins[motor],
            range_max=range_maxes[motor],
        )

    self.bus.write_calibration(self.calibration)
    self._save_calibration()
    print("Calibration saved to", self.calibration_fpath)
```

### `configure()`

하드웨어 설정(서보 제어 모드, 게인 등)을 적용합니다. 연결 시점에 실행되며 여러 번 호출해도 안전하도록(idempotent) 작성하는 것이 좋습니다.

```python
def configure(self) -> None:
    with self.bus.torque_disabled():
        self.bus.configure_motors()
        for motor in self.bus.motors:
            self.bus.write("Operating_Mode", motor, OperatingMode.POSITION.value)
            self.bus.write("P_Coefficient", motor, 16)
            self.bus.write("I_Coefficient", motor, 0)
            self.bus.write("D_Coefficient", motor, 32)
```

## Step 5: 센서 읽기와 액션 전송 구현

런타임의 핵심 I/O 루프입니다.

### `get_observation()`

로봇 센서 값을 딕셔너리로 반환합니다. 여기에는 모터 상태, 카메라 프레임, 기타 센서 등이 포함될 수 있습니다. LeRobot에서는 이 관측이 정책 입력으로 사용되며, 구조는 `observation_features`와 일치해야 합니다.

```python
def get_observation(self) -> dict[str, Any]:
    if not self.is_connected:
        raise ConnectionError(f"{self} is not connected.")

    # 팔 위치 읽기
    obs_dict = self.bus.sync_read("Present_Position")
    obs_dict = {f"{motor}.pos": val for motor, val in obs_dict.items()}

    # 카메라 이미지 캡처
    for cam_key, cam in self.cameras.items():
        obs_dict[cam_key] = cam.async_read()

    return obs_dict
```

### `send_action()`

`action_features`와 같은 구조의 딕셔너리를 받아 하드웨어로 전달합니다. 필요하다면 안전 제한(클리핑/스무딩)을 적용하고 실제 전송 값을 반환할 수 있습니다.

예시에서는 단순히 그대로 전송합니다:

```python
def send_action(self, action: dict[str, Any]) -> dict[str, Any]:
    goal_pos = {key.removesuffix(".pos"): val for key, val in action.items()}

    # 팔에 목표 위치 전송
    self.bus.sync_write("Goal_Position", goal_pos)

    return action
```

## 텔레오퍼레이터 추가하기

텔레오퍼레이션 장치를 구현하려면 [`Teleoperator`](https://github.com/huggingface/lerobot/blob/main/src/lerobot/teleoperators/teleoperator.py) 베이스 클래스를 사용할 수 있습니다. 구조는 `Robot`과 유사하며, 로봇 형태에 제한을 두지 않습니다.

주요 차이는 I/O 메서드입니다. 텔레오퍼레이터는 `get_action`으로 액션을 생성하고, `send_feedback`으로 피드백 액션을 받을 수 있습니다. 피드백은 리더 암의 힘/모션 피드백, 게임패드 진동 등 사용자가 액션 결과를 이해하는 데 도움이 되는 어떤 신호도 가능합니다. 구현 시 이 튜토리얼을 참고해 두 메서드에 맞춰 적용하세요.

## 나만의 `LeRobot` 디바이스 사용하기 🔌

카메라, 로봇, 텔레오퍼레이션 장치 등 커스텀 하드웨어를 별도의 설치 가능한 Python 패키지로 만들어 `lerobot`을 확장할 수 있습니다. 몇 가지 규칙만 지키면 `lerobot-teleop`, `lerobot-record` 같은 CLI 도구가 별도의 수정 없이 플러그인을 자동으로 발견하고 통합합니다.

이 가이드는 플러그인 규칙을 설명합니다.

### 핵심 4가지 규칙

커스텀 디바이스가 자동으로 탐지되려면 아래 4가지를 지켜야 합니다.

#### 1\. 특정 접두어로 시작하는 설치 가능한 패키지 만들기

프로젝트는 표준 Python 패키지 형태여야 하며, `pyproject.toml` 또는 `setup.py`에 정의된 패키지 이름이 아래 접두어 중 하나로 시작해야 합니다:

- 로봇: `lerobot_robot_`
- 카메라: `lerobot_camera_`
- 텔레오퍼레이션 장치: `lerobot_teleoperator_`

이 접두어 규칙을 통해 `lerobot`이 Python 환경에서 플러그인을 자동으로 찾습니다.

#### 2\. `SomethingConfig`/`Something` 네이밍 규칙

구현 클래스는 설정 클래스 이름에서 `Config` 접미사를 뺀 이름을 사용해야 합니다.

- **Config 클래스:** `MyAwesomeTeleopConfig`
- **디바이스 클래스:** `MyAwesomeTeleop`

#### 3\. 예측 가능한 파일 구조

디바이스 클래스(`MyAwesomeTeleop`)는 설정 클래스(`MyAwesomeTeleopConfig`)와 예측 가능한 모듈 구조에 있어야 합니다. `lerobot`은 다음 경로를 자동으로 탐색합니다:

- 설정 클래스와 **같은 모듈**
- 설정 클래스 이름의 **하위 모듈**(예: `my_awesome_teleop.py`)

가장 간단한 방법은 같은 디렉토리 안에서 파일을 분리해 두는 것입니다.

#### 4\. `__init__.py`에서 클래스 노출

패키지의 `__init__.py`에서 설정 클래스와 디바이스 클래스를 import하여 공개해야 합니다.

### 전체 예시

`my_awesome_teleop` 텔레오퍼레이터를 만든다고 가정해 보겠습니다.

#### 디렉토리 구조

아래와 같은 구조가 되어야 합니다. 패키지 이름 `lerobot_teleoperator_my_awesome_teleop`이 **규칙 #1**을 만족합니다.

```
lerobot_teleoperator_my_awesome_teleop/
├── pyproject.toml # (또는 setup.py) lerobot을 의존성으로 포함
└── lerobot_teleoperator_my_awesome_teleop/
    ├── __init__.py
    ├── config_my_awesome_teleop.py
    └── my_awesome_teleop.py
```

#### 파일 내용

- **`config_my_awesome_teleop.py`**: 설정 클래스를 정의합니다. `Config` 접미사를 확인하세요(**규칙 #2**).

  ```python
  from dataclasses import dataclass

  from lerobot.teleoperators.config import TeleoperatorConfig

  @TeleoperatorConfig.register_subclass("my_awesome_teleop")
  @dataclass
  class MyAwesomeTeleopConfig(TeleoperatorConfig):
      # 설정 필드
      port: str = "192.168.1.1"
  ```

- **`my_awesome_teleop.py`**: 디바이스 구현입니다. 클래스 이름은 설정 클래스와 일치해야 합니다(**규칙 #2**). 파일 구조는 **규칙 #3**을 만족합니다.

  ```python
  from lerobot.teleoperators.teleoperator import Teleoperator

  from .config_my_awesome_teleop import MyAwesomeTeleopConfig

  class MyAwesomeTeleop(Teleoperator):
      config_class = MyAwesomeTeleopConfig
      name = "my_awesome_teleop"

      def __init__(self, config: MyAwesomeTeleopConfig):
          super().__init__(config)
          self.config = config

      # 디바이스 로직(예: connect)을 여기에 구현
  ```

- **`__init__.py`**: 핵심 클래스를 노출합니다(**규칙 #4**).

  ```python
  from .config_my_awesome_teleop import MyAwesomeTeleopConfig
  from .my_awesome_teleop import MyAwesomeTeleop
  ```

### 설치 및 사용

1. **플러그인 설치**: 로컬 패키지는 editable 모드로 설치하거나 PyPI에서 설치합니다.

    ```bash
    # 로컬 설치
    # 플러그인 루트 디렉토리로 이동 후 설치
    cd lerobot_teleoperator_my_awesome_teleop
    pip install -e .

    # PyPI에서 설치
    pip install lerobot_teleoperator_my_awesome_teleop
    ```

2. **CLI에서 사용**: 타입 이름으로 바로 사용할 수 있습니다.

    ```bash
    lerobot-teleoperate --teleop.type=my_awesome_teleop \
    # other arguments
    ```

이제 커스텀 디바이스가 완전히 통합되었습니다.

### 예시가 필요하신가요?

커뮤니티에서 제공하는 예시를 참고하세요:

- https://github.com/SpesRobotics/lerobot-robot-xarm
- https://github.com/SpesRobotics/lerobot-teleoperator-teleop

## 마무리

로봇 클래스 구현이 끝나면 LeRobot의 생태계를 그대로 활용할 수 있습니다:

- 텔레오퍼레이터로 로봇 제어(또는 직접 텔레오퍼레이션 장치 통합)
- 학습 데이터 기록 및 시각화
- RL 또는 모방 학습 파이프라인에 통합

질문이 있으면 [Discord](https://discord.gg/s3KuuzsPFb) 커뮤니티로 연락 주세요. 🤗
