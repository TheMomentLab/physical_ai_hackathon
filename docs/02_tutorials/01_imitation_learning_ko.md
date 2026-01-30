# 실제 로봇에서의 모방 학습

이 튜토리얼은 실제 로봇을 자율적으로 제어하도록 신경망을 학습시키는 방법을 설명합니다.

**배울 내용:**

1. 데이터셋을 기록하고 시각화하는 방법.
2. 데이터로 정책(policy)을 학습하고 평가를 위한 준비 방법.
3. 정책을 평가하고 결과를 시각화하는 방법.

이 단계를 따르면 아래 영상처럼 레고 블록을 집어 통에 넣는 작업을 높은 성공률로 재현할 수 있습니다.

이 튜토리얼은 특정 로봇에 종속되지 않습니다. 지원되는 어떤 플랫폼에도 적용할 수 있도록 명령과 API 스니펫을 안내합니다.

데이터 수집 중에는 리더 암 또는 키보드 같은 “텔레오퍼레이션” 장치를 사용해 로봇을 원격 조작하고 움직임 궤적을 기록합니다.

충분한 궤적을 모으면, 해당 궤적을 모방하도록 신경망을 학습시키고 학습된 모델을 배포해 로봇이 작업을 자율적으로 수행하도록 합니다.

어느 단계에서든 문제가 생기면 [Discord 커뮤니티](https://discord.com/invite/s3KuuzsPFb)에서 도움을 받으세요.

## 설정 및 캘리브레이션

아직 로봇과 텔레오퍼레이션 장치를 설정/캘리브레이션하지 않았다면, 로봇별 튜토리얼을 따라 진행하세요.

## 텔레오퍼레이션

이 예시에서는 SO101 로봇을 텔레오퍼레이션하는 방법을 보여줍니다. 각 명령에 대해 대응하는 API 예제도 제공합니다.

로봇과 연관된 `id`는 캘리브레이션 파일을 저장하는 데 사용됩니다. 동일한 설정에서 텔레오퍼레이션, 기록, 평가를 할 때는 같은 `id`를 사용하는 것이 중요합니다.

```bash
lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1 \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1 \
    --teleop.id=my_so101_leader_1
```

```python
from lerobot.teleoperators.so_leader import SO101LeaderConfig, SO101Leader
from lerobot.robots.so_follower import SO101FollowerConfig, SO101Follower

robot_config = SO101FollowerConfig(
    port="/dev/follower_arm_1",
    id="my_so101_follower_1",
)

teleop_config = SO101LeaderConfig(
    port="/dev/leader_arm_1",
    id="my_so101_leader_1",
)

robot = SO101Follower(robot_config)
teleop_device = SO101Leader(teleop_config)
robot.connect()
teleop_device.connect()

while True:
    action = teleop_device.get_action()
    robot.send_action(action)
```

`teleoperate` 명령은 자동으로 다음을 수행합니다:

1. 누락된 캘리브레이션을 확인하고 캘리브레이션 절차를 시작합니다.
2. 로봇과 텔레오퍼레이션 장치를 연결하고 원격 조작을 시작합니다.

## 카메라

설정에 카메라를 추가하려면 이 [가이드](./cameras_ko.md#setup-cameras)를 따르세요.

## 카메라와 함께 텔레오퍼레이션

`rerun`을 사용하면 카메라 피드와 관절 위치를 동시에 시각화하면서 텔레오퍼레이션할 수 있습니다.

### 옵션 설명

| 옵션 | 설명 |
|------|------|
| `--robot.cameras` | 카메라 구성을 JSON 문자열로 전달합니다. `key`는 카메라 이름(예: `front`, `top`)이며, `index_or_path`에는 장치 경로(예: `/dev/video*`)를 지정합니다. |
| `--display_data` | `true`로 설정하면 Rerun 시각화 도구를 실행해 실시간으로 데이터를 확인합니다. |
| `--robot.type` | 사용할 로봇의 종류입니다 (예: `so101_follower`). |
| `--teleop.type` | 사용할 텔레오퍼레이션 장치의 종류입니다 (예: `so101_leader`). |

### 1. 단일 카메라 (Single Camera)

로봇에 부착된 카메라(Robot Camera)만 사용하는 경우입니다.

```bash
lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1 \
    --robot.cameras="{ \
      front: {type: opencv, index_or_path: /dev/follower_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG} \
    }" \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1 \
    --teleop.id=my_so101_leader_1 \
    --display_data=true
```

### 2. 다중 카메라 (Dual Camera)

탑뷰(Top View)와 로봇 카메라(Front)를 모두 사용하는 권장 설정입니다.

```bash
lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1 \
    --robot.cameras="{ \
      top: {type: opencv, index_or_path: /dev/top_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG}, \
      front: {type: opencv, index_or_path: /dev/follower_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG} \
    }" \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1 \
    --teleop.id=my_so101_leader_1 \
    --display_data=true
```

```python
from lerobot.cameras.opencv.configuration_opencv import OpenCVCameraConfig
from lerobot.teleoperators.so_leader import SO101LeaderConfig, SO101Leader
from lerobot.robots.so_follower import SO101FollowerConfig, SO101Follower

camera_config = {
    "front": OpenCVCameraConfig(index_or_path="/dev/follower_cam_1", width=640, height=480, fps=30, fourcc="MJPG"),
    "top": OpenCVCameraConfig(index_or_path="/dev/top_cam_1", width=640, height=480, fps=30, fourcc="MJPG")
}

robot_config = SO101FollowerConfig(
    port="/dev/follower_arm_1",
    id="my_so101_follower_1",
    cameras=camera_config
)

teleop_config = SO101LeaderConfig(
    port="/dev/leader_arm_1",
    id="my_so101_leader_1",
)

robot = SO101Follower(robot_config)
teleop_device = SO101Leader(teleop_config)
robot.connect()
teleop_device.connect()

while True:
    observation = robot.get_observation()
    action = teleop_device.get_action()
    robot.send_action(action)
```

## 데이터셋 기록

텔레오퍼레이션에 익숙해지면 첫 데이터셋을 기록할 수 있습니다.

데이터셋 업로드에는 Hugging Face 허브 기능을 사용합니다. 이전에 Hub를 사용한 적이 없다면, 쓰기 권한 토큰으로 CLI 로그인이 가능한지 확인하세요. 토큰은 [Hugging Face 설정](https://huggingface.co/settings/tokens)에서 생성할 수 있습니다.

다음 명령으로 토큰을 CLI에 추가하세요:

```bash
huggingface-cli login --token ${HUGGINGFACE_TOKEN} --add-to-git-credential
```

그 다음 Hugging Face 저장소 이름을 변수에 저장합니다:

```bash
HF_USER=$(hf auth whoami | head -n 1)
echo $HF_USER
```

> ⚠️ **주의**: `HF_USER`가 비어 있으면 `repo_id`가 `/record-test`처럼 루트 경로로 해석되어 **Permission denied**가 발생할 수 있습니다.  
> Hub 업로드를 하지 않을 경우 `--dataset.push_to_hub=false`와 함께 `--dataset.root`를 로컬 경로로 지정하세요.

이제 데이터셋을 기록할 수 있습니다. 5개의 에피소드를 기록하고 데이터셋을 허브에 업로드하려면, 아래 코드를 로봇에 맞게 수정한 뒤 명령 또는 API 예제를 실행하세요.

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1 \
    --robot.cameras="{ \
      top: {type: opencv, index_or_path: /dev/top_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG}, \
      front: {type: opencv, index_or_path: /dev/follower_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG} \
    }" \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1 \
    --teleop.id=my_so101_leader_1 \
    --display_data=true \
    --dataset.repo_id=${HF_USER}/record-test \
    --dataset.num_episodes=5 \
    --dataset.single_task="Grab the black cube"
```

### 데이터셋 시각화

기록된 로컬 데이터셋을 시각화하려면 아래 명령을 사용하세요.

```bash
lerobot-dataset-viz \
    --repo-id ${HF_USER}/record-test \
    --episode-index 0 \
    --root ./outputs/datasets/record-test-03 \
    --display-compressed-images false
```

> `lerobot-dataset-viz`는 `--display-compressed-images` 플래그가 필수입니다.

로컬 저장만 할 경우 (Hub 업로드 X):

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1 \
    --robot.cameras="{ \
      top: {type: opencv, index_or_path: /dev/top_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG}, \
      front: {type: opencv, index_or_path: /dev/follower_cam_1, width: 640, height: 480, fps: 30, fourcc: MJPG} \
    }" \
    --teleop.type=so101_leader \
    --teleop.port=/dev/leader_arm_1 \
    --teleop.id=my_so101_leader_1 \
    --display_data=true \
    --dataset.push_to_hub=false \
    --dataset.repo_id=${HF_USER}/record-test \
    --dataset.root=./outputs/datasets/record-test \
    --dataset.num_episodes=5 \
    --dataset.single_task="Grab the black cube"
```

### `lerobot-record` 상세 옵션 가이드

기본 옵션 외에도 다양한 설정을 사용하여 녹화 환경을 최적화할 수 있습니다.

| 카테고리 | 옵션 | 기본값 | 설명 |
|---|---|---|---|
| **필수** | `--robot.type` | - | 로봇 모델 지정 (예: `so101_follower`) |
| | `--robot.port` | - | 로봇 연결 포트 (예: `/dev/follower_arm_1`) |
| | `--robot.cameras` | - | 카메라 구성 (JSON 형식) |
| | `--dataset.repo_id` | - | 저장할 데이터셋 ID (`유저명/데이터셋명`) |
| **시간** | `--dataset.episode_time_s` | `60` | 에피소드당 녹화 시간 (초) |
| | `--dataset.reset_time_s` | `60` | 에피소드 사이 초기화/휴식 시간 (초) |
| **저장/업로드** | `--dataset.push_to_hub` | `true` | 녹화 후 Hugging Face Hub 업로드 여부 (`false` 시 로컬 저장만 함) |
| | `--resume` | `false` | 중단된 녹화를 이어서 진행할지 여부 |
| | `--dataset.vcodec` | `libsvtav1` | 비디오 코덱 (`h264`로 변경 시 CPU 부하 감소) |
| **기타** | `--display_data` | `false` | `true`일 경우 Rerun을 통해 녹화 화면 실시간 확인 |
| | `--play_sounds` | `true` | 녹화 시작/종료 시 음성 알림 사용 여부 |

```python
from lerobot.cameras.opencv.configuration_opencv import OpenCVCameraConfig
from lerobot.datasets.lerobot_dataset import LeRobotDataset
from lerobot.datasets.utils import hw_to_dataset_features
from lerobot.robots.so_follower import SO101Follower, SO101FollowerConfig
from lerobot.teleoperators.so_leader import SO101LeaderConfig, SO101Leader
from lerobot.utils.control_utils import init_keyboard_listener
from lerobot.utils.utils import log_say
from lerobot.utils.visualization_utils import init_rerun
from lerobot.scripts.lerobot_record import record_loop
from lerobot.processor import make_default_processors

NUM_EPISODES = 5
FPS = 30
EPISODE_TIME_SEC = 60
RESET_TIME_SEC = 10
TASK_DESCRIPTION = "My task description"

# Create robot configuration
robot_config = SO101FollowerConfig(
    id="my_so101_follower_1",
    cameras={
        "front": OpenCVCameraConfig(index_or_path="/dev/follower_cam_1", width=640, height=480, fps=FPS, fourcc="MJPG")
    },
    port="/dev/follower_arm_1",
)

teleop_config = SO101LeaderConfig(
    id="my_so101_leader_1",
    port="/dev/leader_arm_1",
)

# Initialize the robot and teleoperator
robot = SO101Follower(robot_config)
teleop = SO101Leader(teleop_config)

# Configure the dataset features
action_features = hw_to_dataset_features(robot.action_features, "action")
obs_features = hw_to_dataset_features(robot.observation_features, "observation")
dataset_features = {**action_features, **obs_features}

# Create the dataset
dataset = LeRobotDataset.create(
    repo_id="/",
    fps=FPS,
    features=dataset_features,
    robot_type=robot.name,
    use_videos=True,
    image_writer_threads=4,
)

# Initialize the keyboard listener and rerun visualization
_, events = init_keyboard_listener()
init_rerun(session_name="recording")

# Connect the robot and teleoperator
robot.connect()
teleop.connect()

# Create the required processors
teleop_action_processor, robot_action_processor, robot_observation_processor = make_default_processors()

episode_idx = 0
while episode_idx /", episodes=[episode_idx])
actions = dataset.hf_dataset.select_columns("action")

log_say(f"Replaying episode {episode_idx}")
for idx in range(dataset.num_frames):
    t0 = time.perf_counter()

    action = {
        name: float(actions[idx]["action"][i]) for i, name in enumerate(dataset.features["action"]["names"])
    }
    robot.send_action(action)

    precise_sleep(max(1.0 / dataset.fps - (time.perf_counter() - t0), 0.0))

robot.disconnect()
```

로봇은 기록한 동작과 유사한 움직임을 재현해야 합니다. 예를 들어, [Trossen Robotics](https://www.trossenrobotics.com)의 Aloha 로봇에서 `replay`를 사용한 [이 영상](https://x.com/RemiCadene/status/1793654950905680090)을 확인해 보세요.

## 정책 학습

로봇을 제어하는 정책을 학습하려면 [`lerobot-train`](https://github.com/huggingface/lerobot/blob/main/src/lerobot/scripts/lerobot_train.py) 스크립트를 사용하세요. 몇 가지 인자가 필요합니다. 예시 명령은 다음과 같습니다:

```bash
lerobot-train \
  --dataset.repo_id=${HF_USER}/so101_test \
  --policy.type=act \
  --output_dir=outputs/train/act_so101_test \
  --job_name=act_so101_test \
  --policy.device=cuda \
  --wandb.enable=true \
  --policy.repo_id=${HF_USER}/my_policy
```

명령을 설명하면 다음과 같습니다:

1. `--dataset.repo_id=${HF_USER}/so101_test`로 데이터셋을 인자로 제공했습니다.
2. `policy.type=act`로 정책을 제공했습니다. 이는 [`configuration_act.py`](https://github.com/huggingface/lerobot/blob/main/src/lerobot/policies/act/configuration_act.py)의 설정을 불러옵니다. 특히 이 정책은 데이터셋에 저장된 로봇의 모터 상태, 모터 액션, 카메라(예: `laptop`, `phone`)의 개수에 자동으로 맞춥니다.
3. Nvidia GPU에서 학습하므로 `policy.device=cuda`를 제공했지만, Apple silicon에서는 `policy.device=mps`를 사용할 수 있습니다.
4. 학습 플롯 시각화를 위해 [Weights and Biases](https://docs.wandb.ai/quickstart)를 사용하려고 `wandb.enable=true`를 제공했습니다. 이는 선택사항이며, 사용하려면 `wandb login`으로 로그인해야 합니다.

학습은 몇 시간 걸릴 수 있습니다. 체크포인트는 `outputs/train/act_so101_test/checkpoints`에서 찾을 수 있습니다.

체크포인트에서 학습을 재개하려면, 아래는 `act_so101_test` 정책의 `last` 체크포인트에서 재개하는 예시 명령입니다:

```bash
lerobot-train \
  --config_path=outputs/train/act_so101_test/checkpoints/last/pretrained_model/train_config.json \
  --resume=true
```

학습 후 모델을 허브에 푸시하지 않으려면 `--policy.push_to_hub=false`를 사용하세요.

추가로 `tags`를 제공하거나 모델의 `license`를 지정하거나, 모델 레포를 `private`로 만들고 싶다면 다음을 추가하세요: `--policy.private=true --policy.tags=\[ppo,rl\] --policy.license=mit`

#### Google Colab으로 학습

로컬 컴퓨터에 강력한 GPU가 없다면, [ACT 학습 노트북](./notebooks#training-act)을 따라 Google Colab을 사용할 수 있습니다.

#### 정책 체크포인트 업로드

학습이 끝나면 최신 체크포인트를 다음으로 업로드하세요:

```bash
huggingface-cli upload ${HF_USER}/act_so101_test \
  outputs/train/act_so101_test/checkpoints/last/pretrained_model
```

중간 체크포인트도 다음처럼 업로드할 수 있습니다:

```bash
CKPT=010000
huggingface-cli upload ${HF_USER}/act_so101_test${CKPT} \
  outputs/train/act_so101_test/checkpoints/${CKPT}/pretrained_model
```

## 추론 실행 및 정책 평가

정책 체크포인트를 입력으로 사용해 추론을 실행하고 평가하려면, [`lerobot-record`](https://github.com/huggingface/lerobot/blob/main/src/lerobot/scripts/lerobot_record.py)의 `record` 스크립트를 사용할 수 있습니다. 예를 들어 아래 명령 또는 API 예제를 실행하면 추론을 수행하고 10개의 평가 에피소드를 기록할 수 있습니다:

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=/dev/follower_arm_1 \
    --robot.id=my_so101_follower_1 \
    --robot.cameras='{ \
      "top": {"type": "opencv", "index_or_path": "/dev/top_cam_1", "width": 640, "height": 480, "fps": 30, "fourcc": "MJPG"}, \
      "front": {"type": "opencv", "index_or_path": "/dev/follower_cam_1", "width": 640, "height": 480, "fps": 30, "fourcc": "MJPG"} \
    }' \
    --policy.path=${HF_USER}/my_policy \
    --display_data=true \
    --dataset.repo_id=${HF_USER}/eval_my_policy \
    --dataset.num_episodes=10 \
    --dataset.single_task="Pick up the block"
```

```python

# Create the robot configuration
camera_config = {"front": OpenCVCameraConfig(index_or_path="/dev/follower_cam_1", width=640, height=480, fps=FPS, fourcc="MJPG")}
robot_config = SO101FollowerConfig(
    port="/dev/follower_arm_1", id="my_so101_follower_1", cameras=camera_config
)

# Initialize the robot
robot = SO101Follower(robot_config)

# Initialize the policy
policy = ACTPolicy.from_pretrained(HF_MODEL_ID)

# Configure the dataset features
action_features = hw_to_dataset_features(robot.action_features, "action")
obs_features = hw_to_dataset_features(robot.observation_features, "observation")
dataset_features = {**action_features, **obs_features}

# Create the dataset
dataset = LeRobotDataset.create(
    repo_id=HF_DATASET_ID,
    fps=FPS,
    features=dataset_features,
    robot_type=robot.name,
    use_videos=True,
    image_writer_threads=4,
)

# Initialize the keyboard listener and rerun visualization
_, events = init_keyboard_listener()
init_rerun(session_name="recording")

# Connect the robot
robot.connect()

preprocessor, postprocessor = make_pre_post_processors(
    policy_cfg=policy,
    pretrained_path=HF_MODEL_ID,
    dataset_stats=dataset.meta.stats,
)

for episode_idx in range(NUM_EPISODES):
    log_say(f"Running inference, recording eval episode {episode_idx + 1} of {NUM_EPISODES}")

    # Run the policy inference loop
    record_loop(
        robot=robot,
        events=events,
        fps=FPS,
        policy=policy,
        preprocessor=preprocessor,
        postprocessor=postprocessor,
        dataset=dataset,
        control_time_s=EPISODE_TIME_SEC,
        single_task=TASK_DESCRIPTION,
        display_data=True,
    )

    dataset.save_episode()

# Clean up
robot.disconnect()
dataset.push_to_hub()
```

보시다시피, 이전에 학습 데이터셋을 기록할 때 사용한 명령과 거의 같습니다. 달라진 점은 두 가지입니다:

1. `--control.policy.path` 인자가 추가되어 정책 체크포인트의 경로를 나타냅니다(예: `outputs/train/eval_act_so101_test/checkpoints/last/pretrained_model`). 허브에 모델 체크포인트를 업로드했다면 모델 저장소(예: `${HF_USER}/act_so101_test`)를 사용할 수도 있습니다.
2. 데이터셋 이름이 `eval`로 시작해 추론을 실행하고 있음을 나타냅니다(예: `${HF_USER}/eval_act_so101_test`).
