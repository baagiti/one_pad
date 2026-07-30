# One Pad — Teknik Tasarım Dokümanı

Versiyon: 0.1
Durum: İnceleme bekliyor
Referans: [product_spec_v0.1.md](product_spec_v0.1.md)

---

## 1. Kesinleşen Kararlar ve Kısıtlar

| Konu | Karar | Gerekçe |
|---|---|---|
| Framework | Flutter | Mevcut deneyim (metronom-akort app), Windows'tan geliştirilebilir |
| iOS build | Codemagic + TestFlight | Mac yok; kanıtlanmış boru hattı |
| Backend | Yok — tamamen local (v1) | Spec backend gerektirmiyor; hız ve maliyet |
| Abonelik | App Store IAP (StoreKit / RevenueCat — karar bekliyor) | |
| Ses mimarisi | "Render et, schedule etme" (bkz. §3) | Zamanlama hassasiyeti + native koda bağımlılığı azaltma |
| Nota render | Kendi renderer'ımız: CustomPainter + Bravura (SMuFL) | Kayan pencere + playhead + sticking harfleri için tam kontrol |
| İçerik modeli | Template havuzu + kısıtlı shuffle (ilk seviyeler), üretken kurallar (ileri seviyeler) | Pedagojik kontrol + içerik yazım maliyeti dengesi |
| Sticking | Birinci sınıf katman; her notanın altında R/L harfi | İlk skill'in asıl müfredatı sticking okuma |
| Bluetooth ses | Desteklenmiyor (spec) | Gecikme değişkenliği |

**Bilinen sınırlama:** Mikrofon analizi hangi elle vurulduğunu ayırt edemez. Sticking doğruluğu analiz metriği DEĞİLDİR ve hiçbir ekranda "el doğruluğu" vaadi verilmez. Analiz yalnızca zamanlama (onset) ölçer.

---

## 2. Mimari Genel Bakış

Dört katman; bağımlılık yönü yukarıdan aşağıya tek yönlü:

```
┌─────────────────────────────────────────────┐
│ Presentation (Flutter UI)                   │
│  ekranlar, notation renderer, playhead      │
├─────────────────────────────────────────────┤
│ Application (akış / state)                  │
│  session akış makinesi, plan gating         │
├─────────────────────────────────────────────┤
│ Domain (saf Dart, platform bağımsız)        │
│  veri modeli, üretim motoru, review pool,   │
│  timeline hesabı, (ileride) analiz          │
├─────────────────────────────────────────────┤
│ Infrastructure                              │
│  audio engine, kayıt, storage, IAP          │
└─────────────────────────────────────────────┘
```

Domain katmanı hiçbir Flutter/platform API'sine dokunmaz → Windows desktop'ta birim testiyle tamamen doğrulanabilir. iPhone'da doğrulanması gereken tek şey Infrastructure katmanıdır (ses gecikmesi, kayıt). Bu, Mac'siz iterasyon maliyetini minimize eden ana tasarım kararıdır.

---

## 3. Ses Mimarisi — "Render Et, Schedule Etme"

### İlke

Tık seslerini çalma anında zamanlamak (timer/event scheduling) yerine, seansın **tüm ses hattı önceden tek PCM buffer'a render edilir** ve kesintisiz tek stream olarak çalınır:

```
[count-in tıkları][ölçü1 tıkları][ölçü2 tıkları]...[ölçü16 tıkları]
        +  (preview modunda) referans pad vuruşları, aynı buffer'a mix
```

### Sonuçları

