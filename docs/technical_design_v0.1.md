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
- **Her notanın altında sticking harfi (R/L)** — temel gereksinim.
- **4 ölçülük kayan pencere** (spec §7): aktif egzersiz çerçeve ile vurgulu; pencere her egzersiz bitiminde bir ölçü **smooth** kayar (animasyonlu translate; layout ölçü genişliklerini önceden hesaplar).
- **Playhead:** `TimelineMap` üzerinden pozisyon → x koordinatı; nota hizasında dikey çizgi.
- Ekranda yalnızca: notasyon, playhead, BPM, metronom göstergesi, session ilerlemesi. Vuruş numarası asla gösterilmez (spec §7).
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

- Kayıt seansla eş başlar; dosya t=0 = timeline t=0.
- Analiz **offline** (seans sonrası, spec §8): onset detection (enerji/spektral flux tabanlı; Dart'ta başla, yavaşsa FFI/C) → tespit edilen vuruşlar `TimelineMap`'teki beklenen vuruşlarla eşleştirilir → egzersiz başına zamanlama skoru.
- **Gecikme kalibrasyonu (zorunlu):** çıkış + mikrofon gecikmesi düzeltilmeden erken/geç yargısı anlamsız. Yöntem: kalibrasyon ekranında cihaz kendi tık sesini çalar, mikrofonla yakalar, round-trip gecikmeyi ölçer; kullanıcı pad'e vurarak doğrular. Cihaz başına saklanır.
- Analiz sonuç ekranı içeriği: **açık konu** (§12).

## 10. Review Pool (M5)

- Otomatik; kullanıcı elle ekleyemez (spec §9). Girdi sinyalleri:
  - Analiz yapılmış seanslar: egzersiz zamanlama skoru eşik altı (tekrarlayan).
  - Analiz yok ise: **açık konu** — aday sinyaller: kullanıcının egzersizi içeren seansı tekrar tekrar çalması, gelecekte "zor geldi" işareti. v1'de yalnız analiz sinyaliyle başlamak muhtemelen doğru.
- Enjeksiyon: premium kullanıcının yeni session'ına havuzdan snapshot egzersizler karıştırılır (birebir replay).

## 11. Free / Premium Uygulaması

Spec §12–13 kuralları `entitlements` modülünde tek yerde:

| Yetki | Free | Premium |
|---|---|---|
| Günde yeni session | 1 (takvim günü, cihaz saati) | sınırsız |
| Session replay | sınırsız | sınırsız |
| BPM değiştirme | ✗ | ✓ |
| Skills | ilk skill | tümü |
| Performance | ✗ | ✓ |
| Kayıt + replay | ✓ | ✓ |
| Analiz | ✗ | ✓ |
| Review önerileri | ✗ | ✓ |

"Takvim günü" = cihaz yerel saati; saat dilimi oyunlarını umursamıyoruz (local-only, kritik değil).

---

## 12. Açık Konular (karar sırası geldiğinde kullanıcıyla)

1. Analiz sonuç ekranı: hangi metrikler, nasıl görselleştirme?
2. Review Pool'a giriş kriteri — analizsiz kullanıcıda davranış.
3. Preview'ın tam davranışı: 16 ölçü baştan sona mı, loop mu, bölüm seçilebilir mi?
4. Ses tasarımı: tık ve referans pad sesleri (sentez mi sample mı, hangi karakter).
5. StoreKit doğrudan mı, RevenueCat mi; fiyatlandırma.
6. Storage teknolojisi (M1 sonunda: muhtemelen `drift` ya da `isar`).
7. Uygulama adı "One Pad" App Store müsaitliği.
8. Metronom-akort'taki ses çözümü vs `flutter_soloud` — mevcut kod incelenecek.

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
