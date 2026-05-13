# ─────────────────────────────────────────────
# POST-TRAINING: fsociety (ejecutar en tu PC)
# ─────────────────────────────────────────────
# 1. Descargar adapters desde HuggingFace
# 2. Mergear base + LoRA
# 3. Convertir a GGUF
# 4. Importar en Ollama
# 5. Subir a HuggingFace
# ─────────────────────────────────────────────

$BASE_DIR = "D:\LLMsFinetunnig\fsociety"
$MERGE_DIR = "$BASE_DIR\merged_fp16"
$GGUF_FILE = "$BASE_DIR\fsociety.gguf"
$MODELLFILE = "$BASE_DIR\Modelfile"
$HF_USER = "murdok1982"
$LORA_REPO = "$HF_USER/fsociety-LoRA"

New-Item -ItemType Directory -Path $BASE_DIR -Force | Out-Null

# ── 1. DESCARGAR ADAPTERS ──
Write-Host "`n[1/5] Descargando adapters LoRA desde HuggingFace..."

pip install huggingface_hub -q
python -c @"
from huggingface_hub import snapshot_download
import os
snapshot_download(
    repo_id='$($LORA_REPO)',
    local_dir=r'$($BASE_DIR)\lora',
    token=os.environ.get('HF_TOKEN')
)
"@
Write-Host "  -> Adapters en $BASE_DIR\lora"

# ── 2. MERGE BASE + LORA ──
Write-Host "`n[2/5] Mergeando modelo base + LoRA (fp16)..."
Write-Host "  Esto toma unos minutos y requiere ~20GB RAM..."
Write-Host "  Asegurate de tener HF_TOKEN en el entorno o configuralo:"
Write-Host "  `$env:HF_TOKEN = 'tu_token_aqui'"
python -c @"
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import os

MODEL_ID = 'google/gemma-4-E4B-it'
LORA_PATH = r'$($BASE_DIR)\lora'
MERGE_PATH = r'$($MERGE_DIR)'

print('  Cargando modelo base...')
model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    torch_dtype=torch.float16,
    device_map='auto',
    token=os.environ['HF_TOKEN']
)
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, token=os.environ['HF_TOKEN'])

print('  Cargando y mergeando adapters LoRA...')
model = PeftModel.from_pretrained(model, LORA_PATH)
model = model.merge_and_unload()

print('  Guardando modelo mergeado...')
model.save_pretrained(MERGE_PATH, safe_serialization=True)
tokenizer.save_pretrained(MERGE_PATH)
print(f'  -> Modelo mergeado en {MERGE_PATH}')
"@

# ── 3. CONVERTIR A GGUF ──
Write-Host "`n[3/5] Convirtiendo a GGUF (Q8_0)..."
Write-Host "  Usando convert_hf_to_gguf.py..."

$env:NO_LOCAL_GGUF = "1"
python "C:\Users\USUARIO\Desktop\Formacion\Entrenamiento\convert_hf_to_gguf.py" `
    $MERGE_DIR `
    --outfile $GGUF_FILE `
    --outtype q8_0 2>&1 | Select-String -NotMatch "blk\.|token_embd|output_norm|ffn_|attn_" | Select-String "INFO:|Writing:|success|Warning|error"

if (Test-Path $GGUF_FILE) {
    Write-Host "  -> GGUF creado: $GGUF_FILE ($([math]::Round((Get-Item $GGUF_FILE).Length/1GB,2)) GB)"
}

# ── 4. IMPORTAR EN OLLAMA ──
Write-Host "`n[4/5] Importando en Ollama..."

@"
FROM $GGUF_FILE
TEMPLATE """{{ if .System }}<start_of_turn>user
{{ .System }}

{{ .Prompt }}<end_of_turn>
<start_of_turn>model
{{ .Response }}<end_of_turn>"""
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER stop "<end_of_turn>"
"@ | Out-File -FilePath $MODELLFILE -Encoding utf8

ollama create fsociety -f $MODELLFILE 2>&1 | Select-Object -Last 3
ollama list | Select-String "fsociety"

Write-Host "  -> Para probar: ollama run fsociety"

# ── 5. SUBIR MODELO COMPLETO A HF ──
Write-Host "`n[5/5] Subiendo modelo completo a HuggingFace..."

python -c @"
import os
from huggingface_hub import HfApi
api = HfApi(token=os.environ.get('HF_TOKEN'))
api.create_repo(repo_id='$($HF_USER)/fsociety', repo_type='model', exist_ok=True)
api.upload_folder(
    repo_id='$($HF_USER)/fsociety',
    folder_path=r'$($MERGE_DIR)',
    repo_type='model'
)
print('  -> Modelo completo subido a $($HF_USER)/fsociety')
"@

Write-Host "`n============================================"
Write-Host "  F SOCIETY LISTO"
Write-Host "============================================"
Write-Host "  Ollama:       ollama run fsociety"
Write-Host "  GGUF:         $GGUF_FILE"
Write-Host "  HF LoRA:      $LORA_REPO"
Write-Host "  HF completo:  $HF_USER/fsociety"
Write-Host "============================================"
