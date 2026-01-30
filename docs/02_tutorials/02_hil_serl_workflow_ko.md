# HIL-SERL 실제 로봇 학습 워크플로 가이드

이 튜토리얼에서는 LeRobot을 사용해 Human-in-the-Loop Sample-Efficient Reinforcement Learning(HIL-SERL)의 전체 워크플로를 따라가며, 실제 로봇에서 RL 정책을 몇 시간 만에 학습하는 방법을 익힙니다.

HIL-SERL은 사람의 데모와 온라인 학습, 그리고 인간 개입을 결합한 샘플 효율적 강화학습 알고리즘입니다. 소량의 인간 데모로 시작해 보상 분류기를 학습하고, 이후 actor-learner 구조에서 정책 실행 중 사람이 개입해 탐색을 유도하고 위험한 행동을 바로잡습니다. 이 튜토리얼에서는 게임패드로 개입을 제공하고 학습 과정 동안 로봇을 제어합니다.

HIL-SERL은 다음 세 가지 핵심 요소를 결합합니다:

1. **오프라인 데모 & 보상 분류기:** 소수의 인간 텔레오퍼레이션 에피소드와 시각 기반 성공 감지기를 사용해 정책의 출발점을 제공
2. **로봇 상의 actor / learner 루프 + 인간 개입:** 분산 SAC 학습기가 정책을 업데이트하는 동안, actor가 실제 로봇에서 탐색을 수행하며 사람은 언제든 개입 가능
3. **안전 & 효율 도구:** 관절/엔드이펙터(EE) 경계, ROI(관심영역) 전처리, WandB 모니터링으로 데이터 품질과 하드웨어 안전 확보

이 요소들을 결합하면, HIL-SERL은 모방 학습만 사용한 베이스라인 대비 더 빠른 사이클과 높은 성공률을 달성합니다.

HIL-SERL 워크플로, Luo et al. 2024

이 가이드는 LeRobot의 HilSerl 구현을 이용해 실제 로봇에서 정책을 학습하는 과정을 단계별로 설명합니다.

## 준비물

- 게임패드(권장) 또는 키보드
- Nvidia GPU
- 실제 로봇(팔로워/리더 암이 있으면 좋음. 키보드나 게임패드를 쓰면 필수는 아님)
- 로봇용 URDF 파일(kinematics 패키지에서 사용. `lerobot/model/kinematics.py` 참고)

## 어떤 작업을 학습할 수 있나요?

HIL-SERL은 다양한 조작 작업에 사용할 수 있습니다. 추천 사항은 다음과 같습니다.

- 시스템 동작을 이해하기 위해 간단한 작업부터 시작하세요.
  - 큐브를 목표 영역으로 밀기
  - 그리퍼로 큐브를 집어서 들어 올리기
- 너무 긴 horizon 작업은 피하세요. 5~10초 내에 완료 가능한 작업에 집중하세요.
- 시스템 이해가 충분해지면 더 복잡하고 긴 작업을 시도할 수 있습니다.
  - 큐브 집어서 놓기
  - 양팔로 물체 집기 같은 양팔 작업
  - 한 팔에서 다른 팔로 물체를 전달하는 hand-over 작업
  - 마음껏 확장!

## HIL-SERL 포함 LeRobot 설치

HIL-SERL을 사용하려면 `hilserl` extra를 설치해야 합니다.

```bash
pip install -e ".[hilserl]"
```

## 실제 로봇 학습 워크플로

### 설정 이해하기

학습 과정은 HILSerl 환경을 위한 올바른 설정에서 시작합니다. 핵심 설정 클래스는 `lerobot/rl/gym_manipulator.py`의 `GymManipulatorConfig`이며, 내부에 `HILSerlRobotEnvConfig`와 `DatasetConfig`가 중첩되어 있습니다. 설정은 기능별 서브 구성으로 나뉩니다:

