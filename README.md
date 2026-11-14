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
- **Gece / gündüz modu** — tek düğmeyle tüm arayüz teması değişir.
- **8 konuşma tonu** — sakin, hızlı, dramatik, çocuk sesi vb.
- **Konuşma süresi kontrolü (1–50 sn)** — hedef süreye otomatik oturtulur, perde bozulmaz.
- **Akıllı akış** — model sadece bir kez çalışır; ton/süre değiştirince metin yeniden
  üretilmeden **anında** yeni ses çıkar.
- **Loader** — analiz ve seslendirme sırasında dönen halka + animasyonlu durum yazısı.
- **Komut satırı modu** — `anlat.cmd`'ye argüman verirseniz arayüz açılmaz, CLI çalışır.
- **Çevrimdışı ve özel** — bulut yok, API anahtarı yok, telemetri yok.

> Arayüz görseli: `docs/screenshot.png` *(kendi ekran görüntünüzü ekleyip bu satırı güncelleyin)*

---

## Gereksinimler

| Bileşen | Minimum | Not |
|---|---|---|
| İşletim sistemi | Windows 10/11 x64 | PowerShell 5.1 (Windows ile gelir) |
| Ekran kartı | NVIDIA 4 GB VRAM | CUDA 12.4. GPU yoksa CPU ile de çalışır (çok yavaş) |
| RAM | 8 GB | 16 GB önerilir |
| Disk | ~5 GB boş alan | Modeller + çalıştırılabilir dosyalar |
| İnternet | Sadece kurulumda | `setup.ps1` dosyaları indirir |

Python gerekmez. Her şey hazır ikili dosyalarla çalışır.

---

## Kurulum

