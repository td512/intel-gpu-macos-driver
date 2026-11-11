<!-- 0.1.4 TASLAĞI (9 Kasım 2026, 10 Kasım'da main'e göre güncellendi). Yayından önce: paket listesini package.sh'in
çıktısıyla, yükseltme adımlarını release/README-INSTALL.tr.md'nin "Yükseltme" bölümüyle karşılaştırın; B570 satırları
hâlâ "test edilmedi" demeli; paketteki IntelXe.kext 10 Kasım sonrası main'den derlenmiş (platform katmanı, kullanıcı
çitleri) ve B580'de çalışmış olmalı; Windows EFI aracı Windows'ta çalıştıktan sonra HybridPM / SSDT-ARCOFF satırlarına
bakın. Ayrıca (10 Kasım 03:00 sonrası birleştirmeler): paketteki kext ve eklenti bunları içermeli (release.sh, kaynakları
son değiştiğinden önce derlenmiş paketleri reddediyor); debug.intelxe.sensors'un güç alanları paketteki kext'ten
okunmalı; WebGPU deferredRendering örneği paketteki eklentiyle Safari'de yeniden çalıştırılmalı; ASPM satırları hâlâ
"test edilmedi" demeli. (10 Kasım öğleden sonra birleştirmeleri): paketteki libintelxevenc AV1'i kaydetmeli (vtencq
--list), Safari maddeleri paketteki eklentiyle yeniden denetlenmeli (three.js sayfaları, gölgelendirici önbelleği "fc spec:
HIT"), paketlenmiş yapıda tools/regress --full çalıştırılmalı. -->
Hesaplamayı hızlandıran sürüm: Metal ve OpenCL işleri sürücüden komut arabelleği başına daha az kilitle geçiyor ve bir
çevirici düzeltmesi bir matris çekirdeğinin hızını ikiye katlıyor. Ayrıca: katkıyla gelen bir aygıt kimliğiyle **Arc
B570** (bizim tarafımızda test edilmedi), 12-14. nesil hibrit Intel işlemciler için **HybridPM** ve yeni macOS
kurulumundan doğrulanmış sürücüye kadar götüren bir kurulum yardımcısıyla yeniden tasarlanan **IntelXe Manager**.

> [!WARNING]
> Deneysel. Tek bir makinede, tek bir kartla (Arc B580) test edildi; Arc B570 destekleniyor ama test edilmedi.
> İmzasız; gevşetilmiş SIP/AMFI ve OpenCore gerekir. Kurmadan önce çalışan bir EFI'yi USB bellekte hazır tutun.

> [!NOTE]
> Yapay zekâ desteğiyle geliştirildi: kodu, her derlemeyi gerçek donanımda test eden proje sahibinin yönetiminde
> Anthropic'in Claude Opus 5.5 modeli (High çaba düzeyi) yazdı.

### Öne çıkanlar

- **Daha hızlı Metal ve OpenCL.** Metal sürücüsü artık bir komut arabelleğinin gönderimi ile tamamlanması boyunca tek
  bir kilidi tutmuyor (lock V2): arka arkaya gönderilen komut arabelleklerinin her biri 18,2 yerine 11,1 µs sürüyor,
  Geekbench 7 Metal 89,0k -> yaklaşık 95,5k, OpenCL yaklaşık 81,7k -> 84-85k. Uygulamalarda varsayılan olarak açık;
  WindowServer ve sistemin arayüzü önceki yolda kalıyor. Bir uygulamanın ortamındaki `NVMTL_LOCK_V2=0` onu o uygulama
  için kapatır.
- **İndisli yüklemeler için bir çevirici düzeltmesi.** LLVM bazı toplamaları örtüşmeyen bitlerin `or`'u olarak yazıyor,
  Mesa ise yalnız toplamaları vektörleştiriyordu; çevirici artık böyle bir `or`'u yeniden toplamaya çeviriyor.
  clbench'in yazmaç bloklu matris çarpımı: 3778 -> 7130 GFLOP/s (Windows: 5456), CPU'da hesaplanan referansla
  doğrulandı.
- **Uygulamalar 5,1 değil 8,2 GB video belleği kullanabileceklerini görüyor** (`recommendedMaxWorkingSetSize`;
  `maxBufferLength` 4 GB).
- **Doğrudan gönderim (isteğe bağlı, varsayılan kapalı).** Bir uygulamanın kuyruğu sık iş gönderdiği sürece halkasında
  kurulu bir yuva tutuyor ve GPU sıradaki işi GuC'ye gidip gelmeden başlatıyor: küçük bir işin exec -> sinyal süresi
  46-52 -> 15-17 µs, Geekbench 7 Metal 97,2k, OpenCL 92,9k. Bir sonraki yeniden başlatmaya kadar açmak için:
  `sudo sysctl debug.intelxe.direct=1`.
- **Kart ve paket gücü.** `sysctl debug.intelxe.sensors` artık kartın ve paketin enerjisiyle (J) ortalama gücünü (W)
  de veriyor; kartın PMT telemetrisinden, Linux `xe_hwmon`'un okuduğu gibi okunuyor. Test makinesinde yazmaçlar boşta
  kart için 36,2 W, paket için 19,6 W; hafif yükte 40,4 W ve 23,3 W verdi (salt okunur yazmaç okumaları, 10 Kasım).
  Yeni alanlardan önceki metin değişmedi. Kartın ve paketin firmware'in ayarladığı güç sınırları da gösteriliyor; Linux
  `xe_hwmon` gibi GPU'nun pcode posta kutusundan okunuyor (test makinesinde: kart PL1 kapalı, PL2 190 W, kritik 380 W;
  paket 155 W, kapalı). Açılıştan sonraki birkaç dakika paketin enerji sayacı hızlı sayıyor; sürücü o sırada
  `package power n/a` gösterip kartın gücünü göstermeye devam ediyor.
