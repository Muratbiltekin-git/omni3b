# Omni3B — Resimden Türkçe Sesli Anlatım

GTX 1650 (4 GB) üzerinde çalışan yerel, çevrimdışı boru hattı:
**Görsel → Türkçe metin (Qwen2.5-Omni-3B) → Türkçe ses (Piper TTS)**

## Kurulum (ilk sefer)

```powershell
cd omni3b
.\setup.ps1
```

Betik; llama.cpp, Qwen2.5-Omni-3B modelleri ve Piper Türkçe sesini indirip
`llama\`, `models\`, `tts\` klasörlerine yerleştirir (~5 GB, internet gerekir).
Kurulumdan sonra internet gerekmez.

## Hızlı kullanım

**En kolay yol:** `anlat.cmd` dosyasına **çift tıklayın** → arayüz açılır.

1. **Görsel Seç** → dosyayı seçin (önizleme görünür)
2. **SES TONU** listesinden ton seçin
3. **KONUŞMA SÜRESİ** → 1–50 saniye arası hedef süre (veya "Doğal hızda bırak")
4. **ANLAT VE DİNLE** → model görseli anlatır ve seçilen ton/süreyle seslendirir
5. Tonu veya süreyi değiştirip **"Bu tonla seslendir"** → model **tekrar çalışmaz**, aynı metni yeni ayarlarla anında üretir

Sağ üstteki **Gece / Gündüz** düğmesi temayı değiştirir.

İşlem sürerken (görsel analizi veya seslendirme) dönen halka şeklinde bir **loader** ve
yanında animasyonlu noktalar (`Görsel analiz ediliyor...`) görünür; işlem bitince kaybolur.

### Arayüz renk paleti

| Renk | Hex | Kullanım |
|---|---|---|
| Charcoal black | `#1B1B1E` / `#242428` | Arka plan ve kartlar |
| Royal blue | `#4169E1` | Ana buton, durum yazısı |
| Tangerine orange | `#F28500` | "Görsel Seç" butonu, başlık altı çizgi, vurgular |

### Konuşma süresi nasıl çalışıyor?

Hedef süre verildiğinde ses önce üretilir, ölçülür, sonra konuşma hızı (`--length_scale`)
hedefe göre yeniden ayarlanıp en fazla 3 denemede hedefe oturtulur. Süre hedefi tutmazsa
arayüzde "(hedef ...sn tutturulamadı, sınırda)" notu çıkar. Perde etkilenmez — sadece hız değişir.