```powershell
git clone https://github.com/<kullanici>/omni3b.git
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

Sağ üstteki **Gece / Gündüz** düğmesi temayı değiştirir.

### Komut satırı

```powershell
.\anlat.cmd foto.jpg                          # normal ton
.\anlat.cmd foto.jpg sakin                    # ton seçerek
.\anlat.cmd foto.jpg enerjik "Bu yemekte ne var?"   # ton + kendi sorunuz
.\tonlar.cmd                                  # tonları listele
.\tonlari-dene.cmd foto.jpg                   # aynı metni 8 tonla üret (karşılaştırma)
```

Çıktılar `output\anlatim-<ton>-<tarih>.wav` ve aynı isimli `.txt` olarak kaydedilir.

### Diğer yardımcılar

| Komut | Ne yapar |
|---|---|
| `run-image.cmd <resim> [soru]` | Sadece metin cevabı (ses üretmez) |
| `run-audio.cmd <ses> [soru]` | Ses dosyasını yazıya çevirir (Türkçe kalitesi sınırlı) |
| `run-server.cmd` | Tarayıcı arayüzü: <http://127.0.0.1:8080> |

---

## Tonlar

| Ton | Karakter | Hız | Perde |
|---|---|---|---|
| `normal` | Dengeli, nötr | 1.00× | — |
| `sakin` | Yavaş, yumuşak, dinlendirici | 0.85× | −4% |
| `hizli` | Hızlı haber spikeri | 1.22× | — |
| `enerjik` | Canlı, coşkulu | 1.11× | +5% |
| `yavas` | Öğretmen gibi, çok net | 0.74× | — |
| `dramatik` | Derin, duraksamalı, kalın | 0.91× | −6% |
| `sunucu` | Profesyonel, nötr | 1.05× | — |
| `cocuk` | İnce, hareketli, meraklı | 0.95× | +12% |

Her ton dört Piper parametresiyle üretilir: `--length_scale`, `--noise_scale`,
`--noise_w`, `--sentence_silence`; ardından gerekirse WAV başlığındaki örnekleme hızı
değiştirilerek perde kaydırılır. `length_scale` aynı oranda telafi edildiği için
perde değişse bile konuşma süresi korunur.

### Konuşma süresi nasıl çalışıyor?

Ses önce üretilir, süresi ölçülür, sonra `hedef / gerçek` oranıyla konuşma hızı yeniden
ayarlanır. Bu döngü en fazla 3 kez çalışır. Süre tutmazsa arayüzde
`(hedef ...sn tutturulamadı, sınırda)` notu görünür. **Perde değişmez, sadece hız değişir.**

---

## Teknik notlar

- **Model:** Qwen2.5-Omni-3B, `Q4_K_M` kuantizasyon, GGUF. Görsel kodlayıcı ayrı bir
  `mmproj` dosyası olarak yüklenir.
- **Çıkarım:** `llama.cpp` / `llama-mtmd-cli.exe`, `-ngl 99 -fit off -c 2048`.
- **Örnekleme:** `--temp 0 --repeat-penalty 1.1 --repeat-last-n 128 -n 200` (greedy).
  Ayrıca metin tarafında 8 kelimelik parça 3 kez tekrarlanırsa çıktı kesilir (döngü koruması).
- **Türkçe karakterler:** PowerShell 5.1 BOM'suz `.ps1` dosyasını ANSI okur; bu yüzden
  betikler **BOM'lu UTF-8**'dir. Türkçe promptlar komut satırı yerine geçici dosyadan (`-f`)
  verilir; aksi halde bozulur.
- **Ses:** Omni modelinin kendi TTS'i GGUF/llama.cpp tarafından desteklenmediği için
  ayrı bir Piper modeli kullanılıyor.
- **VRAM:** ~3.8 GB (GTX 1650 4 GB'de test edildi). Bağlamı 4096'nın üstüne çıkarmayın.
- **Hız:** ~50 token/s; görsel kodlama ~5 sn, seslendirme gerçek zamanın ~15 katı hızlı.

---

## Sınırlar (dürüst notlar)

- **Tonlar farklı insan sesleri değildir.** Türkçe Piper sesi tek konuşmacılıdır
  (`num_speakers = 1`). Tonlar; hız, tonlama oynaklığı, duraklama ve perde ile üretilir.
  Gerçekten farklı kadın/erkek sesleri istiyorsanız `edge-tts`
  (`tr-TR-AhmetNeural`, `tr-TR-EmelNeural`) çevrimiçi bir alternatiftir.
- **Arayüz analiz sırasında kısa süre donar** (5–15 sn). Model tek parça çalıştığı için
  spinner yalnızca işlemin başında ve sonunda akıcı görünür. Bunu Runspace'e taşımak
  mümkündür; henüz yapılmadı.
- **Türkçe konuşma tanıma zayıftır** (`run-audio.cmd`). Seslendirme ve görsel anlatım iyi.
- **4 GB VRAM hedeflenmiştir.** Daha büyük bağlam veya `Q8_0` model bu kartta taşmaz.
- Yalnızca **Windows** için paketlenmiştir (WinForms arayüzü ve `.cmd` başlatıcılar).

---

## Sorun giderme

| Belirti | Çözüm |
|---|---|
| `Eksik dosyalar` uyarısı | `.\setup.ps1` çalıştırın |
| `llama-mtmd-cli.exe` bulunamadı | `.\setup.ps1 -Force` ile llama klasörünü yeniden kurun |
| CUDA hatası / `cublas64_12.dll` yok | NVIDIA sürücünüzü güncelleyin; olmazsa `.\setup.ps1 -Cpu -Force` |
| `Out of memory` (VRAM) | `-c` değerini düşürün (2048 → 1024) |
| Türkçe karakterler bozuk | `.ps1` dosyalarının BOM'lu UTF-8 olduğundan emin olun |
| Model tekrara düşüyor | `--repeat-penalty` değerini artırın (1.1 → 1.2) |
| Çift tıkta pencere açılmıyor | Sağ tık → *Birlikte aç* → Windows PowerShell; ya da `powershell -STA -File gui.ps1` |

---

## Depo düzeni

```
omni3b\
├── anlat.cmd          çift tık → arayüz, argümanlı → CLI
├── gui.ps1            WinForms arayüzü
├── describe.ps1       komut satırı hattı (ton destekli)
├── setup.ps1          tüm ikili dosyaları indirir
├── tonlar.cmd         ton listesi
├── tonlari-dene.cmd   tüm tonları karşılaştır
├── run-image.cmd      sadece metin
├── run-audio.cmd      ses → yazı
├── run-server.cmd     tarayıcı arayüzü
├── KULLANIM.md        ayrıntılı Türkçe kullanım
├── llama\             (indirilir, .gitignore'da)
├── models\            (indirilir, .gitignore'da)
├── tts\               (indirilir, .gitignore'da)
└── output\            üretilen .wav / .txt
```

---

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