- **PCIe ASPM raporu ve bir L1 anahtarı (deneysel, henüz bir B580'de çalışmadı).** `sysctl debug.intelxe.aspm`, GPU
  ile işlemcinin kök portu arasındaki her PCIe bağlantısının güç tasarrufu durumunu (ASPM) ve L1'in Linux'un
  denetimlerinden geçip geçmediğini gösteriyor. `sudo sysctl debug.intelxe.aspm_l1=1` L1'i bu bağlantılarda yalnız
  hepsi denetimlerden geçerse açıyor, `0` ASPM'i kapatıyor, `-1` (varsayılan) bağlantıları donanım yazılımının
  bıraktığı gibi bırakıyor. Siz yazmadıkça hiçbir şey değişmiyor; bir değişiklik bir sonraki yeniden başlatmaya kadar
  sürüyor. Amacı yukarıdaki boşta gücü düşürmek; düşürüp düşürmediği henüz ölçülmedi.
- **Safari'nin WebGPU'su ve Metal sürücüsü.** three.js'in WebGPU çizicisi çiziyor (r170 ve r181 test sayfaları:
  malzemeler, ortam haritaları, instancing, compute, gölgeler); çıktı pass'i argument buffer'da tutulan bir işaretçiden
  uniform okuyordu ve çevirici bunu sıfıra çeviriyordu. WebKit'in GPU'da doğruladığı WebGPU render bundle'ları artık
  çalışıyor: indirect command buffer'a çizim kodlayan gölgelendirici (`render_command`, WebKit'in `vsICB`'si) çevriliyor
  ve çizimler slot kayıtlarından `vkCmdDraw*Indirect` ile yapılıyor (kayıtlar VRAM'de; aynı durumdaki ardışık slotlar tek
  bir çoklu çizim: slot başına 11 µs yerine yaklaşık 0,03 µs GPU zamanı, doğrudan çizimler kadar). `var<workgroup>` kullanan WGSL compute
  gölgelendiricileri Safari'de `createComputePipeline`'da başarısız oluyordu: WebKit workgroup belleğini her 32 bitlik
  sözcüğe bayt işaretçisiyle bayt bayt yazarak sıfırlıyor ve Vulkan bunu ifade edemiyor; çevirici artık her baytı
  sözcüğünün oku-değiştir-yaz işlemi olarak yazıyor (bütünüyle sıfırlanan, `s = S{}`, bir Metal `threadgroup` struct
  parametresi de benzer bir nedenle reddediliyordu). Metal'in GPU zaman damgaları (aşama sınırlarında
  sayaç örnekleme, nanosaniye) uygulamalar için yeni; Safari Intel GPU'larda WebGPU'nun `timestamp-query`'sini sunmuyor
  (WebKit'in tercihi, bkz. Bilinen sorunlar).
- **nullmoth 2.9 birleştirildi.** Upstream'in 2.7.2 ile 2.9 arasında Metal sürücüsüne ve çevirmene dokunan 153
  commit'inden 42'si alındı (28'i bütün, 14'ü kısmen); DLSS, NVENC, uygulama profilleri, hibrit dizüstüler ve
  upstream'in isteğe bağlı özellikleri alınmadı (her birinin nedeni `nullmoth/CHANGES.md`'de). Bununla gelenler: her
  doku şeklinde LOD sorguları ve pull-model enterpolasyon (ikisi de aygıta sorularak yanıtlanıyor), bütün olduğunu
  kanıtlayan gölgelendirici önbelleği kayıtları (yarım kalmış dosya yeniden çevriliyor), büyük heap'lerin gerektikçe
  doldurulması, Metal gibi BGRA'nın RGBA bir pipeline'a çizilmesi, boyutu uyumlu biçimler arasında kopyalar, iç içe
  argument encoder'lar, GPU kalıcı olarak kaybolunca düzgün hata veren komut tamponları ve geliştiriciler için
  `nvmtl-air-dis`. Metal 4 giriş noktaları `NVMTL_METAL4=1` verilmedikçe kapalı.
- **Safari derlenmiş gölgelendiricilerini saklıyor.** WebKit'in GPU süreci `fsync` yapamadığı için Metal sürücüsünün
  gölgelendirici önbelleklerine her kayıt orada başarısız oluyordu ve Safari arayüz gölgelendiricilerini her açılışta
  yeniden derliyordu (her biri yaklaşık 2 sn). Önbellekler artık o sandbox'ın izin verdiği gibi yazıyor; ikinci açılış
  onları önbellekten alıyor.
- **AV1 kodlama varsayılan olarak açık.** AV1 kodlayıcı VideoToolbox'a HEVC ve H.264'ün yanında kaydediliyor. `vtencq`
  kodlama kalitesini kaynağa göre ölçüyor (PSNR): B580'de H.264 8 Mbit/s'de 43,3 dB, HEVC 8 Mbit/s'de 43,7 dB, AV1
  6 Mbit/s'de 42,3 dB (10 bit 41,6 dB), her kare çıkıyor.
