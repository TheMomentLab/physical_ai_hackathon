# GR00T N1.5 정책

GR00T N1.5는 NVIDIA가 개발한 범용 휴머노이드 로봇 추론 및 스킬을 위한 오픈 Foundation 모델입니다. 언어 및 이미지를 포함한 멀티모달 입력을 받아 다양한 환경에서 조작 작업을 수행하는 크로스-임바디먼트(Cross-embodiment) 모델입니다.

이 문서는 LeRobot 프레임워크 내에서의 통합 및 사용에 대한 구체적인 내용을 설명합니다.

## 모델 개요

NVIDIA Isaac GR00T N1.5는 GR00T N1 Foundation 모델의 업그레이드 버전입니다. 휴머노이드 로봇의 일반화 능력과 언어 이해 능력을 향상시키기 위해 개발되었습니다.

개발자와 연구자는 GR00T N1.5를 자체 실제 데이터 또는 합성 데이터로 후속 학습(post-train)하여 특정 휴머노이드 로봇이나 작업에 적응시킬 수 있습니다.

GR00T N1.5(특히 GR00T-N1.5-3B 모델)는 사전 학습된 비전 및 언어 인코더를 사용하여 구축되었습니다. Flow Matching Action Transformer를 활용하여 비전, 언어, 고유수용성(proprioception)을 조건으로 하는 액션 청크를 모델링합니다.

강력한 성능은 광범위하고 다양한 휴머노이드 데이터셋으로 학습한 결과입니다. 여기에는 다음이 포함됩니다:

- 로봇에서 수집한 실제 캡처 데이터
- NVIDIA Isaac GR00T Blueprint를 사용해 생성한 합성 데이터
- 인터넷 규모의 비디오 데이터

이러한 접근 방식을 통해 모델은 특정 임바디먼트, 작업, 환경에 대한 후속 학습을 통해 높은 적응성을 가집니다.

## 설치 요구사항

현재 GR00T N1.5는 내부 작동을 위해 Flash Attention이 필요합니다.

이를 선택 사항으로 만들기 위해 작업 중이지만, 현재는 추가 설치 단계가 필요하며 CUDA 지원 장치에서만 사용할 수 있습니다.

1. [Installation Guide](../01_getting_started/01_installation_ko.md)의 환경 설정을 따르세요. **주의**: 이 단계에서는 `lerobot`을 설치하지 마세요.
2. 다음 명령을 실행하여 [Flash Attention](https://github.com/Dao-AILab/flash-attention)을 설치하세요:

```bash
# 시스템에 맞는 PyTorch를 https://pytorch.org/get-started/locally/ 에서 확인하세요
pip install "torch>=2.2.1,<3.0.0" --index-url https://download.pytorch.org/whl/cu121
pip install flash-attn --no-build-isolation
```

3. GR00T 요구사항과 함께 LeRobot을 설치하세요:

```bash
pip install -e ".[groot]"
```

## 학습

GR00T N1.5는 Flow Matching을 사용하며 학습 중 언어 지시를 샘플링해야 합니다. 즉, 데이터셋에 언어 지시가 포함되어 있는지 확인해야 하며, 그렇지 않으면 모델이 제대로 학습되지 않습니다.

표준 학습 파이프라인을 사용하여 GR00T N1.5를 학습할 수 있습니다:

```bash
lerobot-train \
  --policy=groot \
  --env.type=libero \
  --env.task=libero_object \
  --dataset.repo_id=lerobot/libero_object \
  --policy.device=cuda \
  --wandb.enable=true
```

### 구성

`lerobot/policies/groot/configuration_groot.py` 파일에 있는 기본 구성을 사용하거나 명령줄 플래그를 통해 사용자 정의 매개변수를 지정하세요.

주요 구성 매개변수:

- `input_shapes`: 관측값(비전, 고유수용성)의 예상 형태 정의
- `output_shapes`: 예측된 액션의 형태 정의
- `vision_backbone`: 비전 인코더 네트워크 (기본값: "dinov2")
- `lang_model`: 언어 인코더 모델
- `chunk_size`: 순전파당 예측되는 액션 스텝 수 (기본값: 32)
- `n_obs_steps`: 관측 이력 스텝 수 (기본값: 2)

### 사전 학습된 체크포인트에서 학습

파인튜닝에 사용할 수 있는 사전 학습된 체크포인트를 제공합니다:

```bash
lerobot-train \
  --policy.path=lerobot/groot-n1.5-3B \
  --env.type=libero \
  --env.task=libero_object \
  --dataset.repo_id=lerobot/libero_object \
  --policy.device=cuda \
  --wandb.enable=true
```

## 평가

### 시뮬레이션 환경에서 평가 (Libero)

> [!NOTE]
> Libero 사용에 대한 지침은 [Libero](./libero)를 참고하세요.

GR00T는 Libero 벤치마크 스위트에서 강력한 성능을 보여주었습니다. LeRobot 구현을 비교하고 테스트하기 위해 GR00T N1.5 모델을 Libero 데이터셋에서 30k 스텝 동안 파인튜닝하고 GR00T 참조 결과와 비교했습니다.

| Benchmark          | LeRobot 구현 | GR00T 참조 |
| ------------------ | ------------ | ---------- |
| **Libero Spatial** | 82.0%        | 92.0%      |
| **Libero Object**  | 99.0%        | 92.0%      |
| **Libero Long**    | 82.0%        | 76.0%      |
| **평균**           | 87.0%        | 87.0%      |

이러한 결과는 다양한 로봇 조작 작업에서 GR00T의 강력한 일반화 능력을 보여줍니다. 이 결과를 재현하려면 [Libero](https://huggingface.co/docs/lerobot/libero) 섹션의 지침을 따르세요.

### 하드웨어 설정에서 평가

매개변수를 사용하여 모델을 학습한 후 다운스트림 작업에서 추론을 실행할 수 있습니다. [Imitation Learning for Robots](../02_tutorials/01_imitation_learning_ko.md)의 지침을 따르세요. 예를 들어:

```bash
lerobot-record \
  --robot.type=bi_so_follower \
  --robot.left_arm_port=/dev/follower_arm_1 \
  --robot.right_arm_port=/dev/follower_arm_1 \
  --robot.id=bimanual_follower \
  --robot.cameras='{ right: {"type": "opencv", "index_or_path": 0, "width": 640, "height": 480, "fps": 30},
    left: {"type": "opencv", "index_or_path": 2, "width": 640, "height": 480, "fps": 30},
    top: {"type": "opencv", "index_or_path": 4, "width": 640, "height": 480, "fps": 30},
  }' \
  --display_data=true \
  --dataset.repo_id=<YOUR_HF_USER>/eval_groot-bimanual  \
  --dataset.num_episodes=10 \
  --dataset.single_task="빨간 큐브를 잡아서 다른 팔로 전달하기" \
  --policy.path=<YOUR_HF_USER>/groot-bimanual  # 학습한 모델
  --dataset.episode_time_s=30 \
  --dataset.reset_time_s=10
```

## 라이선스

이 모델은 원본 [GR00T repository](https://github.com/NVIDIA/Isaac-GR00T)와 일관되게 **Apache 2.0 License**를 따릅니다.