- **Master Timeline (spec §15) = ses motorunun playback pozisyonu.** Tek doğruluk kaynağı ses saatidir. Metronom, count-in, referans vuruşlar buffer'ın içinde olduğu için tanım gereği senkrondur; jitter imkânsızdır.
- **Playhead:** playback pozisyonu periyodik okunur (~60 Hz UI frame'inde), aradaki kareler monotonic clock ile enterpole edilir, her okumada ses pozisyonuna resync edilir.
- **Exercise geçişleri:** pozisyon → ölçü/vuruş eşlemesi saf matematik (`TimelineMap`: sample offset ↔ measure/beat). Domain'de hesaplanır, test edilebilir.
- **BPM değişimi:** Session içeriği değişmez (spec §4), yalnızca ses hattı yeni BPM ile yeniden render edilir (offline, ms mertebesi).
- **Kayıt:** çalma başladığı anda kayıt başlar; kayıt dosyasının t=0'ı, ses hattının t=0'ına sabitlenir (gecikme kalibrasyonu §9).

### Uygulama

- Aday paket: `flutter_soloud` (miniaudio tabanlı, düşük gecikme, hassas pozisyon okuma). Metronom-akort'ta kullanılan çözüm değerlendirilecek — hangisi daha iyi pozisyon raporluyorsa o.
- `AudioEngine` soyut arayüzü: `load(pcm)`, `play()`, `stop()`, `positionSamples`, `onComplete`. Paket değişimi tek sınıfı etkiler.
- Render: 44.1 kHz, 16-bit mono yeterli. Tık/pad sesleri kısa WAV sample'ları; render = sample'ları hesaplanan offset'lere mixleme (saf Dart, domain'e yakın ama Infrastructure'da).
- Sesler: normal tık, vurgulu tık (ölçü başı), count-in tıkı (farklı ses — spec §6), referans pad sesi. Ses tasarımı: açık konu (§12).

---

## 4. Veri Modeli

```
Skill
 ├─ id, name, description
 ├─ timeSignature (v1: 4/4; model çoklu destekler)
 ├─ bpmDefault, bpmRange
 └─ levels: [Level]

Level
 ├─ level (int), name
 ├─ generation: GenerationSpec (strateji + kısıtlar)
 └─ templates: [ExerciseTemplate]

ExerciseTemplate
 ├─ id
 ├─ rhythm: [NoteToken]        // ör. ["q","q","q","q"]; "rq" = dörtlük sus
 ├─ sticking: [ "R" | "L" ]    // nota sayısıyla eşit uzunluk (suslar hariç)
 └─ difficulty (int)

Exercise (çözülmüş örnek — session içinde saklanan)
 ├─ templateId (kaynak referansı)
 ├─ rhythm, sticking (SNAPSHOT — template sonradan değişse bile
 │                     birebir replay garantisi; spec §9 "exact replay")
 └─ index (session içi sıra 0..15)

Session
 ├─ id, createdAt
 ├─ source: SkillRef(level) | PerformanceAreaRef
 ├─ bpm
 ├─ exercises: [Exercise]  (v1: 16)
 └─ recordings: [RecordingRef]

ReviewPoolEntry
 ├─ exercise (snapshot), sourceSkill, bpm
 ├─ difficultyEvidence (hangi sinyalle girdi — §10)
 └─ timestamps

PerformanceArea (v1'de model var, içerik sonra)
 ├─ allowedSkills, difficultyLimits, bpmLimits, generationRules
```

**NoteToken kodlaması:** `w h q e s` (birlik→onaltılık), sus için `r` öneki (`rq`), nokta için `.` soneki (`q.`). v1 yalnızca `q` kullanır; kodlama ileriyi karşılar.

### Template içerik dosyası (JSON) — örnek

```json
{
  "schemaVersion": 1,
  "skillId": "quarter_note_pulse",
  "name": "Quarter-Note Pulse",
  "timeSignature": "4/4",
  "bpmDefault": 70,
  "bpmRange": [50, 120],
  "levels": [
    {
      "level": 1,
      "name": "Steady Alternation",
      "generation": {
        "strategy": "pool_shuffle",
        "constraints": { "noAdjacentRepeat": true, "difficultyRamp": true }
      },
      "templates": [
        { "id": "qnp_1_rlrl", "rhythm": ["q","q","q","q"], "sticking": ["R","L","R","L"], "difficulty": 1 },
        { "id": "qnp_1_lrlr", "rhythm": ["q","q","q","q"], "sticking": ["L","R","L","R"], "difficulty": 1 }
      ]
    }
  ]
}
```

İçerik dosyaları asset olarak paketlenir; içerik eklemek kod değişikliği gerektirmez.

---

## 5. Üretim Motoru

Her Level bir `GenerationSpec` bildirir; motor stratejiyi yorumlar:

1. **`pool_shuffle`** — havuzdan kısıtlı seçim/sıralama. Kısıtlar: ardışık tekrar yasağı, zorluk rampası (kolay başla → zorlaş), minimum çeşitlilik (16 slotta en az N farklı template).
2. **`pool_transform`** — havuz + parametrik dönüşümler (sticking permütasyonu, sus ikamesi, ayna). Az template → çok egzersiz.
3. **`generative`** — kural tabanlı tam üretim (ileri skill'ler; v1'de implement edilmez, arayüzü tanımlanır).

Ortak boru hattı:

```
GenerationSpec → aday üretimi → kısıt filtresi → sıralama →
Review Pool enjeksiyonu (premium, §10) → Session (16 Exercise snapshot)
```

Motor deterministik çalışır (seed'li RNG) → testlerde tekrarlanabilir.

### Tempo Müfredatı (2026-07-20 karar, 2026-07-27'de KALDIRILDI)

Prosedürel çeşitlilik (`pool_shuffle`) tek başına ilk dersler için yeterli bir müfredat değil: metronomla senkron kurmak ve temel nabız hissini inşa etmek, oturumdan oturuma **kasıtlı bir ilerleme** gerektirir düşüncesiyle, `Level` modeline opsiyonel bir `curriculumBpms` alanı eklenmişti (`domain/curriculum/curriculum_policy.dart`, Quarter-Note Pulse Level 1: 30→180 BPM/16 seans; Eighth Notes ve Sixteenth Notes Level 1'lerinde de aynı desen tekrarlandı).

**2026-07-27 karar: bu mekanizma tamamen kaldırıldı.** Kullanıcı "diğer dersler gibi olsun" dedi — sabit/otomatik BPM ilerlemesi yerine, bu üç Level 1 de artık tüm diğer seviyeler gibi serbest BPM kontrolüyle (+/- ok, Tap Tempo) çalışıyor, `bpmDefault`'tan başlıyor. `resolveCurriculumBpm`/`curriculum_policy.dart` ve drift'teki hiçbir karşılığı yoktu (BPM ilerlemesi zaten sadece `completedCount`'a bakıyordu, ayrı bir tablo gerekmiyordu) silindi. Yerine, `Level`e opsiyonel bir `note` alanı eklendi (Session Preview'da küçük bir ipucu olarak gösteriliyor) — üç etkilenen Level 1'e "BPM'i değiştirerek çalış, yavaş tempoları atlama" notu eklendi, ramp'ın arkasındaki pedagojik tavsiye (yavaş tempoları ihmal etme) böylece korunmuş oldu, sadece zorunlu/otomatik olmaktan çıktı.

### İlk Skill: Quarter-Note Pulse — seviye planı

Ritim tüm seviyelerde sabit 4 dörtlük; müfredat tamamen sticking:

| Seviye | İçerik | Örnekler |
|---|---|---|
| 1 | Katı alternasyon, ölçü içi sabit | RLRL, LRLR |
| 2 | Öncü el değişimi (ölçüden ölçüye) | RLRL → LRLR ardışık |
| 3 | Çiftlemeler / simetrik kalıplar | RRLL, LLRR, RLLR, LRRL |
| 4 | Serbest sticking okuma — istenç üzerine el komutu | RRRL, RLLL, LRRR, RLRR... |

Seviye 4'ün havuzu `pool_transform` ile üretilebilir (4 notaya R/L ataması = 16 kombinasyon, 2'si seviye 1'de → kalan 14; elle yazmaya bile gerek yok, ama pedagojik sıralama elle etiketlenir).

---

## 6. Nota Renderer

- `CustomPainter` + **Bravura** fontu (SMuFL, ücretsiz/açık lisans). Glifler font'tan, konumlandırma bizden.
- Tek çizgili perküsyon porte, tek ses (pad). Anahtar: perküsyon clef.
- **Glif kaynağı: Bravura (SMuFL) — 2026-07-20 karar.** Notalar/suslar artık vektörel el çizimi değil, Bravura font glifleri (`assets/fonts/Bravura.otf`, SIL OFL lisanslı). Karar değişikliği: Skill 2 sus gerektirdi, Skill 3+ (Eighth/Sixteenth Notes, Rudiments) bayrak/kiriş gerektirecek — elle Path çizmek kırılgan. **Kritik teknik:** SMuFL glifleri metin **baseline**'ına göre konumlandırılır (`TextPainter.computeDistanceToActualBaseline`), rastgele bir yükseklik kesri TAHMİN ETMEK YERİNE — aksi halde nota ve sus farklı hizalara oturur (yaşanan bir hataydı, baseline hizalamasıyla düzeldi). Kod noktaları: `noteQuarterUp` U+E1D5, `restQuarter` U+E4E5 (diğer süreler için de harita hazır: whole/half/8th/16th).
- **Her notanın altında sticking harfi (R/L)** — temel gereksinim.
- **4 ölçülük kayan pencere** (spec §7): aktif egzersiz çerçeve ile vurgulu; pencere her egzersiz bitiminde bir ölçü **smooth** kayar (animasyonlu translate; layout ölçü genişliklerini önceden hesaplar).
- **Playhead:** `TimelineMap` üzerinden pozisyon → x koordinatı; nota hizasında dikey çizgi.
- Ekranda yalnızca: notasyon, playhead, BPM, metronom göstergesi, session ilerlemesi. **Vuruş numarası asla gösterilmez** (spec §7) — bu kural 2026-07-20'de referans mockup'a rağmen bilinçli olarak korundu (bkz. §14).
- Layout motoru domain-yanı saf fonksiyon: `[Exercise] → [GlyphPlacement]` — golden test edilebilir.

---

## 7. Ekran Akışı ve Durum Makinesi

```
Home ──Start Practice──▶ SessionPreview ──▶ CountIn ──▶ Practice ──▶ Results
  │                          │  ▲                          │
  ├─ Skills (seçim)          │  └── tekrar dinleme         └─ (kayıt varsa) Analyze? ─▶ Results
  └─ Performance (premium)   └─ Reference hits on/off
```

Session akışı tek durum makinesi: `idle → previewing → countIn → practicing → finished → (analyzing) → results`. Count-in: tam bir ölçü, farklı tık sesi, notasyon ve referans vuruş yok, kaydedilmez/analiz edilmez (spec §6) — render edilen ses hattının başındadır ama `TimelineMap` bu bölgeyi "pre-roll" olarak işaretler.

---

## 8. Modül / Klasör Yapısı

```
lib/
  domain/
    model/          // Skill, Level, Exercise, Session, ...
    generation/     // stratejiler, kısıtlar, RNG
    timeline/       // TimelineMap: sample ↔ measure/beat
    review/         // Review Pool kuralları
    analysis/       // (M4) onset eşleme, skorlama — saf Dart
  application/
    session_flow/   // durum makinesi
    entitlements/   // free/premium gating
  infrastructure/
    audio/          // AudioEngine impl, PCM render, sample assets
    recording/      // mikrofon kaydı
    storage/        // local persistence (drift/isar/shared_prefs — karar M1'de)
    iap/            // StoreKit/RevenueCat (M5)
  presentation/
    screens/        // home, preview, practice, results, skills, paywall
    notation/       // renderer, layout, Bravura
    theme/
content/
  skills/quarter_note_pulse.json
test/               // domain %100 platformsuz test edilebilir
```

---

## 9. Kayıt ve Analiz (M3–M4)

- **Referans pad sesi (2026-07-20 karar):** `SessionAudioRenderer`'ın per-note reference hit mekanizması (her ritim notasının konumuna, metronom vuruşundan bağımsız olarak bir pad sesi yerleştirir — `lengthInBeats` ile herhangi bir ritme genelleşir) artık **Practice modunda da duyulur** (önceden sadece Preview'daydı). **Record modunda kapanmalı** — mikrofon aktifken duyulur referans sesi kayda sızıp M4'ün onset tespitini kirletebilir. M3'te gerçek kayıt akışı kurulduğunda, kayıt başlangıcı `includeReferenceHits: false` ile yüklenmeli.
- Kayıt seansla eş başlar; dosya t=0 = timeline t=0.
- Analiz **offline** (seans sonrası, spec §8): onset detection (enerji/spektral flux tabanlı; Dart'ta başla, yavaşsa FFI/C) → tespit edilen vuruşlar `TimelineMap`'teki beklenen vuruşlarla eşleştirilir → egzersiz başına zamanlama skoru.
- **Gecikme kalibrasyonu (zorunlu):** çıkış + mikrofon gecikmesi düzeltilmeden erken/geç yargısı anlamsız. Yöntem: kalibrasyon ekranında cihaz kendi tık sesini çalar, mikrofonla yakalar, round-trip gecikmeyi ölçer; kullanıcı pad'e vurarak doğrular. Cihaz başına saklanır.
- Analiz sonuç ekranı içeriği: **açık konu** (§12).

### 9.1 M3 İmplementasyonu — Kayıt (2026-07-22)

- **Paket:** `flutter_recorder` (`flutter_soloud` ile aynı ekosistem — miniaudio tabanlı, iOS/Windows/Android/Web destekli). `AudioEngine`'e paralel yeni bir soyutlama: `lib/infrastructure/audio/audio_recorder.dart`.
  ```dart
  abstract class AudioRecorder {
    Future<void> init();
    void startRecording(String filePath);  // dosyaya WAV yazımını başlatır
    void stopRecording();                  // dosyayı sonlandırır, cihaz açık kalır
    void dispose();
  }
  ```
  `init()` dışında hepsi senkron — gerçek `flutter_recorder` API'si de öyle (sadece `init` async). `FlutterRecorderAudioRecorder`, `Recorder.instance`'ı sarar; `sampleRate: 44100` ile başlatılır (paketin kendi varsayılanı 22050'dir — `PracticeFlowController.sampleRate` ile birebir eşleşmesi, M4'te `TimelineMap` örnek konumlarıyla dönüşümsüz karşılaştırma için gerekli).
- **`PracticeFlowController`** genişledi: `recorder` (zorunlu constructor parametresi, `engine` gibi), `isRecording`/`recordingPath` getter'ları, `startRecording({filePath})` — `startPractice()` ile aynı, ama referans vuruşlar hep kapalı (`_load(includeReferenceHits: false)`) ve mikrofon `engine.play()`'den ÖNCE başlatılıyor (kaydın ilk vuruşu kaçırmaması için). `poll()`/`stop()` seans bitince/iptal edilince kaydı da otomatik durduruyor (`_stopRecordingIfActive`). `generateSession`/`startPractice` her çağrıldığında `recordingPath` sıfırlanıyor — Results ekranının eski bir kaydı yanlışlıkla göstermemesi için.
- **Dosya konumu:** `lib/infrastructure/audio/recording_paths.dart` — `path_provider`'ın uygulama belgeleri dizini altında `recordings/<skillId>_<epochMs>.wav`.
- **UI:** Session Preview'a "Record" butonu eklendi (dosya yolu önceden üretilip `PracticeScreen(recordingFilePath: ...)`'a taşınıyor); Practice ekranının başlığında kayıt sırasında kırmızı REC noktası; Results ekranı artık Stateful — `recordingPath` doluysa "Play Recording" ile kaydı `controller.engine` üzerinden (aynı `AudioEngine`, o an boşta) geri çalıyor.
- **iOS:** `Info.plist`'e `NSMicrophoneUsageDescription` eklendi — bu olmadan mikrofon erişimi isteği uygulamayı doğrudan çökertir.
- **Doğrulama:** `flutter analyze` temiz, 241 test yeşil (5 yeni: kayıt başlatma, doğal bitişte tek seferlik durdurma, `stop()` ile iptalde durdurma, düz practice'in recorder'a hiç dokunmaması + eski `recordingPath`'i temizlemesi, `generateSession`'ın temizlemesi). Windows'ta gerçek mikrofonla uçtan uca doğrulandı: kullanıcı Record → konuştu → Play Recording ile dinledi; diskte `OneDrive\Belgeler\recordings\paradiddle_eighth_notes_...wav` (~6 MB) oluştuğu ayrıca dosya sisteminden teyit edildi.
- **Kapsam dışı (M4'e bırakıldı):** onset detection, FFT (`PCMFormat.f32le` gerektirir — şu an varsayılan `s16le`), skorlama, sonuç metrikleri.

**DÜZELTME — ilk gerçek TestFlight dağıtımında bulunan çökme (2026-07-30).** `PracticeFlowController.init()` (uygulama açılışında, `main.dart`'tan çağrılıyor) o güne kadar hem `engine.init()` (flutter_soloud) hem `recorder.init()` (flutter_recorder) çağırıyordu. Bu, Windows'ta hiç sorun çıkarmadı (M3/M4 boyunca mikrofonla defalarca doğrulandı), ama gerçek iPhone'da her açılışta çöktü: `RecorderInitializeFailedException: ... already inited? (on the C++ side)`. Kök neden: iki paket AYNI native miniaudio kütüphanesini sarıyor; ikisini birlikte, uygulama açılışında eagerly initialize etmek gerçek donanımda çakıştı (Windows'un WASAPI backend'i muhtemelen ayrı context'lere izin verirken, iOS'un tekil `AVAudioSession` modeli izin vermiyor). **Düzeltme:** `recorder.init()` genel `init()`'ten kaldırılıp `startRecording()`'in başına taşındı (lazy init) — Record modu zaten Premium-only olduğu için çoğu seans hiç recorder'a dokunmuyor. GENEL DERS (M4'ün kalibrasyon dersiyle aynı ailede): Windows'ta ne kadar kapsamlı test edilirse edilsin, gerçek cihazın platforma özgü kısıtları (burada: paylaşılan native kütüphane + tekil audio session) sadece cihazda ortaya çıkabilir.

### 9.2 M4 İmplementasyonu — Analiz ve Skorlama (2026-07-27)

**Onaylanan plan (uygulama öncesi):** eğitim-dostu skor bantları (Great ±40ms, Good ±80ms, Miss >150ms — araştırma: yarışmacı ritim oyunları ±15-50ms kullanıyor ama bu bir pratik aracı), minimal Results ekranı (tek genel skor, egzersiz-bazlı liste değil), kayıt başlangıcında "pedi cihaza yakın tut" uyarısı.

**Onset detection (`domain/analysis/onset_detector.dart`):** `fftea` paketiyle (pure-Dart FFT, STFT+Hanning window desteği var) spectral flux — ardışık STFT frame'leri arasındaki pozitif magnitude artışlarının toplamı — üzerinden adaptif eşikli peak-picking. Eşik = `max(yerel ortalama + 3×std, global_max × 0.15)` — sadece yerel istatistiğe dayanan eşik saf gürültü üzerinde bile "yerel ortalamaya göre yüksek" görünen sahte pikler üretiyordu (test verisiyle bulundu), global-max'a göre bir taban eklenince düzeldi. `WavAudio`/`wavToPcm16` (`wav_codec.dart`) — `pcm16ToWav`'ın tersi, native recorder'ın ürettiği WAV'ı chunk-tarayarak (sabit 44 byte header varsaymadan) çözüyor.

**Skorlama (`domain/analysis/timing_scorer.dart` + `expected_onsets.dart`):** `expectedOnsetSamples()` — bir exercise'ın her `isStruck` notasının beklenen örnek konumu — `SessionAudioRenderer`'ın referans-vuruş render mantığından çıkarılıp iki yerde de (render + skorlama) paylaşılan tek fonksiyon oldu (sıfır davranış değişikliği, testlerle doğrulandı). `TimingScorer` beklenen/algılanan vuruşları greedy en-yakın-eşleştirme ile eşleyip Great/Good/Miss dağılımı ve genel `grade` (0-100) üretiyor.

**KRİTİK KEŞİF — sabit cihaz kalibrasyonu güvenilmez çıktı:** İlk tasarım (onaylanmıştı): kullanıcı bir kez "Calibrate Microphone" akışından geçer (cihaz kendi tık sesini çalar+kaydeder, round-trip gecikmeyi ölçer), ölçülen ms drift'e kaydedilir, her Record seansında bu sabit değer kullanılır. Gerçek Windows testinde skor sürekli ~%0 çıktı. Kök neden analizi (gerçek kayıtları `dart run` ile doğrudan analiz ederek, sentetik test verisiyle DEĞİL) şunu gösterdi: 8 saniyelik kısa bir kalibrasyon tık dizisi (270-670ms arası farklı ölçümler verdi, ölçüm ölçüme tutarsız) ile gerçek ~38-50 saniyelik bir Record seansının gerektirdiği hizalama arasında büyük ve TUTARSIZ bir fark vardı — tam nedeni netleştirilemedi (muhtemelen kısa/uzun buffer yükleme farkı, WASAPI/debug build gecikmesi gibi Windows'a özgü bir etken), ama pratikte "bir kez ölç, hep kullan" yaklaşımı çalışmıyordu. Bir ipucu: manuel doğrulama sırasında da bir index-off-by-one hatası ("ilk nota algılanamadıysa tüm sonraki notalar bir kaydırılmış" gibi görünüyor) gerçek gecikmeyi yanlış hesaplattı — bu da "tek bir sabit sayıya güvenmenin" kırılganlığını gösterdi.

**Çözüm — self-calibrating skorlama (`domain/analysis/latency_search.dart`):** Kalibrasyondan TAMAMEN vazgeçildi. Bunun yerine `findBestLatencySamples()` — her kaydın kendi beklenen/algılanan vuruş desenine bakıp, adaylar arasında (0-2sn, 10ms adım) en çok notayı eşleştiren offset'i arıyor (greedy nearest-match, TimingScorer'ın kullandığı aynı kural). Gerçek bir kayıtla doğrulandı: manuel analizdeki hatalı ~900ms tahminine karşı, doğru arama ~160ms buldu ve **%96 skor** üretti. Kullanıcı onayıyla (2026-07-27): **CalibrationScreen, CalibrationService, `latency_measurement.dart`, drift'teki `CalibrationSettings` tablosu (schemaVersion 2→3 migration ile düşürüldü) tamamen silindi** — Record artık kalibrasyonsuz, doğrudan başlıyor. "Pedi cihaza yakın tut / mümkünse kulaklık kullan" uyarısı (metronom sesinin mikrofona sızıp analiz kirletmesini önlemek için) Practice ekranındaki "Before you record" diyalogunda kaldı.

**GENEL DERS:** Bir ölçüm/kalibrasyon mekanizması tasarlarken "tek seferlik, önceden ölç, hep güven" yaklaşımı çekici görünse de, ölçüm KOŞULLARI (kısa/temiz sinyal) ile GERÇEK KULLANIM KOŞULLARI (uzun, gürültülü, değişken) arasında sistematik bir fark varsa kırılgan olabilir. Mümkünse, her seansın kendi verisinden türetilen (self-calibrating) bir yaklaşım hem daha basit (ayrı bir kalibrasyon ekranı/akışı/DB tablosu gerektirmiyor) hem daha sağlam çıkabilir — bu turda tam olarak böyle oldu.

**Doğrulama:** `flutter analyze` temiz, 252 test yeşil. Windows'ta gerçek mikrofonla kullanıcı tarafından doğrulandı (kalibrasyonsuz Record → mantıklı skor).

### 9.3 Tempo Müfredatının Kaldırılması (2026-07-27)

M4 doğrulaması sırasında kullanıcı, Quarter-Note Pulse/Eighth Notes/Sixteenth Notes Level 1'lerindeki otomatik BPM rampasının (bkz. "Tempo Müfredatı" bölümü) diğer seviyeler gibi serbest BPM'e dönüştürülmesini istedi — üç skill'de de aynı mekanizma vardı, tutarlılık için üçü birden kaldırıldı. `Level.curriculumBpms` yerine opsiyonel `Level.note` (Session Preview'da küçük ipucu satırı) eklendi; üç etkilenen Level 1'e "BPM'i değiştirerek çalış, yavaş tempoları atlama" notu verildi — ramp'ın pedagojik amacı (yavaş tempoyu ihmal etmemek) böylece korunmuş oldu, sadece zorunlu olmaktan çıktı. `curriculum_policy.dart` ve testi silindi. 252 test yeşil (değişiklik öncesiyle aynı sayı — kaldırılan curriculumBpm testleri, eklenen `note` testleriyle yer değiştirdi).

## 10. Review Pool (M5)

- Otomatik; kullanıcı elle ekleyemez (spec §9). Girdi sinyalleri:
  - Analiz yapılmış seanslar: egzersiz zamanlama skoru eşik altı (tekrarlayan).
  - Analiz yok ise: **açık konu** — aday sinyaller: kullanıcının egzersizi içeren seansı tekrar tekrar çalması, gelecekte "zor geldi" işareti. v1'de yalnız analiz sinyaliyle başlamak muhtemelen doğru.
- Enjeksiyon: premium kullanıcının yeni session'ına havuzdan snapshot egzersizler karıştırılır (birebir replay).

## 11. Free / Premium Uygulaması

**GÜNCEL — 2026-07-27'de gerçek gating uygulandı** (bkz. §32 uygulama detayları). Aşağıdaki tablo eski bir plandı (asla kodlanmamıştı); gerçek uygulanan kurallar farklı çıktı, kullanıcıyla birlikte iteratif kararlaştırıldı:

| Yetki | Free | Premium |
|---|---|---|
| Ücretsiz skill'ler | İlk 3 (`quarter_note_pulse`, `quarter_note_rests`, `eighth_notes`) | Tümü (20 skill) |
| Günde yeni ders başlatma | 3 (takvim günü, cihaz saati) | sınırsız |
| Zaten bugün açılmış dersi tekrar açma | Sınırsız (limite saymaz) | Sınırsız |
| Başlangıç BPM'i | Sabit 60 (skill'in kendi `bpmDefault`'u değil) | Skill'in kendi `bpmDefault`'u |
| BPM değiştirme (canlı, +/-/Tap Tempo) | ✓ (kısıtlanmadı) | ✓ |
| Kayıt + analiz (M3/M4) | ✗ | ✓ |
| Review önerileri (M5, henüz yok) | ✗ | ✓ |
| Reklamlar (banner + interstitial) | ✓ (görür) | ✗ (hiç görmez) |
| Rewarded ad ile +1 bonus seans (günde 1 kez) | ✓ | — (gerekmez, sınır yok) |
| Loop (dersi otomatik tekrar başlatma) | ✗ | ✓ |

"Takvim günü" = cihaz yerel saati (`AppDatabase._todayKey()`, `'YYYY-MM-DD'` string — saat dilimi/DateTime karşılaştırma sorunlarını komple es geçiyor).

**Karar mantığı (kullanıcıyla, 2026-07-27):** Kullanıcı açıkça "ikisini de [günlük limit + skill kilidi]" istedi, sayıları kendisi verdi (günde 3 seans, ilk 3 skill). BPM'in 60'a sabitlenmesi de kullanıcı kararı — "tüm dersler 60 bpm'de açılsın, bpm değiştirme şansları olsun" (yani başlangıç kısıtlı, canlı kontrol serbest).

~~**Muafiyet (2026-07-20 karar):** Günde 1 yeni seans sınırı, tempo müfredatı olan seviyelere uygulanmaz.~~ **GEÇERSİZ** — hem tempo müfredatı mekanizması 2026-07-27'de tamamen kaldırıldı hem de günlük limit sonunda hiç istisnasız, sabit sayıyla (3) uygulandı.

---

## 12. Açık Konular (karar sırası geldiğinde kullanıcıyla)

1. ~~Analiz sonuç ekranı: hangi metrikler, nasıl görselleştirme?~~ **KAPANDI — bkz. §14** (2026-07-20 referans mockup).
2. Review Pool'a giriş kriteri — analizsiz kullanıcıda davranış. *(hâlâ açık)*
3. ~~Preview'ın tam davranışı~~ **KAPANDI** — Preview mockup'taki "Practice" ekranıyla aynı yapıyı kullanır: tam 16 ölçü, loop yok, bölüm seçimi yok.
4. Ses tasarımı: tık ve referans pad sesleri (sentez mi sample mı, hangi karakter). *(hâlâ açık — mockup ses karakterini göstermiyor)*
5. StoreKit doğrudan mı, RevenueCat mi; fiyatlandırma. *(hâlâ açık)*
6. ~~Storage teknolojisi~~ **KAPANDI — `drift` (SQLite)**, 2026-07-20.
7. ~~Uygulama adı~~ **KAPANDI — App Store'da "Stick Trainer"**, bundle id/proje adı `one_pad` kalıyor.
8. ~~Metronom-akort'taki ses çözümü vs `flutter_soloud`~~ **KAPANDI** — `flutter_soloud` ile devam; iPhone'da TestFlight testi başarılı (M2).

### Yeni açık konular (2026-07-20 tasarım turu sonrası)

9. Sound design'ın kendisi (tık/pad seslerinin gerçek karakteri) hâlâ yer tutucu — mockup bunu göstermiyor.
10. ~~"Go Premium" kartının gerçek paywall'a bağlanması M5'e kadar bekliyor~~ **KISMEN KAPANDI — 2026-07-27, bkz. §32.** Gerçek bir Premium ekranı (özellik listesi + fiyat) ve gating mantığı (günlük limit, skill kilidi) tamamen çalışıyor durumda — ama "satın alma" hâlâ gerçek değil, sadece dev-only local toggle. Kalan gerçek iş: StoreKit/RevenueCat entegrasyonu, Restore Purchases akışı, abonelik durumu/süre takibi (bkz. madde 12-13).
11. Bottom tab bar (Home/Lessons/Practice/Recordings/Profile) mockup'ta var ama Recordings ve Profile ekranları henüz yok — sahte navigasyon eklenmedi, M3'te Recordings gerçek ekran olunca birlikte tasarlanacak.

### Yeni açık konular (2026-07-27, premium ekranı sonrası)

12. ~~**Restore Purchases**~~ **KAPANDI — 2026-07-30.** `lib/infrastructure/iap/purchase_service.dart` (`PurchaseService`, `in_app_purchase` paketi) gerçek `restorePurchases()`'a bağlandı, Premium ekranında buton var. `premiumProductId` henüz App Store Connect'te yok (madde 15), o yüzden şimdilik hep "hiçbir şey bulunamadı" dönecek — ama kod/akış hazır, ürün oluşturulunca otomatik çalışacak. `in_app_purchase`'ın Windows implementasyonu yok; `main.dart` sadece iOS/Android'de dinlemeye başlıyor, Windows build'i bozmadığı doğrulandı.
13. **Abonelik durumu/süre takibi** — Şu anki `PremiumSettings.isPremium` kalıcı bir açık/kapalı bayrak (bkz. §32). Gerçek bir otomatik yenilenen abonelikte süre dolabilir/yenilenebilir/iptal edilebilir — `PurchaseService`'in purchase stream dinleyicisi `purchased`/`restored` durumunda `setPremium(true)` çağırıyor ama `expired`/iptal durumunu henüz `setPremium(false)`'a bağlamıyor (StoreKit bu durumları farklı bir sinyalle iletir, henüz işlenmedi). *(hâlâ kısmen açık)*
14. **Apple'ın zorunlu abonelik metni** — Otomatik yenilenen abonelikler için "Subscribe" butonunun yakınında fiyat/süre/otomatik yenileme uyarısı + Kullanım Şartları/Gizlilik Politikası linki gösterilmesi App Store kurallarının bir parçası; `premium_screen.dart`'a henüz eklenmedi.
15. Premium fiyatı $4.99/ay olarak UI'da sabit yazılı (`premium_screen.dart`) — gerçek App Store Connect ürün/fiyat tier kurulumu henüz yapılmadı (Apple Developer hesabı gerektiriyor, kod yazmakla bitmiyor). Kurulunca Apple, bu USD tier'ın her storefront'taki yerel para birimi karşılığını KENDİSİ hesaplayıp gösterir — uygulama tarafında döviz kuru kodu YAZILMAYACAK. `PurchaseService.premiumProductId` (`com.burakakkaya.onePad.premium_monthly`) ASC'de oluşturulacak gerçek ürün ID'siyle BİREBİR eşleşmeli.

### Yeni açık konular (2026-07-30, "hazır mıyız?" denetimi)

16. ~~**App icon hâlâ Flutter'ın varsayılan mavi logosu**~~ **KAPANDI — 2026-07-30.** Kullanıcı Gemini ile ikon konsepti üretti (davul + baget, "Sunset Coral" turuncusu); Gemini çıktısındaki sabit bir sparkle/yıldız artefaktı (her iki denemede de aynı köşede) renk-eşleştirmeli bir yama ile temizlendi, 1024×1024 master'dan tüm 15 iOS boyutu (`ios/Runner/Assets.xcassets/AppIcon.appiconset/`) üretildi. RGB, alfa kanalsız, tam kare — Apple'ın gereksinimleri karşılanıyor.
17. **Launch screen de muhtemelen varsayılan** (`ios/Runner/Assets.xcassets/LaunchImage.imageset/` — klasörde hâlâ Flutter'ın kendi `README.md`'si duruyor, hiç dokunulmamış izlenimi veriyor). Küçük bir kozmetik eksik, App Store'u engellemez ama ilk açılış hissini zayıflatır.
18. **`PrivacyInfo.xcprivacy` (gizlilik manifestosu) yok** — Apple, Mayıs 2024'ten beri belirli "required reason API"leri kullanan uygulamalardan bunu istiyor; mikrofon kullanan bu uygulama için gerekip gerekmediği netleştirilmeli (App Store Connect submission sırasında Apple'ın kendisi eksikse uyarıyor/reddediyor).
19. **App Store Connect metadata** (kod dışı, doğrudan kontrol edemediğim alan): ekran görüntüleri, açıklama metni, gizlilik politikası URL'si (mikrofon kaydı topladığı için muhtemelen ZORUNLU), App Privacy veri toplama beyanı, yaş derecelendirmesi — hiçbiri bu oturumda kontrol edilmedi, App Store Connect'te elle doğrulanmalı.

### Yeni açık konular (2026-07-30, reklam entegrasyonu sonrası)

20. ~~**RevenueCat gerekli mi?**~~ **KAPANDI (karar: hayır).** Tek platform (iOS) + `PurchaseService`'in kendi receipt/restore mantığı zaten yazılı olduğu için RevenueCat'in kazandıracağı şey (çapraz platform entitlement + üçüncü taraf servis bağımlılığı) şu an gerekmiyor. Aylık/yıllık ikinci bir ürün eklemek gerçek StoreKit ile de mümkün: ASC'de aynı subscription group'a ikinci ürün + `PurchaseService`'e ikinci bir product ID yeterli.
21. **Gerçek AdMob hesabı/ID'leri yok.** `AdsService`, `ios/Runner/Info.plist`'teki `GADApplicationIdentifier` ve tüm ad unit ID'leri şu an Google'ın herkese açık *test* ID'leri (§33) — her zaman dolar, hiç gerçek gelir üretmez. Gerçek AdMob hesabı açılıp gerçek ID'lerle değiştirilmeden App Store'a gitmemeli.
22. **Reklam sıklığı/UX ince ayarı henüz test edilmedi** — özellikle interstitial'ın her seans sonunda (günde en fazla 3-4 kez, free cap nedeniyle) gösterilmesinin rahatsız edici olup olmadığı gerçek kullanımda değerlendirilmeli; gerekirse sıklık sınırlandırılabilir (örn. 2 seansta 1).

---

## 14. Görsel Kimlik (2026-07-20 karar)

Kullanıcının sağladığı referans mockup (8 ekranlık tam akış: Home, Practice, Preparing to Record, Recording, Analyzing, Results, Detailed Analysis, Playback, Recordings Library) görsel dilin ve M3-M5 ekranlarının **resmi referansı** olarak kilitlendi. Kilitlenen, mockup'ın *estetik dili ve yapısı*dır — spesifik ders isimleri/ritim içeriği değil (mockup'taki "Quarter Note Rests", "Eighth Notes Intro" gibi ders adları jenerik örnektir; bizim içerik hâlâ §5'teki sticking müfredatını kullanır).

### Mood

Sıcak/organik (vintage davul pratik odası hissi) + ciddi/profesyonel (temiz kart yapısı, düzenli istatistikler) melezi. Aşırı oyunlaştırılmış değil, aşırı steril de değil.

### Renk Paleti

**"Sunset Coral" — 2026-07-27, orijinal krem/mavi paletin YERİNE geçti.** Kullanıcı "ui rengimiz krem rengi gibi bi renk, daha canlı/enerjik bir renk olsun" dedi; 4 aday (Sunset Coral, Electric Mint, Vivid Sky, Punchy Sunshine) mockup olarak gösterildi, Sunset Coral seçildi. `AppColors` (`lib/presentation/theme/app_theme.dart`) — tam liste:

| Rol | Ton (hex) | Kullanım |
|---|---|---|
| Arka plan | `#FFE8D6` (canlı şeftali) | Ekran zemini |
| Surface (kart) | `#FFF6EE` (neredeyse beyaz, sıcak) | Kartlar, ders satırları |
| Ana aksiyon | `#E8542A` (canlı mercan-turuncu) | Start butonu, aktif seçim çerçevesi |
| İkincil/premium | `#F2A93B` (amber) | Premium rozeti, "Mastered" rozet rengi |
| Başarı | `#3E8E52` (yeşil, değişmedi) | — |
| Hata/uyarı | `#C62828` (kırmızı, mercan ile karışmasın diye ayarlandı) | — |
| Metin (birincil) | `#3A2216` (sıcak koyu kahve) | Pure black değil |
| Metin (ikincil) | `#8A6A57` | Alt başlıklar, meta bilgi |

**Rozet (tier) renkleri (2026-07-27, §32):** Bronz `#B87A4A`, Gümüş `#9BA3AA`, Altın = ikincil renk (amber, ayrı bir sıcak ton eklememek için), Platin `#7FA6A3`, Diamond `#3FA9CC`.

**Arka plan görseli (2026-07-27):** Home, Session Preview ve Results ekranlarının arkasında gerçek bir practice pad fotoğrafı var (`assets/images/drum_pad_bg.jpg` — Pexels, ücretsiz lisans, marka logosu kırpılarak temizlendi), üstte içerikle karışmaması için krem tona doğru bir gradient fade var (`lib/presentation/widgets/drum_head_background.dart`). Notasyon (Session Preview) fotoğrafın üstünde okunaklı kalması için ayrı bir opak "sayfa" kartı içinde render ediliyor. Practice ekranı BİLİNÇLİ OLARAK bu arka planı almıyor — aktif çalışma sırasında görsel gürültü istenmedi.

### Tipografi

Sade sistem fontu (SF Pro / Roboto). Başlıklar kalın, gövde metni normal ağırlık. Karakter renk + ikonografiden geliyor, fonttan değil.

### İkonografi

Çapraz davul çubuğu motifi ana marka sembolü (bottom nav'ın merkez ikonu, "Practice" eylemi). "Stick Trainer" ismiyle birebir örtüşüyor.

### Home Ekranı — Yeni Yapı (mockup'tan uyarlanmış)

```
[Tagline header: "Let's make some rhythms."]
[Today's Session kartı: aktif skill/level özeti + Start butonu]
[Lessons listesi: skill.levels üzerinden, her satırda
   ikon + isim + meta (time signature) + ilerleme yüzdesi + chevron]
[Go Premium kartı: kilitli, M5'e kadar pasif]
```

Bottom tab bar **eklenmedi** (açık konu #11) — Recordings/Profile ekranları henüz yok.

### İlerleme Göstergesi (Home'daki Lessons listesi)

**DEĞİŞTİ — 2026-07-27, bkz. §32.** M4 (gerçek analiz skoru) gelene kadar kullanılan `min(1.0, tamamlanan_seans_sayısı / 5)` yüzdesi kaldırıldı — kullanıcı bunun "uygun olmadığını" belirtti, çünkü ölçmediği bir hassasiyeti (doğruluk) iddia ediyordu; gerçekte sadece tekrar sayısını ölçüyordu. Yerine **tekrar-sayısı kademe (tier) rozeti** geldi (`domain/progress/progress_policy.dart`, `ProgressTier` enum): Practicing (1-5) → Solid (6-15) → Mastered (16-30) → Virtuoso (31-50) → Legend (51+). Kayıt yapılmış (Premium) seviyelerde ayrıca gerçek M4 skoru ("En iyi skor: %X") ayrı bir metin olarak gösterilecek (henüz uygulanmadı) — rozet ve skor birbirine KARIŞTIRILMAYACAK, biri tekrarı biri doğruluğu anlatıyor.

### Yeni Özellik: Tap Tempo

Mockup'ta BPM'i çubukla vurarak ayarlayan "TAP TEMPO" kontrolü var; spec'e eklendi. Preview ekranında `[<] ♩=NN [>] [TAP TEMPO]` düzeni; tap aralıklarından BPM hesaplanır (saf Dart, `TapTempoCalculator`), skill'in bpm aralığına clamp edilir.

### Storage

`drift` (SQLite). `PracticeSessions` tablosu: id, skillId, level, bpm, completedAt. İlerleme yüzdesi ve (ileride) Review Pool sorguları bu katmanın üzerine kurulur.

---

## 15. Müfredat Haritası (2026-07-20 karar)

Duolingo tarzı bir paketleme bu uygulamaya uymuyor — fiziksel/motor beceri inşası dil öğreniminden farklı pedagoji gerektiriyor. Önce **ne öğretileceğine** (skill sırası), sonra **nasıl sunulacağına** (paketleme, unlock mantığı, ekran akışı) karar veriliyor.

**Paketleme, ilk adım (2026-07-20):** Home ekranı artık tüm 12 skill'i bir yol haritası olarak gösteriyor (§14) — içeriği hazır olanlar tıklanabilir/seviyeli, geri kalanı kilitli "Coming soon". İnce ayar (unlock mantığı, sıralı zorunluluk vb.) hâlâ açık konu.

Müfredat dört bağımsız eksenin kesişiminden oluşuyor: **nota/ritim sözlüğü** (dörtlük→sus→sekizlik→onaltılık→senkop), **sticking kontrolü** (Skill 1'in ürettiği ilerleme, diğer skill'lere de uygulanabilir bir şablon), **ölçü türü** (4/4→3/4,6/8→5/4,7/8), **tempo** (skill'e özel müfredat rampası, opsiyonel).

Planlanan skill sırası:

**BPM tavanı — 2026-07-30 karar:** Bu bölümdeki (ve §16-29'daki) her skill'in `bpmRange` üst sınırı, o skill'in yazıldığı tarihte yoğunluğa göre ayrı ayrı belirlenmişti (ör. Quarter-Note Pulse 180, Sixteenth Notes 100, 32nd Notes 50). Uygulamayı finalize ederken kullanıcı **tüm skill'lerin üst sınırının, yoğunluğa bakılmaksızın düz 240'a çıkarılmasını** istedi (alt sınır ve `bpmDefault` değişmedi). Aşağıdaki ve §16-29'daki metinlerde geçen eski üst sınır sayıları (140, 100, 80, 50 vb.) artık GEÇERSİZ — gerçek değer her skill için 240'tır; metinler o kararın ARKASINDAKİ pedagojik gerekçeyi (o skill'in bpmDefault'unun neden o sayı olduğunu) hâlâ doğru anlatıyor, sadece üst sınır sayısı değişti. `content/skills/*.json` + `tool/generate_*.dart` (+ Performance Areas'ın 4 kümesi, hepsi artık `[30, 240]`) güncellendi, 295 test yeşil.

1. **Quarter-Note Pulse** *(tamamlandı, Home'a bağlı)* — 4/4, dörtlük, sticking (bpmRange 30-240; sabit ramp yerine serbest BPM + pratik notu, 2026-07-27)
2. **Quarter Note Rests** *(tamamlandı, Home'a bağlı, §16)* — nabzı korurken sus yerleştirme
3. **Eighth Notes** *(tamamlandı, Home'a bağlı, §17)* — alt bölüm (subdivision) kavramı, yoğunluk ekseni + tam akış sticking alt-müfredatı
4. **Eighth Notes + Rests** *(tamamlandı, Home'a bağlı, §18)* — offbeat/senkoplu "and" vuruşu
5. **Dotted Quarter + Eighth** *(tamamlandı, Home'a bağlı, §19)* — noktalı dörtlük + sekizlik ritmi (eski adı "Quarter & Eighth Combinations"tı, araştırma sonrası değiştirildi)
6. **Rudiments (Eighth Notes)** *(tamamlandı, Home'a bağlı, §20)* — Single Paradiddle, aksan notasyonu ile
7. **Sixteenth Notes** *(tamamlandı, Home'a bağlı, §21)* — tam grup, kırık-sekizlik kombinasyonları, sus, tam akış sticking alt-müfredatı (noktalı sekizlik+onaltılık ileriye bırakıldı)
8. **Rudiments (Sixteenth Notes)** *(tamamlandı, Home'a bağlı, §22)* — Single Paradiddle (16'lık hız) + Triple Paradiddle (Double Paradiddle/Paradiddle-Diddle 6/8'e ertelendi)
9. **Syncopation / Ties** *(tamamlandı, Home'a bağlı, §24)* — sekizlik+noktalı dörtlük (Skill5'ten ertelenen ters sıra), klasik sekizlik-dörtlük-sekizlik figürü, ve gerçek bir bağ (tie) örneği
10. **Alternate Meters** *(tamamlandı, Home'a bağlı, §25)* — 3/4 (basit üçlü) ve 6/8 (bileşik ikili, + Double Paradiddle ve Single Paradiddle-Diddle capstone'ları, §28) iki AYRI Skill/roadmap satırı olarak (`Skill.timeSignature` skill başına tek değer, seviye başına değil)
11. **Odd Meters** *(tamamlandı, Home'a bağlı, §26)* — 5/4 (basit, tek sayı) ve 7/8 (asimetrik, "2+2+3") iki AYRI Skill/roadmap satırı olarak
12. **Triplets** *(tamamlandı, Home'a bağlı, §27 — 2026-07-21'de gap-analysis sonrası roadmap'e EKLENDİ, orijinal 12 maddelik listede yoktu)* — sekizlik ve dörtlük üçleme, "3'e 2" hissi
13. **Rudiments: Roll Family** *(tamamlandı, Home'a bağlı, §28 — kullanıcının "daha komplike rudimentler yok mu?" sorusuyla eklendi)* — 5/7/9-Stroke Roll
14. **Performance Areas** *(tamamlandı, Home'a bağlı, §29)* — TEK bir madde değil, 4 AYRI küme/roadmap satırı: Foundations, Syncopated Feel, Fast Subdivision, Rudiment Workout (yukarıdaki 4/4 skill'lerinin şablon havuzlarının tematik birleşimi; 3/4/6/8/5/4/7/8 skill'leri farklı ölçü oldukları için hiçbirine dahil değil)

**2026-07-27 sonradan eklenenler (§30-§31, roadmap 20 maddeye çıktı):**
- **Sextuplet** (16'lık üçleme) — Triplets skill'ine Level 3 olarak eklendi, yeni roadmap maddesi değil.
- **Double Stroke Roll** — Roll Family skill'ine Level 1 olarak eklendi (5/7/9-Stroke'tan önce), yeni roadmap maddesi değil.
- **Duplet** (6/8'de 2-in-3) — Alternate Meters: 6/8 skill'ine Level 5 olarak eklendi, yeni roadmap maddesi değil.
- **32nd Notes** *(§30)* — TEK BAŞINA yeni bir roadmap maddesi (Rudiments (Sixteenth Notes)'tan sonra, Syncopation/Ties'tan önce) — `NoteDuration.thirtySecond` + 3. seviye kiriş render'ı gerektirdi.
- **"How to Count" dersleri** *(§31)* — yeni roadmap maddesi DEĞİL; 6 mevcut skill'in (Eighth Notes, Sixteenth Notes, Quarter Note Rests, Alternate Meters 6/8, Odd Meters 7/8, Triplets) her birine Level 0 olarak eklenen okuma-tanıtım dersleri.

## 16. Skill 2: Quarter Note Rests (2026-07-20 karar)

**Sticking modeli — "hayalet vuruş":** Alternasyon (R L R L) susların altında da kesintisiz sürer; sus, sıradaki eli "yer" ama çalınmaz. Görünürde çalınan notalar bazen aynı el art arda gelir (ör. R _ R L → görünen sticking R,R,L) — bu, gerçek davul tekniğine sadık kalmak için bilinçli bir sonuç, hata değil.

**Level ekseni — sus sayısı ve bitişikliği (Skill 1'in "seviye = kombinasyon kategorisi" mantığıyla tutarlı):**

| Level | İçerik | Şablon sayısı |
|---|---|---|
| 1 | 1 sus, 3 vuruş — 4 pozisyon × 2 taban (R-başlangıç/L-başlangıç) | 8 |
| 2 | 2 bitişik olmayan sus, 2 vuruş | 6 |
| 3 | 2 bitişik (ard arda) sus, 2 vuruş | 6 |
| 4 | 3 sus, tek vuruş — ölçüde tek bir nota | 8 |

**Tempo:** Özel müfredat yok — nabız inşası Skill 1'in işiydi. `bpmDefault: 80`, `bpmRange: [30, 180]` (Skill 1 ile tutarlı).

**Kapsam notu:** İçerik, testler ve Home bağlantısı tamamlandı.

---

## 17. Skill 3: Eighth Notes (2026-07-20 karar)

İlk kez **alt bölüm (subdivision)** kavramı giriyor — bir vuruşun içinde iki nota olabiliyor. Araştırma bulguları ve kararlar:

**Sticking modeli — DÜZELTME (2026-07-20, ikinci geçiş).** İlk taslak, susların "hayalet vuruş" modelini (Skill 2, §16) 8'lik ızgaraya taşıyıp dörtlük vuruşları da "yarısı hayalet" olarak ele almıştı — bu, düz dörtlüklerin **her zaman aynı eli** kullanmasına ve bazı pozisyonlarda **4 kez art arda aynı el** gibi yapay sonuçlara yol açtı. Kullanıcı bunun pedagojik gerekliliğini sorguladı; gerçek kaynaklarla (Alfred's Drum Method, Drumeo) karşılaştırınca model **yanlış** çıktı: **bir sus** gerçekten sessiz bir slot'tur (hayaletlenmesi mantıklı), ama **bölünmemiş bir dörtlük nota** hiç "ikinci slot"a sahip değildir — o slot yok, hayaletlenecek bir şey yok. Düzeltme: **Level 1-4 (yoğunluk seviyeleri) artık basit ardışık alternasyon kullanıyor** — çalınan her nota, sırasız/ızgarasız, bir öncekinin zıt eli. Sonuç: pozisyon ne olursa olsun sticking her zaman temiz alternasyon (R,L,R,L,R gibi), zorluk farkı yalnızca *ritmik* (alt bölümün nerede olduğu) — ki bu tam olarak Ted Reed'in *Syncopation* metodolojisiyle örtüşen, gerçek kaynaklarda doğrulanan yaklaşım. Level 5-7 (tam akış, hiç dörtlük içermiyor) bu değişiklikten etkilenmedi.

**Level ekseni:**

| Level | İçerik | Şablon |
|---|---|---|
| 1 | 1 sekizlik çift, 3 dörtlük — 4 pozisyon × 2 el | 8 |
| 2 | 2 sekizlik çift, **bitişik değil** | 6 |
| 3 | 2 sekizlik çift, **bitişik** (4 ardışık sekizlik, daha zor) | 6 |
| 4 | 3 sekizlik çift, 1 dörtlük | 8 |
| 5 | Tam akış: Steady Alternation (single stroke roll temeli) | 2 |
| 6 | Tam akış: Lead-Hand Switching | 2 |
| 7 | Tam akış: Doubles (RRLLRRLL vb., 4-notalık doubles'ın 2 katı) | 4 |

Level 5-7, Skill 1'in ilk 3 sticking seviyesini (alternasyon→öncü el→çiftlemeler) tam sekizlik akışında **tekrar** uyguluyor — tekrar değil, gerçek bir teknik sıçrama (el hızı/çeviklik iki katına çıkıyor). Drumeo'nun kendi müfredatıyla (steady eighth-note patterns → doubles/rudimentlere giriş) birebir örtüşüyor.

**`sessionFixed` üretim modu (2026-07-20 eklendi):** Level 5 ve Level 6 aynı 2 şablonu (tam RLRLRLRL / LRLRLRLR) kullanıyor; tek fark `noAdjacentRepeat` bayrağıydı. Sorun: sadece 2 şablonluk bir havuzda "serbest seçim" zaten ~yarı yarıya kendiliğinden değişiyor, yani kısıtlı/kısıtsız hal pratikte neredeyse ayırt edilemiyordu (kullanıcı bunu fark etti: "sessionlar çok birbirine benziyo"). Çözüm: `GenerationSpec`'e `sessionFixed: bool` eklendi — true olduğunda `SessionGenerator` havuzdan **seans başına bir kez** şablon seçip 16 egzersizin tamamına aynısını uyguluyor (seanslar arası hâlâ değişken, ama seans içinde sabit). Level 5 artık gerçekten "seans boyunca tek öncü el" demek, Level 6'dan (her ölçüde zorunlu değişim) bariz farklı hissettiriyor. `noAdjacentRepeat` ile birlikte anlamlı değil (aynı şablonun tekrarı zaten "bitişik tekrar" sayılır) — `sessionFixed` true olduğunda bu kısıt kontrolü atlanıyor.

**Level 8 KALDIRILDI (2026-07-20).** İlk taslakta "Free Sticking Reading" adında, Skill 1'in Level 4'ünden (serbest sticking okuma) doğrudan pattern-match edilerek türetilmiş, 8-slot uzayında küratörlü 12 rastgele-kombinasyon şablonu vardı. Kullanıcının isteğiyle gerçek kaynaklar araştırıldı (Alfred's Drum Method, Drumeo): **hiçbiri** sekizlik nota tanıtımı aşamasında rastgele/serbest el kombinasyonu öğretmiyor — katı alternasyon, sonra doubles, sonra **isimlendirilmiş** rudiment'lere (paradiddle ailesi) geçiliyor. "Serbest okuma", Skill 1'de (sadece dörtlük, tek zorluk ekseni sticking) savunulabilirdi; burada (zaten yeni bir ritmik kavram + rastgele sticking üst üste) karşılığı yok. Skill 3 artık Level 7'de doğal ve sağlam bir noktada bitiyor; serbest okuma ve rudiment'ler planlanan ayrı "Rudiments" skill'ine (§15, madde 6) ait.

**Tempo — sadece Level 1'de bir pratik notu.** Gerekçe: aynı BPM'de sekizlik çalmak dörtlüğün iki katı el hızı ister (Skill 1'in 180 BPM'lik dörtlük sonu, sekizlikte ~90 BPM'e karşılık gelir). Önceden 30→100 BPM/8 adımlık sabit bir ramp vardı, 2026-07-27'de kaldırıldı — artık diğer seviyeler gibi serbest BPM, sadece Level 1'e "BPM'i değiştirerek çalış" notu eklendi. `bpmDefault: 60`, `bpmRange: [30, 140]`.

**Kiriş (beam) render'ı:** Bravura'nın bayraklı birleşik sekizlik glifi (`note8thUp`) yerine, aynı vuruştaki sekizlik çiftler için notehead-only glif (`noteheadBlack`) + elle çizilmiş sap + iki sap ucunu birleştiren dikdörtgen kiriş kullanılıyor (standart notasyon kuralı: kiriş vuruş sınırını aşmaz). `NotationLayout.notesOf()` her notaya `beamed` + `beamGroupEnd` bilgisini ekliyor; painter, `beamGroupEnd` görene kadar biriktirip **tek bir kiriş** çiziyor.

*(2026-07-20 güncelleme, §20 ile birlikte: gruplama artık sabit "ikişer" değil — bir kiriş serisi (run) aksanlı bir nota içeriyorsa grup genişliği yarım ölçüye (4 nota) çıkıyor, bu skill'de hâlâ değişmiyor; ayrıntı ve gerekçe §20'de.)*

**Kapsam notu:** İçerik (`content/skills/eighth_notes.json`, üretici script `tool/generate_eighth_notes_content.dart`), testler ve Home bağlantısı tamamlandı.

---

## 18. Skill 4: Eighth Notes + Rests / "Offbeat Eighth Notes" (2026-07-20 karar)

**Araştırma bulgusu (Vic Firth WebRhythms Lesson 03A):** Sekizlik sus, gerçek metotlarda dörtlüklerle değil, **zaten bilinen sekizlik çiftin bir dönüşümü** olarak tanıtılıyor: "besteci 've'de çalınsın ama sayıda çalınmasın istiyorsa, çiftteki ilk sekizliği atıp yerine sus koyar." Bu, `sus+nota` sırasının (offbeat/senkoplu "and" vuruşu — funk/jazz'ın temeli) `nota+sus` sırasından **pedagojik olarak** farklı ve önemli olduğunu gösteriyor.

**Bilinçli dışlama:** "sekizlik + sekizlik sus" (nota önce, sus sonra) sesli olarak **bölünmemiş bir dörtlük notayla birebir aynı** (tek vuruş, ardından sessizlik) — ayrı bir egzersiz olarak öğretmenin ritmik değeri yok, sadece notasyon okuma çeldiricisi olurdu. İçerikte yok.

**Level ekseni — Skill 2/3'ün pozisyon-permütasyon yöntemiyle tutarlı, arka plan sekizlik çift (E), yeni eleman offbeat (O = sus-sekizlik + sekizlik):**

| Level | İçerik | Şablon |
|---|---|---|
| 1 | 1 vuruş offbeat, 3 vuruş sekizlik çift | 8 |
| 2 | 2 vuruş offbeat (tüm pozisyonlar) | 12 |
| 3 | 3 vuruş offbeat | 8 |
| 4 | 4 vuruş offbeat ("and" sayımı) — `sessionFixed: true` | 2 |

**Bitişiklik ekseni KALDIRILDI (2026-07-20, kullanıcı testte fark edemedi).** İlk taslakta Level 2/3, Skill 2/3'teki gibi "bitişik olmayan / bitişik" diye ikiye bölünmüştü. Ama bu eksen buraya taşınmıyor: bir sus ya da sekizlik-çift vuruşu **tam** dolu olduğu için bitişik ikisi gerçekten daha uzun bir kesintisiz blok oluşturuyordu (Skill 2: 2 vuruşluk sessizlik; Skill 3: 4 ardışık sekizlik). Offbeat vuruş ise her zaman "yarı sus, yarı vuruş" — iki offbeat bitişik olsa bile aralarında hep bir vuruş kalıyor, kesintisiz blok oluşmuyor. 8-slotluk sayımda kontrol edildi: Spread (poz. 2&4) → `X X . X X X . X`, Consecutive (poz. 1&2) → `. X . X X X X X` — ikisi de 6 vuruş/2 sus, sadece kaymış. Level 2/3 tek levelde birleştirildi (6 pozisyon × 2 el = 12 şablon).

Sticking: Skill 3'ün düzeltilmiş modeliyle aynı — basit ardışık alternasyon, özel bir ızgara mantığı yok. Tempo müfredatı yok (yeni zorluk el hızı değil, algısal/zamanlama — offbeat'i önceden bir vuruş olmadan doğru yakalamak); `bpmDefault: 70`, `bpmRange: [30, 140]`.

**Notasyon:** Offbeat notasının sus ortağı `NotationLayout.notesOf()` tarafından zaten filtrelendiği için (rests ayrı işleniyor), kiriş eşleştirme mantığı ek değişiklik gerektirmeden offbeat notasını doğru şekilde **tek bayraklı, kirişsiz** çiziyor (test edildi).

**Kapsam notu:** İçerik (`content/skills/offbeat_eighth_notes.json`, üretici script `tool/generate_offbeat_eighths_content.dart`, roadmap başlığı "Eighth Notes + Rests"), testler ve Home bağlantısı tamamlandı.

---

## 19. Skill 5: Dotted Quarter + Eighth (2026-07-20 karar)

**"Quarter & Eighth Combinations" planı araştırma sonrası terk edildi.** §15'te planlanan bir sonraki adım orijinal olarak "dörtlük ve sekizlik notaların kombinasyonu" idi. Alfred's Drum Method'un ders sırası incelendiğinde (Lesson 6, sekizlik nota+sus derslerinden hemen sonra) böyle ayrı bir "kombinasyon" dersi **yok** — çünkü bu zaten Skill 3'ün yoğunluk seviyeleri (Level 1-4: dörtlük arka planına sekizlik çift ekleme) tarafından tam olarak kapsanmış durumda; ayrı bir skill olarak tekrarı redundant olurdu. Gerçek metotlarda bir sonraki adım **noktalı dörtlük + sekizlik** ritmidir — birden fazla kaynakta (Alfred's, genel öğretim materyalleri) başlangıç seviyesi öğrenciler için **en zor ritimlerden biri** olarak belirtiliyor: ilk nota, beat 1'in "and"ından beat 2'ye kadar (1.5 vuruş) hiç kesilmeden tutuluyor — Skill 1-4'teki hiçbir boşluktan daha uzun bir "sessiz bekleme" süresi.

**Yapı bloğu — ölçü YARISI, tek vuruş değil.** Noktalı dörtlük+sekizlik çifti (D) tam olarak 2 vuruş = 4/4 ölçünün yarısı kaplıyor, bu yüzden Skill 2-4'teki "vuruş" ekseni yerine burada doğal birim **ölçü yarısı**. Her yarı üç şeyden biri:

- **Q** = iki düz dörtlük (en basit arka plan)
- **E** = dört sekizlik (Skill 3 territory, daha yoğun arka plan)
- **D** = noktalı dörtlük + sekizlik (yeni eleman)

**Level ekseni:**

| Level | İçerik | Şablon |
|---|---|---|
| 1 | Noktalı dörtlük vs. düz dörtlükler (D+Q, Q+D) | 4 |
| 2 | Noktalı dörtlük vs. sekizlikler (D+E, E+D) | 4 |
| 3 | Ölçünün tamamı noktalı dörtlük (D+D) — `sessionFixed: true` | 2 |

Level 1→2 geçişi zorluğu artırıyor çünkü arka plan yoğunlaştıkça (Q→E) noktalı notanın 1.5 vuruşluk tutuşunu sekizliklerin sabit nabzına karşı hissetmek zorlaşıyor. Level 3, Skill 3 Level 5/6 ile aynı gerekçeyle (§17) `sessionFixed: true` — sadece 2 şablon olduğu için sabitlenmezse seanslar ayırt edilemez olurdu.

Sticking: Skill 3/4'ün düzeltilmiş modeliyle aynı — basit ardışık alternasyon, özel ızgara yok. Tempo müfredatı yok (Skill 1'in işiydi); `bpmDefault: 60`, `bpmRange: [30, 140]` (Skill 3 ile tutarlı, çünkü noktalı ritmi doğru hissetmek de dörtlüğe göre daha yavaş başlamayı gerektiriyor).

**Notasyon render'ı — noktalı nota eksikliği fark edildi ve giderildi.** Skill 5 içerik olarak ilk kez `isDotted: true` bir nota üretiyor, ama painter'da noktalı notalar için hiç render mantığı yoktu (`NotePlacement` bu bilgiyi hiç taşımıyordu). Eklendi: `NotationLayout.notesOf()` artık `NotePlacement.isDotted`'i `NoteToken.isDotted`'dan taşıyor; `NotationPainter` her nota gliflinden sonra Bravura'nın `augmentationDot` glifini (U+E1E7) notanın sağına, notanın gerçek çizilen genişliğine göre konumlandırarak çiziyor (hem düz notalar hem kirişli notalar için — genişlik `_paintGlyph`/`_paintBeamedNotehead`'in dönüş değerinden alınıyor).

**Kapsam notu:** İçerik (`content/skills/dotted_quarter_eighth.json`, üretici script `tool/generate_dotted_quarter_eighth_content.dart`, roadmap başlığı "Dotted Quarter + Eighth"), testler (`test/domain/dotted_quarter_eighth_content_test.dart`, `test/presentation/notation_layout_test.dart`'a noktalı nota testi eklendi) ve Home bağlantısı tamamlandı.

---

## 20. Skill 6: Rudiments (Eighth Notes) — Single Paradiddle (2026-07-20 karar)

**Araştırma bulguları:**
- Paradiddle ailesi gerçek kaynaklarda (Alfred's Drum Method, Drumeo, Vic Firth, PAS 40 Essential Rudiments) önce **sekizlik nota hızında** pratik edilip sonra geleneksel onaltılık hıza geçiliyor — roadmap'teki sıralamayı (bu skill, "Sixteenth Notes"den önce) doğruluyor.
- Single Paradiddle (RLRR LRLL), Skill 3 Level 7 "Doubles"tan (RRLLRRLL, saf double) **gerçekten farklı** bir sticking şekli — "single-single-double" kombinasyonu daha önce hiç öğretilmedi.
- Birden fazla kaynak, her 4'lü grubun ilk notasındaki **aksanın** paradiddle'ın tanımlayıcı özelliği olduğunu vurguluyor ("a paradiddle with no accents sounds like a mush of even notes") — bu yüzden aksan notasyonu bu skill'le birlikte eklendi (kullanıcı kararı, aşağıda).

**Mimari kısıt bulundu (2026-07-20, sonradan giderildi — bkz. §23):** `ExerciseTemplate.validateAgainst` o sırada her template'in tam olarak **tek ölçü** olmasını zorunlu kılıyordu (toplam süre == `timeSignature.beats`). Bu yüzden Triple Paradiddle (16 vuruş = 2 ölçü) o mimariye **sığmıyordu** — ilk taslakta Level 3 olarak önerilmişti, bu kısıt fark edilince değiştirildi. **2026-07-21 güncellemesi:** çok-ölçülü template desteği eklenince (§23) Triple Paradiddle Level 4 olarak geri eklendi (aşağıda).

**Level ekseni:**

| Level | İçerik | Şablon |
|---|---|---|
| 1 | Single Paradiddle, sabit öncü el (`sessionFixed`) | 2 |
| 2 | Single Paradiddle, öncü el her ölçüde değişiyor | 2 |
| 3 | Paradiddle grubu + düz alternasyon grubu karışımı (ölçü yarısı, P+A / A+P sırası) | 4 |
| 4 | Triple Paradiddle (2 ölçü, `sessionFixed`) — §23'ün çok-ölçülü mimarisiyle 2026-07-21'de eklendi | 2 |

Level 3, Skill 5'in "ölçü yarısı" yöntemini (§19) tekrar kullanıyor: yarım ölçü paradiddle grubu (R L R R, aksanlı), yarım ölçü düz alternasyon (R L R L, aksansız) — öğrenci paradiddle şeklini düz bir akış içinde tanıyıp aksanı doğru yerde koruyor. Sticking, hand pointer'ın gruplar arasında sürekli akmasıyla üretiliyor (`buildFromGroups`, `tool/generate_paradiddle_content.dart`) — paradiddle grubunun son notası (double'ın ikinci vuruşu) neresi biterse bir sonraki grup oradan doğal alternasyonla devam ediyor.

**Aksan kararı (kullanıcıya soruldu):** Kullanıcı, sadece sticking öğretmek yerine gerçek aksan notasyonunu şimdi eklemeyi tercih etti ("Şimdi aksan notasyonu ekle"). Uygulandı:
- `NoteToken`'a `isAccented` alanı eklendi; string kodlamada `>` son eki (`.`dan sonra, varsa) — ör. `"e>"` = aksanlı sekizlik.
- `NotationLayout.notesOf()` → `NotePlacement.isAccented`.
- `NotationPainter`, aksanlı her notanın üstüne Bravura `articAccentAbove` glifini (U+E4A0) çiziyor.

**Kiriş gruplama DÜZELTMESİ (2026-07-20, kullanıcı Windows'ta test ederken fark etti).** İlk implementasyon, §17'nin "her vuruşta bir kiriş" kuralını olduğu gibi miras almıştı — bu yüzden paradiddle (RLRR LRLL) 4 ayrı kiriş (ikişerli) olarak çiziliyordu. Kullanıcı gerçek bir rudiment notasyon örneği paylaşıp "bu 8'lik notaları neden böyle yazmıyoruz" diye sordu; araştırma (drumscore.com'un "The Standard Paradiddle In Groups Of Four" dersi, PAS resmi rudiment dokümanları) doğruladı: rudiment notasyonunda kiriş, vuruşu değil **ritmik grubun kendisini** (paradiddle'ın 4 notası = yarım ölçü) takip eder — bu, sıradan sekizlik akışlar için "vuruş başına kiriş" kuralının kasıtlı bir istisnası. Düzeltme: `NotationLayout.notesOf()`'taki kiriş algoritması genelleştirildi — art arda gelen sekizlik notalardan oluşan bir "run" aksanlı bir nota içeriyorsa grup genişliği 1 vuruştan 2 vuruşa (yarım ölçü, 4 nota) çıkıyor; aksansız içerikte (Skill 3/4) davranış birebir aynı kalıyor (regresyon testiyle doğrulandı — `test/presentation/notation_layout_test.dart`). Painter da tek-kiriş-çizme mantığına geçirildi (`beamGroupEnd` alanı, ikili sabit pencere yerine).

Tempo müfredatı yok (yeni zorluk hız değil, sticking şekli); `bpmDefault: 60`, `bpmRange: [30, 140]` (Skill 5 ile tutarlı).

**Kapsam notu:** İçerik (`content/skills/paradiddle_eighth_notes.json`, üretici script `tool/generate_paradiddle_content.dart`, roadmap başlığı "Rudiments (Eighth Notes)"), testler (`test/domain/paradiddle_eighth_notes_content_test.dart`, `note_token_test.dart` ve `notation_layout_test.dart`'a aksan testleri eklendi) ve Home bağlantısı tamamlandı. Level 4 (Triple Paradiddle) §23'ün çok-ölçülü mimarisiyle 2026-07-21'de eklendi.

---

## 21. Skill 7: Sixteenth Notes (2026-07-20 karar)

**Araştırma (Vic Firth WebRhythms Lesson 3B-3D, 4; Alfred's Drum Method Lesson 10-11, 16; Drumeo) — gerçek ders sırası:**
- **3B — Tam grup:** vuruş başına 4 onaltılık ("1 e and a"), zaten bilinen sekizlik-çift arka planına karşı.
- **3C — İki onaltılık + sekizlik:** "vuruştaki İLK sekizlik ikiye bölünüyor."
- **3D — Sekizlik + iki onaltılık:** "İKİNCİ sekizlik ikiye bölünüyor." Skill 4'ün dışladığı "nota+sus" şeklinin aksine, burada İKİ SIRA da gerçek, kulakla ayırt edilebilir, gerçekten öğretilen farklı figürler — biri diğerinin yerini tutmuyor, ikisi de içerikte kalmalı.
- **Lesson 4 — Onaltılık suslar:** ÖNEMLİ BULGU — Vic Firth açıkça "sixteenths always follow RLRL […] regardless of rest placement" diyor. Yani burada Skill 3'te düzelttiğimiz "plain sequential alternation" DEĞİL, Skill 2'nin "hayalet vuruş" (sabit ızgara) modeli geçerli — çünkü bir onaltılık vuruş her zaman gerçek bir 4-slotluk ızgara (tümü çalınsa da bazıları sus olsa da), Skill 3'ün yoğunluk seviyelerindeki gibi farklı-uzunluktaki notaların karışımı değil.
- **Lesson 5 — Noktalı sekizlik+onaltılık:** doğal bir sonraki adım ama kullanıcı kararıyla bu skill'e DAHİL EDİLMEDİ — Skill 5'in "Quarter & Eighth Combinations"tan ayrılma mantığıyla, ileride kendi araştırmasıyla ayrı bir skill olarak ele alınacak (kapsamın şişmesini önlemek için).

**Level ekseni (7 seviye):**

| Level | İçerik | Şablon | Sticking modeli |
|---|---|---|---|
| 1 | Tam onaltılık grup vs sekizlik-çift arka plan (1 vuruş pozisyonu × 2 el) | 8 | plain sequential alternation |
| 2 | İki onaltılık + sekizlik (ilk sekizlik kırık) | 8 | plain sequential alternation |
| 3 | Sekizlik + iki onaltılık (ikinci sekizlik kırık) | 8 | plain sequential alternation |
| 4 | Onaltılık suslar (2 kanonik figür — Vic Firth'in "lead"/"trail" örnekleri — × 4 pozisyon × 2 el) | 16 | **hayalet vuruş (sabit ızgara)** |
| 5 | Tam akış: Steady Alternation (`sessionFixed`) | 2 | — |
| 6 | Tam akış: Lead-Hand Switching | 2 | — |
| 7 | Tam akış: Doubles | 4 | — |

Level 1-3'ün sticking modeli Skill 3'ün düzeltilmiş modeliyle aynı (farklı uzunluktaki notaların karışımı → ızgara yok, düz ardışık alternasyon). Level 4 ise Vic Firth'in açık kuralına uyarak `quarter_note_rests.json`'daki AYNI hayalet-vuruş mantığını kullanıyor — ama ızgara tüm ölçüye değil, sadece o TEK vuruşun 4 slotuna uygulanıyor (diğer 3 vuruş düz sekizlik-çift, sus yok, ızgaraya ihtiyaç yok). Level 4'te tüm kombinatorik sus-pozisyon uzayı değil, Vic Firth'in kanonik 2 örneği (baştaki sus, sondaki sus) kullanıldı — Skill 4'ün de kanonik figürleri seçip tam kombinatoriği kullanmadığı yaklaşımla tutarlı. Level 5-7, Skill 3'ün zaten doğrulanmış tam-akış sticking alt-müfredatını (steady alternation → lead-switching → doubles) bir alt bölüm seviyesi yukarı taşıyor.

Tempo: yeni bir el-hızı ikiye katlaması (sekizlik→onaltılık, Skill 3'ün dörtlük→sekizlik geçişiyle aynı gerekçe) olduğu için sadece Level 1'de bir pratik notu var (önceden `curriculumBpm: [20,25,30,35,40,45,50,55]` sabit rampı vardı, 2026-07-27'de kaldırıldı — bkz. "Tempo Müfredatı" bölümü). `bpmDefault: 50`, `bpmRange: [20,100]` (Skill 3'ün 30-140/60'ının yaklaşık yarısı, çünkü aynı BPM'de onaltılık çalmak sekizliğin iki katı el hızı istiyor).

**Notasyon render'ı — kiriş (beam) mimarisinin genelleştirilmesi.** Skill 7'ye kadar kiriş algoritması SADECE sekizlik notaları işliyordu (`raw[i].$3 != NoteDuration.eighth` kontrolü); onaltılıklar hiç kirişlenmeyecekti (her biri ayrı çift-bayraklı glif olarak çizilecekti). Windows'a geçmeden önce fark edilip düzeltildi:
- `NotationLayout.notesOf()`'taki run-tespiti artık hem sekizlik hem onaltılık notaları "kirişlenebilir" sayıyor, bitişiklik kontrolü notanın GERÇEK süresine göre yapılıyor (sabit 0.5 yerine).
- Karışık sekizlik/onaltılık figürlerde (Level 2/3), standart notasyon kuralına uyarak grubun TAMAMI tek bir ana kirişle bağlanıyor, AYRICA ardışık onaltılıkların oluşturduğu alt-dizi (varsa) ikinci (iç) bir kirişle işaretleniyor — `NotePlacement.secondaryBeamed`/`secondaryBeamGroupEnd`, `NotationPainter._paintBeam`'e eklenen `yOffset` parametresiyle ana kirişin hemen altına ikinci bir çubuk çiziyor.
- Level 5-7'nin (16 ardışık onaltılık) gruplama sınırı hâlâ VUKUŞ bazında (4'erli 4 grup) kalıyor — yarım-ölçüye genişleme SADECE aksanlı içerikte (Skill 6) devreye giriyor, aksansız onaltılık akışlar için standart per-beat kural değişmedi.

**Kapsam notu:** İçerik (`content/skills/sixteenth_notes.json`, üretici script `tool/generate_sixteenth_notes_content.dart`), testler (`test/domain/sixteenth_notes_content_test.dart`, `notation_layout_test.dart`'a çift-kiriş testleri eklendi) ve Home bağlantısı tamamlandı.

---

## 22. Skill 8: Rudiments (Sixteenth Notes) (2026-07-21 karar)

Skill 6'nın Single Paradiddle'ını gerçek/geleneksel onaltılık hızına taşıyor (PAS 40 resmi sırası: #16 Single, #17 Double, #18 Triple, #19 Single Paradiddle-Diddle).

**Mimari kontrol (içerik yazılmadan ÖNCE yapıldı — Skill 6'nın Triple Paradiddle deneyiminden ders alınarak):** `ExerciseTemplate` her zaman tam 1 ölçü. Onaltılık hızda:
- Single Paradiddle = 8 vuruş = 2 vuruş (yarım ölçü) — ölçüyü doldurmak için İKİ KEZ art arda çalınıyor (Skill 6 Level1/2 ile aynı şekil, sadece 8'lik yerine 16'lık).
- **Triple Paradiddle = 16 vuruş = 4 vuruş = TAM 1 ÖLÇÜ.** İlk kez sığıyor — sekizlik hızda (Skill 6) 2 ölçü gerektirdiği için dışlanmıştı.
- Double Paradiddle ve Single Paradiddle-Diddle = 12 vuruş = 3 vuruş — hâlâ 4/4'e sığmıyor. Doğal evleri 6/8 (12 onaltılık = tam 1 ölçü) — yani gelecekteki "Alternate Meters" skill'ine (§15 madde 10) ait, Skill 6'daki Double Paradiddle kararıyla tutarlı şekilde tekrar ertelendi.

**Level ekseni (3 seviye):**

| Level | İçerik | Şablon |
|---|---|---|
| 1 | Single Paradiddle (16'lık), sabit öncü el (`sessionFixed`) | 2 |
| 2 | Single Paradiddle (16'lık), öncü el her ölçüde değişiyor | 2 |
| 3 | Triple Paradiddle (16'lık) | 2 |

**Kiriş genişliği DÜZELTMESİ (2026-07-21, içerik yazılmadan önce araştırmayla bulundu).** Skill 6'da eklenen "aksan varsa kiriş grubu 2 vuruşa genişler" kuralı sabit bir `2.0` sabitiydi — bu sadece SEKİZLİK notalar için doğruydu (4 sekizlik = 2 vuruş). Referans notasyon araştırması doğruladı: onaltılık notalar HER ZAMAN vuruş başına 4'lük gruplar halinde kirişlenir — **Triple Paradiddle'da bile** (aksan 2 vuruşta bir düşse de) kiriş 8'li değil 4'lü kalır ("Triple Paradiddle In Groups Of Four"). Düzeltme: `NotationLayout.notesOf()`'taki grup genişliği artık `4 × notaSüresi` olarak hesaplanıyor (sabit `2.0` yerine) — sekizlik için hâlâ 2 vuruş (Skill 6 davranışı korunuyor), onaltılık için 1 vuruş (yani hiç genişlemiyor, zaten varsayılan). Regresyon testiyle doğrulandı (`notation_layout_test.dart`).

Tempo müfredatı yok (yeni bir hız-ikiye-katlama anı değil — o Skill 7'nin işiydi; burada sadece sticking şekli daha zor). `bpmDefault: 35`, `bpmRange: [20, 80]` (Skill 6'nın ~yarısı, Skill 7'nin onaltılık hız düşüşü mantığıyla tutarlı).

**Kapsam notu:** İçerik (`content/skills/paradiddle_sixteenth_notes.json`, üretici script `tool/generate_paradiddle_sixteenth_content.dart`), testler (`test/domain/paradiddle_sixteenth_notes_content_test.dart`, `notation_layout_test.dart`'a onaltılık-aksan kiriş genişliği testi eklendi) ve Home bağlantısı tamamlandı.

---

## 23. Çok Ölçülü (Multi-Measure) Exercise Mimarisi (2026-07-21 karar)

**Motivasyon:** Skill 6'da Triple Paradiddle'ın (16 vuruş = 2 ölçü, sekizlik hızda) dışlanmasına yol açan kısıt — `ExerciseTemplate` her zaman tam 1 ölçü — kullanıcının açık isteğiyle genelleştirildi: "rudimentler eğer sığmıyorsa bizim tek ölçülük sınırlamamıza, 2 ölçülü üretim kuralları geliştir."

**Kapsam kararı:** Her SESSION içindeki tüm exercise'lar aynı ölçü sayısını (K) paylaşıyor — bir level'ın template havuzu zaten her zaman homojen (tüm şablonlar aynı ritmik uzunlukta, sadece sticking/pozisyon permütasyonuyla farklılaşıyor), yani heterojen (bazı exercise 1 ölçü, bazısı 2 ölçü aynı seansta) bir senaryo gerçek içerikte hiç oluşmuyor. Bu, mimariyi çok basitleştirdi: cumulative/karma bir ofset yapısı yerine tek bir sabit K çarpanı yeterli.

**Değişen dosyalar ve nasıl:**
- `ExerciseTemplate.validateAgainst(ts)`: artık toplam süre `ts.beats`in TAM KATI olmasını istiyor (== değil, `% == 0`). `measureCountFor(ts)` yeni bir yardımcı — kaç ölçü olduğunu döndürüyor.
- `Exercise`: yeni `measureCount` alanı (şablon gibi bir snapshot). `Exercise.fromTemplate` artık `TimeSignature` parametresi alıyor.
- `TimelineMap`: yeni `measuresPerExercise` (K, varsayılan 1) alanı. `baseMeasureOfExercise(exercise) => exercise*K+1` (count-in'den sonraki ilk ölçü). `sampleOfBeat` yeni `measureWithinExercise` parametresi aldı (varsayılan 0 — eski imza/davranış korunuyor). `positionAt`, global ölçüyü `(exercise, measureWithinExercise)` çiftine çözüyor (negatif-index tuzağına dikkat: Dart'ın `~/` işlemi negatif sayılarda sıfıra yuvarladığı için count-in durumu ayrıca dallandırıldı).
- `TimelinePosition`: yeni `measureWithinExercise` alanı eklendi. `beat` alanının anlamı DEĞİŞMEDİ — hâlâ "mevcut ÖLÇÜ içindeki vuruş" (0..ts.beats-1), kümülatif değil — bu sayede `beat`i kullanan mevcut UI kodu (ilerleme yüzdesi, "beat X/4" metni) kırılmadan kaldı, sadece `measureWithinExercise`i de hesaba katacak şekilde küçük düzeltmeler gerekti (`practice_screen.dart`, `dev_playground_screen.dart`).
- `NotationLayout`: yeni `measuresPerExercise` alanı + `baseMeasureOfExercise(exercise) => exercise*K` (kendi koordinat sisteminde, count-in yok). `notesOf`/`restsOf`, her nota/susun kümülatif vuruş konumunu `(ölçü-içi-vuruş, exercise-içi-ölçü)`e çözüp doğru global ölçü/satırı hesaplıyor — artık `e.index`i doğrudan ölçü numarası olarak KULLANMIYOR. `playheadX` üç parametre alıyor (`exercise, measureWithinExercise, beatWithFraction`). Constructor'da bir `assert` var: `measuresPerRow % K == 0 || K % measuresPerRow == 0` — bu, çok-ölçülü bir exercise'ın asla iki SATIRA bölünmemesini garanti ediyor (K=2, measuresPerRow=2 için exercise tam 1 satır kaplıyor).
- `NotationPainter`: `_paintRow`, her ölçü sütununu değil, her EXERCISE'ı BİR KEZ çiziyor (exercise'ın İLK ölçü sütununa denk geldiğinde) — aksi halde 2 ölçülük bir exercise iki kez çizilirdi. Notalar artık PAYLAŞILAN tek bir `staffY` yerine kendi `n.row`larına göre `layout.staffY(n.row)` kullanıyor (bir exercise'ın notaları farklı satırlara düşebileceği ihtimaline karşı sağlam, though mevcut `assert` bunun asla olmadığını garanti ediyor). `_paintHighlight`, artık tek ölçü değil exercise'ın TÜMÜNÜ (K×measureWidth genişliğinde) çerçeveliyor.
- `SessionAudioRenderer`: referans vuruş ofseti artık `map.baseMeasureOfExercise(e.index)` kullanıyor (eskiden `e.index+1` doğrudan yazılıydı) — `beatPos` zaten tüm exercise boyunca kümülatif biriktiği için (ölçü sınırında sıfırlanmıyor), formül K>1 için EK bir değişiklik gerektirmedi, sadece doğru ölçü ofsetini bulmak yeterliydi.

**Geriye dönük uyumluluk:** K=1 (varsayılan) için HER YERDE davranış birebir eskisiyle aynı — 144 mevcut test hiç değişiklik gerektirmeden yeşil kaldı (regresyon riski yok). K=2 için yeni testler eklendi (`timeline_map_test.dart`, `notation_layout_test.dart`, `exercise_test.dart`).

**İlk gerçek kullanım:** Skill 6'ya Level 4 "Triple Paradiddle" (16 vuruş, sekizlik hızda 2 ölçü) geri eklendi — bu mimarinin var olma sebebi.

**Açık kalan sınır:** Double Paradiddle / Single Paradiddle-Diddle (12 vuruş = 3 vuruş, ne 1 ne 2 ölçüye tam bölünüyor) bu genellemeyle de çözülmüyor — onların doğal evi 6/8 ölçü (roadmap madde 10, "Alternate Meters"), ayrı bir konu.

---

## 24. Skill 9: Syncopation / Ties (2026-07-21 karar)

**Araştırma (Vic Firth WebRhythms Lesson 10, Alfred's Drum Method Lesson 36 "Syncopation" / 38 "Tied Notes", Ted Reed'in *Progressive Steps to Syncopation*):** Alfred's senkopasyon ve bağı AYRI derslerde veriyor — roadmap'teki "Syncopation / Ties" ismi gerçekten iki farklı ama ilişkili kavramı bir araya getiriyor.

- **Klasik senkopasyon figürü — sekizlik-dörtlük-sekizlik** (2 vuruş): Vic Firth'ün temel örneği — "the longest note on the 'and' syllable of the first count." Ortadaki dörtlük "1"in "and"ında başlıyor, bir vuruş tutuluyor, kapanış sekizliği "2"nin "and"ında geliyor.
- **Skill 5'te ertelenen "sekizlik+noktalı dörtlük" (ters sıra)** de gerçek bir senkopasyon figürü — daha basit (2 atak; klasik figür 3 atak) — doğal bir **Level 1**, klasik figür **Level 2**.
- **Bağ (tie) ne zaman GEREKLİ:** Araştırma doğruladı — bir nota 4/4 ölçünün ORTASINI (3. vuruşu) örtüyorsa, tek noktalı nota yerine **iki nota + bağ çizgisi** kullanılır, böylece 3. vuruşun görsel olarak "görünür" kalması sağlanır. Bu, sadece "daha uzun bir nota" değil, gerçekten yeni bir render özelliği.

**Level ekseni (3 seviye):**

| Level | İçerik | Şablon | Bağ gerekli mi? |
|---|---|---|---|
| 1 | Sekizlik + noktalı dörtlük (ölçü yarısı, arka plan düz dörtlük) | 4 | Hayır — ölçü ortasını geçmiyor |
| 2 | Sekizlik-dörtlük-sekizlik (ölçü yarısı, arka plan düz dörtlük) | 4 | Hayır — düz dörtlük, noktasız |
| 3 | Tied Across Beat 3 — `e,e,e,e,q~,e,e` (2. vuruşun "and"ından başlayıp 3. vuruşu geçen bağlı nota) | 2 (`sessionFixed`) | **Evet** |

Level 1/2, Skill 5'in "ölçü yarısı" yöntemini (§19) tekrar kullanıyor. Level 3'ün tam ritmi: ilk 4 sekizlik (1. vuruş + 2. vuruşun ilk yarısı + bağın başladığı nota), sonra `q~` (bağlı dörtlük, 3. vuruşu kaplıyor, çalınmıyor), sonra 4. vuruşta 2 sekizlik. Sticking bağlı notayı sus gibi atlıyor — el sırası bağlı notaya HİÇ geçmiyor, bir sonraki gerçek vuruş kaldığı yerden alternasyona devam ediyor (RLRL_RL → RLRLRL, temiz, hayalet-vuruş modelindeki gibi bir bozulma yok çünkü zaten sabit bir ızgara yok, sadece "atlanan" bir slot var).

**Yeni özellik — `NoteToken.isTied` (`~` son eki, nokta/aksandan sonra, ör. `"q~"`):**
- `NoteToken.isStruck` yardımcı getter'ı eklendi (`!isRest && !isTied`) — hem rest hem tied notalar sticking/reference-hit/click almıyor.
- `ExerciseTemplate`'in sticking-uzunluğu kontrolü artık `isStruck` kullanıyor (önceden sadece `!isRest`).
- `NotationLayout.notesOf()`: bağlı nota yerleşime dahil oluyor (kendi notehead'i çiziliyor, ki 3. vuruş görünür kalsın) ama `noteIdx`'i artırmıyor / sticking ataması almıyor (`NotePlacement.sticking` boş string).
- `NotationPainter`: bağlı notanın altında sticking harfi YOK; `_paintTie()` iki nota arasında (bir önceki notadan bağlı notaya) sığ bir eğik çizgi çiziyor (sap yönünün tersi, notaların altında — standart bağ gravürü).
- `SessionAudioRenderer`: bağlı notalar için referans vuruş sesi çalınmıyor (`token.isStruck` kontrolü, rest'lerle aynı mantık).

Tempo müfredatı yok; `bpmDefault: 60`, `bpmRange: [30, 140]` (Skill 5 ile tutarlı).

**Kapsam notu:** İçerik (`content/skills/syncopation_ties.json`, üretici script `tool/generate_syncopation_ties_content.dart`), testler (`test/domain/syncopation_ties_content_test.dart`, `note_token_test.dart`/`exercise_test.dart`/`notation_layout_test.dart`/`session_audio_renderer_test.dart`'a bağ testleri eklendi) ve Home bağlantısı tamamlandı.

---

## 25. Skill 10: Alternate Meters — 3/4 ve 6/8 (2026-07-21 karar)

**Araştırma (Alfred's Drum Method Lesson 15 "3/4" / Lesson 33 "6/8 in 2 with Rolls", Vic Firth WebRhythms Lesson 6 "Time Signatures and Meter" / Lesson 7 "Odd Meter Time Signatures", Drumeo):** 3/4 ve 6/8 pedagojik olarak birbirinden ÇOK uzak — Alfred's aralarına 18 ders koyuyor. Sebebi, bunların farklı TÜRDE ölçüler olması:

- **3/4 = basit üçlü:** 3 dörtlük vuruş, her biri 2'ye bölünüyor — 4/4 ile aynı alt-bölüm mantığı, sadece 3 vuruş. Yeni bir okuma becerisi gerektirmiyor.
- **6/8 = bileşik ikili:** payda (6) hissedilen vuruş sayısı DEĞİL — gerçekte 2 nabız var (noktalı dörtlükler), her biri 3'e bölünüyor. Birden fazla kaynak "6/8 şaşırtıcı derecede zor, davulcular hep zorlanır" diyor — gerçekten yeni bir alt-bölüm kavramı.

**Mimari kısıt bulundu (içerik yazılmadan önce):** `Skill.timeSignature` skill başına TEK değer (seviye başına değil). Bu yüzden 3/4 ve 6/8 içeriği TEK bir Skill nesnesinde birleştirilemiyor — zorunlu olarak İKİ AYRI Skill (iki JSON dosyası, `alternate_meters_34` / `alternate_meters_68`) ve Home roadmap'inde İKİ AYRI satır ("Alternate Meters: 3/4" / "Alternate Meters: 6/8") olarak uygulandı — kullanıcıya soruldu, bu pragmatik çözüm onaylandı (alternatif: Level'a kendi TimeSignature'ını ekleyip mimariyi genişletmek, kapsam çok büyürdü). Roadmap 12'den 13 maddeye çıktı.

**İkinci mimari kısıt bulundu (yine içerik yazılmadan önce, araştırmayla):** `NotationLayout.notesOf()`'un kiriş genişliği formülü basit ölçü varsayıyordu (varsayılan grup = 1 numaratör-vuruş). 6/8'de "1 numaratör-vuruş" tek bir sekizlik nota demek — bu kuralla hiçbir şey kirişlenmezdi (her nota kendi "grubu" sayılırdı). Düzeltme: `TimeSignature.isCompound` eklendi (payda 3'ün katı VE >3, yani 6/9/12 — 3/4 hariç). Bileşik ölçülerde kiriş grubu her zaman **3 numaratör-vuruş** (noktalı-dörtlük eşdeğeri nabız) — aksanlı olsun olmasın. Bu aynı zamanda Double Paradiddle'ın 6 vuruşluk hücresini de doğru kirişliyor (tesadüfen değil: bileşik nabız = 6 onaltılık = Double Paradiddle'ın yarısı tam örtüşüyor).

**Level ekseni:**

**`alternate_meters_34.json` (3/4):**

| Level | İçerik | Şablon |
|---|---|---|
| 1 | Dörtlük nabız (3 vuruş, `sessionFixed`) | 2 |
| 2 | Sekizlik çift transferi (3 pozisyon × 2 el, Skill3 yoğunluk yöntemiyle) | 6 |

**`alternate_meters_68.json` (6/8):**

| Level | İçerik | Şablon |
|---|---|---|
| 1 | Tam sekizlik akış (6 nota, 2×3 kirişli) | 2 |
| 2 | Noktalı-dörtlük nabız ("2'yi hissetmek" — ölçü başına sadece 2 nota) | 2 |
| 3 | **Double Paradiddle** (12 onaltılık = tam 1 ölçü — Skill 6/8'de sığmadığı için ertelenen rudiment'in doğal evi) | 2 |
| 4 | **Single Paradiddle-Diddle** (2026-07-21'de eklendi, §28) | 2 |

Double Paradiddle sticking: `RLRLRR LRLRLL` (ya da ayna) — klasik "para-para-diddle" (4 alternasyon + double), Single/Triple Paradiddle'ın devamı niteliğinde ama farklı hücre boyutuyla (6 vuruş, 4 değil). Single Paradiddle-Diddle sticking: `RLRRLL LRLLRR` — "para-diddle-diddle" (2 tekli + 2 çiftli), aynı 6 vuruşluk hücre boyutu, aynı 6/8'e sığma mantığı — ayrıntı §28'de.

Tempo: 3/4 için `bpmDefault: 80, bpmRange: [30,180]` (Skill1 ile tutarlı, yeni bir hız kavramı yok). 6/8 için `bpmDefault: 60, bpmRange: [30,140]` (Skill6/8 ile tutarlı, ayrıca compound tempo genelde dotted-quarter=nabız olarak düşünülür ama biz numaratör-vuruş bazlı BPM kullanmaya devam ediyoruz, tutarlılık için).

**Kapsam notu:** İçerik (`content/skills/alternate_meters_34.json` + `alternate_meters_68.json`, üretici script `tool/generate_alternate_meters_content.dart`), testler (`test/domain/alternate_meters_content_test.dart`, `notation_layout_test.dart`'a bileşik-ölçü kiriş testleri eklendi) ve Home bağlantısı (2 roadmap satırı) tamamlandı.

---

## 26. Skill 11: Odd Meters — 5/4 ve 7/8 (2026-07-21 karar)

**Kullanıcı talimatı:** "Sadece elimizdeki ana menüde müfredat olarak düşünme — araştırma sonucu yeni skill eklenmesi gerekirse ekleyelim." Bu skill tam olarak bunun bir örneği: araştırma, 7/8'in kendine özgü bir mimari eksikliği (aşağıda) ortaya çıkardı ve yeni bir alan/mekanizma eklendi.

**Araştırma (Vic Firth WebRhythms Lesson 6 "Time Signatures and Meter" / Lesson 7 "Odd Meter Time Signatures", Drumeo, DrumGearAdvisor):**
- **5/4 = basit, tek sayılı ölçü:** 5 dörtlük vuruş, 3+2 ya da 2+3 gruplanıyor — ama dörtlük notalar zaten hiç kirişlenmiyor, yani 3/4 gibi sıfır mimari risk taşıyor.
- **7/8 = asimetrik, TEK bir doğal gruplaması yok.** Vic Firth'ün kendi ifadesiyle: **"a bar of seven-eight...can be phrased as 2+2+3, 2+3+2, or 3+2+2 ... the phrasing of each measure is conveyed to you by the beams."** Yani 6/8'in aksine (paydan otomatik türetilebilen tek bir bileşik kural), 7/8'in gruplaması İÇERİK tarafından AÇIKÇA belirtilmek zorunda — kirişlerin kendisi okuyucuya hangi gruplamanın kullanıldığını söylüyor. "2+2+3" en sık atıf yapılan varsayılan gruplama, bu yüzden içerikte o kullanıldı.

**Yeni mimari — açık kiriş gruplama (`beatGroupPattern`):**
- `Skill.beatGroupPattern` (nullable `List<int>?`, numaratör-vuruş biriminde, ör. 7/8 için `[2,2,3]`) — içerik JSON'unda opsiyonel `"beatGroupPattern"` alanı, `ContentLoader` tarafından parse ediliyor.
- `Session.beatGroupPattern`: `SessionGenerator` tarafından skill'den snapshot'lanıyor (tıpkı `timeSignature`/`bpm` gibi).
- `NotationLayout`'a `beatGroupPattern` parametresi eklendi; `notesOf()`'un kiriş sınırı hesaplaması artık İKİ yola ayrılıyor: `beatGroupPattern` varsa (kümülatif toplamlardan sınır listesi, ölçü uzunluğunda tekrarlanıyor), yoksa eski türetilmiş mantık (basit/bileşik/aksan) — **eski yol hiç değişmedi**, sıfır regresyon riski.
- `notation_view.dart`, `session.beatGroupPattern`'ı `NotationLayout`'a geçiriyor.

**Level ekseni:**

**`odd_meters_54.json` (5/4):**

| Level | İçerik | Şablon |
|---|---|---|
| 1 | Dörtlük nabız (5 vuruş, `sessionFixed`) | 2 |
| 2 | Sekizlik çift transferi (5 pozisyon × 2 el) | 10 |

**`odd_meters_78.json` (7/8, `beatGroupPattern: [2,2,3]`):**

| Level | İçerik | Şablon |
|---|---|---|
| 1 | Tam sekizlik akış (7 nota, 2+2+3 kirişli) | 2 |
| 2 | "2+2+3 nabzını hissetmek" — `q,q,q.` (2+2+3 numaratör-vuruş, tam 7/8'i dolduruyor) | 2 |

Tempo: 5/4 için `bpmDefault: 80, bpmRange: [30,180]` (3/4 ile tutarlı). 7/8 için `bpmDefault: 60, bpmRange: [30,140]` (6/8 ile tutarlı, dikkatli başlangıç).

**Kapsam notu:** İçerik (`content/skills/odd_meters_54.json` + `odd_meters_78.json`, üretici script `tool/generate_odd_meters_content.dart`), testler (`test/domain/odd_meters_content_test.dart`, `notation_layout_test.dart`'a açık-gruplama kiriş testi eklendi) ve Home bağlantısı (2 roadmap satırı, toplam roadmap artık 14 madde) tamamlandı.

---

## 27. Skill 12: Triplets (2026-07-21 karar — roadmap'e sonradan eklendi)

**Kullanıcı talimatı:** "Sadece elimizdeki ana menüde müfredat olarak düşünme — araştırma sonucu yeni skill eklenmesi gerekirse ekleyelim." Odd Meters'tan sonra "Performance Areas dışında eklememiz gereken bir şey kalmadı mı" diye soruldu — bu, orijinal 12 maddelik roadmap'in dışına çıkıp derin bir gap-analizi yapmayı tetikledi.

**Araştırma (Vic Firth WebRhythms Lesson 8 "Eighth Note Triplets" / Lesson 9 "Quarter Note Triplets", Alfred's Drum Method Lesson 22-23, genel metot kitabı taraması):**
- **Üçleme (triplet) = gerçek bir eksik.** "3'e 2" hissi — bir vuruşun (ya da 2 vuruşun) içine 3 EŞİT nota sığdırma — hemen hemen her metot kitabında var, hiç işlemediğimiz saf bir ritim-okuma konusu. Sekizlik üçleme (1 vuruşu dolduran 3 nota) önce, dörtlük üçleme (2 vuruşu dolduran 3 nota, daha zor türev) sonra öğretiliyor — Vic Firth'ün kendi ders sırası da bu.
- **Flam/Drag/isimlendirilmiş rulo aileleri BİLİNÇLİ OLARAK DIŞLANDI.** Araştırma doğruladı: flam'ın "grace note"u **ritmik bir değere sahip değil** — ton/doku efekti, ayrı bir zamanlama olayı değil. Uygulamamızın temel önermesi zamanlama-odaklı analiz (mikrofon hangi eli ayırt edemiyor, teknik doğruluk asla vaat edilmiyor) — flam'lar bu sınırın tamamen dışında.
- **Swing/Shuffle hissi** not düşüldü ama kapsam dışı bırakıldı: aynı yazılı nota farklı OKUNUYOR (2:1 triplet tabanlı) — gerçek ama farklı türde bir konu (yeni notasyon değil, yorumlama kuralı), gelecekte ayrı ele alınabilir.

**Yeni mimari — `NoteToken.isTriplet`:**
- String kodlamada `t` son eki (en dışta, ör. `"et"` = üçleme sekizlik, `"qt"` = üçleme dörtlük).
- `lengthInBeats`: üçleme bir notanın süresi normal süresinin **2/3'ü** — 3 tanesi, 2 normal notanın kapladığı süreye tam eşit oluyor (3×(2/3)=2).
- `NotationLayout.notesOf()`: kiriş algoritmasındaki `lengthOf()` üçlemeyi hesaba katacak şekilde güncellendi (aksi halde ardışıklık/kiriş sınırı matematiği yanlış olurdu). AYRICA yeni, kirişten BAĞIMSIZ bir "üçleme grubu" hesaplaması eklendi (`NotePlacement.isTriplet` + `tripletGroupEnd`) — sekizlik üçleme HEM kirişleniyor HEM "3" işareti alıyor, dörtlük üçleme (dörtlükler hiç kirişlenmediği için) SADECE köşeli parantez + "3" işareti alıyor.
- `NotationPainter._paintTripletMark()`: notaların üstünde küçük italik "3" çiziyor; kirişli değilse (dörtlük üçleme) önce yatay bir parantez (ufak dikey çentiklerle) çiziyor.

**Level ekseni (2 seviye):**

| Level | İçerik | Şablon |
|---|---|---|
| 1 | Sekizlik Üçleme (4 pozisyon × 2 el, hangi vuruş üçleme) | 8 |
| 2 | Dörtlük Üçleme (ölçü yarısı, Skill 5/9'un yöntemiyle — 3 dörtlük-üçleme = tam yarım ölçü) | 4 |

Sticking: plain sequential alternation (design doc §17) — 3'lü (tek sayı) grup doğal olarak öncü eli bir sonraki vuruşta çeviriyor, gerçek üçleme okumasının gerektirdiği tam olarak bu.

Tempo: `bpmDefault: 70`, `bpmRange: [30, 140]` (Skill 4/9 ile tutarlı, yeni bir hız kavramı yok).

**Kapsam notu:** İçerik (`content/skills/triplets.json`, üretici script `tool/generate_triplets_content.dart`), testler (`test/domain/triplets_content_test.dart`, `note_token_test.dart`/`notation_layout_test.dart`'a üçleme testleri eklendi) ve Home bağlantısı (roadmap artık 15 madde) tamamlandı.

---

## 28. Single Paradiddle-Diddle + Rudiments: Roll Family (2026-07-21 karar)

**Kullanıcı sorusu:** Triplets'ten sonra "daha komplike rudimentler yok mu?" diye soruldu. Kontrol edilip iki gerçek eksik bulundu.

**1. Single Paradiddle-Diddle hâlâ borçluydu.** Skill 6/8'de (§20/§22) "Double Paradiddle VE Single Paradiddle-Diddle'ın doğal evi 6/8" denmişti, ama Skill 10 (§25) yazılırken sadece Double Paradiddle eklenmiş, Paradiddle-Diddle unutulmuştu. `alternate_meters_68.json`'a Level 4 olarak eklendi: sticking `RLRRLL LRLLRR` ("para-diddle-diddle" — 2 tekli + 2 çiftli, PAS resmi tanımı: "two single strokes and two double strokes, the first single stroke accented"), Double Paradiddle ile AYNI 6 vuruşluk hücre boyutu, aynı 2×`sessionFixed` şablon yapısı, sıfır yeni mimari.

**2. Araştırma yeni bir rudiment ailesi ortaya çıkardı: Roll Family (5/7/9-Stroke Roll).** PAS 40'ın "Double Stroke Open Roll Rudiments" ailesi — Single/Double Stroke Roll'dan hemen sonra öğretilen "Tier 2" temel rudimentler. Her biri N-1 çiftli vuruş + 1 AKSANLI tekli vuruş (alternasyonu doğal olarak sürdüren): 5-Stroke = `RRLLR`, 7-Stroke = `RRLLRRL`, 9-Stroke = `RRLLRRLLR`. Flam'ın aksine (§27'de dışlanmıştı — grace note'un ritmik değeri yok), buradaki HER vuruş (çiftler dahil) kendi net atağına sahip — tamamen zamanlama bazlı, uygulamanın kapsamına tam uyuyor.

**Süre kurgusu (standart notasyona göre):** her rulo, son aksanlı vuruş UZATILARAK temiz bir 2-vuruşluk yarıya (ya da 9-stroke için tam 4-vuruşluk ölçüye) tamamlanıyor:
- 5-Stroke: 4 onaltılık (1 vuruş) + 1 aksanlı DÖRTLÜK (1 vuruş) = 2 vuruş, ayna ile tekrarlanıp tam ölçüyü dolduruyor.
- 7-Stroke: 6 onaltılık (1.5 vuruş) + 1 aksanlı SEKİZLİK (0.5 vuruş) = 2 vuruş, aynı şekilde ayna.
- 9-Stroke: 8 onaltılık (2 vuruş) + 1 aksanlı YARIM NOTA (2 vuruş) = 4 vuruş — TEK BAŞINA tam ölçüyü dolduruyor, ayna yarıya gerek yok (R-lead/L-lead 2 şablon yeterli).

**Level ekseni (`roll_rudiments.json`, 3 seviye, hepsi `sessionFixed` — 2 şablonluk havuzlarda önceki her skill'le tutarlı gerekçe):**

| Level | İçerik | Şablon |
|---|---|---|
| 1 | 5-Stroke Roll | 2 |
| 2 | 7-Stroke Roll | 2 |
| 3 | 9-Stroke Roll | 2 |

Zaten var olan aksan notasyonu (§20) ve "ölçü yarısı" yöntemi (§19/§24/§27) dışında SIFIR yeni mimari gerekti. `bpmDefault: 60`, `bpmRange: [30,120]` (Skill 6/8 ile tutarlı, rudiment-hızında).

**Kapsam notu:** İçerik (`content/skills/roll_rudiments.json`, üretici script `tool/generate_roll_rudiments_content.dart`; `alternate_meters_68.json` güncellendi, üretici script `tool/generate_alternate_meters_content.dart`'a Level 4 eklendi), testler (`test/domain/roll_rudiments_content_test.dart`, `alternate_meters_content_test.dart` güncellendi) ve Home bağlantısı (roadmap artık 16 madde) tamamlandı.

---

## 29. Performance Areas — 4 Küme (2026-07-21 karar)

**Kullanıcı gözlemi:** "Şimdi çok fazla skill'imiz var. Performance areas'ta her derste hepsini birden kullanamayız... 2li 3lü birleştirerek alt skill grupları yapmalıyız." Araştırma bu sezgiyi doğruladı: Alfred's Drum Method'un "solo" (birleştirme) sayfaları HER ZAMAN o dersin YENİ materyalini YAKIN ZAMANDA öğrenilenle birleştiriyor, asla kitabın tamamını birden karıştırmıyor.

**Mimari bulgu (kolaylaştırıcı):** Bir "Performance Area" için YENİ domain kodu gerekmedi. `ExerciseTemplate` hangi skill'den geldiğini hiç bilmiyor/umursamıyor — bir Performance Area, sadece birkaç ZATEN ÜRETİLMİŞ VE DOĞRULANMIŞ skill'in şablon havuzlarının BİRLEŞİMİ olan, TEK seviyeli bir Skill. Tek gerçek kısıt: `Session`/`TimelineMap`/`NotationLayout` hepsi seans başına TEK `timeSignature` varsayıyor — bu yüzden sadece **4/4 skill'leri** birbirleriyle karıştırılabildi; 3/4, 6/8, 5/4, 7/8 skill'leri (farklı ölçüler) hiçbir Performance Area'ya dahil edilmedi, kendi başlarına kaldı.

**4 küme (tümü 4/4, örtüşmeden 11 tane 4/4 skill'ini kapsıyor):**

| Küme | İçerdiği skill'ler | Havuz boyutu |
|---|---|---|
| **Foundations** | Quarter-Note Pulse, Quarter Note Rests, Eighth Notes | 86 şablon |
| **Syncopated Feel** | Eighth Notes + Rests, Dotted Quarter + Eighth, Syncopation/Ties | 50 şablon |
| **Fast Subdivision** | Sixteenth Notes, Triplets | 60 şablon |
| **Rudiment Workout** | Rudiments (8th), Rudiments (16th), Roll Family | 22 şablon |

**Uygulama:** `tool/generate_performance_areas_content.dart`, her küme için referans verilen skill dosyalarının TÜM seviyelerindeki TÜM şablonları okuyup TEK bir `level`e havuzluyor (id'ler zaten her skill'in kendi prefix'iyle benzersiz, çakışma kontrolü yapıldı). BPM: her kümenin `bpmRange`'i, bileşen skill'lerin aralıklarının KESİŞİMİ (hiçbir şablonun asıl bağlamından daha hızlı/yavaş çalınmaması için); `bpmDefault` en yavaş bileşenin varsayılanı (karışık zorlukta güvenli başlangıç). `minVariety: 10`, `sessionFixed: false`, `difficultyRamp: false` (karışık kaynaklı, tutarlı bir zorluk metriği yok).

**Kapsam notu:** İçerik (4 dosya: `performance_foundations.json`, `performance_syncopated_feel.json`, `performance_fast_subdivision.json`, `performance_rudiment_workout.json`), testler (`test/domain/performance_areas_content_test.dart`) ve Home bağlantısı (roadmap artık 19 madde, TAMAMEN dolu — hiç kilitli "Coming soon" satırı kalmadı) tamamlandı.

---

## 30. Sextuplet, Double Stroke Roll, Duplet, 32nd Notes (2026-07-27 karar)

Roadmap §29'da "tamamen dolu" ilan edilmişti; bu 4 ekleme sonradan geldi (kullanıcı isteğiyle, gap-analizi olmadan doğrudan).

**Sextuplet (16'lık üçleme):** Triplets skill'ine (§27) Level 3 olarak eklendi. `NoteToken.isTriplet` zaten sekizlik üçlemeye uygulanmıştı — aynı bayrağı onaltılık nota süresine uygulamak SIFIR yeni kod gerektirdi (`lengthInBeats`'in `×2/3` çarpanı süre-bağımsız). 6 nota tek vuruşu dolduruyor.

**Double Stroke Roll:** Roll Family skill'ine (§28) Level 1 olarak eklendi (5/7/9-Stroke'tan ÖNCE — PAS 40 sırasında Double Stroke Roll, Roll Family'nin temeli/ön koşulu). Sticking `RRLL` deseni, mevcut aksan/kiriş mimarisiyle sıfır yeni kod.

**Duplet (6/8'de 2-in-3):** Alternate Meters: 6/8 skill'ine (§25) Level 5 olarak eklendi — bileşik ölçüde normalde 3'e bölünen bir vuruşu 2'ye bölme (`isTriplet`'in "ayna görüntüsü"). Yeni domain alanı: `NoteToken.isDuplet` (`d` son eki, `t` ile karşılıklı dışlayıcı), `lengthInBeats` artık `isDuplet` ise `×3/2`. `NotationLayout`'a `dupletGroupEnd` (2'li gruplar, `tripletGroupEnd`'in 3'lü mantığının aynası) eklendi; `NotationPainter._paintGroupNumeralMark` (eski adı `_paintTripletMark`) artık parametrik numeral alıyor ("3" veya "2").

**32nd Notes — TEK BAŞINA yeni skill, en büyük mimari değişiklik:** Rudiments (Sixteenth Notes)'tan sonra, Syncopation/Ties'tan önce eklendi (hız-kademesi sırasına uygun). Yeni `NoteDuration.thirtySecond` (kod `'x'`, 8 tanesi 1 vuruşu dolduruyor). **3. seviye kiriş (tertiary beam) render'ı gerekti** — daha önce sadece birincil (§17) ve ikincil (§21) kiriş vardı, 32'lik notalar üçüncü bir iç kirişe ihtiyaç duyuyor. `beamLevel(NoteDuration)` yardımcı fonksiyonu eklendi (8th=1, 16th=2, 32nd=3), `closeSubGroup(start, end, level, ...)` fonksiyonu seviye 2 VE 3'te tekrar kullanılabilir hale getirildi (kod tekrarı yerine genelleme). 2 seviye: "Full 32nd-Note Group", "Full Stream: Steady Alternation". `bpmDefault: 25`, `bpmRange: [10, 50]` (en yavaş skill — 32'lik hızda bu bile hızlı).

**Performance Areas gap'i (kullanıcı tarafından yakalandı):** Kullanıcı doğrudan sordu — "sonradan eklediğimiz skilleri (32'lik notlar) performance areas'ın kurallarına ekledin mi?" Kontrol edince HAYIR çıktı: `tool/generate_performance_areas_content.dart` grep'lenince `thirty_second_notes` hiç referans edilmiyordu. Düzeltme: Fast Subdivision kümesine eklendi (Sixteenth Notes + Triplets ile aynı "el hızı" ailesi), `bpmRange` 3'lü kesişime daraltıldı (`[30,100] ∩ [30,140] ∩ [10,50] = [30,50]`), `bpmDefault` 50→30. Şablon sayısı 68→78 (+10, tam olarak 32nd Notes'un 8+2 şablonuyla eşleşiyor). **GENEL DERS:** kullanıcının "bunu da yaptın mı" sorularını asla varsayımla cevaplama — her seferinde grep/dosya okuyarak doğrula, bu turda gerçek bir eksik yakaladı.

**Kapsam notu:** 291 test yeşil, `flutter analyze` temiz, Windows'ta doğrulandı.

---

## 31. "How to Count" Dersleri (2026-07-27 karar)

**Kullanıcı isteği:** "Bu skillerin en başına how to count dersi koyalım — video dersi olmadan öğrenciye geçmesi için iyi bir yol bul." Amaç: bir ritim figürünü ilk kez gören öğrencinin, video/ses anlatımı olmadan SADECE görsel notasyon üzerinden nasıl sayılacağını (heceleme — "1 e and a" gibi) öğrenmesi.

**Uygulanan çözüm — `countingLabels`:** `ExerciseTemplate`/`Exercise`'a opsiyonel `List<String>? countingLabels` eklendi — **her token için bir giriş** (susular DAHİL — `sticking`'in "sadece çalınan notalar" kuralından FARKLI bir indeksleme). Varsa, `NotationPainter` sticking harfi (R/L) yerine bu sayım hecesini gösteriyor (susların altında parantez içinde). `ContentLoader._parseTemplate` JSON'dan `countingLabels` alanını okuyor.

**Level 0 deseni:** "How to Count" dersleri mevcut seviyeleri kaydırmadan `level: 0` olarak ekleniyor — `content_loader.dart`'ın seviye sıralaması (`a.level.compareTo(b.level)`) zaten doğal olarak en başa koyuyor, ekstra kod gerekmedi.

**6 skill'e eklendi:**

| Skill | Sayım heceleri | Not |
|---|---|---|
| Eighth Notes | `1 & 2 & 3 & 4 &` | Standart sekizlik sayımı |
| Sixteenth Notes | `1 e & a ...` | Standart onaltılık sayımı |
| Quarter Note Rests | `1 2 3 4` | "How to Count: Rests" — sus altında da hece görünüyor (sessiz sayılsa da) |
| Alternate Meters: 6/8 | `1 & a 2 & a` | 4/4'ün "1 e & a"sından BİLİNÇLİ OLARAK farklı — aynı görünen heceler, farklı nabız |
| Odd Meters: 7/8 | `1 & 2 & 3 & a` | Skill'in kendi 2+2+3 `beatGroupPattern`'ıyla uyumlu (son grup compound-tarzı "a") |
| Triplets | (üçleme heceleme) | — |

**Performance Areas'tan hariç tutuldu:** `pooledTemplates()` artık `level == 0` olan template'leri atlıyor — How to Count içeriği "gerçek pratik materyali" değil, bir Performance Area'nın capstone havuzunu sulandırır.

**Kapsam notu:** Domain model + notasyon render + 6 skill içeriği + testler tamamlandı. 274 test yeşil (bu turun sonunda).

---

## 32. Tema Değişikliği, Davul Pad Arka Planı, Free/Premium Gating, Rozet Sistemi (2026-07-27, tek oturum)

Roadmap içerik olarak tamamlandıktan sonraki oturum — UI/UX ve monetizasyon işine geçildi.

### Tema: "Sunset Coral"

Bkz. §14 — orijinal krem/mavi palet YERİNE geçti, detaylar orada.

### Arka plan: gerçek davul pad fotoğrafı

İlk deneme (kod ile çizilmiş CustomPainter davul silüeti — kasnak + civata) kullanıcı tarafından reddedildi ("çok kötü/ilkel"). Gerçek fotoğraf arayışında iki tur elendi: (1) markalı/dağınık stok fotoğraflar (Remo/Roland logoları, kirli davul derisi), (2) "sıkı crop" ile logo temizlenen bir Roland practice pad fotoğrafı seçildi (Pexels, ücretsiz lisans). **GENEL DERS:** stok fotoğraf aramasında davul/enstrüman fotoğrafları neredeyse HER ZAMAN marka logosu taşıyor — kırpma ile temizlemek mümkün ama birkaç tur gerekebilir, önce küçük önizlemelerle (indirmeden) elemek indirme/crop döngüsünü hızlandırıyor.

### Free/Premium gating (bkz. §11 için güncel kurallar tablosu)

**Mimari:** `domain/progress/access_policy.dart` — `freeSkillIds` (sabit 3'lü set), `freeDailySessionCap = 3`, `freeBpm = 60`, ve saf bir karar fonksiyonu `decideGate({premium, skillId, alreadyUnlockedToday, todayUnlockCount}) → GateDecision {allow, upsellLocked, upsellCapReached}`. **Kullanıcının "3'ten sonra duracak mı?" sorusu üzerine bu fonksiyon Home ekranının `_startPractice`'inden AYRI, saf bir fonksiyon olarak çıkarıldı** — widget/DB bağımlılığı olmadan sınır durumlarını (4. yeni ders engellenir mi, zaten açık olan tekrar açılabilir mi) doğrudan test edebilmek için. 8 test bu tam senaryoyu kapsıyor.

**DB (schemaVersion 3→4):** `DailyUnlocks` tablosu (`dateKey` TEXT 'YYYY-MM-DD', `skillId`, `level`) — bir free kullanıcının bugün açtığı dersler. `PremiumSettings` tablosu (tek satır, `isPremium` bool) — gerçek StoreKit gelene kadar dev-only toggle'ın yazdığı yer.

**"Today's Lessons" → "Today's Session" sayfası (birkaç iterasyonda kullanıcı geri bildirimiyle şekillendi):**
1. İlk versiyon: Home ekranında, "Today's Session" kartının ALTINDA büyüyen bir liste.
2. Kullanıcı: "Today's Session kısmında alt alta yazmasın, dokununca kendi sayfasına girsin." → Ayrı `TodaySessionScreen`'e taşındı, Home'daki kart artık sadece giriş noktası (tek satır, chevron).
3. Kullanıcı: "Premium kullanıcıları da son derslerini orada görsün." → Ekran premium/free ayrımı yapan tek bir widget'a dönüştü: **free tier** `watchTodayUnlocks()` (bugüne özel, gece yarısı sıfırlanan, 3'e sabit) gösteriyor; **Premium** `watchRecentPracticed()` (TÜM zamanların en son TAMAMLANMIŞ 3 dersi, `PracticeSessions` tablosundan `GROUP BY (skillId,level) ORDER BY MAX(completedAt) DESC` — gün sınırı yok, çünkü Premium'da günlük kavramı yok).
4. Free tier'ın slot listesi HER ZAMAN tam 3 satır gösteriyor (doldukça dolan değil) — boş slotlar "Free slot available" placeholder'ı. Amaç: günün 3-ders hakkının baştan görünür olması.

### Rozet (tier) sistemi

Bkz. §14 "İlerleme Göstergesi" — detaylar orada.

### Premium ekranı

`premium_screen.dart` — özellik listesi (4 madde: tüm skill'ler, sınırsız günlük seans, kendi tempo, kayıt+analiz), sabit `$4.99/ay` fiyat metni + "App Store yerel para biriminizi kendi gösterecek" notu, dev-only Subscribe/Cancel Premium diyalogları. Gerçek StoreKit entegrasyonu ve eksikler için §12 madde 12-15.

### Ölü kod temizliği

Roadmap 20 skill'in tamamı artık dolu olduğu için `_RoadmapEntry.skill` hiçbir zaman null olmuyor — `_buildLockedRow`/`_showComingSoon`/"Coming soon" satırı kodu tamamen ölüydü (kullanıcının "eksik bir şey var mı" sorusuna verilen cevapta bulundu, sonra temizlendi).

**Kapsam notu:** Oturum sonunda 295 test yeşil, `flutter analyze` temiz, her adım Windows'ta görsel olarak doğrulandı.

---

## 33. App Icon Finalizasyonu ve Reklam Monetizasyonu (2026-07-30, tek oturum)

TestFlight dağıtımı + Restore Purchases oturumunun devamı — "hazır mıyız?" denetiminde bulunan app icon eksiği kapatıldı, ardından kullanıcı reklam monetizasyonu istedi.

### App icon

Kullanıcı Gemini ile iki ayrı kavram üretti: önce metronom+baget, sonra (son kararı) davul+baget ("Sunset Coral" turuncu gradyanlı, çizgi film tarzı). **Her iki Gemini çıktısında da aynı köşede (sağ-alt) aynı boyutta bir sparkle/yıldız artefaktı vardı** — muhtemelen Gemini'nin sabit bir imzası/watermark'ı. Temizleme yöntemi: artefaktın bounding box'ı blur-diff ile bulundu, temiz bir gradyan bölgesinden (görselin başka bir yerinden, artefaktsız) renk-eşleştirmeli (yerel ortalama renge göre parlaklık/ton kaydırılmış) bir yama kesilip üstüne yapıştırıldı, kenarları hafif feather ile yumuşatıldı — sonuç, tam boyutta bakıldığında izi görünmeyen pürüzsüz bir gradyan. 1024×1024 master'dan Python/PIL ile 15 boyutun tamamı (`ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png`, 20×20'den 1024×1024'e, RGB, alfasız) üretildi.

### Reklam monetizasyonu (free-tier kullanıcılar için)

Kullanıcının kararı ("Hepsi. Hatta... today's session hakkını 3'ten 4'e çıkarma"): Home + Results + Today's Session'da banner, seans sonrası (Practice→Results geçişinde) interstitial, VE bir rewarded-ad ile günde +1 bonus seans hakkı. Premium kullanıcılar hiçbir reklam görmez.

**Paket:** `google_mobile_ads` (banner/interstitial/rewarded) + `app_tracking_transparency` (iOS ATT izni, AdMob SDK'sından önce istenir). `in_app_purchase` ile aynı risk profili — sadece Android/iOS platform implementasyonu var; 2026-07-30'da bağımlılık eklendikten VE UI'nin her yerine bağlandıktan sonra `flutter run -d windows`'un hâlâ çalıştığı doğrulandı.

**Mimari:** `lib/infrastructure/ads/ads_service.dart` (`AdsService`) — `PurchaseService` ile aynı desen: `init()` (ATT iste → `MobileAds.instance.initialize()` → interstitial/rewarded önceden yükle), `showInterstitial()`/`showRewarded()` (`Completer` ile "kapatılana kadar bekle" + rewarded için "ödül kazanıldı mı" bilgisini döndürür), her ikisi de kapanınca otomatik yeniden ön-yükleme yapar. `AdsService.supported` (`defaultTargetPlatform` kontrolü) her gerçek SDK çağrısından önce kontrol ediliyor — Windows'ta sessizce no-op. `lib/presentation/widgets/ad_banner.dart` (`AdBanner`) — kendi `BannerAd`'ini yükleyip dispose eden, yüklenene kadar/desteklenmeyen platformda `SizedBox.shrink()` döndüren bağımsız widget.

**Ad unit ID'leri şu an Google'ın herkese açık TEST ID'leri** (`ca-app-pub-3940256099942544/...`) — her zaman dolar, hiç gerçek gelir üretmez. Gerçek AdMob hesabı açılınca değiştirilmesi gerekiyor (bkz. §12 madde 21).

**Rewarded bonus slot mimarisi:** `access_policy.dart`'a `freeBonusSlotCap = 1` (günde en fazla +1, biriktirilemez) ve `decideGate()`'e opsiyonel `bonusSlotsToday` parametresi eklendi (`effectiveCap = freeDailySessionCap + bonusSlotsToday.clamp(0, freeBonusSlotCap)`) — geriye dönük uyumlu (varsayılan 0), mevcut çağrı yerleri/testler değişmeden geçti. DB tarafı: yeni `AdBonusSlots` tablosu (`dateKey`, `count`), schemaVersion 4→5. `TodaySessionScreen`'de 3 slot dolunca ve bugünün bonus'u kullanılmamışsa "Watch a video for +1 session" kartı beliriyor; reklam izlenip ödül kazanılınca `db.addBonusSlot()` çağrılıyor.

**Ekran zinciri değişikliği:** `AdsService` artık `main.dart` → `HomeScreen`/`TodaySessionScreen` → `SessionPreviewScreen` → `PracticeScreen` → `ResultsScreen` boyunca constructor parametresi olarak taşınıyor (projede bir servis-locator/DI yok, hep açık constructor injection kullanılıyor — bu desene sadık kalındı). Interstitial `ResultsScreen.initState`'te `db.isPremium()` tek seferlik okumasından sonra, post-frame callback ile (build'i bloklamadan) tetikleniyor.

**Kapsam notu:** Oturum sonunda 301 test yeşil (4 yeni `decideGate` bonus-slot testi + 2 yeni `AdBonusSlots` DB testi), `flutter analyze` temiz, `flutter run -d windows` reklam kodu eklendikten sonra da hatasız açılıyor doğrulandı. Gerçek cihazda (TestFlight) reklamların görsel doğrulaması henüz yapılmadı — bir sonraki deploy'da kontrol edilmeli.

### Loop (Premium-only Practice tekrarı)

Kullanıcı isteği: seçilen dersi baştan sona bitince otomatik tekrar başlatan bir "Loop" seçeneği, sadece Premium'da. `PracticeFlowController`'a `loopPractice` (bool, varsayılan false) eklendi; `poll()`'da ses akışı bitip `!engine.isPlaying` olduğunda, `loopPractice` açıksa ve mod Record değilse (`!wasRecording` — kayıtlı bir take'in net bir bitişi olmalı), `_setStage(finished)` yerine `startPractice()` yeniden çağrılıyor. Bu, `startPractice()`'ın zaten her zaman `FlowStage.countIn`'e geçmesi sayesinde **her loop turunun kendi count-in'iyle başlamasını** bedavaya getiriyor — kullanıcının "yeniden başlarken ritmi nasıl hissedecek" endişesine mimari olarak zaten cevap. Yeniden yükleme async olduğu için (`_load()` PCM'i yeniden render edip soloud'a yüklüyor), `poll()` senkron olduğundan restart "fire-and-forget" (`unawaited`) çağrılıyor; `_restartingLoop` bayrağı, bu kısa async boşlukta `poll()`'un aynı dalı tekrar tekrar tetiklemesini engelliyor.

**Rozet sayımı kararı (kullanıcı, 2026-07-30):** İlk tasarımda loop turları `onSessionCompleted`'ı tetiklemiyordu (rozet sayacını şişirmesin diye) — kullanıcı bunu tersine çevirdi: "rozet işini saysın, her loop sayılsın." Şimdi her tamamlanan loop turu da normal bir seans gibi `onSessionCompleted`'ı tetikliyor.

**UI:** `SessionPreviewScreen`, `ResultsScreen`'deki gibi tek seferlik `db.isPremium()` okumasıyla kendi `_premium` durumunu tutuyor; "Reference hits" switch'inin altında, sadece Premium'da görünen bir "Loop" `SwitchListTile`'ı var (premium rozet ikonuyla).

**Doğrulama notu:** İlk elden test denemesinde loop çalışmadı gibi göründü (sonuç ekranına düştü) — kök neden koddan değil, muhtemelen kesilmiş/eski bir `flutter run` process'ine karşı test edilmiş olmasından kaynaklandı (önceki smoke-test komutları `timeout 90` ile otomatik kesiliyordu). Zaman aşımı olmadan taze bir `flutter run -d windows` başlatılıp yeniden denendiğinde loop doğru çalıştı — kullanıcı onayladı ("tamam şimdi oldu").

---

## 13. Milestone Planı

| # | Kapsam | Doğrulama |
|---|---|---|
| **M1 — Yürüyen iskelet** | Domain modeli + üretim motoru (skill 1, 4 seviye) + PCM render + AudioEngine + notation renderer + Home→Preview→CountIn→Practice→Results akışı. Windows desktop'ta çalışır. | Birim testler + desktop'ta uçtan uca seans |
| **M2 — iOS boru hattı** | Codemagic config, TestFlight build, iPhone'da ses zamanlaması/gecikme doğrulaması | iPhone'da gerçek pad ile pratik |
| **M3 — Kayıt** | Mikrofon kaydı, seansla senkron, replay | iPhone testi |
| **M4 — Analiz** | Gecikme kalibrasyonu, onset detection, skorlama, sonuç ekranı | Bilinen kayıtlarla doğruluk testi |
| **M5 — Ürünleşme** | Review Pool, free/premium gating, IAP, paywall | TestFlight beta |
| **M6 — Yayın hazırlığı** | Polish, lokalizasyon iskeleti, App Store metaryali | App Review |
