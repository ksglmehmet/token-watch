# token-watch

**Kodlama ajanının (Claude Code) not kasandaki hangi dosyaları gerçekten okuduğunu canlı izle.**

Claude Code'a bir soru soruyorsun, cevap veriyor. Peki 90 notunun hangilerini açtı, hangilerini
yalnızca bir aramada adıyla gördü, hangilerine hiç dokunmadı? `token-watch` bunu olurken ekranda
gösterir ve o turda okunan token'ı kasanın toplamıyla karşılaştırır.

![token-watch](assets/cover.gif)

```
❯ Pentaho ile alakalı bildiklerimizi anlatır mısın

  ▪ index.md                                   ← okundu
  ▪ entities/pentaho-server.md                 ← okundu
  ▪ architecture/sap-pentaho-postgresql-...    ← okundu
  ░ log.md                                     ← grep gördü, açılmadı
  · 80 dosya daha                              ← hiç dokunulmadı

  ~9.800 okunan  /  ~82.000 toplam  =  8,4× tasarruf
```

> `token-watch`, Selma Kocabıyık'ın açık kaynak **[vault-radar](https://github.com/selmakcby/vault-radar)**
> projesinin bir çatalıdır (fork). Temel tasarım ve kodun büyük kısmı ona aittir. Bu depo, aracı
> **Windows + PowerShell** üzerinde ve Türkçe içerikle sorunsuz çalışacak hale getiren düzeltmeleri
> ve görüntüleyici iyileştirmelerini içerir. Farklar için [Upstream'den farklar](#upstreamden-farklar)
> bölümüne bak. Orijinal İngilizce belge: [README.vault-radar.md](README.vault-radar.md).

---

## İçindekiler

- [Neden?](#neden)
- [Nasıl çalışır?](#nasıl-çalışır)
- [Upstream'den farklar](#upstreamden-farklar)
- [Gereksinimler](#gereksinimler)
- [Kurulum](#kurulum)
  - [1. Depoyu klonla](#1-depoyu-klonla)
  - [2. Hook'u Claude Code ayarlarına ekle](#2-hooku-claude-code-ayarlarına-ekle)
  - [3a. Tarayıcı görüntüleyicisi](#3a-tarayıcı-görüntüleyicisi)
  - [3b. Obsidian eklentisi](#3b-obsidian-eklentisi)
- [Docker ile çalıştırma](#docker-ile-çalıştırma)
- [Kullanım](#kullanım)
- [Renkler ve durumlar](#renkler-ve-durumlar)
- [Seçenekler](#seçenekler)
- [Kasanın boyutunu ölçmek](#kasanın-boyutunu-ölçmek)
- [Gizlilik ve güvenlik](#gizlilik-ve-güvenlik)
- [Sorun giderme](#sorun-giderme)
- [Sınırlamalar](#sınırlamalar)
- [Proje yapısı](#proje-yapısı)
- [Geliştirme ve test](#geliştirme-ve-test)
- [Lisans ve atıf](#lisans-ve-atıf)

---

## Neden?

Ajan hafıza sistemleri (ör. Karpathy'nin *LLM Wiki* deseni, Obsidian kasaları) bir vaatle gelir:
ajan her şeyi okumaz, bir `index.md` üzerinden **gezinir**. Bu vaat genellikle görünmezdir; cevabı
görürsün ama yolu görmezsin. `token-watch` yolu görünür yapar. Böylece şunları anlarsın:

- İndeks sayfan işini yapıyor mu, yoksa ajan klasörü baştan sona mı tarıyor?
- Bir soruya cevap vermek için kasanın ne kadarı bağlama (context) girdi?
- Hangi notlar hiç okunmuyor, hangileri her soruda açılıyor?

## Nasıl çalışır?

Üç parça, sihir yok:

```
 Claude Code ──(hook, her araç çağrısında)──► radar.py hook ──► ~/.vault-radar/events.jsonl
                                                                   │
                         ┌─────────────────────────────────────────┤
                         ▼                                         ▼
          radar.py serve (SSE, :7777)                 Obsidian eklentisi (dosyayı doğrudan okur)
                         ▼                                         ▼
              tarayıcı görüntüleyicisi                  Obsidian'ın kendi grafik görünümü
```

1. **Hook.** Claude Code her araç çağrısından sonra `PostToolUse` olayını tetikler.
   `radar.py hook` olay verisini stdin'den JSON olarak okur ve `~/.vault-radar/events.jsonl`
   dosyasına tek satır ekler. `Read`, `Grep`, `Glob`, `Bash` ve `PowerShell` araçlarını yakalar
   (`cat`, `head`, `Get-Content`, `Select-String` gibi kabuk okumaları dahil). Ayrıca
   `UserPromptSubmit` (yeni soru) ve `Stop` (tur bitti) olaylarını kaydeder.
2. **Sunucu (isteğe bağlı).** `radar.py serve` kasayı bir kez tarar (yol, boyut, token tahmini,
   `[[wikilink]]` bağları), olay dosyasını izler ve her yeni satırı Server-Sent Events ile
   tarayıcıya iter.
3. **Görüntüleyici.** Tek bir HTML dosyası. Kasadaki her not bir düğümdür; ajan dokundukça düğüm
   yanar ve küçük bir imleç sorudan okunan dosyaya doğru yürür.

Hook **asla** turu bloklamaz ve hata fırlatmaz: bozuk bir veri sessizce yutulur, çıkış kodu her
zaman 0'dır. Radar yalnızca gözlemler; ajanın işini bozmasına izin yoktur.

## Upstream'den farklar

| Alan | vault-radar | token-watch |
|---|---|---|
| PowerShell aracı | İzlenmiyor | `Get-Content`/`gc`, `Select-String`, `Get-ChildItem` okumaları ve aramaları yakalanıyor; matcher'a `PowerShell` eklendi |
| Türkçe karakterler (Windows) | `json.load(sys.stdin)` ANSI kod sayfasıyla okuduğu için `Değiştirdim` → `DeÄŸiÅŸtirdim` | stdin her zaman UTF-8 olarak okunuyor |
| Grep çıktısı (Windows) | `C:\yol\a.md:12:eşleşme` satırında yol `C` olarak kalıyordu | Sürücü harfi korunuyor |
| Görüntüleyici yol eşleme | Yalnızca `/` ayıracı; Windows'ta hiçbir okuma eşleşmiyor, ekran hareketsiz | `\` ve `/` ayıraçlarının ikisi de tanınıyor |
| Sunucu logu (Windows) | Sekme kapanınca `WinError 10053/10054` traceback'leri | Bağlantı kopmaları sessizce geçiliyor; gerçek hatalar yine yazılıyor |
| Geniş mod | Yalnızca panel büyüyor; yazı 9px, bağlar neredeyse görünmez | Yazı, düğüm ve çizgiler ekranla ölçekleniyor; bağlar belirgin; yerleşim ekran oranına yayılıyor |
| Doğrudan geniş açılış | — | `http://localhost:7777/?wide=1` |
| Pencere açma (Windows) | Yalnızca macOS/Linux tarayıcı yolları | Windows Chrome/Edge yolları eklendi |

Etiket davranışı upstream ile aynıdır: **yalnızca okunan** notların adı görünür; diğerleri adsız
noktadır.

## Gereksinimler

- **Python 3.9+** (yalnızca standart kütüphane; ek paket yok)
- **Claude Code** (hook desteğiyle)
- İsteğe bağlı: **Obsidian 1.4+** (eklenti için; 1.13.7'de doğrulandı)
- Windows 10/11, macOS veya Linux
- İsteğe bağlı: **Docker** (görüntüleyici sunucusunu konteynerde çalıştırmak için; bkz.
  [Docker ile çalıştırma](#docker-ile-çalıştırma))

## Kurulum

### 1. Depoyu klonla

```bash
git clone https://github.com/ksglmehmet/token-watch.git
cd token-watch
```

### 2. Hook'u Claude Code ayarlarına ekle

Hazır bloğu yazdır:

```bash
python radar.py install        # Windows
python3 radar.py install       # macOS / Linux
```

Çıktıyı bir Claude Code ayar dosyasına, var olan `"hooks"` bloğuyla **birleştirerek** ekle.
Hangi dosyayı seçtiğin, neyin izleneceğini belirler:

| Dosya | Kapsam |
|---|---|
| `~/.claude/settings.json` | Tüm Claude Code oturumların |
| `<proje>/.claude/settings.json` | Yalnızca o klasörden başlatılan oturumlar (**önerilen**: log daha az şey toplar) |

Windows için örnek blok (yolu kendi klon yerinle değiştir; ileri eğik çizgi kullan):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Read|Grep|Glob|NotebookRead|Bash|PowerShell",
        "hooks": [{ "type": "command", "command": "python C:/yol/token-watch/radar.py hook" }]
      }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "python C:/yol/token-watch/radar.py hook" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "python C:/yol/token-watch/radar.py hook" }] }
    ]
  }
}
```

> **Dikkat — geçersiz JSON:** Bloğu bir web sayfasından ya da sohbetten kopyalarken `python` ile
> yolun arasına görünmez bir **TAB** karakteri girebilir. JSON buna izin vermez ve Claude Code
> dosyanın tamamını okuyamaz; aynı dosyadaki `permissions`/`deny` kuralların da devre dışı
> kalabilir. Ekledikten sonra doğrula:
>
> ```powershell
> python -c "import json;json.load(open('.claude/settings.json',encoding='utf-8'));print('OK')"
> ```

> **Not — auto mode:** Claude Code'un auto mode'u, ajanın kendi ayar dosyasına hook yazmasını
> "kendi ayarını değiştirme" olarak engeller. Bu bloğu ayar dosyasına **sen** eklemelisin.

Hook, ayar dosyası kaydedildikten sonra çoğu zaman açık oturumda da hemen çalışmaya başlar; emin
olmak için Claude Code'u yeniden başlat. Çalıştığını şöyle görürsün:

```powershell
Get-Content ~/.vault-radar/events.jsonl -Tail 3      # Windows
tail -3 ~/.vault-radar/events.jsonl                   # macOS / Linux
```

### 3a. Tarayıcı görüntüleyicisi

```bash
python radar.py serve --vault "C:/yol/kasan" --no-open
```

Açılışta kasanın özetini yazar:

```
vault-radar · 91 files · ~81,299 tokens
vault  : C:\yol\kasan
events : C:\Users\sen\.vault-radar\events.jsonl
open   : http://localhost:7777
```

Tarayıcıda `http://localhost:7777` adresini aç. Komut çalıştığı sürece terminal açık kalmalı.

- `--no-open` olmadan, bulunursa Chrome/Edge'de ekranın sağına yapışık, çerçevesiz bir pencere açılır.
- Komutu **`radar.py`'nin bulunduğu klasörden** çalıştır ya da tam yolunu ver; aksi halde
  `No such file` hatası alırsın.

### 3b. Obsidian eklentisi

Eklenti, Obsidian'ın **kendi grafik görünümünü** boyar ve aynı `events.jsonl` dosyasını doğrudan
okur. Bunun için `radar.py serve` çalışıyor olmak zorunda değil; hook yeterli.

**macOS / Linux:**

```bash
./install-obsidian-plugin.sh ~/yol/kasan
```

**Windows (PowerShell)** — betik `python3` beklediği için elle kurmak daha kolay:

```powershell
$vault = "C:\yol\kasan"
New-Item -ItemType Directory -Force "$vault\.obsidian\plugins\vault-radar" | Out-Null
Copy-Item obsidian-plugin\manifest.json, obsidian-plugin\main.js "$vault\.obsidian\plugins\vault-radar\"
# community-plugins.json yoksa oluştur; varsa listeye "vault-radar" ekle
if (-not (Test-Path "$vault\.obsidian\community-plugins.json")) {
  '["vault-radar"]' | Set-Content -Encoding utf8 "$vault\.obsidian\community-plugins.json"
}
```

Ardından Obsidian'da:

1. **Ayarlar → Topluluk eklentileri → Kısıtlı modu kapat.**
2. Kasayı yeniden yükle ve **Vault Radar**'ın açık olduğunu kontrol et.
3. Grafik görünümünü aç (sol şeritteki grafik simgesi ya da `Ctrl+G`) ve ajana bir soru sor.

Çalışıyorsa sağ alttaki durum çubuğunda `radar: …` yazısı ve grafikte küçük bir robot görünür.
Robot, ajan bir dosyayı açtığında grafiğin **gerçek bağlantıları** üzerinden o nota yürür. İki not
bağlı değilse doğrudan atlar; bu da o sayfanın, ajanın bulunduğu yerden link ile ulaşılamadığını
gösterir.

Eklenti komutları: **Clear radar highlighting**, **Reconnect to event log**,
**Write graph diagnostics to disk**. Ayarlardan robot boyutu, hızı ve grep vurgusu değiştirilebilir.

> ⚠️ Eklenti Obsidian'ın herkese açık olmayan iç API'sine dayanır (`renderer.nodeLookup`,
> `node.color`, `renderer.changed()`). Bir sürüm bunları değiştirirse eklenti yalnızca boyamayı
> bırakır ve `~/.vault-radar/obsidian-debug.json` dosyasına teşhis yazar; kasana ya da grafiğine
> zarar vermez. Kodu kasa içine kopyalanır; kasan git ile sürümleniyorsa
> `.obsidian/plugins/` klasörünü `.gitignore`'a eklemeyi düşün.

## Docker ile çalıştırma

Görüntüleyici sunucusu (`radar.py serve`) bir konteyner olarak paketlenmiştir. İmaj
`python:3.12-slim` tabanlıdır ve bu taban birden çok mimari için yayınlandığından **Intel/AMD
PC'lerde, Apple Silicon Mac'lerde ve ARM sunucularda** aynı komutla derlenir. Ek Python paketi
yoktur; imaj ~120 MB'tır.

### Hangi parça nerede çalışır?

| Parça | Nerede | Neden |
|---|---|---|
| Sunucu + görüntüleyici | **Konteyner** | Uzun süre açık kalan bağımsız bir servis |
| Hook | Ana makine (önerilen) | Claude Code onu her araç çağrısında ana makinede başlatır |
| Obsidian eklentisi | Ana makine | Obsidian'ın içinde çalışır |

Hook ve konteyner, ana makinedeki `~/.vault-radar/events.jsonl` dosyası üzerinden konuşur:
hook dosyaya yazar, konteyner onu bind mount ile okur.

### Hızlı başlangıç (Docker Compose)

```bash
cp env.example .env              # Windows PowerShell: Copy-Item env.example .env
# .env içinde VAULT_PATH'i not klasörüne ayarla (Windows'ta ileri eğik çizgi: C:/Users/sen/Kasa)
docker compose up -d --build
```

Ardından `http://localhost:7777` (ya da `http://localhost:7777/?wide=1`). Hook'u
[2. adımdaki](#2-hooku-claude-code-ayarlarına-ekle) gibi ana makinede kurmuş olman yeterli.

| `.env` değişkeni | Varsayılan | Anlamı |
|---|---|---|
| `VAULT_PATH` | **zorunlu** | Not klasörü; konteynere **salt okunur** bağlanır (`/vault`) |
| `RADAR_DATA` | `~/.vault-radar` | Hook'un olay dosyasının klasörü (`/data`); SIFIRLA düğmesi için yazılabilir |
| `RADAR_PORT` | `7777` | Ana makinedeki port (yalnızca `127.0.0.1`'de açılır) |
| `VAULT_RADAR_CPT` | `3.8` | Token başına karakter (Türkçe ≈3,6) |
| `RADAR_UID` / `RADAR_GID` | `1000` | Yalnızca Linux: kendi `id -u` / `id -g` değerin |

Sık kullanılan komutlar:

```bash
docker compose logs -f           # sunucu çıktısı
docker compose ps                # durum (sağlık kontrolü: healthy)
docker compose restart           # kasaya not eklediysen yeniden tara
docker compose down              # durdur ve kaldır
```

### Compose olmadan

```bash
docker build -t token-watch .
docker run -d --name token-watch --restart unless-stopped \
  -p 127.0.0.1:7777:7777 \
  -v "/yol/kasan:/vault:ro" \
  -v "$HOME/.vault-radar:/data" \
  -e VAULT_RADAR_CPT=3.6 \
  token-watch
```

Windows PowerShell'de satır devamı için `\` yerine `` ` `` kullan ve yolları
`C:/Users/sen/...` biçiminde yaz.

Başka bir mimari için imaj üretmek (ör. ARM sunucuya taşımak):

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t <kayıt>/token-watch:latest --push .
```

### Python'u olmayan makinede hook

Hook da aynı imajla çalıştırılabilir. Ayar dosyasındaki `command` değerini şöyle yap:

```json
"command": "docker run --rm -i -v $HOME/.vault-radar:/data token-watch hook"
```

Windows'ta Claude Code hook'ları Git Bash ile çalıştırır. Git Bash `C:/...:/data` biçimindeki
yolu bozmasın diye başına `MSYS_NO_PATHCONV=1` ekle:

```json
"command": "MSYS_NO_PATHCONV=1 docker run --rm -i -v C:/Users/sen/.vault-radar:/data token-watch hook"
```

İmajın önceden derlenmiş olması gerekir (`docker build -t token-watch .` ya da
`docker compose build`).

> Bu yöntem çalışır ama **her araç çağrısına ~3 sn** ekler (konteyner başlatma süresi; ana
> makinedeki Python ile ~1 sn). Python kurulabiliyorsa ana makinede çalıştırmak çok daha hızlıdır.

### Güvenlik ayarları

Compose dosyası konteyneri sıkılaştırılmış biçimde başlatır:

- Port yalnızca **`127.0.0.1`**'de yayınlanır; ağdaki başka makineler erişemez. Konteyner içinde
  `0.0.0.0` dinlenir, ama sunucu yine yalnızca loopback `Host` başlığı taşıyan istekleri kabul
  eder (başka bir `Host` → 403).
- Not klasörü **salt okunur** bağlanır; konteyner notlarını değiştiremez.
- Yetkisiz kullanıcı (`radar`, uid 1000), salt okunur kök dosya sistemi (`read_only`),
  tüm Linux yetenekleri düşürülmüş (`cap_drop: ALL`), `no-new-privileges`.
- Yalnızca `radar.py` ve `ui/` imaja girer (`.dockerignore`); `.env`, `CLAUDE.md` ve sırlar
  derleme bağlamına alınmaz.

### Docker sorunları

| Belirti | Çözüm |
|---|---|
| `set VAULT_PATH in .env` hatası | `.env` dosyasını oluştur ve `VAULT_PATH`'i doldur |
| Görüntüleyici açılıyor ama hiçbir şey yanmıyor | `RADAR_DATA` hook'un yazdığı klasörle aynı mı? `docker compose logs` içindeki `events :` satırı `/data/events.jsonl` olmalı; ana makinede `~/.vault-radar/events.jsonl` büyüyor mu? |
| Linux'ta `Permission denied` (`/data`) | `.env` içinde `RADAR_UID`/`RADAR_GID` değerlerini kendi `id -u`/`id -g` değerinle eşle |
| Windows'ta `failed to connect to the docker API` | Docker Desktop'ı başlat |
| Yeni notlar görünmüyor | Kasa açılışta taranır; `docker compose restart` |

## Kullanım

1. Görüntüleyiciyi ya da Obsidian grafiğini aç.
2. Claude Code'a kasanla ilgili bir soru sor.
3. Ajan dosyaları okudukça düğümler yanar; alt kısımda okunan token, toplam token ve tasarruf
   oranı güncellenir.
4. Her yeni soru (prompt) ekranı sıfırlar; yalnızca o turun okumaları görünür.

Görüntüleyici düğmeleri:

| Düğme | Ne yapar |
|---|---|
| **GENİŞLET** | Paneli tam ekrana açar; yazı, düğüm ve bağlar ekran boyuna göre büyür |
| **DEMO** | Kayıtlı bir izi sahte bir kasa üzerinde oynatır (hook kurmadan arayüzü denemek için) |
| **SIFIRLA** | Olay dosyasını siler ve ekranı temizler |

Yer imleri:

- `http://localhost:7777/?wide=1` — doğrudan geniş modda açar
- `http://localhost:7777/?demo=1` — demo modunda açar

## Renkler ve durumlar

| Görüntüleyici | Obsidian | Anlamı |
|---|---|---|
| gri, adsız | varsayılan | Bu turda dokunulmadı |
| sarı | kehribar | Bir `grep`/`glob` eşleşti; ajan dosyanın **adını** gördü, içeriğini değil |
| turuncu + ad | turuncu | Açıldı ve bağlama okundu |
| — | açık şeftali, büyük | Şu anda okunuyor |

Sarı durum ilginç olanıdır: kırk dosya adı döndüren bir arama neredeyse bedavadır, kırk dosyayı
açmak ise pahalıdır. Radar bu farkı gösterir.

## Seçenekler

```bash
python radar.py serve --vault <yol> [--port 7777] [--ext .md,.txt] [--no-open] [--width 520]
```

| Bayrak / ortam değişkeni | Varsayılan | Anlamı |
|---|---|---|
| `--vault` | zorunlu | İzlenecek klasör |
| `--port` | `7777` | Görüntüleyici portu |
| `--host` / `VAULT_RADAR_BIND` | `127.0.0.1` | Dinlenecek adres (konteynerde `0.0.0.0`) |
| `--ext` | `.md` | İzlenecek uzantılar (virgülle) |
| `--no-open` | kapalı | Pencere açma |
| `--width` | `520` | Yapışık pencere genişliği (px) |
| `VAULT_RADAR_HOME` | `~/.vault-radar` | Olay dosyasının klasörü |
| `VAULT_RADAR_CPT` | `3.8` | Token başına karakter (İngilizce ≈4,0, Türkçe ≈3,6) |

## Kasanın boyutunu ölçmek

`serve` açılışta toplam dosya ve tahmini token sayısını yazar. Türkçe içerik için oranı ayarla:

```powershell
$env:VAULT_RADAR_CPT = "3.6"
python radar.py serve --vault "C:/yol/kasan" --no-open
```

Yalnızca kelime ve karakter sayısı için, kasanın kökünde:

```powershell
Get-ChildItem -Recurse -Filter *.md | Where-Object FullName -notmatch '\\\.obsidian\\' |
  Get-Content -Raw -Encoding UTF8 | Measure-Object -Word -Character
```

Token sayıları **dosya boyutundan tahmindir** (bayt / oran), gerçek tokenizer çıktısı değildir.
Orantı görmek içindir, faturalama için değil. Sayıma `.md` dosyaları girer; nokta ile başlayan
klasörler (`.obsidian`, `.git`) atlanır.

## Gizlilik ve güvenlik

- **Dışarıya hiçbir şey gönderilmez.** Kodda dış ağ isteği yoktur. Sunucu yalnızca `127.0.0.1`'e
  bağlanır; Host/Origin kontrolüyle DNS rebinding ve başka sitelerden gelen isteklere kapalıdır.
- **Olay dosyası hassas olabilir.** `~/.vault-radar/events.jsonl` şunları tutar:
  her prompt'un **ilk 400 karakteri**, okunan dosya yolları, arama yapan kabuk komutlarının ilk 80
  karakteri, oturum kimliği ve çalışma klasörü (`cwd`). Yerelde kalır ama şirket ya da kişisel bilgi içerebilir. Paylaşma; gerekirse
  **SIFIRLA** düğmesiyle ya da dosyayı silerek temizle.
- **Kapsamı dar tut.** Hook'u kullanıcı geneli yerine yalnızca ilgili proje klasörünün
  `.claude/settings.json` dosyasına eklemek, log'a giren prompt sayısını azaltır.
- **Gecikme.** Her hook çağrısı yeni bir Python süreci başlatır; Windows'ta çağrı başına ~1 sn
  ölçüldü. Bu, her araç çağrısına küçük bir gecikme ekler.

## Sorun giderme

| Belirti | Sebep | Çözüm |
|---|---|---|
| `events.jsonl` hiç oluşmuyor | Hook çalışmıyor | Ayar dosyasının geçerli JSON olduğunu doğrula (TAB uyarısına bak); Claude Code'u yeniden başlat |
| `python radar.py serve` → `No such file` | Komut başka klasörden çalıştırıldı | `radar.py`'nin klasörüne geç ya da tam yolunu ver |
| Görüntüleyici "canlı" ama hiçbir şey yanmıyor | Okunan dosyalar `--vault` klasörünün dışında, ya da o turda hiç okuma yok | Alt kısımdaki "vault dışı: N" sayacına bak; `--vault` yolunu kontrol et |
| Görüntüleyici "bağlanıyor"da kalıyor | Sunucu kapalı ya da port farklı | `serve` komutunun çalıştığını ve adresin portla eşleştiğini kontrol et |
| Prompt'ta `Ã`, `Å` gibi bozuk karakterler | Eski sürüm stdin'i ANSI kod sayfasıyla okuyordu | Bu çatalı kullan; düzeltilmiş durumda |
| Terminalde `WinError 10053/10054` | Tarayıcı sekmesi kapandı/yenilendi (zararsız) | Bu çatalda susturuldu; `serve`'ü yeniden başlat |
| Obsidian'da renk yok | Kısıtlı mod açık ya da iç API değişti | Kısıtlı modu kapat; `~/.vault-radar/obsidian-debug.json` dosyasına bak |
| PowerShell okumaları görünmüyor | Matcher'da `PowerShell` yok | Hook bloğundaki `matcher` değerini güncelle |

## Sınırlamalar

- Okumalar dosya adına göre eşlenir; farklı köklerde aynı göreli yola sahip iki dosya karışabilir.
- `Grep` sonuçlarının ayrıştırılması en iyi çabadır: aracın yanıt biçimi herkese açık bir sözleşme
  değildir ve değişebilir. Kabuk aramalarında (`rg`, `Select-String`) eşleşen dosyalar çıkarılmaz.
- Aynı anda tek oturum: iki Claude Code oturumu aynı log'a yazar; görüntüleyici en son prompt
  gönderen oturumu izler.
- Kabuk okuma tespiti komut metnine dayalı bir tahmindir; yalnızca ilk dosya argümanı sayılır.
- Yalnızca yerel; `127.0.0.1`'e bağlanır.

## Proje yapısı

```
token-watch/
├── radar.py                    # hook, SSE sunucusu, install çıktısı (tek dosya, bağımlılık yok)
├── ui/index.html               # tek dosyalık canlı görüntüleyici
├── obsidian-plugin/
│   ├── main.js                 # Obsidian grafiğini boyayan eklenti
│   └── manifest.json
├── install-obsidian-plugin.sh  # eklenti kurulum betiği (macOS / Linux)
├── Dockerfile                  # sunucu imajı (python:3.12-slim, çok mimarili)
├── docker-compose.yml          # loopback'e bağlı, sıkılaştırılmış servis tanımı
├── env.example                 # compose ayarlarının şablonu (.env olarak kopyala)
├── .dockerignore
├── assets/                     # README görselleri
├── README.vault-radar.md       # upstream'in orijinal İngilizce belgesi
├── CONTRIBUTING.md             # upstream katkı kuralları
└── LICENSE                     # MIT (upstream + bu çatalın telif bildirimleri)
```

## Geliştirme ve test

Test paketi yok; elle doğrulama:

```bash
# Hook bozuk girdide sessiz kalmalı ve 0 ile çıkmalı
echo 'not json' | python radar.py hook; echo $?

# Örnek olay — gerçek log'u kirletmemek için geçici bir klasör kullan
export VAULT_RADAR_HOME=/tmp/radar-test          # PowerShell: $env:VAULT_RADAR_HOME = "$env:TEMP\radar-test"
echo '{"hook_event_name":"UserPromptSubmit","prompt":"Değiştirdim","session_id":"t"}' | python radar.py hook
cat /tmp/radar-test/events.jsonl                # Türkçe karakterler bozulmadan görünmeli
```

Arayüzü hook olmadan denemek için `?demo=1`. `radar.py` üçüncü parti paket almaz (upstream kuralı).

Upstream güncellemelerini almak için:

```bash
git remote add upstream https://github.com/selmakcby/vault-radar.git
git fetch upstream
git merge upstream/main        # çakışmaları çöz; rebase değil merge
```

## Lisans ve atıf

MIT — bkz. [LICENSE](LICENSE).

- Orijinal eser: **vault-radar** © 2026 Selma Kocabıyık —
  <https://github.com/selmakcby/vault-radar>
- Windows/Türkçe düzeltmeleri ve görüntüleyici değişiklikleri: **token-watch** © 2026 Mehmet Akif KÖSOĞLU

Anthropic ile bağlantılı değildir ve Anthropic tarafından onaylanmamıştır. "Claude" ve
"Claude Code" Anthropic'in ticari markalarıdır; bu proje yalnızca Claude Code'un zaten ürettiği hook
verisini okur.
