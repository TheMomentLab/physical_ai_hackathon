# ACT (Action Chunking with Transformers)

ACT는 **가볍고 효율적인 모방 학습 정책**으로, 특히 정밀한 조작 작업에 잘 맞습니다. 학습 속도가 빠르고 연산 요구가 낮으며 성능이 좋아서, LeRobot을 처음 시작할 때 **가장 먼저 추천하는 모델**입니다.

LeRobot 팀의 튜토리얼 영상으로 ACT를 이해해 보세요: [LeRobot ACT Tutorial](https://www.youtube.com/watch?v=ft73x0LfGpM)

## 모델 개요

Action Chunking with Transformers(ACT)는 Zhao et al.의 논문 [Learning Fine-Grained Bimanual Manipulation with Low-Cost Hardware](https://arxiv.org/abs/2304.13705)에서 소개되었습니다. 이 정책은 저렴한 하드웨어와 적은 데모로도 정밀하고 접촉이 많은 조작 작업을 수행할 수 있도록 설계되었습니다.

### ACT가 초보자에게 좋은 이유

ACT가 시작점으로 훌륭한 이유는 다음과 같습니다:

- **빠른 학습**: 단일 GPU에서 몇 시간 내 학습
- **경량**: 약 8천만 파라미터로 효율적
- **데이터 효율**: 약 50개 데모만으로도 높은 성공률 달성 가능

### 아키텍처

ACT는 트랜스포머 기반 아키텍처로, 다음 세 가지 주요 구성 요소로 이루어집니다:

1. **비전 백본**: ResNet-18이 여러 카메라 시점의 이미지를 처리
2. **트랜스포머 인코더**: 카메라 특징, 관절 위치, 학습된 latent 변수 정보를 통합
3. **트랜스포머 디코더**: 크로스 어텐션으로 일관된 액션 시퀀스를 생성

정책 입력:

- 여러 장의 RGB 이미지(손목/전면/상단 카메라 등)
- 현재 로봇 관절 위치
- 학습된 스타일 변수 `z` (학습 시 학습되며, 추론 시에는 0으로 설정)

출력:

- 앞으로 `k` 스텝의 액션 시퀀스 청크

## 설치 요구사항

1. [설치 가이드](./01_installation_ko.md)를 따라 LeRobot을 설치하세요.
2. ACT는 기본 LeRobot 설치에 포함되어 있으므로 추가 의존성은 필요 없습니다.

## ACT 학습

ACT는 LeRobot의 표준 학습 파이프라인과 바로 호환됩니다. 아래는 학습 예시입니다:

```bash
lerobot-train \
  --dataset.repo_id=${HF_USER}/your_dataset \
  --policy.type=act \
  --output_dir=outputs/train/act_your_dataset \
  --job_name=act_your_dataset \
  --policy.device=cuda \
  --wandb.enable=true \
  --policy.repo_id=${HF_USER}/act_policy
```

### 학습 팁

1. **기본값으로 시작**: 대부분의 작업은 ACT 기본 하이퍼파라미터로 충분합니다.
2. **학습 시간**: 단일 GPU에서 10만 스텝 기준 몇 시간이 소요됩니다.
3. **배치 크기**: 배치 크기 8에서 시작해 GPU 메모리에 맞게 조정하세요.

### Google Colab으로 학습하기

로컬에 GPU가 없다면 Google Colab에서 학습할 수 있습니다. [ACT 학습 노트북](./notebooks#training-act)을 참고하세요.

## ACT 평가

학습이 끝나면 `lerobot-record`로 정책을 평가하며 에피소드를 기록할 수 있습니다:

```bash
lerobot-record \
  --robot.type=so100_follower \
  --robot.port=/dev/follower_arm_1 \
  --robot.id=my_robot \
  --robot.cameras="{ front: {type: opencv, index_or_path: 0, width: 640, height: 480, fps: 30}}" \
  --display_data=true \
  --dataset.repo_id=${HF_USER}/eval_act_your_dataset \
  --dataset.num_episodes=10 \
  --dataset.single_task="Your task description" \
  --policy.path=${HF_USER}/act_policy
```
