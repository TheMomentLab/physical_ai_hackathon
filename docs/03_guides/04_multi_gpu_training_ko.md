# 멀티 GPU 학습

이 가이드는 [Hugging Face Accelerate](https://huggingface.co/docs/accelerate)를 사용해 여러 GPU에서 정책을 학습하는 방법을 설명합니다.

## 설치

먼저 accelerate를 설치하세요:

```bash
pip install accelerate
```

## 여러 GPU로 학습하기

학습은 두 가지 방식으로 실행할 수 있습니다.

### 옵션 1: config 없이 직접 파라미터 지정

`accelerate config`를 실행하지 않고도 모든 파라미터를 커맨드에서 직접 지정할 수 있습니다:

```bash
accelerate launch \
  --multi_gpu \
  --num_processes=2 \
  $(which lerobot-train) \
  --dataset.repo_id=${HF_USER}/my_dataset \
  --policy.type=act \
  --policy.repo_id=${HF_USER}/my_trained_policy \
  --output_dir=outputs/train/act_multi_gpu \
  --job_name=act_multi_gpu \
  --wandb.enable=true
```

**핵심 accelerate 파라미터:**

- `--multi_gpu`: 멀티 GPU 학습 활성화
- `--num_processes=2`: 사용할 GPU 수
- `--mixed_precision=fp16`: fp16 혼합정밀도 사용(지원되면 `bf16` 사용 가능)

### 옵션 2: accelerate config 사용

설정을 저장하고 싶다면 하드웨어 환경에 맞게 `accelerate config`를 실행할 수 있습니다:

```bash
accelerate config
```

이 인터랙티브 설정은 GPU 수, 혼합정밀도 등 환경 질문에 답하도록 하고, 이후 재사용할 수 있도록 설정을 저장합니다. 단일 머신에서의 간단한 멀티 GPU 설정 권장값은 다음과 같습니다:

- Compute environment: This machine
- Number of machines: 1
- Number of processes: (사용할 GPU 수)
- GPU ids to use: (비워두면 전체 사용)
- Mixed precision: fp16 또는 bf16(학습 속도 향상에 권장)

이후 다음과 같이 학습을 실행합니다:

```bash
accelerate launch $(which lerobot-train) \
  --dataset.repo_id=${HF_USER}/my_dataset \
  --policy.type=act \
  --policy.repo_id=${HF_USER}/my_trained_policy \
  --output_dir=outputs/train/act_multi_gpu \
  --job_name=act_multi_gpu \
  --wandb.enable=true
```

## 동작 방식

accelerate로 학습을 실행하면 다음이 자동으로 처리됩니다:

1. **자동 감지**: LeRobot이 accelerate 실행 여부를 자동 감지
2. **데이터 분산**: 배치가 GPU들에 자동 분할
3. **그래디언트 동기화**: 역전파 시 GPU 간 그래디언트 동기화
4. **단일 프로세스 로깅**: 메인 프로세스만 wandb 로깅 및 체크포인트 저장

## 학습률과 스텝 스케일링

**중요:** LeRobot은 GPU 수에 따라 학습률이나 학습 스텝을 **자동 스케일링하지 않습니다.** 따라서 하이퍼파라미터는 사용자가 직접 제어해야 합니다.

### 왜 자동 스케일링이 없나요?

많은 분산 학습 프레임워크는 학습률을 GPU 수에 비례해 자동으로 키웁니다(예: `lr = base_lr × num_gpus`).
하지만 LeRobot은 사용자가 지정한 학습률을 그대로 유지합니다.

### 언제/어떻게 스케일링할까요?

멀티 GPU 사용 시 수동으로 조정할 수 있습니다:

**학습률 스케일링:**

```bash
# 예: 2 GPU에서 선형 LR 스케일링
# 기본 LR: 1e-4, 2 GPU -> 2e-4
accelerate launch --num_processes=2 $(which lerobot-train) \
  --optimizer.lr=2e-4 \
  --dataset.repo_id=lerobot/pusht \
  --policy=act
```

**학습 스텝 스케일링:**

유효 배치 크기는 `batch_size × num_gpus`이므로, 스텝 수를 비례해 줄이는 것이 일반적입니다:

```bash
# 예: 2 GPU에서 유효 배치 2배
# 기존: batch_size=8, steps=100000
# 2 GPU 사용 시: batch_size=8(총 16), steps=50000
accelerate launch --num_processes=2 $(which lerobot-train) \
  --batch_size=8 \
  --steps=50000 \
  --dataset.repo_id=lerobot/pusht \
  --policy=act
```

## 참고 사항

- `lerobot-train`의 `--policy.use_amp` 플래그는 accelerate 없이 실행할 때만 사용됩니다. accelerate 사용 시 혼합정밀도는 accelerate 설정으로 제어합니다.
- 로그, 체크포인트, Hub 업로드는 메인 프로세스만 수행해 충돌을 방지합니다. 다른 프로세스는 콘솔 로깅을 비활성화합니다.
- 유효 배치 크기는 `batch_size × num_gpus`입니다. 예를 들어 GPU 4개에 `--batch_size=8`이면 유효 배치 크기는 32입니다.
- 학습률 스케줄링은 멀티 프로세스에서 올바르게 처리됩니다. LeRobot은 `step_scheduler_with_optimizer=False`로 설정해 accelerate가 스케줄러 스텝을 프로세스 수로 조정하지 않도록 합니다.
- 저장/업로드 시 LeRobot이 모델을 accelerate 분산 래퍼에서 자동으로 해제해 호환성을 유지합니다.
- WandB는 메인 프로세스에서만 초기화되어 중복 실행을 방지합니다.

고급 설정과 트러블슈팅은 [Accelerate 문서](https://huggingface.co/docs/accelerate)를 참고하세요. 많은 GPU로 학습하는 방법을 더 알고 싶다면 [Ultrascale Playbook](https://huggingface.co/spaces/nanotron/ultrascale-playbook)을 확인해 보세요.
