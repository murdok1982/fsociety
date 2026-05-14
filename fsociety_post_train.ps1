$BASE_DIR = "D:\LLMsFinetunnig\fsociety"
$MERGE_DIR = "$BASE_DIR\merged_fp16"
$GGUF_FILE = "$BASE_DIR\fsociety-qwen.gguf"
$MODELLFILE = "$BASE_DIR\Modelfile"
$HF_USER = "murdok1982"
$LORA_REPO = "$HF_USER/fsociety-LoRA"

New-Item -ItemType Directory -Path $BASE_DIR -Force | Out-Null

Write-Host "`n[1/5] Descargando adapters LoRA desde HuggingFace..."
pip install huggingface_hub -q
python -c @"
from huggingface_hub import snapshot_download
snapshot_download(repo_id='$($LORA_REPO)', local_dir=r'$($BASE_DIR)\lora')
"@
Write-Host "  -> Adapters en $BASE_DIR\lora"

Write-Host "`n[2/5] Mergeando modelo base Qwen2.5-Coder-1.5B + LoRA..."
Write-Host "  Requiere ~10GB RAM..."
python -c @"
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import os

MODEL_ID = 'Qwen/Qwen2.5-Coder-1.5B-Instruct'
LORA_PATH = r'$($BASE_DIR)\lora'
MERGE_PATH = r'$($MERGE_DIR)'

print('  Cargando modelo base...')
model = AutoModelForCausalLM.from_pretrained(MODEL_ID, torch_dtype=torch.float16, device_map='auto')
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

print('  Cargando y mergeando adapters LoRA...')
model = PeftModel.from_pretrained(model, LORA_PATH)
model = model.merge_and_unload()

print('  Guardando modelo mergeado...')
model.save_pretrained(MERGE_PATH, safe_serialization=True)
tokenizer.save_pretrained(MERGE_PATH)
print(f'  -> Modelo mergeado en {MERGE_PATH}')
"@

Write-Host "`n[3/5] Convirtiendo a GGUF (Q8_0)..."
python "C:\Users\USUARIO\Desktop\Formacion\Entrenamiento\convert_hf_to_gguf.py" `
    $MERGE_DIR --outfile $GGUF_FILE --outtype q8_0 2>&1 | Select-String "INFO:|Writing:|success|Warning|error"

if (Test-Path $GGUF_FILE) {
    Write-Host "  -> GGUF: $GGUF_FILE ($([math]::Round((Get-Item $GGUF_FILE).Length/1GB,2)) GB)"
}

Write-Host "`n[4/5] Importando en Ollama..."
@"
FROM $GGUF_FILE
TEMPLATE """{{ if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}<|im_start|>user
{{ .Prompt }}<|im_end|>
<|im_start|>assistant"""
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER stop "<|im_end|>"
"@ | Out-File -FilePath $MODELLFILE -Encoding utf8

ollama create fsociety -f $MODELLFILE 2>&1 | Select-Object -Last 3
ollama list | Select-String "fsociety"
Write-Host "  -> ollama run fsociety"

Write-Host "`n[5/5] Subiendo modelo completo a HuggingFace..."
python -c @"
from huggingface_hub import HfApi
api = HfApi()
api.create_repo(repo_id='$($HF_USER)/fsociety', repo_type='model', exist_ok=True)
api.upload_folder(repo_id='$($HF_USER)/fsociety', folder_path=r'$($MERGE_DIR)', repo_type='model')
print('  -> Modelo completo subido')
"@

Write-Host "`n============================================"
Write-Host "  F SOCIETY LISTO (Qwen2.5-Coder-1.5B)"
Write-Host "============================================"
Write-Host "  Ollama:       ollama run fsociety"
Write-Host "  GGUF:         $GGUF_FILE"
Write-Host "  HF LoRA:      $LORA_REPO"
Write-Host "============================================"