```python
class GymManipulatorConfig:
    env: HILSerlRobotEnvConfig    # 환경 설정 (중첩)
    dataset: DatasetConfig    # 데이터셋 기록/리플레이 설정 (중첩)
    mode: str | None = None    # "record", "replay", 또는 None(학습)
    device: str = "cpu"    # 연산 장치

class HILSerlRobotEnvConfig(EnvConfig):
    robot: RobotConfig | None = None    # 메인 로봇 에이전트 (`lerobot/robots`)
    teleop: TeleoperatorConfig | None = None    # 텔레오퍼레이터(예: 게임패드, 리더 암)
    processor: HILSerlProcessorConfig    # 처리 파이프라인 설정 (중첩)
    name: str = "real_robot"    # 환경 이름
    task: str | None = None    # 태스크 식별자
    fps: int = 10    # 제어 주파수

# 중첩 프로세서 구성
class HILSerlProcessorConfig:
    control_mode: str = "gamepad"    # 제어 모드
    observation: ObservationConfig | None = None    # 관측 처리 설정
    image_preprocessing: ImagePreprocessingConfig | None = None    # 이미지 크롭/리사이즈 설정
    gripper: GripperConfig | None = None    # 그리퍼 제어/패널티 설정
    reset: ResetConfig | None = None    # 리셋 및 타이밍 설정
    inverse_kinematics: InverseKinematicsConfig | None = None    # IK 설정
    reward_classifier: RewardClassifierConfig | None = None    # 보상 분류기 설정
    max_gripper_pos: float | None = 100.0    # 그리퍼 최대 위치

# 하위 구성 클래스
class ObservationConfig:
    add_joint_velocity_to_observation: bool = False    # 관측에 관절 속도 추가
    add_current_to_observation: bool = False    # 관측에 모터 전류 추가
    display_cameras: bool = False    # 실행 중 카메라 피드 표시

class ImagePreprocessingConfig:
    crop_params_dict: dict[str, tuple[int, int, int, int]] | None = None    # 이미지 크롭 파라미터
    resize_size: tuple[int, int] | None = None    # 목표 이미지 크기

class GripperConfig:
    use_gripper: bool = True    # 그리퍼 사용
    gripper_penalty: float = 0.0    # 부적절한 그리퍼 사용 패널티

class ResetConfig:
    fixed_reset_joint_positions: Any | None = None    # 리셋 관절 위치
    reset_time_s: float = 5.0    # 리셋 대기 시간
    control_time_s: float = 20.0    # 최대 에피소드 길이
    terminate_on_success: bool = True    # 성공 시 에피소드 종료 여부

class InverseKinematicsConfig:
    urdf_path: str | None = None    # URDF 경로
    target_frame_name: str | None = None    # EE 프레임 이름
    end_effector_bounds: dict[str, list[float]] | None = None    # EE 작업공간 경계
    end_effector_step_sizes: dict[str, float] | None = None    # EE 축별 스텝 크기

class RewardClassifierConfig:
    pretrained_path: str | None = None    # 사전학습 보상 분류기 경로
    success_threshold: float = 0.5    # 성공 판정 임계값
    success_reward: float = 1.0    # 성공 보상 값

# 데이터셋 설정
class DatasetConfig:
    repo_id: str    # LeRobot 데이터셋 저장소 ID
    task: str    # 태스크 식별자
    root: str | None = None    # 로컬 데이터셋 루트
    num_episodes_to_record: int = 5    # 기록할 에피소드 수
    replay_episode: int | None = None    # 리플레이 에피소드 인덱스
    push_to_hub: bool = False    # Hub 업로드 여부
```

### 프로세서 파이프라인 아키텍처

HIL-SERL은 모듈형 프로세서 파이프라인을 사용해 로봇 관측과 액션을 여러 단계로 처리합니다. 파이프라인은 두 부분으로 나뉩니다.

#### 환경 프로세서 파이프라인

환경 프로세서(`env_processor`)는 들어오는 관측과 상태를 처리합니다:

1. **VanillaObservationProcessorStep**: 원시 관측을 표준 형식으로 변환
2. **JointVelocityProcessorStep**(옵션): 관측에 관절 속도 추가
3. **MotorCurrentProcessorStep**(옵션): 관측에 모터 전류 추가
4. **ForwardKinematicsJointsToEE**(옵션): 관절에서 EE 포즈 계산
5. **ImageCropResizeProcessorStep**(옵션): 이미지 크롭/리사이즈
6. **TimeLimitProcessorStep**(옵션): 에피소드 시간 제한
7. **GripperPenaltyProcessorStep**(옵션): 그리퍼 사용 패널티
8. **RewardClassifierProcessorStep**(옵션): 비전 기반 보상 감지
9. **AddBatchDimensionProcessorStep**: 배치 차원 추가
10. **DeviceProcessorStep**: 데이터를 지정한 장치(CPU/GPU)로 이동

#### 액션 프로세서 파이프라인

액션 프로세서(`action_processor`)는 나가는 액션과 인간 개입을 처리합니다:

