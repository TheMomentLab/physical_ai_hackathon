# SO-101

아래 단계에서는 대표 로봇인 SO-101을 조립하는 방법을 설명합니다.

## 부품 준비

이 [README](https://github.com/TheRobotStudio/SO-ARM100)를 따르세요. 부품 목록과 부품을 구입할 수 있는 링크, 그리고 부품을 3D 프린팅하는 방법이 포함되어 있습니다.
또한 처음 출력하는 경우이거나 3D 프린터가 없다면 안내해 주세요.

## LeRobot 🤗 설치

LeRobot을 설치하려면 [Installation Guide](../01_getting_started/01_installation_ko.md)를 따르세요.

이 안내 외에도 Feetech SDK를 설치해야 합니다:

```bash
pip install -e ".[feetech]"
```

## 단계별 조립 지침

팔로워 팔은 1/345 감속비의 STS3215 모터 6개를 사용합니다. 반면 리더는 자기 무게를 지탱하면서도 큰 힘 없이 움직일 수 있도록 서로 다른 감속비의 모터 3개를 사용합니다. 어떤 관절에 어떤 모터가 필요한지는 아래 표에 나와 있습니다.

| Leader-Arm Axis     | Motor | Gear Ratio |
| ------------------- | :---: | :--------: |
| Base / Shoulder Pan |   1   |  1 / 191   |
| Shoulder Lift       |   2   |  1 / 345   |
| Elbow Flex          |   3   |  1 / 191   |
| Wrist Flex          |   4   |  1 / 147   |
| Wrist Roll          |   5   |  1 / 147   |
| Gripper             |   6   |  1 / 147   |

## 모터 구성

### 1. 각 팔에 해당하는 USB 포트 찾기

각 버스 서보 어댑터의 포트를 찾으려면 MotorBus를 USB와 전원으로 컴퓨터에 연결하세요. 아래 스크립트를 실행하고, 안내가 나오면 MotorBus를 분리하세요:

```bash
lerobot-find-port
```

예시 출력:

```
Finding all available ports for the MotorBus.
['/dev/tty.usbmodem575E0032081', '/dev/tty.usbmodem575E0031751']
Remove the USB cable from your MotorsBus and press Enter when done.

[...Disconnect corresponding leader or follower arm and press Enter...]

The port of this MotorsBus is /dev/tty.usbmodem575E0032081
Reconnect the USB cable.
```

찾은 포트: `/dev/tty.usbmodem575E0032081` 가 리더 또는 팔로워 팔에 해당합니다.

Linux에서는 다음을 실행해 USB 포트 접근 권한을 부여해야 할 수도 있습니다:

```bash
sudo chmod 666 /dev/ttyACM0
sudo chmod 666 /dev/ttyACM1
```

예시 출력:

```
Finding all available ports for the MotorBus.
['/dev/ttyACM0', '/dev/ttyACM1']
Remove the usb cable from your MotorsBus and press Enter when done.

[...Disconnect corresponding leader or follower arm and press Enter...]

The port of this MotorsBus is /dev/ttyACM1
Reconnect the USB cable.
```

찾은 포트: `/dev/ttyACM1` 가 리더 또는 팔로워 팔에 해당합니다.

### 2. 모터 ID와 보드레이트 설정

각 모터는 버스에서 고유한 ID로 식별됩니다. 새 모터는 보통 기본 ID가 `1`로 설정되어 있습니다. 모터와 컨트롤러가 제대로 통신하려면 각 모터에 서로 다른 고유 ID를 먼저 설정해야 합니다. 또한 버스에서 데이터가 전송되는 속도는 보드레이트로 결정됩니다. 서로 통신하려면 컨트롤러와 모든 모터가 동일한 보드레이트로 설정되어 있어야 합니다.

이를 위해 먼저 컨트롤러로 각 모터에 개별적으로 연결해 위 설정을 합니다. 이 값들은 모터 내부 메모리의 비휘발성 영역(EEPROM)에 기록되므로 한 번만 하면 됩니다.

다른 로봇에서 모터를 재사용하는 경우, ID와 보드레이트가 맞지 않을 가능성이 크므로 이 단계도 필요합니다.

아래 영상은 모터 ID를 설정하는 단계의 순서를 보여줍니다.

##### 모터 설정 영상

  
    
  

#### 팔로워

컴퓨터의 USB 케이블과 전원 공급 장치를 팔로워 팔의 컨트롤러 보드에 연결하세요. 그런 다음 아래 명령을 실행하거나 이전 단계에서 얻은 포트로 API 예제를 실행하세요. 또한 `id` 파라미터로 리더 팔에 이름을 지정해야 합니다.

```bash
lerobot-setup-motors \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1  # port.txt에서 정의한 persistent device name
```

문제 해결

이 시점에 오류가 발생하면 케이블이 제대로 연결되어 있는지 확인하세요:

  Power supply
  USB cable between your computer and the controller board
  The 3-pin cable from the controller board to the motor

Waveshare 컨트롤러 보드를 사용하는 경우, 두 점퍼가 `B` 채널(USB)에 설정되어 있는지 확인하세요.

그 다음 아래 메시지가 표시됩니다:

```bash
'gripper' motor id set to 6
```

그리고 다음 지시가 이어집니다:

```bash
Connect the controller board to the 'wrist_roll' motor only and press enter.
```

컨트롤러 보드에서 3핀 케이블을 분리할 수 있지만, 반대쪽의 그리퍼 모터에는 연결된 상태로 두어도 됩니다(이미 올바른 위치에 있기 때문입니다). 이제 다른 3핀 케이블을 손목 롤 모터에 꽂고 컨트롤러 보드에 연결하세요. 앞선 모터와 마찬가지로 보드에는 해당 모터만 연결되어 있어야 하며, 모터 자체도 다른 모터와 연결되어 있으면 안 됩니다.

안내되는 대로 각 모터에 대해 같은 작업을 반복하세요.

> [!TIP]
> 각 단계에서 Enter를 누르기 전에 배선을 확인하세요. 예를 들어 보드를 조작하는 동안 전원 공급 케이블이 빠질 수 있습니다.

완료되면 스크립트가 종료되고 모터는 사용할 준비가 됩니다. 이제 각 모터를 3핀 케이블로 서로 연결하고, 첫 번째 모터(‘shoulder pan’, id=1)에서 나온 케이블을 컨트롤러 보드에 연결하세요. 컨트롤러 보드는 이제 팔의 베이스에 부착할 수 있습니다.

#### 리더

리더 팔도 같은 단계를 수행하세요.

```bash
lerobot-setup-motors \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1  # port.txt에서 정의한 persistent device name
```

### Joint 2

- 위에서 두 번째 모터를 미끄러뜨려 끼웁니다.
- 두 번째 모터를 M2x6mm 나사 4개로 고정합니다.
- 두 개의 모터 혼을 모터 2에 부착하고, 다시 M3x6mm 혼 나사를 사용합니다.
- 상완(upper arm)을 양쪽에 M3x6mm 나사 4개로 부착합니다.

  
    
  

### Joint 3

- 모터 3을 삽입하고 M2x6mm 나사 4개로 고정합니다.
- 두 개의 모터 혼을 모터 3에 부착하고, 하나는 M3x6mm 혼 나사로 고정합니다.
- 전완(forearm)을 양쪽에 M3x6mm 나사 4개로 모터 3에 연결합니다.

  
    
  

### Joint 4

- 모터 홀더 4를 끼웁니다.
- 모터 4를 끼워 넣습니다.
- 모터 4를 M2x6mm 나사 4개로 고정하고 모터 혼을 부착한 뒤 M3x6mm 혼 나사를 사용합니다.

  
    
  

### Joint 5

- 모터 5를 손목 홀더에 넣고 M2x6mm 전면 나사 2개로 고정합니다.
- 손목 모터에는 모터 혼 하나만 설치하고 M3x6mm 혼 나사를 사용해 고정합니다.
- 손목을 양쪽에 M3x6mm 나사 4개로 모터 4에 고정합니다.

  
    
  

### 그리퍼 / 핸들

- 그리퍼를 모터 5에 부착하고, 손목의 모터 혼에 M3x6mm 나사 4개로 고정합니다.
- 그리퍼 모터를 삽입하고 양쪽에 M2x6mm 나사 2개로 고정합니다.
- 모터 혼을 부착하고 다시 M3x6mm 혼 나사를 사용합니다.
- 그리퍼 클로를 양쪽에 M3x6mm 나사 4개로 고정합니다.

  
    
  

- 리더 홀더를 손목에 장착하고 M3x6mm 나사 4개로 고정합니다.
- 핸들을 모터 5에 M2x6mm 나사 1개로 부착합니다.
- 그리퍼 모터를 삽입하고 양쪽에 M2x6mm 나사 2개로 고정한 뒤, 모터 혼을 M3x6mm 혼 나사로 부착합니다.
- 팔로워 트리거를 M3x6mm 나사 4개로 부착합니다.

  
    
  

## 캘리브레이션

다음으로 로봇을 캘리브레이션해야 합니다. 리더 팔과 팔로워 팔이 같은 물리적 위치에 있을 때 동일한 위치 값을 가지도록 하기 위함입니다.
캘리브레이션 과정은 매우 중요하며, 한 로봇에서 학습된 신경망이 다른 로봇에서도 작동하도록 합니다.

#### 팔로워

다음 명령 또는 API 예제를 실행해 팔로워 팔을 캘리브레이션하세요:

```bash
lerobot-calibrate \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1 # port.txt에서 정의한 persistent device name
```

#### 리더

리더 팔도 같은 단계로 캘리브레이션하세요. 다음 명령 또는 API 예제를 실행합니다:

```bash
lerobot-calibrate \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1 \
    --teleop.id=my_so101_leader_1  # port.txt에서 정의한 persistent device name
```

> [!TIP]
> 질문이 있거나 도움이 필요하면 [Discord](https://discord.com/invite/s3KuuzsPFb)로 문의해 주세요.
