# 🤗 PEFT로 파라미터 효율적 파인튜닝

[🤗 PEFT](https://github.com/huggingface/peft) (Parameter-Efficient Fine-Tuning)는 대형 사전학습 모델(예: SmolVLA, π₀ 등)을 모든 파라미터를 학습하지 않고도 새로운 태스크에 효율적으로 적응시키는 라이브러리이며, 성능은 유사한 수준을 유지할 수 있습니다.

PEFT 지원을 활성화하려면 `lerobot[peft]` 옵션 패키지를 설치하세요.

적용 가능한 모든 어댑테이션 방법은 [🤗 PEFT 문서](https://huggingface.co/docs/peft/index)를 참고하세요.

## SmolVLA 학습

이 섹션에서는 libero 데이터셋에서 사전학습된 SmolVLA 정책을 PEFT로 학습하는 방법을 보여줍니다.
간단히 `libero_spatial` 서브셋만 사용하며, `lerobot/smolvla_base`를 파라미터 효율적 파인튜닝 대상으로 사용합니다:

```
lerobot-train \
 --policy.path=lerobot/smolvla_base \
 --policy.repo_id=your_hub_name/my_libero_smolvla \
 --dataset.repo_id=HuggingFaceVLA/libero \
 --policy.output_features=null \
 --policy.input_features=null \
 --policy.optimizer_lr=1e-3 \
 --policy.scheduler_decay_lr=1e-4 \
 --env.type=libero \
 --env.task=libero_spatial \
 --steps=100000 \
 --batch_size=32 \
 --peft.method_type=LORA \
 --peft.r=64
```

`--peft.method_type`로 사용할 PEFT 방법을 선택합니다. 여기서는 가장 널리 쓰이는
[LoRA](https://huggingface.co/docs/peft/main/en/package_reference/lora) (Low-Rank Adapter)를 사용합니다.
Low-rank 적응은 전체 가중치 행렬 대신 비교적 낮은 rank의 행렬만 학습한다는 의미입니다. 이 rank는
`--peft.r`로 지정하며, 값이 높을수록 전체 파인튜닝에 가까워집니다.

더 복잡한(파라미터 수가 많은) 방법도 있지만, 아직 지원되지 않습니다. 원하는 PEFT 방법이 있다면 이슈를 등록해 주세요.

기본적으로 PEFT는 SmolVLA의 LM expert에 있는 `q_proj`, `v_proj` 레이어를 대상으로 합니다.
또한 태스크 의존성이 높은 state/action projection 행렬도 대상으로 설정됩니다.
다른 레이어를 대상으로 하고 싶다면 `--peft.target_modules`로 지정할 수 있습니다.
각 PEFT 방법의 문서에서 지원 입력 형식을 확인하세요(예: [LoRA target_modules 문서](https://huggingface.co/docs/peft/main/en/package_reference/lora#peft.LoraConfig.target_modules)).
보통 suffix 리스트나 정규식을 지원합니다. 예를 들어 `lm_expert`의 q/v 대신 MLP를 대상으로 하려면:

```
--peft.target_modules='(model\.vlm_with_expert\.lm_expert\..*\.(down|gate|up)_proj|.*\.(state_proj|action_in_proj|action_out_proj|action_time_mlp_in|action_time_mlp_out))'
```

어떤 레이어는 적응이 아니라 전체 파인튜닝이 필요할 수 있습니다. 이 경우 `--peft.full_training_modules`에
레이어 suffix 목록을 전달하면 됩니다:

```
--peft.full_training_modules=["state_proj"]
```

일반적으로 LoRA를 사용하면 학습률과 스케줄러 목표 학습률을 전체 파인튜닝 대비 10배 정도 높여도 됩니다
(예: 일반 1e-4 → LoRA 1e-3).