1. **AddTeleopActionAsComplimentaryDataStep**: 텔레오퍼레이터 액션 기록
2. **AddTeleopEventsAsInfoStep**: 개입 이벤트 및 에피소드 제어 기록
3. **InterventionActionProcessorStep**: 인간 개입 및 종료 처리
4. **역기구학 파이프라인**(활성 시):
   - **MapDeltaActionToRobotActionStep**: 델타 액션을 로봇 액션으로 변환
   - **EEReferenceAndDelta**: EE 기준 및 델타 계산
   - **EEBoundsAndSafety**: 작업공간 안전 경계 적용
   - **InverseKinematicsEEToJoints**: EE 액션을 관절 타겟으로 변환
   - **GripperVelocityToJoint**: 그리퍼 제어 처리

#### 설정 예시

**기본 관측 처리**:

```json
{
  "env": {
    "processor": {
      "observation": {
        "add_joint_velocity_to_observation": true,
        "add_current_to_observation": false,
        "display_cameras": false
      }
    }
  }
}
```

**이미지 처리**:

```json
{
  "env": {
    "processor": {
      "image_preprocessing": {
        "crop_params_dict": {
          "observation.images.front": [180, 250, 120, 150],
          "observation.images.side": [180, 207, 180, 200]
        },
        "resize_size": [128, 128]
      }
    }
  }
}
```

**역기구학 설정**:

```json
{
  "env": {
    "processor": {
      "inverse_kinematics": {
        "urdf_path": "path/to/robot.urdf",
        "target_frame_name": "end_effector",
        "end_effector_bounds": {
          "min": [0.16, -0.08, 0.03],
          "max": [0.24, 0.2, 0.1]
        },
        "end_effector_step_sizes": {
          "x": 0.02,
          "y": 0.02,
          "z": 0.02
        }
      }
    }
  }
}
```

### 고급 관측 처리

HIL-SERL은 관측 처리에서 추가 기능을 지원하며, 정책 학습에 도움이 될 수 있습니다.

#### 관절 속도 처리

관절 속도 추정을 활성화하여 정책에 동작 정보를 제공합니다:

```json
{
  "env": {
    "processor": {
      "observation": {
        "add_joint_velocity_to_observation": true
      }
    }
  }
}
```

이 프로세서는 다음을 수행합니다:

- 연속된 관절 위치 차분으로 속도 추정
- 관측 상태 벡터에 속도 추가
- 동적 작업에서 유용

#### 모터 전류 처리

모터 전류를 모니터링해 접촉 힘이나 부하를 감지합니다:

```json
{
  "env": {
    "processor": {
      "observation": {
        "add_current_to_observation": true
      }
    }
  }
}
```

이 프로세서는 다음을 수행합니다:

- 로봇 제어 시스템에서 전류 값 읽기
- 관측 상태 벡터에 전류 추가
- 접촉 이벤트/무게/저항 감지에 도움
- 접촉이 많은 작업에 유용

#### 관측 처리 조합

여러 관측 처리를 동시에 활성화할 수 있습니다:

```json
{
  "env": {
    "processor": {
      "observation": {
        "add_joint_velocity_to_observation": true,
        "add_current_to_observation": true,
        "display_cameras": false
      }
    }
  }
}
```

**Note**: 관측을 추가하면 상태 공간 차원이 증가하므로, 정책 네트워크 구조 조정이나 추가 데이터 수집이 필요할 수 있습니다.

### 로봇 작업공간 경계 찾기

데모 수집 전 로봇의 작업공간 경계를 결정해야 합니다.

이는 실제 로봇 학습을 단순화하는 데 두 가지 장점이 있습니다: 1) 작업을 수행하는 특정 영역으로 작업 공간을 제한해 불필요하거나 위험한 탐색을 줄이고, 2) 관절 공간이 아닌 엔드이펙터(EE) 공간에서 학습할 수 있게 해줍니다. 경험적으로 조작 작업에서 RL을 관절 공간으로 학습하는 것은 더 어렵고, 어떤 작업은 EE 공간으로 변환해야 학습이 가능합니다.

**`lerobot-find-joint-limits` 사용**

이 스크립트는 로봇 EE의 안전한 작업 경계를 찾는 데 도움을 줍니다. 팔로워/리더 암이 있다면 팔로워 암의 경계를 찾아 학습에 적용할 수 있습니다. 액션 공간을 제한하면 불필요한 탐색을 줄이고 안전성을 보장합니다.

