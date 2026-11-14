# Üçüncü taraf bileşenler ve lisansları

Bu depodaki **kod** (`.ps1`, `.cmd`, `.md` dosyaları) MIT lisanslıdır — bkz. [LICENSE](LICENSE).

Aşağıdaki bileşenler bu depoda **dağıtılmaz**; `setup.ps1` ile kendi kaynaklarından
indirilir ve kendi lisansları geçerlidir.

| Bileşen | Lisans | Kaynak |
|---|---|---|
| Qwen2.5-Omni-3B (model ağırlıkları) | Apache License 2.0 | <https://huggingface.co/ggml-org/Qwen2.5-Omni-3B-GGUF> |
| llama.cpp (çalıştırılabilir dosyalar) | MIT | <https://github.com/ggml-org/llama.cpp> |
| Piper TTS | MIT | <https://github.com/rhasspy/piper> |
| tr_TR-dfki-medium (Türkçe ses modeli) | **CC BY-NC-SA 4.0** | <https://huggingface.co/rhasspy/piper-voices> |

## Önemli not: Türkçe ses modeli

`tr_TR-dfki-medium` sesi, DFKI veri seti üzerinde eğitilmiştir ve veri seti lisansı
**CC BY-NC-SA 4.0**'dır:

> <https://creativecommons.org/licenses/by-nc-sa/4.0/>

Bu, ses modeli için **ticari olmayan kullanım** anlamına gelir. Kısıt yalnızca ses
modeline aittir; bu depodaki koda (MIT) uygulanmaz.

## Model kartı

```text
# Model card for dfki (medium)

* Language: tr_TR (Turkish, Turkey)
* Speakers: 1
* Quality: medium
* Samplerate: 22,050Hz

## Dataset

* URL: https://github.com/marytts/dfki-ot-data/
* License: https://creativecommons.org/licenses/by-nc-sa/4.0/

## Training

Finetuned from U.S. English lessac voice (medium quality).
```

## Not

Model ağırlıkları ve ses modelleri yeniden dağıtılmadığı için bu depo hiçbir model
lisansını ihlal etmez; kullanıcı dosyaları doğrudan yayıncılarından indirir ve
ilgili lisans koşullarına kendisi uyar.