- **Yeniden tasarlanan IntelXe Manager:** durum başlığı ve o an önemli olan tek eylemiyle bir Genel bakış sayfası;
  bir **kurulum yardımcısı** (OpenCore'u hazırlama, isterseniz Safari'nin ayarlarıyla aynı adımda; sürücü; EFI kext'i;
  GPU testi; bitti); OpenCore bir önyükleme yolu kaydetmemişse EFI bölümlerini seçmek için listeliyor, Safari'yi GPU'da
  ve Zink'i son sayfasından kuruyor; GPU testleri (Metal özellikleri, OpenGL, OpenCL, bit bit video çözme, kodlama
  kalitesi, hesaplama hızı, bant genişliği, akıcılık) ve uzun bir test; GPU saati, sıcaklık ve kareler için beş
  dakikalık grafikleriyle bir İzleme sayfası ve isteğe bağlı bir menü çubuğu öğesi; bir Güç ve uygulama sayfası;
  çözümleriyle açılış uyarıları; adımlarını gösteren bir kurulum; bir Hakkında penceresi.
- **Safari uygulamadan GPU'da.** Sürücü sayfasının *Safari ve WebKit* bölümü Metal sürücüsünün sistem birimi kopyasını
  kuruyor, denetliyor ve kaldırıyor, bir macOS güncellemesi onu sildiğinde bunu söylüyor; EFI sayfası o kopyanın
  gerektirdiği OpenCore `SecureBootModel = Disabled` ayarını yapıyor (yedekli, geri alınabilir).
- **Oturum açılışında denetim (isteğe bağlı):** yalnız ilgilenilmesi gereken bir şey varsa, örneğin bir macOS
  güncellemesi sistem birimi kopyasını sildiyse, tek bir pencere.