```bash
lerobot-find-joint-limits \
  --robot.type=so100_follower \
  --robot.port=/dev/follower_arm_1 \
  --robot.id=black \
  --teleop.type=so100_leader \
  --teleop.port=/dev/leader_arm_1 \
  --teleop.id=blue
```

**워크플로**

1. 스크립트를 실행하고 작업에 필요한 공간으로 로봇을 움직입니다.
2. 스크립트가 EE 위치와 관절 각도의 최소/최대 값을 기록해 콘솔에 출력합니다. 예:
   ```
   Max ee position [0.2417 0.2012 0.1027]
   Min ee position [0.1663 -0.0823 0.0336]
   Max joint positions [-20.0, -20.0, -20.0, -20.0, -20.0, -20.0]
   Min joint positions [50.0, 50.0, 50.0, 50.0, 50.0, 50.0]
   ```
3. 이 값을 텔레오퍼레이터 설정(`TeleoperatorConfig`)의 `end_effector_bounds`에 입력합니다.

**예시 설정**

```json
"end_effector_bounds": {
    "max": [0.24, 0.20, 0.10],
    "min": [0.16, -0.08, 0.03]
}
```

### 데모 수집

경계가 설정되면 안전하게 데모를 수집할 수 있습니다. 오프폴리시 RL은 오프라인 데이터셋을 활용해 학습 효율을 높일 수 있습니다.

**Record 모드 설정**

