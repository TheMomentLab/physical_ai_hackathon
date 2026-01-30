# SmolVLA

SmolVLA는 Hugging Face의 경량 로봇용 파운데이션 모델입니다. LeRobot 데이터셋에서 손쉽게 파인튜닝하도록 설계되어 개발 속도를 높여줍니다.

Figure 1. SmolVLA는 (i) 여러 카메라 뷰, (ii) 로봇의 현재 센서모터 상태, (iii) 자연어 명령을 입력으로 받아 컨텍스트 특징으로 인코딩하고, 이를 액션 전문가가 액션 청크를 생성할 때 조건으로 사용합니다.

## 환경 설정

1. [설치 가이드](./01_installation_ko.md)를 따라 LeRobot을 설치합니다.
2. SmolVLA 의존성을 설치합니다:

   ```bash
   pip install -e ".[smolvla]"
   ```

## 데이터셋 수집

SmolVLA는 베이스 모델이므로, 여러분의 환경에 맞춰 파인튜닝하는 것이 필수입니다.
시작점으로 작업당 약 50 에피소드를 기록하는 것을 권장합니다. 가이드는 [데이터셋 기록](./03_imitation_learning_real_robots_ko.md)을 참고하세요.

데이터셋에서는 변형(예: 큐브 pick-place에서 테이블 위 큐브 위치)마다 충분한 데모가 포함되도록 하세요.

아래는 [SmolVLA 논문](https://huggingface.co/papers/2506.01844)에서 사용한 참고 데이터셋입니다:

🔗 [SVLA SO100 PickPlace](https://huggingface.co/spaces/lerobot/visualize_dataset?path=%2Flerobot%2Fsvla_so100_pickplace%2Fepisode_0)

이 데이터셋은 서로 다른 5개 큐브 위치에 대해 총 50개 에피소드를 기록했습니다. 각 위치별로 10개 에피소드의 pick-and-place 상호작용을 수집했습니다. 이렇게 변형을 반복 수집하면 일반화가 좋아집니다. 25 에피소드로는 성능이 충분하지 않았고, 데이터의 품질과 양이 핵심이라는 점을 확인했습니다.

데이터셋을 Hub에 올려두면 SmolVLA 파인튜닝 스크립트를 바로 사용할 수 있습니다.

## 내 데이터로 SmolVLA 파인튜닝

사전학습된 4.5억(450M) 모델 [`smolvla_base`](https://hf.co/lerobot/smolvla_base)를 사용해 파인튜닝합니다.
A100 단일 GPU 기준 2만 스텝 학습에 약 4시간이 걸립니다. 성능과 사용 목적에 맞게 스텝 수를 조정하세요.

GPU가 없다면 [Google Colab 노트북](https://colab.research.google.com/github/huggingface/notebooks/blob/main/lerobot/training-smolvla.ipynb)으로 학습할 수 있습니다.

`--dataset.repo_id`로 데이터셋을 지정합니다. 설치 테스트용으로는 [SmolVLA 논문](https://huggingface.co/papers/2506.01844)에서 사용된 데이터셋 중 하나를 사용할 수 있습니다.

```bash
cd lerobot && lerobot-train \
  --policy.path=lerobot/smolvla_base \
  --dataset.repo_id=${HF_USER}/mydataset \
  --batch_size=64 \
  --steps=20000 \
  --output_dir=outputs/train/my_smolvla \
  --job_name=my_smolvla_training \
  --policy.device=cuda \
  --wandb.enable=true
```

GPU가 허용하는 범위에서 배치 크기를 작게 시작해 점진적으로 늘리면 됩니다. 로딩 시간이 너무 길어지지 않게 유지하세요.

파인튜닝은 정답이 하나가 아닙니다. 가능한 옵션 전체를 보려면 다음 명령을 실행하세요:

```bash
lerobot-train --help
```

Figure 2: SmolVLA의 태스크 변형별 비교. 왼쪽부터: (1) 픽-플레이스 큐브 카운팅, (2) 픽-플레이스 큐브 카운팅, (3) 교란이 있는 픽-플레이스 큐브 카운팅, (4) 실제 SO101에서 레고 블록 pick-and-place 일반화.

## 파인튜닝 모델 평가 및 실시간 실행

에피소드 기록과 마찬가지로 Hugging Face Hub 로그인 상태를 권장합니다. 필요한 단계는 [데이터셋 기록](./03_imitation_learning_real_robots_ko.md)을 참고하세요.
로그인 후 아래와 같이 추론을 실행합니다:

```bash
lerobot-record \
  --robot.type=so101_follower \
  --robot.port=/dev/follower_arm_1 \ # <- 포트에 맞게 변경
  --robot.id=my_blue_follower_arm \ # <- 로봇 ID에 맞게 변경
  --robot.cameras="{ front: {type: opencv, index_or_path: 8, width: 640, height: 480, fps: 30}}" \ # <- 카메라에 맞게 변경
  --dataset.single_task="Grasp a lego block and put it in the bin." \ # <- 데이터 기록 시 사용한 동일한 작업 설명
  --dataset.repo_id=${HF_USER}/eval_DATASET_NAME_test \  # <- HF Hub에 생성될 데이터셋 이름
  --dataset.episode_time_s=50 \
  --dataset.num_episodes=10 \
  # <- 에피소드 사이 텔레오퍼레이션이 필요하면 사용(선택) \
  # --teleop.type=so100_leader \
  # --teleop.port=/dev/leader_arm_1 \
  # --teleop.id=my_red_leader_arm \
  --policy.path=HF_USER/FINETUNE_MODEL_NAME # <- 파인튜닝된 모델 경로
```

평가 설정에 따라 에피소드 길이와 기록 개수를 조정할 수 있습니다.