- **Yerel OpenGL uygulamaları tek tek Zink üzerinden (deneysel).** Zink paketindeki `cglzink-app.sh`,
  CGL/NSOpenGL kullanan bir uygulamayı OpenGL'i Zink'te çalışacak biçimde başlatan `~/Applications/X (zink).app`'i
  oluşturuyor: GZDoom (MAP01, sınırsız) Apple'ın OpenGL'inde ~1600, cglzink ile ~1910 fps.
  - **Bütün yerel OpenGL uygulamaları birden (deneysel, varsayılan kapalı):** Zink paketinde
    `sudo ./install.sh --global-gl on`. Bir LaunchAgent küçük `libcglzink-boot.dylib`'i oturumun
    `DYLD_INSERT_LIBRARIES` değişkenine koyuyor (sürücünün kurulumu AMFI'yi kapattığı için macOS onu geçiriyor); kütüphane
    her süreçte cglzink'i yükleyip yüklemeyeceğine bir kez karar veriyor: yalnız uygulama paketleri; Apple'ınkiler
    (Satranç hariç), tarayıcılar, Electron/Chromium uygulamaları, video oynatıcılar ve IntelXe Manager değil.
    `/Library/IntelXe/GL/cglzink-global.txt` bir uygulamayı reddediyor (`-paket.kimliği`) ya da ekliyor
    (`+paket.kimliği`). `sudo ./install.sh --global-gl off` kapatır, `--undo` önce onu kapatır. B580'de (11 Kasım):
    Satranç zink üzerinden çizdi; TextEdit, Hesap Makinesi, Sistem Ayarları, Safari ve 1Password Apple'ın OpenGL'inde
    kaldı; kapatınca Satranç Apple'ın OpenGL'ine döndü.
- **SSDT-ARCOFF kendini kartınıza uyarlıyor.** Kartın ACPI yolu paketle gelen tablonunkinden farklıysa `efi.sh`,
  uygulama ve Windows EFI aracı yolunuzu tablonun bir kopyasına yazıyor (üçünden de aynı baytlar): düzenlenecek `.dsl`
  ya da `iasl` yok.
- **Neyin yanlış olduğunu söyleyen raporlar.** Tanı raporu uyarılarla ve her birinde ne yapılacağıyla başlıyor;
  uygulamanın Rapor sayfası raporu oluşturuyor (kullanıcı olarak ya da yönetici kipinde), çalışırken adımı ve geçen
  süreyi, sonra bulduklarını gösteriyor ve sorun formunu rapor kimliği doldurulmuş olarak açıyor (test makinesinde
  yaklaşık 16 sn). Yeni bir sorun formu, *Intel GPU'm için destek*, yeni bir kartın gerektirdiği Linux ve macOS
  raporlarını istiyor; `--acpi` DSDT/SSDT tablolarını ekliyor (Windows lisansını taşıyan tabloları asla). macOS 26 bu
  tabloları artık yayımlamıyor; orada macOS raporunun `--acpi`'si hiçbir şey toplamıyor ve uygulama seçeneği griye
  çeviriyor; Linux raporunda tablolar var. `tools/clbench` aynı OpenCL çekirdeklerini Windows, macOS ve Linux'ta
  ölçüyor.

### Performans

Test makinesi (HybridPM'li i7-14700K, Arc B580, macOS 26.7.1), 9 Kasım 2026; GuC düşük gecikme ipucu her sütunda
kapalı. "0.1.3" sütunu 0.1.3'ün Metal sürücüsünün aynı gün ölçümü.

| | 0.1.3 | 0.1.4 | 0.1.4 + doğrudan gönderim (isteğe bağlı) | Windows (Intel'in sürücüsü) |
|---|---|---|---|---|
| Geekbench 7 Metal | 89,0k | 95,4k-95,7k | 97,2k | Vulkan 111,1k |
| Geekbench 7 OpenCL | ~81,7k | 84,1k-85,5k | 92,9k | 108,5k |
| clbench `sgemm_reg` | 3778 GFLOP/s | 7130 GFLOP/s | | 5456 GFLOP/s |
| Arka arkaya komut arabellekleri | her biri 18,2 µs | her biri 11,1 µs | | |
| Küçük bir iş, exec -> sinyal | | 46-52 µs | 15-17 µs | |

GuC düşük gecikme ipucu açıkken 0.1.4'ün daha önceki bir test derlemesi (lock V2'den önce) Geekbench 7 Metal 97,7k ve
OpenCL 90,1k-92,5k aldı: ipucunun varsayılan olarak kapalı olması (Bilinen sorunlar) biraz hıza mal oluyor; doğrudan
gönderim (isteğe bağlı) OpenCL'i 92,9k'ye geri getiriyor.

Geekbench skorları oturumdan oturuma birkaç yüzde oynuyor (0.1.3'ün README'si 5 Kasım'dan Metal 92,9k / OpenCL 86,9k
veriyordu); farklı günlerin sayılarını değil, bir tablonun sütunlarını karşılaştırın.

### Yeni donanım

- **Arc B570 (8086:E20C).** Kext'ler, `install.sh`, uygulama, `efi.sh` ve Windows EFI aracı onu kabul ediyor; Bu Mac
  Hakkında onu adıyla gösteriyor. B580'in yongası (BMG-G21), daha az Xe çekirdeğiyle; sürücü bunu sigortalardan
  (fuse) okuyor. **Bizde B570 yok, onda çalıştırmadık.** Uygulamanın GPU testi onu bir karttan ölçülmüş değerlere
  değil, Intel'in belirtimine (11,52 TFLOP/s, 380 GB/s) göre değerlendiriyor. Elinizde varsa lütfen deneyin ve çalışsa da çalışmasa da tanı
  raporuyla (`tools/report/collect-macos.sh`) bir sorun açın. Aygıt kimliği için `@1964356263`'e teşekkürler (PR #2).
- **Hibrit Intel işlemciler için HybridPM.kext (12-14. nesil, E çekirdekli Alder Lake / Raptor Lake).** macOS'un
  işlemci güç yönetimi bu işlemcilerin P çekirdeklerini sınırlıyor ve tam yüklü çekirdekleri 800 MHz'de tutabiliyor;
  GPU sürücüsü komut arabelleği başına çok CPU işi yaptığı için GPU da yavaş görünüyor. Test makinesinde (i7-14700K)
  tek bir CPU iş parçacığı iki kattan fazla hızlandı, Geekbench'in GPU skorları yaklaşık üçte bir arttı. İsteğe bağlı;
  `-efi.zip`'te ve macOS paketinde; işlemci gerektiriyorsa uygulamanın EFI sayfası, `efi.sh` ve Windows EFI aracı onu
  4. aşamada ekliyor (masaüstü ve dizüstü modelleri, U ve P modelleri de).
  Bir Lilu eklentisi (Lilu pakette yok); Core Ultra'ya, E çekirdeği olmayan ve daha eski işlemcilere
  dokunmuyor (yalnız nedenini günlüğe yazıyor). Paketteki `hpmstat` çekirdek başına saatleri ve paket gücünü gösteriyor.

### Paketler

| Dosya | Ne için | Nerede açılır |
|---|---|---|
| `IntelXe-Manager-0.1.4.zip` | IntelXe Manager uygulaması (macOS 15 ve sonrası): kurulum yardımcısı, kurulum, EFI, Safari, Zink, testler, raporlar | macOS |
| `intel-gpu-macos-driver-0.1.4-tahoe.zip` | macOS 26 Tahoe (26.7.1'de test edildi) | macOS |
| `intel-gpu-macos-driver-0.1.4-sequoia.zip` | macOS 15 Sequoia (aynı kaynaklar; Sequoia'da yeniden test edilmedi) | macOS |
| `intel-gpu-macos-driver-0.1.4-efi.zip` | OpenCore parçaları: `IntelXe.kext` (yeni), `SSDT-ARCOFF`, `HybridPM.kext` (yeni, isteğe bağlı), Windows için `IntelXe-EFI.ps1` | her sistem |
| `intel-gpu-macos-driver-0.1.4-zink-gl.zip` | isteğe bağlı: LWJGL 3 oyunları (Minecraft Java) için Mesa'nın Zink'i üzerinden OpenGL; yeni: yerel OpenGL uygulamaları için `cglzink-app.sh` (deneysel) | macOS |

Sağlama toplamları: `intel-gpu-macos-driver-0.1.4.sha256`. Kurulum kılavuzu: her macOS paketinde `README-INSTALL.tr.md`
ve [depoda](https://github.com/yusufklncc/intel-gpu-macos-driver/blob/v0.1.4/release/README-INSTALL.tr.md)
(İngilizcesi: `README-INSTALL.md`).

### 0.1.3'ten yükseltme

1. Paketi kurun (uygulamada v0.1.4'ü indirin, ardından *Bu paketi kur*; ya da `sudo ./install.sh --apply`).
   `IntelXeFB.kext`, `NMXAccel.kext` (`Info.plist`'i: B570'in kimliği), Metal sürücüsü ve video kodlayıcı (AV1
   varsayılan olarak açık) yeni; Mesa ve video kod çözücüler 0.1.3'ünkiler.
2. Yeniden başlatmadan önce **EFI'deki `IntelXe.kext`'i değiştirin** (uygulamanın EFI sayfası, macOS'ta
   `sudo ./efi.sh --apply`, Windows'ta `IntelXe-EFI.ps1` ya da elle; `config.plist` girdisi olduğu gibi kalır). B570'in
   kimliğini, GPU saati, sıcaklık ve güç okumalarını, uygulamanın Güç sayfasının yazdığı ayarları, doğrudan gönderimi ve
   deneysel ASPM anahtarını getiriyor.
3. **Hibrit Intel işlemci mi (E çekirdekli 12-14. nesil)?** Uygulamanın EFI sayfası, `efi.sh` ve `IntelXe-EFI.ps1`,
   2. adımda `HybridPM.kext`'i ekliyor; `Kernel > Add` girdisi **`Lilu.kext`'in altına** giriyor. `IntelXe-EFI.ps1`
   çalıştığı bilgisayarın işlemcisine bakıyor: onu EFI'yi açacak bilgisayarda çalıştırın. HybridPM Lilu gerektirir, bu
   sürümde Lilu yok: çoğu EFI'de VirtualSMC için zaten var; yoksa
   [acidanthera/Lilu](https://github.com/acidanthera/Lilu/releases)'dan alıp 2. adımı yeniden yapın. Elle eklemek için
   kılavuzun *Hibrit Intel işlemciler* bölümünde girdisi ve nasıl denetleneceği (`sysctl debug.hybridpm.why`) var.
4. Safari için sistem birimi kopyasını kurduysanız bu paketinkini de kurun (uygulamanın Sürücü sayfası, *Safari ve
   WebKit*; ya da `sudo ./system-volume/ssv-install.sh --apply`), Safari yeni Metal sürücüsünü alsın.
5. Yeniden başlatın.

0.1.4'ün ilk test derlemelerinin açtığı GuC düşük gecikme ipucu isteğe bağlı: uygulamanın *Güç ve uygulama* sayfası
(*Uygulamalar için hızlı GPU yanıtı*) ya da `/Library/GPUBundles/NVMTLDriver.low-latency`. Ne kazandırdığı Performans'ta,
neden kapalı olduğu Bilinen sorunlar'da.

0.1.2 ya da daha eskisinden geliyorsanız önce kılavuzun yükseltme bölümünü izleyin.

### Düzeltilenler

- Windows raporu yeniden boyutlandırılmış BAR'ı görmüyordu (WMI yalnız 4 GB altındaki belleği listeliyor) ve onu olan
  her kartta "Resizable BAR yok" diyordu; artık Windows'un atadığı aralıkları okuyor. Özeti bir şey toplanamadığında
  bozuluyordu, `dxdiag` de hiç zamanında bitmiyordu.
- macOS raporu Metal sürücüsünü yalnız 0.1.2 öncesindeki adıyla arıyor, kurulu olanı görmüyordu.
- Root olarak çalışan macOS raporu, OpenCore'un açılışta kirli (dirty) olarak bıraktığı bir EFI bölümünden
  `config.plist` toplamıyordu (macOS böyle bir bölümü yalnız okuma-yazma bağlıyor, salt okunur bağlama başarısız
  oluyordu); artık onu `mount_msdos` ile salt okunur bağlıyor ve sonra ayırıyor.
- Metal aygıtına `supportsPlacementSparse` soran bir uygulama çöküyordu (tanınmayan seçici, yakalanmamış istisna);
  artık NO yanıtını alıyor. Aygıt, Metal sürücüsünün boş bıraktığı diğer özellikleri de yanıtlıyor: `location` Slot
  (önce Unspecified), `maxTransferRate` kök portun bağlantısından (test makinesinin Gen4 x8 bağlantısı için
  15753846152 B/s; önce 0), `supports32BitFloatFiltering` ve `supports32BitMSAA` Vulkan sürücüsünün bildirdiği gibi
  YES, `maxArgumentBufferSamplerCount` örnekleyici yığınının 2047'si. 10 Kasım'da B580'de, yeni Metal sürücüsü yalnız
  test süreci için yüklenerek denetlendi; `mtl_f32filter` 32 bit float süzmeyi doğruluyor (PASS).
- Bir gölgelendiricinin örneklediği küp dokularından texel okumaları (`read()`) yanlış veri döndürüyordu: her texel
  yanlıştı (1-5. yüzler 0, 0. yüz 4. yüzü okuyordu), küp dizileri çevrilmiyordu, 1. ve 2. mip düzeyleri 0. düzeyi
  okuyordu. `mtl_cube_read` artık B580'de her durumda geçiyor (float, tamsayı ve küp dizisi dokuları, 0-2. düzeyler ve
  bir okuma-yazma küpü; 10 Kasım, yeni Metal sürücüsü yalnız test süreci için yüklenerek).
- Safari'nin WebGPU'su: deferredRendering örneği "Fragment function failed creation" hatası veriyordu, G-buffer
  okumaları da sıfır dönüyordu. WebKit'in gölgelendirici derleyicisi argüman arabelleğindeki bir dokuyu 64 bit kaynak
  kimliği olarak okuyor; çevirici bunu doku olarak almıyordu. Safari'nin B580'de derlediği 88 WebGPU gölgelendirici
  kütüphanesinin hepsi artık çevriliyor (önce biri başarısızdı) ve örnek B580'de Safari'de çiziyor (10 Kasım). Bir dal ya da select ile seçilen doku artık seçilen dokuyu okuyor (önce bağlı başka bir
  dokuyu ya da sıfır); yakalanan gölgelendiricilerin hiçbiri bunu yapmadığı için bu kısım aygıtta test edilmedi.

### Geliştiriciler için

- GuC bir bağlamı sıfırladığında ya da bir iş hiç başlamadığında `IntelXe.kext` hata yazmaçlarını, her render/compute
  motorunun halka durumunu ve bekleyen işi olan kuyrukları G2H günlüğüne yazıyor; takılan bir motoru zamanlama
  yapmayan bir GuC'den ayırmak için. Artık BAR penceresine girip çıkan BO taşımalarını, TLB geçersizlemelerini (ve
  birinin sürüp sürmediğini) ve hata veren kuyruğun VM'sini de yazıyor: son unbind, remap ve bind'ı, sayfa
  tablolarının kuyruğun son geçersizlemesinden sonra değişip değişmediğini.
- **Platform tanımları**, Linux `xe_pci.c`'deki gibi (`kernel/IntelXe/xe_platform.*`): her aygıt kimliği listesi için
  IP sürümleri, bayraklar, motorlar, yazılım (firmware) adları ve sürücünün o aile için hâlâ eksikleriyle bir girdi.
  `IntelXe.kext` platformunu açılışta bir kez buluyor ve günlükte adını veriyor (`IntelXe: 8086:e20b: BMG-G21, graphics
  20.01, media 13.01, discrete`); yalnız BMG-G21 (B580, B570) destekleniyor, oradaki diğer 17 girdi (Gen12'den Panther
  Lake'e, bir de BMG-G31) tek bir günlük satırıyla reddediliyor. XeProbe aynı tabloyu okuyor. Bu satır dışında B580
  eskisi gibi çalışıyor. Diğer ailelerin her birinin hâlâ neye ihtiyacı olduğu: `docs/design/DESIGN-platforms.md`.
- **Kullanıcı çitleri (user fences)**, `xe`'deki gibi: exec ve VM_BIND'da `DRM_XE_SYNC_TYPE_USER_FENCE` ve
  `DRM_IOCTL_XE_WAIT_USER_FENCE`; Intel'in compute runtime'ı ikisini de gerektiriyor (önceden reddediliyorlardı). Bir
  bind'ın kullanıcı çiti bind tamamlandığında, geç tamamlansa da yazılıyor. `GEM_CREATE` uzantı zinciri `xe_bo.c`'nin
  denetlediği gibi denetleniyor. Mesa'nın Vulkan sürücüsü kullanıcı çitlerini kullanmıyor; Metal, Vulkan ve OpenGL
  etkilenmiyor. uAPI eşdeğerlik tablosu (`docs/parity/`) artık 182 xe uAPI ögesinin 99'unu ve 16 ioctl'in 13'ünü
  sayıyor (önce 77 ve 11); compute runtime için kalan ögeler 35'ten 24'e indi.
- `debug.intelxe.jobtime` (varsayılan kapalı): her işin aşamaları GPU zaman damgalarıyla. `debug.intelxe.sensors`:
  GT saati, paket ve VRAM sıcaklıkları ve (bkz. Öne çıkanlar) kart ve paket enerjisi ve gücü, herkes okuyabilir.
  `debug.intelxe.aspm` / `debug.intelxe.aspm_l1`: bkz. Öne çıkanlar; denetimler ve bağlantıların hangi sırayla
  değiştirildiği `kernel/README.md`'de.
- Çevirici, gevşek (relaxed) bir threadgroup atomiğini (add, min, max, and, or, xor) gevşek olarak yazıyor; Mesa artık
  her birinin çevresinde paylaşılan yerel belleği çitlemiyor (clbench `hist256` döngüsü artık IGC'ninkiyle aynı).
- Testler: `mtl_order_stress` (kuyruklar ve iş parçacıkları arasında komut arabelleği sırası), `direct_lat`,
  `mtl_lat split`, `ufence` (GPU'da kullanıcı çitleri: her motor, bekleme işlemleri, maskeler ve zaman aşımları, bind
  çitleri); platform tablosu (`kernel/IntelXe/tests/platform_test.cpp`) ve uAPI argüman denetimleri
  (`kernel/IntelXe/tests/uapi_test.cpp`) için GPU'suz ana makine testleri. Çeviricinin birim ve tümleşik testleri
  geçiyor (bir düzeltme: adres uzayı bozuk bir tipli işaretçi genel diye okunmuyor, reddediliyor); `xlate_check` bir
  girdiyi `newFunctionWithName:`'in yaptığı gibi çeviriyor. 10 Kasım'da yeni: `mtl_cube_read` (küp dokularının her
  yüzünün, diliminin ve düzeyinin her texeli), `mtl_props` (Metal sürücüsünün yanıtladığı aygıt özellikleri) ve
  `mtl_f32filter` (32 bit float dokuların doğrusal süzülmesi), `nullmoth/build/build-intelxe.sh tests` ile derleniyor;
  ana makine testleri `pmt_test` (enerji yolu: konumlar, birimler, sayaç taşmaları, ortalama güç) ve `aspm_test` (ASPM
  kuralları, değişikliklerin sırası ve rapor için 46 denetim).
- **Tek bir desteklenen aygıt listesi:** `data/platforms.json` `"supported"` sürücünün bağlandığı kartları (B580, B570)
  tutuyor; `tools/parity/devices.py` herhangi bir kopya farklıysa hata veriyor (kext eşleşmeleri, `install.sh`,
  `efi.sh`, uygulama, Windows EFI aracı, platform testi, clbench); `release/release.sh` ve `release/test-efi-flow.sh`
  onu çalıştırıyor. Uygulamanın GPU testi beklediği değerleri bu listeden PCI aygıt kimliğiyle alıyor (başka bir GPU
  değerlendirme almıyor; önce adında "Arc" geçen her GPU B580'in değerlerini alıyordu); Güç sayfasının varsayılan
  aralığı çekirdeğin bildirdiği saat aralığından oluşuyor (B580'de "Default (1200-2850 MHz)"). `clbench` ve `cl_lat`
  OpenCL GPU'sunu üretici kimliğiyle seçiyor, kodlayıcı test yolu kodlayıcılarını kartın modeliyle adlandırıyor. Yeni bir
  ailenin çekirdek dışında nelere ihtiyacı olduğu: `docs/design/DESIGN-platforms.md` 4. bölüm. Zink ikili dosyalarının
  kaynak kaydı `zink-gl/src/mesa-zink.diff` artık yalnız Zink'e özel bir derlemenin derlediklerini tutuyor (IntelXe
  adlandırmasından önceki ANV değişikliklerini hâlâ taşıyordu).
- 10 Kasım öğleden sonrasından itibaren: `mtl_timestamps` (her sınırda sayaç örnekleme, komut arabelleğinin GPU
  süresine karşı), `mtl_gpu_icb` (bir kernel'in ve bir vertex gölgelendiricisinin indirect command buffer'a kodladığı
  çizimler; B580'de ve Apple GPU'sunda 6/6), `mtl_icb_cost` (indirect command buffer slotu başına GPU süresi, doğrudan
  çizime karşı), `mtl_dirty_stress` (nesne silmeleri boyunca bağlamalar), `vtencq` (kodlama
  kalitesi), ana makine testi `pcode_test` (güç sınırı çözümleme). **`tools/regress`** test makinesindeki donanım
  denetimlerini tek komutla çalıştırıp tek bir tabloyla bitiriyor (`regress.sh`; `--full` Safari'deki WebGPU sayfalarını ve
  Geekbench'i ekliyor; `sweep` sayfası diğer sayfaların ulaşmadığı 18 WebGPU özelliğini deniyor); `selftest.sh` her kararı kayıtlı çıktılara karşı denetliyor. Kext platform başlangıç satırını
  `IntelXePlatform` kayıt özelliği olarak da yayımlıyor.
- Araçlar: `vcbench` bir HEVC kümesinin içinde çalıştırılınca çöküyordu (H.264 tanımını arıyordu); düzeltildi,
  `VCB_DUMP=<dizin>` karşılaştırma için her resmi yazıyor. B580'de (10 Kasım) H.264 2K, HEVC 2K ve HEVC 4K donanım
  resimleri her karede Apple'ın yazılım çözücüsününkiyle aynı; H.264 4K (tam aralıklı bir akış) çözücünün kendi
  biçiminde aynı, video aralığı istendiğinde ise donanım dönüştürüyor, Apple'ın yazılım H.264 çözücüsü dönüştürmüyor.
  `dmode W H [Hz]` ekran kipini kalıcı olarak değiştiriyor (süreç bitince geri dönüyordu) ve yenileme hızını
  seçebiliyor.
- `release/release.sh` bir sürümü yayımlanmadan önce denetliyor (sürüm, etiket, paketler ve sağlama toplamları,
  içlerindeki sürümler, notlar, kimlik taraması) ve yalnız `--publish` ile yayımlıyor. İçine girenlerin (kod, betikler,
  şablonlar, paketleyici) son değişikliğinden önce derlenmiş paketleri reddediyor.

### Bilinen sorunlar

- **Uzun boşta kalmadan sonra GPU hataları (nedeni açık).** GuC düşük gecikme ipucu açıkken, uzun bir boşta kalmanın
  ardından gelen ilk ağır çalışma 6 test koşusunun 3'ünde bir `MEMORY_CAT_ERROR`, bir GT sıfırlaması ve yeniden
  oynatılan bir WindowServer kuyruğuyla bitti; ipucu kapalıyken 4 koşunun 0'ında. Bu yüzden ipucu varsayılan olarak
  kapalı. Nedeni henüz bilinmiyor; artık hatadan önceki BO taşımalarını, TLB geçersizlemelerini ve VM'nin son unbind'ını
  da kaydeden yeni motor dökümü onu bulmak için. Görürseniz lütfen bir rapor gönderin.
- **Doğrudan gönderim varsayılan olarak kapalı**; daha uzun gözetimsiz çalışmalardan (güç, boşta kalma, uyku) sonra
  açılacak. Yalnız bir sysctl, bu yüzden bir sonraki yeniden başlatmada kapanır.
- **Geekbench'in Background Blur ve Super Resolution testleri** GPU saatine duyarlı: ipucu kapalıyken açık olduğundan
  düşük puan alıyorlar.
- **Windows EFI aracının yeni adımları** (`HybridPM.kext`, başka bir yola uyarlanan SSDT-ARCOFF) macOS'ta `efi.sh`'e
  karşı bayt bayt denendi ama henüz Windows'ta çalışmadı; araç henüz ardından bir bilgisayarın açıldığı bir EFI de
  hazırlamadı. Her planı onaylamadan önce okuyun.
- **B570 test edilmedi**, yukarıdaki gibi.
- **PCIe ASPM (`debug.intelxe.aspm_l1`) henüz bir B580'de çalışmadı.** Test etmiyorsanız varsayılanında bırakın;
  rapor (`debug.intelxe.aspm`) yalnız okuyor.
- **Safari WebGPU'nun `timestamp-query`'sini Intel GPU'larda sunmuyor:** WebKit x86_64'te aygıt adına bakıyor
  (`HardwareCapabilities.mm`) ve Metal sürücüsüne hiç sormuyor. WebKit aynı tercihi Apple'ın kendi sürücüleri dahil
  her Intel GPU için yapıyor. three.js r187'nin Inspector'ı (threejs.org WebGPU örneklerinin çoğunda sağ üstteki FPS
  paneli) renderer özelliğe baktıktan sonra zaman damgası izlemeyi açıyor; bu sayfalar özellik yokken `createQuerySet`
  çağırıp Intel GPU'lu Safari'de hiçbir şey çizmiyor; Inspector'sız örnekler çiziyor (11 Kasım, B580: Inspector'lı 7
  örneğin 7'si siyah, Inspector'sız 3'ün 3'ü ve WebGPU örneklerinin 8'i 8'i doğru).
- **GPU'da kodlanan indeksli çizimler** CPU'nun o slota kodladığı indeks tamponunun içini ve onun ilkel türünü
  göstermeli (çekirdek Vulkan ikisini de GPU belleğinden alamıyor) ve CPU'nun indeksli çizim kodladığı bir slot
  gölgelendiriciden yalnızca indeksli çizim alıyor; diğerleri atlanıp log'a yazılıyor. WebKit'in doğrulama
  gölgelendiricisi bunlara her zaman uyuyor. Gölgelendiricinin yazabildiği bir indirect command buffer'da durumu
  (pipeline, tamponlar, derinlik ya da raster durumu) önceki slottan farklı olan bir slot hâlâ yaklaşık 2 µs GPU zamanı
  tutuyor (ANV tek bir çizimin her dolaylı parametresini ayrı bir yazmaç yüklemesiyle okuyor); aynı durumdaki slot
  dizileri slot başına yaklaşık 0,03 µs.
- **Zink üzerinden yerel OpenGL uygulamaları** (`cglzink-app.sh`) deneysel: IOSurface'e çizim (tarayıcılar) ve CGL
  pbuffer'ları henüz desteklenmiyor.
- **Bütün OpenGL uygulamaları için anahtar** (`install.sh --global-gl on`) deneysel ve varsayılan olarak kapalı; B580'de
  yalnız birkaç uygulamayla çalıştı. macOS, LaunchAgent'ını Giriş Öğeleri'nde "IntelXeGL" olarak gösteriyor (değişkeni
  yalnız iki kütüphane de yerindeyken koyan küçük bir yardımcı). Oturumun başlattığı her uygulamaya bir kütüphane ekliyor: `/Library/IntelXe/GL`'yi elle
  silmeden önce kapatın (`sudo ./install.sh --global-gl off`), çünkü eklenen kütüphane eksikse hiçbir uygulama
  açılmaz.
- Giriş ekranında ve kilit ekranında macOS parola alanının imlecini ve cam malzemesini her karede yeniden çiziyor; 180
  Hz bir monitörde saniyede yaklaşık 140 kare. Bu macOS'un kendi animasyonu; GPU zamanını yalnız o ekran açıkken
  harcıyor (ölçümleri oturum açıkken yapın).
- Gerisi 0.1.3'teki gibi: DisplayPort'ta tek monitör; 2560x1440 dışındaki monitörler için HiDPI boyutları test
  edilmedi; tutulan bir açılış Apple logosunda kalıyor (OpenCore seçicisinde Reset NVRAM).

### Teşekkürler

- Arc B570 aygıt kimliği için `@1964356263` (PR #2).
- HybridPM'in üzerine kurulduğu [Lilu](https://github.com/acidanthera/Lilu) (acidanthera) (BSD-3-Clause; bildirimi
  kext'in içinde ve `LICENSES/` altında).
- Her sürümde olduğu gibi: nullmoth (NullMoth Systems), metal2vulkan (Anees Iqbal), Linux `xe` ve i915, Mesa, FFmpeg
  ve Emil J. Tywoniak'ın Xe2 VDEnc çalışması; README'ye bakın.