데모 기록을 위한 설정 파일을 만듭니다(예: [env_config.json](https://huggingface.co/datasets/lerobot/config_examples/resolve/main/rl/env_config.json)).

1. 루트에서 `mode`를 `"record"`로 설정
2. `dataset.repo_id`에 고유한 저장소 이름 지정(예: `username/task_name`)
3. `dataset.num_episodes_to_record`에 수집할 에피소드 수 지정
4. `env.processor.image_preprocessing.crop_params_dict`를 `{}`로 초기 설정(나중에 크롭 결정)
5. `env` 섹션에서 `robot`, `teleop` 등 하드웨어 설정 구성

예시 설정 섹션:

```json
{
  "env": {
    "type": "gym_manipulator",
    "name": "real_robot",
    "fps": 10,
    "processor": {
      "control_mode": "gamepad",
      "observation": {
        "display_cameras": false
      },
      "image_preprocessing": {
        "crop_params_dict": {},
        "resize_size": [128, 128]
      },
      "gripper": {
        "use_gripper": true,
        "gripper_penalty": 0.0
      },
      "reset": {
        "reset_time_s": 5.0,
        "control_time_s": 20.0
      }
    },
    "robot": {
      // ... robot configuration ...
    },
    "teleop": {
      // ... teleoperator configuration ...
    }
  },
  "dataset": {
    "repo_id": "username/pick_lift_cube",
    "root": null,
    "task": "pick_and_lift",
    "num_episodes_to_record": 15,
    "replay_episode": 0,
    "push_to_hub": true
  },
  "mode": "record",
  "device": "cpu"
}
```

### 텔레오퍼레이션 장치 사용

데이터 수집과 온라인 학습 중 개입을 위해 텔레오퍼레이션 장치가 필요합니다. 게임패드, 키보드, 또는 리더 암을 사용할 수 있습니다.

HIL-Serl은 로봇의 EE 공간에서 액션을 학습합니다. 따라서 텔레오퍼레이션은 EE의 x, y, z 변위를 제어합니다.

이를 위해 EE 공간에서 액션을 받는 로봇 버전이 필요합니다. 기본 파라미터는 `SO100FollowerEndEffector`와 `SO100FollowerEndEffectorConfig`를 참고하세요.

```python
class SO100FollowerEndEffectorConfig(SO100FollowerConfig):
    """SO100FollowerEndEffector 로봇 설정."""

    # EE 위치 기본 경계(미터)
    end_effector_bounds: dict[str, list[float]] = field( # x,y,z 경계
        default_factory=lambda: {
            "min": [-1.0, -1.0, -1.0],  # min x, y, z
            "max": [1.0, 1.0, 1.0],  # max x, y, z
        }
    )

    max_gripper_pos: float = 50 # 그리퍼 최대 오픈 위치

    end_effector_step_sizes: dict[str, float] = field( # EE x,y,z 스텝 크기
        default_factory=lambda: {
            "x": 0.02,
            "y": 0.02,
            "z": 0.02,
        }
    )
```

`Teleoperator`는 텔레오퍼레이션 장치를 정의합니다. 사용 가능한 텔레오퍼레이터 목록은 `lerobot/teleoperators`에서 확인하세요.

**게임패드 설정**

게임패드는 로봇과 에피소드 상태를 제어하기에 매우 편리합니다.

게임패드를 사용하려면 `control_mode`를 `"gamepad"`로 설정하고 `teleop` 섹션을 구성합니다.

```json
{
  "env": {
    "teleop": {
      "type": "gamepad",
      "use_gripper": true
    },
    "processor": {
      "control_mode": "gamepad",
      "gripper": {
        "use_gripper": true
      }
    }
  }
}
```

Gamepad button mapping for robot control and episode management

**SO101 리더 설정**

SO101 리더 암은 감속 기어가 있어 팔로워 암을 더 부드럽게 추적할 수 있습니다. 따라서 기어가 없는 SO100보다 개입이 매끄럽습니다.

SO101 리더를 사용하려면 `control_mode`를 `"leader"`로 설정하고 `teleop` 섹션을 구성합니다.

```json
{
  "env": {
    "teleop": {
      "type": "so101_leader",
      "port": "/dev/follower_arm_1",
      "use_degrees": true
    },
    "processor": {
      "control_mode": "leader",
      "gripper": {
        "use_gripper": true
      }
    }
  }
}
```

성공/실패 라벨링을 위해 **키보드**로 `s`(성공), `esc`(실패)를 눌러야 합니다.
온라인 학습 중에는 `space`로 정책을 일시 중지하고 개입하며, 다시 `space`로 정책에 제어를 돌려줍니다.

Video: SO101 leader teleoperation

SO101 leader teleoperation example, the leader tracks the follower, press `space` to intervene

**데모 기록**

기록을 시작합니다. 예시 설정 파일은 [여기](https://huggingface.co/datasets/aractingi/lerobot-example-config-files/blob/main/env_config_so100.json)에서 확인할 수 있습니다.

```bash
python -m lerobot.rl.gym_manipulator --config_path src/lerobot/configs/env_config_so100.json
```

기록 중:

1. 로봇은 설정 파일의 `env.processor.reset.fixed_reset_joint_positions`로 리셋합니다.
2. 작업을 성공적으로 완료합니다.
3. "성공" 버튼을 누르면 보상 1로 에피소드가 종료됩니다.
4. 시간 제한에 도달하거나 "실패" 버튼을 누르면 보상 0으로 종료됩니다.
5. "rerecord" 버튼으로 에피소드를 다시 기록할 수 있습니다.
6. 자동으로 다음 에피소드로 진행합니다.
7. 모든 에피소드 기록 후, 데이터셋은 Hub에 업로드(옵션)되고 로컬에 저장됩니다.

### 데이터셋 처리

데모 수집 후 카메라 크롭을 결정하기 위해 데이터를 처리합니다. RL은 배경 노이즈에 민감하므로 작업 영역에 집중하도록 이미지를 크롭하는 것이 중요합니다.

비전 기반 RL은 픽셀 입력을 그대로 학습하므로 관련 없는 시각 정보에 취약합니다. 조명 변화, 그림자, 움직이는 사람, 작업 영역 밖 물체 등은 학습을 혼란시킬 수 있습니다. 좋은 ROI는 다음을 만족해야 합니다:

- 작업이 이루어지는 필수 작업 공간만 포함
- 로봇 EE와 모든 대상 물체 포함
- 불필요한 배경 요소와 방해 요소 제외

참고: 이미 크롭 파라미터를 알고 있다면 이 단계를 건너뛰고, 기록 단계에서 `crop_params_dict`에 바로 입력해도 됩니다.

**크롭 파라미터 결정**

`crop_dataset_roi.py` 스크립트로 카메라 이미지의 관심 영역을 선택합니다:

```bash
python -m lerobot.rl.crop_dataset_roi --repo-id username/pick_lift_cube
```

1. 각 카메라 뷰에 대해 첫 프레임이 표시됩니다.
2. 작업 영역을 포함하는 사각형을 그립니다.
3. `c`를 눌러 선택을 확정합니다.
4. 모든 카메라 뷰에 대해 반복합니다.
5. 스크립트가 크롭 파라미터를 출력하고, 크롭된 새 데이터셋을 생성합니다.

예시 출력:

```
Selected Rectangular Regions of Interest (top, left, height, width):
observation.images.side: [180, 207, 180, 200]
observation.images.front: [180, 250, 120, 150]
```

Interactive cropping tool for selecting regions of interest

**설정 업데이트**

학습 설정에 크롭 파라미터를 추가합니다:

```json
{
  "env": {
    "processor": {
      "image_preprocessing": {
        "crop_params_dict": {
          "observation.images.side": [180, 207, 180, 200],
          "observation.images.front": [180, 250, 120, 150]
        },
        "resize_size": [128, 128]
      }
    }
  }
}
```

**권장 이미지 해상도**

대부분의 비전 정책은 **128×128**(기본) 또는 **64×64** 정사각형 입력에서 검증되었습니다. 따라서 `resize_size`는 `[128, 128]`을 권장하며, GPU 메모리/대역폭 절약이 필요하면 `[64, 64]`를 사용할 수 있습니다. 다른 해상도도 가능하지만 충분히 검증되지는 않았습니다.

### 보상 분류기 학습

보상 분류기는 HIL-SERL에서 보상 할당을 자동화하고 성공 여부를 시각적으로 감지합니다. 매 타임스텝에 사람이 보상을 주는 대신, 보상 분류기가 성공/실패를 예측해 일관된 보상을 제공합니다.

이 가이드는 LeRobot의 사람-개입 RL을 위한 보상 분류기 학습 방법을 설명합니다. 보상 분류기는 상태에서 보상 값을 예측해 RL 학습에 사용할 수 있습니다.

**Note**: 보상 분류기 학습은 선택 사항입니다. 초기 RL 실험은 게임패드/키보드로 성공 여부를 직접 라벨링해 시작할 수도 있습니다.

보상 분류기 구현은 `modeling_classifier.py`에 있으며, 사전학습 비전 모델을 사용합니다. 이 모델은 이진 성공/실패용 단일 출력 또는 다중 클래스 출력을 지원합니다.

**보상 분류기 데이터셋 수집**

학습 전에 라벨된 데이터셋을 수집해야 합니다. `gym_manipulator.py`의 `record_dataset` 함수로 관측/액션/보상 데이터를 기록할 수 있습니다.

데이터셋을 수집하려면 HILSerlRobotEnvConfig의 일부 파라미터를 수정해야 합니다.

```bash
python -m lerobot.rl.gym_manipulator --config_path src/lerobot/configs/reward_classifier_train_config.json
```

**데이터 수집 주요 파라미터**

- **mode**: 루트에서 `"record"`로 설정
- **dataset.repo_id**: Hub 저장소 이름(`"hf_username/dataset_name"`)
- **dataset.num_episodes_to_record**: 기록할 에피소드 수
- **env.processor.reset.terminate_on_success**: 성공 시 자동 종료 여부(기본: `true`)
- **env.fps**: 기록 FPS
- **dataset.push_to_hub**: Hub 업로드 여부

`env.processor.reset.terminate_on_success`를 `false`로 두면 성공 이후에도 에피소드가 계속되어 보상=1 예시를 더 많이 수집할 수 있습니다. 보상 분류기 학습에 중요합니다. 일반 HIL-SERL 학습에서는 `true`를 유지해 성공 시 자동 종료하는 것이 좋습니다.

예시 설정:

```json
{
  "env": {
    "type": "gym_manipulator",
    "name": "real_robot",
    "fps": 10,
    "processor": {
      "reset": {
        "reset_time_s": 5.0,
        "control_time_s": 20.0,
        "terminate_on_success": false
      },
      "gripper": {
        "use_gripper": true
      }
    },
    "robot": {
      // ... robot configuration ...
    },
    "teleop": {
      // ... teleoperator configuration ...
    }
  },
  "dataset": {
    "repo_id": "hf_username/dataset_name",
    "dataset_root": "data/your_dataset",
    "task": "reward_classifier_task",
    "num_episodes_to_record": 20,
    "replay_episode": null,
    "push_to_hub": true
  },
  "mode": "record",
  "device": "cpu"
}
```

**보상 분류기 설정**

보상 분류기는 `configuration_classifier.py`에서 설정합니다. 주요 파라미터는 다음과 같습니다:

- **model_name**: 기본 모델(예: 주로 `"helper2424/resnet10"`)
- **model_type**: `"cnn"` 또는 `"transformer"`
- **num_cameras**: 카메라 수
- **num_classes**: 출력 클래스 수(보통 2)
- **hidden_dim**: 은닉 차원
- **dropout_rate**: 정규화 파라미터
- **learning_rate**: 학습률

보상 분류기 학습 예시 설정([reward_classifier_train_config.json](https://huggingface.co/datasets/aractingi/lerobot-example-config-files/blob/main/reward_classifier_train_config.json)):

```json
{
  "policy": {
    "type": "reward_classifier",
    "model_name": "helper2424/resnet10",
    "model_type": "cnn",
    "num_cameras": 2,
    "num_classes": 2,
    "hidden_dim": 256,
    "dropout_rate": 0.1,
    "learning_rate": 1e-4,
    "device": "cuda",
    "use_amp": true,
    "input_features": {
      "observation.images.front": {
        "type": "VISUAL",
        "shape": [3, 128, 128]
      },
      "observation.images.side": {
        "type": "VISUAL",
        "shape": [3, 128, 128]
      }
    }
  }
}
```

**분류기 학습**

다음 명령으로 학습합니다:

```bash
lerobot-train --config_path path/to/reward_classifier_train_config.json
```

**모델 배포 및 테스트**

학습한 보상 분류기를 사용하려면 `HILSerlRobotEnvConfig`에 경로를 지정합니다:

```python
config = GymManipulatorConfig(
    env=HILSerlRobotEnvConfig(
        processor=HILSerlProcessorConfig(
            reward_classifier=RewardClassifierConfig(
                pretrained_path="path_to_your_pretrained_trained_model"
            )
        ),
        # Other environment parameters
    ),
    dataset=DatasetConfig(...),
    mode=None  # For training
)
```

또는 JSON 설정에서 지정할 수 있습니다:

```json
{
  "env": {
    "processor": {
      "reward_classifier": {
        "pretrained_path": "path_to_your_pretrained_model",
        "success_threshold": 0.7,
        "success_reward": 1.0
      },
      "reset": {
        "terminate_on_success": true
      }
    }
  }
}
```

`gym_manipulator.py`로 모델을 테스트합니다.

```bash
python -m lerobot.rl.gym_manipulator --config_path path/to/env_config.json
```

보상 분류기가 카메라 입력을 기반으로 자동 보상을 제공합니다.

**보상 분류기 학습 예시 워크플로**

1. **설정 파일 생성**: 보상 분류기 및 환경 설정 JSON을 만듭니다. 예시는 [여기](https://huggingface.co/datasets/lerobot/config_examples/resolve/main/reward_classifier/config.json) 참고.

2. **데이터 수집**:

   ```bash
   python -m lerobot.rl.gym_manipulator --config_path src/lerobot/configs/env_config.json
   ```

3. **분류기 학습**:

   ```bash
   lerobot-train --config_path src/lerobot/configs/reward_classifier_train_config.json
   ```

4. **분류기 테스트**:
   ```bash
   python -m lerobot.rl.gym_manipulator --config_path src/lerobot/configs/env_config.json
   ```

### Actor-Learner 학습

LeRobot은 분산 actor-learner 아키텍처를 사용합니다. 로봇 상호작용과 학습을 분리해 동시에 실행되며 서로를 블로킹하지 않습니다. actor 서버가 로봇 관측/액션을 처리하고 데이터를 learner 서버로 전송하며, learner는 그라디언트 업데이트를 수행하고 actor에 정책 가중치를 전달합니다. 학습을 위해 learner와 actor 두 프로세스를 실행해야 합니다.

**설정 준비**

학습 설정 파일을 만듭니다(예: [train_config.json](https://huggingface.co/datasets/lerobot/config_examples/resolve/main/rl/train_config.json)). 학습 설정은 `lerobot/configs/train.py`의 `TrainRLServerPipelineConfig`를 기반으로 합니다.

1. 정책 설정(`type="sac"`, `device` 등) 구성
2. `dataset`에 크롭된 데이터셋 지정
3. 크롭 파라미터 포함한 환경 설정
4. SAC 관련 파라미터는 [configuration_sac.py](https://github.com/huggingface/lerobot/blob/main/src/lerobot/policies/sac/configuration_sac.py#L79) 참고
5. `policy`의 `input_features`/`output_features`가 태스크에 맞는지 확인

**Learner 시작**

먼저 learner 서버를 실행합니다:

```bash
python -m lerobot.rl.learner --config_path src/lerobot/configs/train_config_hilserl_so100.json
```

learner는 다음을 수행합니다:

- 정책 네트워크 초기화
- 리플레이 버퍼 준비
- actor와 통신하는 `gRPC` 서버 오픈
- 전이(transition) 처리 및 정책 업데이트

**Actor 시작**

다른 터미널에서 같은 설정으로 actor를 실행합니다:

```bash
python -m lerobot.rl.actor --config_path src/lerobot/configs/train_config_hilserl_so100.json
```

actor는 다음을 수행합니다:

- `gRPC`로 learner에 연결
- 환경 초기화
- 정책 롤아웃 수행
- 전이를 learner로 전송
- 업데이트된 정책 파라미터 수신

**학습 흐름**

1. actor가 환경에서 정책 실행
2. 전이를 수집해 learner로 전송
3. learner가 전이로 정책 업데이트
4. 업데이트된 파라미터를 actor에 전달
5. 설정된 스텝까지 반복

**Human in the Loop**

- 효율적 학습을 위해 인간 개입이 중요합니다. 위험 상황에서 보정하고 탐색을 돕습니다.
- 개입하려면 게임패드의 오른쪽 상단 트리거(또는 키보드 `space`)를 누릅니다. 정책 액션이 일시 정지되며 사람이 제어합니다.
- 학습이 진행될수록 개입 횟수가 감소하는 것이 성공적인 실험입니다. `wandb` 대시보드에서 개입률을 모니터링할 수 있습니다.

Example showing how human interventions help guide policy learning over time

- 그래프는 상호작용 스텝에 따른 에피소드 보상을 보여줍니다.
- 주황색은 인간 개입이 없는 실험, 분홍/파란색은 개입이 있는 실험입니다.
- 인간 개입이 있을 때 최대 보상 도달까지 스텝 수가 약 1/4로 줄어드는 것을 볼 수 있습니다.

**모니터링 및 디버깅**

설정에서 `wandb.enable`을 `true`로 두면 [Weights & Biases](https://wandb.ai/site/) 대시보드에서 학습 진행 상황을 실시간으로 모니터링할 수 있습니다.

### 인간 개입 가이드

학습은 개입 전략에 민감하므로 몇 번의 시행착오가 필요합니다. 팁은 다음과 같습니다:

- 학습 초반에는 몇 에피소드 동안 정책이 탐색하도록 두세요.
- 긴 시간 동안 개입하지 말고, 로봇이 잘못된 방향으로 갈 때 짧게 교정하세요.
- 정책이 작업을 달성하기 시작하면, 짧고 간단한 보정(예: 짧은 그립 조작)만으로도 충분합니다.

이상적인 행동은 아래 그래프처럼 개입률이 점차 감소하는 것입니다.

Plot of the intervention rate during a training run on a pick and lift cube task

### 튜닝해야 할 핵심 하이퍼파라미터

학습 안정성과 속도에 큰 영향을 주는 파라미터가 있습니다:

- **`temperature_init`** (`policy.temperature_init`) – SAC의 초기 엔트로피 온도. 높을수록 탐색이 늘고 낮을수록 초기에 결정적입니다. 시작 값으로 `1e-2`를 권장합니다. 너무 높으면 인간 개입 효과가 줄고 학습이 느려질 수 있습니다.
- **`policy_parameters_push_frequency`** (`policy.actor_learner_config.policy_parameters_push_frequency`) – learner가 actor로 가중치를 푸시하는 간격(초). 기본값은 `4 s`. 더 신선한 가중치를 원하면 **1~2 s**로 줄이되 네트워크 트래픽이 늘어납니다. 연결이 느릴 때만 늘리세요.
- **`storage_device`** (`policy.storage_device`) – learner가 정책 파라미터를 저장하는 장치. 여유 GPU 메모리가 있으면 기본 `"cpu"` 대신 `"cuda"`를 권장합니다. GPU에 두면 CPU→GPU 전송 오버헤드가 줄어 업데이트 속도가 개선됩니다.

축하합니다 🎉 튜토리얼을 완료했습니다!

> [!TIP]
> 질문이나 도움이 필요하면 [Discord](https://discord.com/invite/s3KuuzsPFb)에 문의하세요.

논문 인용:

```
@article{luo2024precise,
  title={Precise and Dexterous Robotic Manipulation via Human-in-the-Loop Reinforcement Learning},
  author={Luo, Jianlan and Xu, Charles and Wu, Jeffrey and Levine, Sergey},
  journal={arXiv preprint arXiv:2410.21845},
  year={2024}
}
```
