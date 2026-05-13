# fsociety

Modelo fine-tuned sobre **Google Gemma 4 E4B (8B)** para programación, exploiting y reversing.

## Stack

| Capa | Tecnología |
|------|-----------|
| Base | Google Gemma 4 E4B (Apache 2.0) |
| Fine-tuning | LoRA (r=32) en Colab T4/Pro |
| Dataset | 169,258 ejemplos ChatML |
| Cuantización | Q8_0 (GGUF) |
| Inferencia local | Ollama |

## Dataset de entrenamiento

- **Código:** CodeSearchNet Python (50K), Stack Exchange (100K), TheAlgorithms (340)
- **Documentación:** Python docs oficial (569 docs)
- **Exploiting:** PyCode-Vul (14K CVE), how2heap (370), CTF writeups (883), Shellcode (718)
- **Seguridad:** SecureCode OWASP web + AI/ML (2,185)

[Dataset en HuggingFace](https://huggingface.co/datasets/murdok1982/gemma4-programacion-seguridad)

## Fine-tuning en Colab

1. Abre [colab_fsociety_finetune.ipynb](colab_fsociety_finetune.ipynb) en Colab
2. Runtime → Change runtime type → **T4 GPU**
3. Conecta tu token de HuggingFace cuando pida login
4. Run all (~1.5h en T4, ~1h en V100)

## Instalación local con Ollama

```bash
# Opcion A: Descargar el GGUF directamente
ollama pull murdok1982/fsociety

# Opcion B: Crear desde Modelfile
ollama create fsociety -f Modelfile
ollama run fsociety
```

## Ejemplo de uso

```bash
ollama run fsociety "Escribe una funcion en Python para busqueda binaria"
ollama run fsociety "Analiza este codigo en busca de buffer overflow: ..."
```

## Post-training (merge + GGUF)

Si entrenaste desde el notebook, ejecuta en local:

```powershell
.\fsociety_post_train.ps1
```

Esto descarga los adapters, mergea con base, convierte a GGUF e importa en Ollama.

## Repositorios en HuggingFace

- **Dataset:** [murdok1982/gemma4-programacion-seguridad](https://huggingface.co/datasets/murdok1982/gemma4-programacion-seguridad)
- **Adapters LoRA:** [murdok1982/fsociety-LoRA](https://huggingface.co/murdok1982/fsociety-LoRA)
- **Modelo completo:** [murdok1982/fsociety](https://huggingface.co/murdok1982/fsociety)

## Licencia

MIT

## Contacto

- Email: gustavolobatoclara@gmail.com
- LinkedIn: https://www.linkedin.com/in/gustavo-lobato-clara1982/
