# Omni3B — Görselden Türkçe Sesli Anlatım

Yerel, çevrimdışı bir **görsel → metin → ses** aracı. Bir fotoğraf seçersiniz, model
fotoğrafı Türkçe anlatır ve seçtiğiniz ton ile konuşma süresinde sesli olarak okur.

Tamamı kendi bilgisayarınızda çalışır: **internet gerekmez**, hiçbir veri dışarı gitmez.
4 GB VRAM'li (GTX 1650 gibi) mütevazı ekran kartlarında çalışacak şekilde ayarlanmıştır.

```
Görsel  ──▶  Qwen2.5-Omni-3B (GGUF / llama.cpp)  ──▶  Türkçe metin
                                                          │
                          Piper TTS  ◀── ton + süre ayarı ┘
                                │
                                ▼
                          output\anlatim-<ton>-<tarih>.wav
```

---

## Özellikler

- **Çift tıklanabilir arayüz** — `anlat.cmd`'ye çift tıklayın, WinForms arayüzü açılır.
- **8 konuşma tonu** — sakin, hızlı, dramatik, çocuk sesi vb.
- **Kendi ağzınızdan anlatım** — kalıcı "Anlatım Tarzım" kutusu; neyi önemsediğinizi bir kez
  yazın, her görselde o üslupla konuşsun.
- **Konuşma süresi kontrolü (1–50 sn)** — hedef süreye otomatik oturtulur, perde bozulmaz.
- **Akıllı akış** — model sadece bir kez çalışır; ton/süre değiştirince metin yeniden
  üretilmeden **anında** yeni ses çıkar.
- **Çevrimdışı ve özel** — bulut yok, API anahtarı yok, telemetri yok.

> Arayüz görseli: <img width="787" height="760" alt="image" src="https://github.com/user-attachments/assets/9e60779a-cfc9-4440-95e6-5a5231925520" />


---

## Gereksinimler

| Bileşen | Minimum | Not |
|---|---|---|
| İşletim sistemi | Windows 10/11 x64 | PowerShell 5.1 (Windows ile gelir) |
| Ekran kartı | NVIDIA 4 GB VRAM | CUDA 12.4. GPU yoksa CPU ile de çalışır (çok yavaş) |
| RAM | 8 GB | 16 GB önerilir |
| Disk | ~5 GB boş alan | Modeller + çalıştırılabilir dosyalar |
| İnternet | Sadece kurulumda | `setup.ps1` dosyaları indirir |


## Kurulum

```powershell
git clone https://github.com/<Muratbiltekin>/omni3b.git
cd omni3b
.\setup.ps1
```

`setup.ps1` şunları indirir ve doğru klasörlere yerleştirir:

| Klasör | İçerik | Boyut |
|---|---|---|
| `llama\` | llama.cpp `b12387` (NVIDIA varsa CUDA 12.4, yoksa CPU) | ~1.2 GB |
| `models\` | Qwen2.5-Omni-3B Q4_K_M + mmproj Q8_0 | ~3.4 GB |
| `tts\` | Piper TTS + `tr_TR-dfki-medium` Türkçe sesi | ~0.2 GB |

Seçenekler:

```powershell
.\setup.ps1 -Cpu        # GPU olsa bile CPU sürümünü indir
.\setup.ps1 -Force      # var olan dosyaları da yeniden indir
```

> Kurulum betiği yönetici yetkisi istemez. İndirme yarıda kalırsa tekrar çalıştırın;
> `curl.exe` ile kaldığı yerden devam eder.

---

## Kullanım

### Arayüz (önerilen)

`anlat.cmd` dosyasına **çift tıklayın**.

1. **Görsel Seç** → dosyayı seçin (önizleme görünür)
2. **SES TONU** → listeden ton seçin
3. **KONUŞMA SÜRESİ** → 1–50 saniye arası hedef (veya *"Doğal hızda bırak"*)
4. **ANLAT VE DİNLE** → model görseli analiz eder ve seslendirir
5. Tonu/süreyi değiştirip **"Bu tonla seslendir"** → model tekrar çalışmadan yeni ses üretilir

### Kendi ağzınızdan anlatım

Arayüzdeki **ANLATIM TARZIM** kutusuna kendi üslubunuzu ve neyi önemsediğinizi yazın.
Bu kutu **kalıcıdır**: yazdığınız metin `benim-tarzim.txt` dosyasına kaydedilir ve bir
sonraki açılışta geri gelir. Model, görseli sizin ağzınızdan anlatır.

Örnek tarzlar:

| Amaç | Yazılacak tarz |
|---|---|
| Kısa ve net | `Kısa ve net konuşurum. En fazla iki cümle söylerim.` |
| Samimi / esprili | `Samimi ve esprili konuşurum, "bence" demeyi severim.` |
| Alışveriş odağı | `Fiyatları, markaları ve ürün adlarını mutlaka söylerim.` |
| Yemek odağı | `Malzemeleri, porsiyonu ve sunumu anlatırım.` |
| Erişilebilirlik | `Renkleri, konumları, sayıları ve yazıları ayrıntılı betimlerim.` |

Tek seferlik bir yönerge için alttaki **SORU / YÖNERGE** kutusunu kullanın; ikisi birlikte
modele verilir. Tarz kutusunu boş bırakırsanız tarz dosyası silinir ve sade anlatım kullanılır.

### Komut satırı ile de çalıştırabilirsin

```powershell
.\anlat.cmd foto.jpg                          # normal ton
.\anlat.cmd foto.jpg sakin                    # ton seçerek
.\anlat.cmd foto.jpg enerjik "Bu yemekte ne var?"   # ton + kendi sorunuz
.\tonlar.cmd                                  # tonları listele
.\tonlari-dene.cmd foto.jpg                   # aynı metni 8 tonla üret (karşılaştırma)
```

`benim-tarzim.txt` varsa komut satırında da otomatik kullanılır:

```powershell
.\describe.ps1 -Image foto.jpg -Style "Kısa ve esprili konuşurum, fiyatları söylerim."
.\describe.ps1 -Image foto.jpg -NoStyle        # tarzı yok say, sade anlat
```

Çıktılar `output\anlatim-<ton>-<tarih>.wav` ve aynı isimli `.txt` olarak kaydedilir.

### Diğer yardımcılar

| Komut | Ne yapar |
|---|---|
| `run-image.cmd <resim> [soru]` | Sadece metin cevabı (ses üretmez) |
| `run-audio.cmd <ses> [soru]` | Ses dosyasını yazıya çevirir (Türkçe kalitesi sınırlı) |
| `run-server.cmd` | Tarayıcı arayüzü: <http://127.0.0.1:8080> |

## Sınırlar (dürüst notlar)

- **Arayüz analiz sırasında kısa süre donar** (5–15 sn). Model tek parça çalıştığı için
  spinner yalnızca işlemin başında ve sonunda akıcı görünür. Bunu Runspace'e taşımak
  mümkündür; henüz yapılmadı.
- **Türkçe konuşma tanıma zayıftır** (`run-audio.cmd`). Seslendirme ve görsel anlatım iyi.
- **4 GB VRAM hedeflenmiştir.** Daha büyük bağlam veya `Q8_0` model bu kartta taşmaz.
- Yalnızca **Windows** için paketlenmiştir (WinForms arayüzü ve `.cmd` başlatıcılar).


## Lisans ve krediler

Bu depodaki **kod** MIT lisanslıdır — bkz. [LICENSE](LICENSE).
Üçüncü taraf bileşenlerin tam lisans metinleri: [NOTICE.md](NOTICE.md).

Model ağırlıkları ve çalıştırılabilir dosyalar depoda **dağıtılmaz**, `setup.ps1` ile
kaynağından indirilir. Kendi lisansları geçerlidir:

| Bileşen | Lisans |
|---|---|
| [Qwen2.5-Omni-3B](https://huggingface.co/ggml-org/Qwen2.5-Omni-3B-GGUF) | Apache 2.0 |
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | MIT |
| [Piper TTS](https://github.com/rhasspy/piper) | MIT |
| [tr_TR-dfki-medium sesi](https://huggingface.co/rhasspy/piper-voices) | **CC BY-NC-SA 4.0** (veri seti) |

> ⚠️ Türkçe ses modeli **ticari olmayan** kullanım içindir (CC BY-NC-SA 4.0).
> Bu kısıt ses modeline aittir; depodaki koda değil.

Geliştirme: [Murat Biltekin](https://github.com/Muratbiltekin-git)
