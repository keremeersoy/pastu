# Hayalimizdeki Clipboard Uygulaması: Ürün ve Yol Haritası

> **Uygulama adı: Pastu** (karar: 2026-11-21). İsim analizi için `docs/03-isim-analizi.md` dosyasına bak.

2026-11-21 · @kerem ersoy

Bu belge, önceki pazar raporunun boşluklarından yola çıkarak sıfırdan bir Mac clipboard uygulamasının ne olması gerektiğini, neyle yazılacağını ve nasıl hayata geçirilebileceğini anlatıyor.

## Vizyon

**Tek cümle:** Kopyaladığın her şeyi yerelde saklayan, klavyeyle anında açılan, kart tabanlı ve görsel bir clipboard katmanı; çekirdeği ücretsiz ve açık kaynak, gizlilik varsayılan.

**Neden şimdi:** Apple Spotlight'a clipboard geçmişi ekleyerek basit ihtiyacı ücretsiz karşıladı; ama [pinleme yok ve geçmiş paneli için şifre koruması yok](https://dev.to/jrw0ng/macos-tahoe-has-built-in-clipboard-history-heres-what-its-still-missing-for-developers-2026-4eko). Paste abonelik getirdi ve [App Store'da tepki aldı](https://apps.apple.com/be/app/id967805235?l=en-gb). Maccy hızlı ama sade. Aradaki alan boş.

### 5 tasarım ilkesi

1. **Hız her şeyden önce.** Bu ürün gün boyu açık kalan bir menu bar aracı; bir geliştirici [SwiftUI menu bar uygulamasının boşta yaklaşık 12 MB RAM kullandığını, benzer bir Electron uygulamasının 80-120 MB](https://dev.to/hamzan/why-i-built-a-15mb-swiftui-menu-bar-app-instead-of-reaching-for-electron-1boe) kullandığını yazıyor. Panel klavyeyle anında açılmalı.
2. **Gizlilik varsayılan.** Veri yerelde kalır, parola yöneticilerinin gizli işaretlediği kopyalar [üç satırlık bir kontrolle](https://dev.to/eduardo_revillavaquero_0/i-shipped-a-clipboard-manager-inside-the-macos-app-store-sandbox-heres-what-works-and-what-5a30) hiç geçmişe girmez.
3. **Sade varsayılan, derinlik isteğe bağlı.** İlk açılışta Maccy kadar sade; pinboard, snippet, queue ve OCR kullanıcı istedikçe açılır.
4. **Abonelik yok.** Çekirdek özellikler sonsuza kadar ücretsiz ve açık kaynak; gelir yolu ayrı (Sürdürülebilirlik ve para bölümü).
5. **Mac'e ait hissettirmeli.** macOS Tahoe'nun Liquid Glass dilini, sistem renklerini ve standart kısayolları kullanır; "web uygulaması gibi" hissettirmez.

## Özellikler: üç katman

Pazar raporundaki boşlukları üç katmana ayırdım: ilk sürümde olması gerekenler, seni ayıran özellikler ve sonra gelecek büyük işler. Yeni bir bulgu: Paste Haziran 2026'da yerel MCP desteği ekledi, yani rekabet hızlı ilerliyor.

| Katman | Özellik | Dayanak |
| --- | --- | --- |
| 1. Çekirdek (v1) | Kısayolla anında açılan panel, yazarak bulan (fuzzy) arama, ⌘ 1-9 ile hızlı yapıştırma, Tab ile tür filtresi | [ClipKitty'nin kısayol düzeni](https://jul-sh.github.io/clipkitty/) |
| 1. Çekirdek (v1) | Metin, link, resim, dosya, e-posta ve renk geçmişi; türe göre filtre | [Raycast'in filtre türleri](https://manual.raycast.com/clipboard-history.md) |
| 1. Çekirdek (v1) | Pin'ler geçmişten ayrı ve silinmez | [Maccy kullanıcı şikayeti](https://alternativeto.net/software/maccy/about/), [Glyphs](https://github.com/devoctane/glyphs) |
| 1. Çekirdek (v1) | Gizli işaretli kopyaları kaydetmeme, uygulama istisnası, her şey yerelde | [nspasteboard.org kuralı](https://dev.to/eduardo_revillavaquero_0/i-shipped-a-clipboard-manager-inside-the-macos-app-store-sandbox-heres-what-works-and-what-5a30) |
| 1. Çekirdek (v1) | Kopyalanan uygulamanın adı ve ikonu, buna göre filtre | [Clipbara kaynak uygulamaya göre arama](https://github.com/mobrava/Clipbara/wiki) |
| 2. Fark yaratan (v1.x) | Paste Queue: çok şey kopyala, sırayla yapıştır | [CleanClip](https://cleanclip.cc/gb/), [PastePal](https://apps.apple.com/au/app/id1503446680?l=en-au), [ClipKeep](https://apps.apple.com/us/app/clipkeep/id6757108580) |
| 2. Fark yaratan (v1.x) | Snippet'ler ve yer tutucular | [SaneClip](https://project-awesome.org/r/sane-apps-SaneClip) |
| 2. Fark yaratan (v1.x) | Ekran görüntüsünde OCR ile arama; işlem cihaz üzerinde | [Apple Vision belgesi](https://developer.apple.com/tutorials/data/documentation/vision/recognizing-text-in-images.md), [PasteDaemon](https://alternativeto.net/software/pastedaemon/about/) |
| 2. Fark yaratan (v1.x) | Şifreli saklama ve Touch ID kilidi | [SaneClip](https://project-awesome.org/r/sane-apps-SaneClip) |
| 2. Fark yaratan (v1.x) | Kopyalanan şeye göre eylem (JSON biçimlendir, renk dönüştür) | [ClipMason](https://dev.to/eduardo_revillavaquero_0/i-shipped-a-clipboard-manager-inside-the-macos-app-store-sandbox-heres-what-works-and-what-5a30), [Pasteratops ClipSense](https://apps.apple.com/us/app/pasteratops/id6468918186?mt=12) |
| 3. İleri (v2) | iCloud senkron, iPhone/iPad uygulaması | [Paste](https://apps.apple.com/app/paste-clipboard-manager/id967805235), [PastePal](https://apps.apple.com/au/app/id1503446680?l=en-au) |
| 3. İleri (v2) | Yerel MCP sunucusu: AI araçları izin verdiğin kopyaları arayabilsin | [Paste MCP, MIT lisanslı köprü](https://github.com/pasteapp/paste-mcp), [9to5Mac](https://9to5mac.com/2026/06/02/paste-launches-mcp-support-to-connect-your-clipboard-history-to-ai-tools/) |
| 3. İleri (v2) | Cihaz üzerinde anlamsal arama ("geçen hafta kopyaladığım fatura linki") | [Yank](https://www.producthunt.com/p/yank-2/yank-4), [Copi](https://github.com/pixlox/copi) |
| 3. İleri (v2) | Paylaşılan pinboard (takım/aile) | [Paste Shared Pinboards](https://apps.apple.com/app/paste-clipboard-manager/id967805235) |

**Kural:** Bir özellik "herkesin istediği ama kimsenin iyi yapmadığı" değilse ilk sürümün dışında kalır. Hassas veri görüntülenen bir uygulama olduğu için, MCP gibi özelliklerde bir Product Hunt yorumcusu [gizli verilerin aynı istisna kurallarıyla filtrelenip filtrelenmediğini](https://www.producthunt.com/p/paste/paste-mcp-ai-tools) soruyor; bunun cevabı tasarımda baştan olmalı.

## Arayüz ve deneyim

Bu bölümdeki kararlar benim yorumum; her birinin yanında dayandığım örnekleri ekledim. Pazarda iki ana düzen var: alttan açılan geniş kart şeridi ([Paste](https://apps.apple.com/app/paste-clipboard-manager/id967805235), [Clipbara](https://github.com/mobrava/Clipbara/wiki) ve [Pastr](https://github.com/iamngoni/Pastr) bu düzende) ve Raycast tarzı liste + önizleme ([Clipin](https://github.com/ccfco/Clipin) iki sütunlu düzen kullanıyor).

**Karar:** İki mod, aynı veri. Varsayılan mod liste + önizleme (hızlı tarama, klavye odaklı), isteyen için alttan kart şeridi (görsel içerik, tasarımcılar için).

| Karar | Ne | Dayanak |
| --- | --- | --- |
| Açılış | Tek global kısayol; örnekler: ⌥Space ve ⌘⇧V | [ClipKitty ⌥Space](https://jul-sh.github.io/clipkitty/), [Clipbara ⌘⇧V](https://github.com/mobrava/Clipbara/wiki) |
| Pencere türü | NSPanel; başka uygulamanın odağını çalmamalı | [Maccy 2.0, AppKit + NSMenu'den SwiftUI + NSPanel'e geçti](https://github.com/p0deje/Maccy/releases) |
| Klavye akışı | Yaz → ok tuşları → Return yapıştır; Tab tür filtresi; ⌘ 1-9 atlama; Esc kapat | [ClipKitty](https://jul-sh.github.io/clipkitty/) |
| Önizleme | Sağda canlı önizleme; boşluk tuşu ile Quick Look | [Clipbara Quick Look](https://github.com/mobrava/Clipbara/wiki) |
| Pin'ler | Panelde ayrı bölüm, üstte | [Maccy şikayeti](https://alternativeto.net/software/maccy/about/) |
| Gizlilik göstergesi | Gizli kopya atlandığında küçük bir işaret | Benim önerim: kullanıcı "neden şifrem gelmedi?" demesin |
| Malzeme | Liquid Glass sadece panel kabuğunda, içerikte değil; cam üzerine cam koyma | [Liquid Glass kılavuzu](https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo), [referans](https://github.com/conorluddy/LiquidGlassReference) |
| Standart bileşenler | Sistem bileşenleri Xcode 26 ile yeniden derlenince Liquid Glass'ı otomatik alır | [Apple "Adopting Liquid Glass"](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass.md) |
| İlk açılış | 3 adım: kısayolu göster, izinleri iste, bir kopya dene | Benim önerim; [bir geliştirici ilk açılışta izin isteyen uygulamanın kötü ilk izlenim bıraktığını yazı](https://mjtsai.com/blog/2025/05/12/pasteboard-privacy-preview-in-macos-15-4)yor |

**Panel düzeni (varsayılan mod):** Üstte arama kutusu ve tür filtreleri (Hepsi, Metin, Link, Resim, Dosya, Renk). Solda tarih gruplu liste, en üstte pin'ler. Sağda seçili öğenin önizlemesi, kaynak uygulama, zaman ve kullanılabilir eylemler (düz metin yapıştır, pin'le, sil). Altta tek satır kısayol ipucu.

## Teknoloji: dil, mimari ve izinler

**Karar:** Mac'e yerel yaz: Swift 6 + SwiftUI, pencere ve izin işleri için AppKit. Bu pazarda adı geçen hızlı açık kaynak uygulamaların çoğu bu yolda: [Maccy](https://alternativeto.net/software/maccy/about), [ClipBook 2](https://mac.softpedia.com/get/Utilities/ClipBook.shtml), [Clipbara](https://github.com/mobrava/Clipbara/wiki), [Clipyy (SwiftUI + SwiftData)](https://github.com/sshssn/clipyy). Arama katı için Rust kullanan [Clipin](https://github.com/ccfco/Clipin) gibi örnekler de var; ilk sürüm için gerekmez.

### Dil seçenekleri

| Seçenek | Artı | Eksi |
| --- | --- | --- |
| Swift + SwiftUI/AppKit | Sistem entegrasyonu; bir geliştirici [SwiftUI menü çubuğu uygulamasının boşta yaklaşık 12 MB RAM](https://dev.to/hamzan/why-i-built-a-15mb-swiftui-menu-bar-app-instead-of-reaching-for-electron-1boe) kullandığını yazıyor | Sadece Apple platformları; web bilginden farklı bir öğrenme eğrisi |
| Tauri (Rust + web) | Web bilgin doğrudan işe yarar; [bir benchmark boşta 42 MB, Electron'da 168 MB](https://tech-insider.org/tauri-vs-electron-2026/) buluyor; Windows/Linux'a geçiş kolay | Bir geliştirici [macOS'a özel API erişiminin manuel olduğunu](https://dev.to/hiyoyok/tauri-v2-vs-electron-after-6-months-of-real-development-my-honest-take-2ic0) yazıyor |
| Electron | En çok örnek ve kütüphane | [Boşta 80-120 MB RAM](https://dev.to/hamzan/why-i-built-a-15mb-swiftui-menu-bar-app-instead-of-reaching-for-electron-1boe); sürekli açık kalan menü çubuğu aracı için ağır |

Cross-platform istersen Tauri mantıklı; [Recopy](https://github.com/shiqkuangsan/Recopy) ve [Clip It](https://github.com/asterd/clip-it) bunu deniyor. Ama Mac'te hız, izin ve sistem hissi ana değer olduğu için ben Swift'i öneriyorum (benim yorumum). Web geliştirici olarak SwiftUI'nin bildirimsel yapısı sana tanıdık gelecektir.

### Mimari: veri hattı

1. **Yakalama:** Pasteboard için bildirim API'si yok; [changeCount 0,5 saniyelik zamanlayıcıyla yoklanır](https://dev.to/eduardo_revillavaquero_0/i-shipped-a-clipboard-manager-inside-the-macos-app-store-sandbox-heres-what-works-and-what-5a30), boşta maliyeti ihmal edilebilir.
2. **Filtre:** `org.nspasteboard.ConcealedType` ve `TransientType` işaretli öğeleri atla. Bu bir topluluk kuralı; bir geliştirici [Spotlight'ın clipboard geçmişinin de bu türleri atladığını gözlemlemiş](https://developer.apple.com/forums/thread/794798) (Apple onaylamadı).
3. **Zenginleştirme:** Kaynak uygulama için `NSWorkspace.frontmostApplication`; resimlerde Apple Vision ile OCR ([işlem cihazda yapılır](https://developer.apple.com/tutorials/data/documentation/vision/recognizing-text-in-images.md)).
4. **Depolama:** SQLite + FTS5 (tam metin arama); Clipin de Rust + SQLite + FTS5 kullanıyor. SwiftData da mümkün ama [Mac'ler arası CloudKit senkronunda sorun bildiren forum konuları](https://developer.apple.com/forums/thread/815583) var.
5. **Arayüz:** NSPanel içinde SwiftUI.
6. **Yapıştırma:** Panoya yaz, sonra ⌘V tuş vuruşu gönder (Erişilebilirlik izni gerekir).
7. **Senkron (v2):** CloudKit; Apple'da [CKSyncEngine örneği](https://github.com/apple/sample-cloudkit-sync-engine) var.
8. **MCP (v2):** Yerel sunucu, yalnız kullanıcının izin verdiği istemcilere, gizli veriler filtrelenmiş.

### İzinler ve sınırlar

- **Otomatik yapıştırma:** ⌘V göndermek için Accessibility/CGEvent gerekiyor ve bir geliştirici clipboard yöneticisi [Guideline 2.4.5 ile reddedildiğini](https://developer.apple.com/forums/thread/820594) anlatıyor. Bir başka geliştirici [App Store sandbox'ında neyin çalışıp neyin çalışmadığını](https://dev.to/eduardo_revillavaquero_0/i-shipped-a-clipboard-manager-inside-the-macos-app-store-sandbox-heres-what-works-and-what-5a30) yazıyor: izleme ve gizli tür kontrolü çalışıyor, otomatik yapıştırma çalışmıyor.
- **Sonuç:** İlk sürümü App Store dışında dağıt; otomatik yapıştırmanın tam çalıştığı sürüm bu olsun.
- **Pasteboard gizlilik uyarısı:** Apple, [kullanıcı etkileşimi olmadan clipboard okuyan uygulamalar için uyarı gösteren bir değişiklik duyurdu](https://www.macrumors.com/2025/05/12/apple-mac-apps-clipboard-change/). Clipboard yöneticileri sürekli okuduğu için bunu güncel macOS'ta ilk gün test et.

## Dağıtım ve yayın

**Karar (Kerem'in cevabıyla güncellendi):** Sadece macOS, açık kaynak, GitHub'da yayın; ilk fazda Apple Developer hesabı yok. Bu, otomatik yapıştırmanın tam çalışması için zaten gereken yol (App Store dışı). Ama bir kritik sınır var:

**Homebrew durumu (yeni bulgu):** Homebrew, [imzasız cask'leri eski ilan etti ve Gatekeeper kontrolünü geçemeyen tüm cask'leri Eylül 2026'da kapatacaktı](https://brew.sh/2025/11/12/homebrew-5.0.0). Bugün Kasım 2026 olduğu için resmi Homebrew cask deposuna imzasız uygulama sokmak gerçekçi değil; cask'ler artık [imzalı ve notarize edilmiş olmalı](https://workbrew.com/blog/homebrew-5-0-0). Bu yüzden "terminalden tek satır" hedefi için kendi Homebrew tap'imizi kullanmak gerekir; Developer ID'si olmayan bir proje bunu [ilk açılışta Gatekeeper'ın uygulamayı engellediğini yazıp](https://raw.githubusercontent.com/NoopApp/noop/master/docs/HOMEBREW.md) kullanıcıya manuel izin adımı gösteriyor.

| Kanal | İmzasız (Developer hesabı yok) durumu | Kullanıcı deneyimi |
| --- | --- | --- |
| GitHub Releases (.dmg / .zip) | Çalışır | İlk açılışta macOS uyarı verir; kullanıcı [Apple'ın imzasız uygulama açma adımlarını](https://support.apple.com/en-us/102445) izler |
| Web sitesi üzerinden tek tık indirme | Çalışır (dosya aynı GitHub Release'ten) | Aynı ilk açılış uyarısı; sitede net bir anlatım şart |
| Kendi Homebrew tap'imiz | Çalışır ama ilk açılışta engellenir (yukarıdaki örnek) | Terminalden tek satır + bir manuel izin |
| Resmi Homebrew cask | Pratikte kapalı (imza + notarization ister) | Developer hesabı gelince açılır |
| Mac App Store | Hesap gerekir | İlk fazda yok |

Ayrıca [Apple silikonlu Mac'lerde imzasız native kodun hiç çalışmayabileceği](https://lemmy.4d2.org/post/1941658/2526816) belirtiliyor; bu yüzden en az ad-hoc imza (Xcode'un sertifikasız imzası) atmak gerekir. Bunu prototipte ilk gün test et. (Kaynak bir forum yorumu, kesin teknik belge değil.)

**Benim önerim:** Faz 1'de GitHub Releases + web sitesi + kendi tap'imiz; README'de ilk açılış adımları net olsun. "Dünyanın en iyisi" hedefi için uzun vadede imza + notarization önemli bir kalite işareti olur: kullanıcı uyarı görmez ve resmi Homebrew'a girebilirsin. Bunun için Apple Developer hesabı yıllık ücretli; sen şimdilik istemediğin için kapıyı sonraya bırakıyoruz.

### Lansman planı (benim önerim)

1. **Önce küçük çevre:** 10-20 kişilik beta; amaç hataları ve ilk açılış deneyimini düzeltmek.
2. **README ve demo GIF:** Açık kaynakta ilk izlenimi bunlar belirler. 10 saniyelik tek GIF: kısayol, arama, yapıştır.
3. **Product Hunt / Hacker News / GitHub:** Pazardaki örneklerde sonuçlar karışık; tek seferlik patlamaya değil düzenli sürüm notuna yatırım yap.
4. **Sürekli:** Her sürümde değişiklik günlüğü, Issues'ta hızlı cevap. Bunun büyümeyi getirdiğine dair veri bulamadım; varsayım.

## Sürdürülebilirlik ve para

**Karar (Kerem'in cevabıyla güncellendi):** Para kazanmak ilk hedef değil. Asıl hedef: portföyde duracak, çok iyi çalışan, uzun süre bakımı yapılan, dünyanın en iyi açık kaynak clipboard uygulaması. Bu yüzden ücretli model, abonelik ve App Store satışı yol haritasından çıktı; uygulama tamamen ücretsiz ve açık kaynak.

Referans olarak pazardaki fiyatlar (Pazar Araştırması raporundan): Paste yaklaşık 30 dolar/yıl, CleanClip 19,99 dolar, SaneClip Pro 14,99 dolar tek seferlik. Bizim konumumuz bu pazarda açık boşluğu doldurur: ücretsiz, güzel ve gizlilik varsayılan. [Paste](https://apps.apple.com/app/paste-clipboard-manager/id967805235) · [CleanClip](https://cleanclip.cc/gb/) · [SaneClip](https://project-awesome.org/r/sane-apps-SaneClip)

**Sürdürülebilir bakım için (benim önerim):**

- Kapsamı küçük tut: v1 çekirdeği yeterince iyi olmadan yeni özellik ekleme.
- Otomatik test ve her sürümde otomatik derleme (GitHub Actions) bakım yükünü azaltır.
- Katkı kuralları (CONTRIBUTING) ve "good first issue" etiketleri ile topluluktan yardım al.
- İstersen ileride GitHub Sponsors açılabilir; zorunlu değil.

## Kim, neden kullanır?

Bu bölüm Pazar Araştırması raporundaki bulgulardan çıkardığım beş profil. Gerçek kullanıcı sayısı verisi bulamadım; bunlar varsayımdır ve ilk beta ile doğrulanmalı.

| Profil | Ne yapar | Neden bizim uygulama | Hangi özellik |
| --- | --- | --- | --- |
| Yazılımcı | Kod, komut, log kopyalar | Hızlı panel, açık kaynak, Homebrew ile kurulum | Arama, paste queue, snippet |
| Tasarımcı / içerik üreticisi | Resim, renk, ekran görüntüsü taşır | Güzel kart görünümü, resim önizleme | Kart şeridi modu, OCR |
| Ofis / başvuru yapan | Aynı metinleri tekrar tekrar yaptırır | Pin'ler ve snippet'ler | Pin, snippet |
| Gizlilik odaklı kullanıcı | Şifre ve gizli veri kopyalar | Gizli işaretli kopyayı kaydetmeme, yerel depolama | Gizli tür filtresi, Touch ID kilidi |
| Spotlight'tan memnun olmayanlar | Mac'in kendi geçmişini denemiş | Spotlight'ta pin ve kilit yok, geçmiş sınırlı süre tutuluyor | Pin, sonsuz geçmiş |

**Spotlight etkisi:** macOS Tahoe'da ⌘Space sonra ⌘4 ile açılan clipboard geçmişi (varsayılan kapalı, 30 dakika / 8 saat / 7 gün seçenekleri) temel ihtiyacı karşılıyor; yani "sadece geçmiş" sunan uygulamalar zor durumda. Bizim farkımız Spotlight'ın yapmadığı şeyler: pin, snippet, kilit, OCR, paste queue.

## Yol haritası

Aşağıdaki plan benim önerim; süre vermedim çünkü senin haftalık çalışma temponu bilmiyorum. Aşamalar zamana göre ölçeklenmemiştir, her aşama bir kapıdan geçmeden bir sonrakine geçilmez.

**Yol haritası (4 aşama, 3 kapı; süre verilmedi, aşamalar zamana ölçeklenmemiştir)**

| Aşama | İçerik | Sonraki kapı |
| --- | --- | --- |
| 1. Prototip | Kendi işinde kullan: yakalama, panel, arama, yapıştırma | Kapı 1: günlük işinde kullanılıyor mu? |
| 2. v1 beta | Çekirdek özellikler, gizlilik filtresi, 10-20 kişilik beta | Kapı 2: gizli veri sızmıyor mu? |
| 3. Açık lansman | GitHub + Homebrew tap, README, demo GIF, sürüm notları | Kapı 3: beta geri bildirimi toplandı mı? |
| 4. v1.x ve v2 | Paste queue, snippet, OCR, kilit; sonra senkron ve MCP | |

İlk kapıdaki ölçüt en önemlisi: uygulamayı önce sen kendi günlük işinde kullanmadan kimseye verme.

## Riskler, açık sorular ve kaynaklar

### Başlıca riskler

| Risk | Neden önemli | Ne yapmalı |
| --- | --- | --- |
| macOS gizlilik değişikliği | Apple, [kullanıcı etkileşimi olmadan clipboard okuyan uygulamalar için uyarı gösteren bir değişiklik duyurdu](https://www.macrumors.com/2025/05/12/apple-mac-apps-clipboard-change/); yöneticiler sürekli okur | Prototipte güncel macOS'ta test et, kullanıcıya ne olacağını açıkla |
| Spotlight rekabeti | [Spotlight'ın clipboard geçmişi](https://developer.apple.com/forums/thread/794798) temel ihtiyacı karşılıyor | Pin, snippet, kilit, OCR ile farklılaş |
| Senkron zorluğu | [CloudKit senkronunda forum şikayetleri](https://developer.apple.com/forums/thread/815583) var | v2'ye bırak, CKSyncEngine ile başla |
| App Store kısıtı | Otomatik yapıştırma sandbox'ta çalışmıyor | İlk sürümü dışarıda dağıt |
| MCP güvenliği | Gizli veri AI aracına sızabilir | Aynı filtre kuralları, istemci bazlı izin; v2'ye bırak |
| Sana ait risk | Swift ve AppKit'e yeni olmak (web'den geliyorsun) | Prototipi küçük tut, panel + yakalama ile başla |

### Verilen kararlar ve açık sorular

**Kerem'in cevapları:** Sadece macOS. Para kazanmak ilk hedef değil; hedef portföye eklenecek, sürekli geliştirilen en iyi açık kaynak clipboard uygulaması. GitHub'da açık kaynak, tek satır veya web sitesinden tek tık indirme. Apple Developer hesabı ilk fazda yok. Uygulamanın adını birlikte seçeceğiz.

**Hala açık:**

- Uygulamanın adı ve lisans (MIT mi, GPL mi?).
- Faz 1'de imzasız dağıtımın ilk açılış uyarısını kabul ediyor musun? Kabul etmiyorsan Apple Developer hesabı gerekir.
- iCloud senkronu (v2): CloudKit'in ücretli hesap gerektireceğini düşünüyorum ama bunu doğrulamadım; hesap almayacaksan senkron için başka bir yol (örneğin dosya tabanlı) araştırmak gerekir.

### Araştırmanın sınırları

- Reddit ve forum yorumlarını doğrudan tarayamadım; kullanıcı görüşleri sınırlı sayıda kaynaktan geliyor. Reddit yorumlarını buraya yapıştırırsan raporu güncelleyebilirim.
- Gerçek indirme ve kullanıcı sayıları kamuya açık değil; "dünyanın en çok kullanılanı" olma hedefi bu raporda bir tahmin değil, yön.
- "Benim önerim" veya "benim yorumum" diyen yerler kanıt değil, çıkarımdır.
- Vergi, şirket ve lisans hukuku konularını araştırmadım.

### Ana kaynaklar

- [Maccy](https://alternativeto.net/software/maccy/about/) · [Clipbara](https://github.com/mobrava/Clipbara/wiki) · [Clipin](https://github.com/ccfco/Clipin) · [ClipKitty](https://jul-sh.github.io/clipkitty/)
- [Paste MCP (9to5Mac)](https://9to5mac.com/2026/06/02/paste-launches-mcp-support-to-connect-your-clipboard-history-to-ai-tools/)
- [App Store sandbox deneyimi](https://dev.to/eduardo_revillavaquero_0/i-shipped-a-clipboard-manager-inside-the-macos-app-store-sandbox-heres-what-works-and-what-5a30)
- [Apple Vision OCR belgesi](https://developer.apple.com/tutorials/data/documentation/vision/recognizing-text-in-images.md)
- [Apple, Liquid Glass'ı benimseme](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass.md)