Komut satırı da çalışmaya devam ediyor (`anlat.cmd`'ye argüman verirseniz arayüz açılmaz):

```powershell
cd omni3b

# Varsayılan (normal ton)
.\anlat.cmd "C:\Resimler\foto.jpg"

# Ton seçerek
.\anlat.cmd foto.jpg sakin

# Ton + kendi sorun
.\anlat.cmd foto.jpg enerjik "Bu yemekte hangi malzemeler var?"

# Tonları listele
.\tonlar.cmd

# Aynı resmi 8 tonun tamamıyla üret (karşılaştırma)
.\tonlari-dene.cmd foto.jpg
```

Çıktılar `output\anlatim-<ton>-<tarih>.wav` ve `.txt` olarak kaydedilir.

## Kendi ağzınızdan anlatım

Arayüzde **ANLATIM TARZIM** kutusu var. Buraya kendi üslubunuzu ve neyi önemsediğinizi
yazın; model görseli **sizin ağzınızdan** anlatır. Kutu kalıcıdır — yazdığınız metin
`benim-tarzim.txt` dosyasına kaydedilir, sonraki açılışta geri gelir.

Örnekler:

| Amaç | Yazılacak tarz |
|---|---|
| Kısa ve net | `Kısa ve net konuşurum, en fazla iki cümle söylerim.` |
| Samimi / esprili | `Samimi ve esprili konuşurum, "bence" demeyi severim.` |
| Alışveriş | `Fiyatları, markaları ve ürün adlarını mutlaka söylerim.` |
| Yemek | `Malzemeleri, porsiyonu ve sunumu anlatırım.` |
| Erişilebilirlik | `Renkleri, konumları, sayıları ve yazıları ayrıntılı betimlerim.` |

- Kutuyu **boş bırakırsanız** `benim-tarzim.txt` silinir, sade anlatım kullanılır.
- **SORU / YÖNERGE** kutusu tek seferliktir; ikisi birlikte modele verilir.
- Komut satırında: `.\describe.ps1 -Image foto.jpg -Style "..."` veya tarzı yok saymak
  için `-NoStyle`.
- Hazır örnek: `benim-tarzim.ornek.txt` dosyasını `benim-tarzim.txt` olarak kopyalayın.

## Tonlar

| Ton | Karakter | Konuşma hızı | Varyasyon | Perde |
|---|---|---|---|---|
| `normal` | Dengeli, nötr | 1.00× | orta | 1.00 |
| `sakin` | Yavaş, yumuşak, dinlendirici | 0.85× | düşük | −4% |
| `hizli` | Hızlı haber spikeri | 1.22× | orta | 1.00 |
| `enerjik` | Canlı, coşkulu | 1.11× | yüksek | +5% |
| `yavas` | Öğretmen gibi, çok net | 0.74× | düşük | 1.00 |
| `dramatik` | Derin, duraksamalı, kalın | 0.91× | çok yüksek | −6% |
| `sunucu` | Profesyonel, nötr | 1.05× | orta-düşük | 1.00 |
| `cocuk` | İnce, hareketli, meraklı | 0.95× | yüksek | +12% |

Teknik olarak her ton 4 parametreyle üretiliyor:
`--length_scale`, `--noise_scale`, `--noise_w`, `--sentence_silence` + WAV perde kaydırma.

### Ton farkının sınırı (dürüst not)

Türkçe Piper sesi **tek konuşmacılı** (`tr_TR-dfki-medium`, num_speakers=1). Yani tonlar
konuşma hızı, tonlama oynaklığı, duraklamalar ve perde ile üretiliyor — **tamamen farklı bir
insan sesi (kadın/erkek) değil**. Gerçek farklı konuşmacılar isterseniz iki seçenek var:

1. **edge-tts** (çevrimiçi, ücretsiz): `tr-TR-AhmetNeural` (erkek), `tr-TR-EmelNeural` (kadın).
   Kurulum: `pip install edge-tts`. İnternet gerektirir.
2. Başka bir Türkçe TTS modeli (Coqui XTTS v2 gibi) — 4 GB VRAM'de ağır, önerilmez.

## Diğer komutlar

| Komut | Ne yapar |
|---|---|
| `anlat.cmd` (çift tık) | **Arayüzü açar** |
| `.\anlat.cmd <resim> [ton] [soru]` | Resmi anlatır + seçilen tonla sesli okur |
| `.\tonlar.cmd` | Ton listesini gösterir |
| `.\tonlari-dene.cmd <resim>` | Aynı metni 8 tonla üretir |
| `.\run-image.cmd <resim> "<soru>"` | Sadece metin cevabı (ses yok) |
| `.\run-audio.cmd <ses> "<soru>"` | Ses dosyasını yazıya çevirir |
| `.\run-server.cmd` | Tarayıcı arayüzü: http://127.0.0.1:8080 |

Özel kullanım:

```powershell
.\describe.ps1 -Image foto.jpg -Tone dramatik -NoPlay      # üret, çalma
.\describe.ps1 -Image foto.jpg -Tone cocuk -Repeat 2       # iki kez dinle
```

## Teknik notlar

- **GPU:** GTX 1650 4 GB — Turing, bu yüzden Flash Attention 2 ve bf16 **yok**.
- **VRAM:** ~3.8 GB kullanılıyor. Bağlam 4096'nın üstüne çıkmayın.
- **Hız:** ~50 token/s; görsel kodlama ~5 sn, seslendirme gerçek zamanın ~15 katı hızlı.
- **Örnekleme:** `--temp 0 --repeat-penalty 1.1` kullanılıyor; aksi halde model tekrara düşüyor.
- **Türkçe karakterler:** PowerShell 5.1 BOM'suz `.ps1` dosyasını ANSI okur. `describe.ps1` bu yüzden
  **BOM'lu** UTF-8. Düzenlerken BOM'u kaybetmeyin; prompt da komut satırı yerine dosyadan veriliyor.
- **Perde kaydırma:** WAV başlığındaki örnekleme hızı değiştiriliyor; `length_scale` aynı oranda
  telafi edilerek konuşma süresi korunuyor.
- **Ses çıkışı (konuşma üretimi):** Omni modelinin kendi TTS'i GGUF'ta desteklenmiyor; bu yüzden
  ayrı Piper modeli kullanılıyor.

## Dosya düzeni

```
omni3b\
├── setup.ps1         gerekli tüm dosyaları indirir (ilk kurulum)
├── llama\            llama.cpp (CUDA 12.4) — llama-mtmd-cli, llama-server
├── models\           Qwen2.5-Omni-3B Q4_K_M + mmproj
├── tts\              piper.exe + tr_TR-dfki-medium.onnx
├── output\           üretilen .wav ve .txt dosyaları
├── gui.ps1           arayüz (WinForms)
├── describe.ps1      komut satırı hattı (ton destekli)
├── benim-tarzim.ornek.txt  tarz dosyası örneği
├── benim-tarzim.txt  kişisel tarzınız (arayüz oluşturur)
├── anlat.cmd         çift tık → arayüz / argümanlı → CLI
├── tonlar.cmd        ton listesi
└── tonlari-dene.cmd  tüm tonları karşılaştır
```
