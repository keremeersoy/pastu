# Mac Clipboard Yöneticisi Pazar Araştırması

2026-11-21 · @kerem ersoy

Mac clipboard yöneticisi pazarı üç parçaya bölünmüş: ücretsiz ve sade araçlar (Maccy), abonelikli ve görsel araçlar (Paste) ve launcher içindeki hazır özellikler (Raycast, Alfred); Apple'ın Spotlight'ı ise temel ihtiyacı artık ücretsiz karşılıyor.

## Pazar haritası

Baktığım kaynaklarda 15'ten fazla Mac clipboard yöneticisi geçiyor; aşağıdakiler en çok anılan ve fikir verenler. Fiyatlar farklı ülkelerin mağazalarında değişebilir, satın almadan önce kontrol et.

| Uygulama | Tür | Fiyat modeli | Platform |
| --- | --- | --- | --- |
| [Maccy](https://alternativeto.net/software/maccy/about) | Açık kaynak (MIT) | Ücretsiz (GitHub/Homebrew); App Store'da destek için yaklaşık 10 dolar | Mac |
| [Clipy](https://alternativeto.net/software/clipy/about) | Açık kaynak (MIT) | Ücretsiz; AlternativeTo'da "discontinued" işaretli | Mac |
| [PasteBar](https://www.alternativeto.net/software/pastebar/about/) | Açık kaynak | Ücretsiz | Mac, Windows |
| [ClipBook](https://mac.softpedia.com/get/Utilities/ClipBook.shtml) | Açık kaynak, Swift/SwiftUI ile yeniden yazıldı | Ücretsiz deneme + ücretli imzalı sürüm | Mac |
| [Clipbara](https://github.com/mobrava/Clipbara/wiki) | Açık kaynak, çift lisans | Ücretsiz; App Store sürümü ayrı lisanslı | Mac |
| [Deck](https://alternativeto.net/software/cleanclip) | Açık kaynak | Ücretsiz | Mac |
| [Paste](https://pasteapp.io/blog/best-clipboard-manager-for-mac) | Kapalı kaynak | Abonelik; yaklaşık 29,99 dolar/yıl | Mac, iPhone, iPad |
| [PastePal](https://apps.apple.com/gb/app/id1503446680) | Kapalı kaynak | Tek seferlik ödeme (App Store'da Pro 22,99 dolar) | Mac, iPhone, iPad |
| [Pastebot](https://alternativeto.net/software/pastebot/?p=3) | Kapalı kaynak (Tapbots) | Tek seferlik veya abonelik | Mac |
| [CleanClip](https://apps.apple.com/us/app/cleanclip/id6463153747?mt=12) | Kapalı kaynak | Tek seferlik; App Store'da 19,99 dolar | Mac |
| [Raycast](https://www.raycast.com/pricing) | Launcher içinde özellik | Ücretsiz (3 ay geçmiş); Pro ayda 10 dolar, yılda 96 dolar | Mac, Windows, iOS |
| [Alfred](https://alfredapp.com/powerpack) | Launcher içinde özellik | Powerpack tek seferlik; clipboard geçmişi Powerpack'te | Mac |
| [SaneClip](https://project-awesome.org/r/sane-apps-SaneClip) | Ücretsiz çekirdek + Pro | Pro 14,99 dolar tek seferlik | Mac, iPhone/iPad eşlik uygulaması |
| [Spotlight (macOS Tahoe)](https://www.macrumors.com/how-to/do-more-with-spotlight-in-macos-tahoe/) | Sistemin kendisi | Ücretsiz | Mac |

## Kim neyi neden kullanıyor

Kullanıcılar özellik sayısına değil, ne kadar hızlı ve ne kadar ödeme gerektirdiğine göre ayırılıyor. Kaynaklardaki yorumlardan çıkan ana gruplar:

| Kullanıcı grubu | Genelde seçtikleri | Neden |
| --- | --- | --- |
| Geliştirici ve yazarlar, sade isteyenler | [Maccy](https://www.digitaltrends.com/computing/i-used-a-free-app-to-fix-my-biggest-problem-with-macos/) | Ücretsiz, hızlı, klavye odaklı, veriler yerelde. Hassas uygulamalar istisna listesine eklenebiliyor. |
| Görsel düşünenler, çok cihaz kullananlar | [Paste](https://apps.apple.com/hu/app/paste-2/id967805235) | Kart görünümü, Pinboard'lar, önizleme, iCloud ile Mac/iPhone/iPad senkronu. |
| Abonelik sevmeyenler | [PastePal](https://apps.apple.com/gb/app/id1503446680), [CleanClip](https://cleanclip.cc/gb/) | Tek seferlik ödeme. PastePal yorumlarında Paste'ten geçenler var. |
| Zaten launcher kullananlar | [Raycast](https://manual.raycast.com/clipboard-history), [Alfred](https://www.alfredapp.com/help/features/clipboard/) | Ek uygulama kurmadan tek tuşla clipboard geçmişi; snippet ve otomasyonla birlikte. |
| Otomasyon ve filtre sevenler | [Pastebot](https://andersnoren.se/gear/software/pastebot-review/) | Filtreler, sequential paste ve Shortcuts eylemleri. |
| Sıralı yapıştırma yapanlar | [CleanClip](https://cleanclip.cc/gb/), [ClipKeep](https://apps.apple.com/us/app/clipkeep/id6757108580) | Paste Stack/Queue: birçok şeyi sıraya al, sırayla yapıştır. |
| Gizlilik odağındakiler | [SaneClip](https://project-awesome.org/r/sane-apps-SaneClip), [Clipbara](https://github.com/mobrava/Clipbara/wiki), [Deck](https://alternativeto.net/software/cleanclip) | Yerel saklama, şifreleme/Touch ID kilidi, hassas veri algılama. |
| Basit ihtiyaç | [Spotlight](https://www.macrumors.com/how-to/do-more-with-spotlight-in-macos-tahoe/) | Ek kurulum yok. Sınırlı geçmiş, pinleme yok. |

Bir Product Hunt tartışmasında [Paste kullanıcısı Raycast'in clipboard'ını kendi iş akışına uydurmakta zorlandığını yazmış](https://www.producthunt.com/p/general/best-clipboard-manager-for-mac). Bir MacSales yazarı da [Raycast'in clipboard görünümünün Paste kadar net olmadığını](https://eshop.macsales.com/blog/96270-paste-the-visual-clipboard-manager-for-mac-iphone-and-ipad/) söylüyor.

## Uygulama bazlı analiz

### Maccy: ücretsiz sade standart

- **Güçlü:** [Sistemin kendi özelliği gibi hıssı veren yerel tasarım, tek işi iyi yapma yaklaşımı](https://apps.apple.com/pw/app/maccy/id1527619437?mt=12). Pin, regex arama ve hassas uygulama istisnası var.
- **Zayıf:** Bir kullanıcı [pin'li öğelerin normal geçmişle karışık durmasından](https://alternativeto.net/software/maccy/about/) yakınıyor. Bir inceleme [etiket, kural ve çok cihaz senkronu olmadığını](https://www.opensourcealternatives.to/item/maccy) söylüyor.
- **Not:** [2.0 sürümü tamamen yeniden yazıldı](https://www.producthunt.com/p/maccy/maccy-2-0); geliştirici drag & drop, iCloud sync ve iPhone sürümünün artık mümkün olduğunu yazıyor.

### Paste: görsel ve senkronlu lider

- **Görsel üstünlük:** [Kart arayüzü, Pinboard'lar, paylaşılan Pinboard'lar ve cihazlar arası senkron](https://apps.apple.com/app/paste-clipboard-manager/id967805235). Yeni sürümde [AI asistanlarına MCP bağlantısı ve Apple Intelligence yazı araçları](https://apps.apple.com/us/app/paste-limitless-clipboard/id967805235?l=ko) da var.
- **Sevilen:** [Product Hunt'ta 4.8/5 (51 yorum)](https://www.producthunt.com/products/paste/reviews).
- **Şikayet:** En sık şikayet abonelik. App Store'da ["abonelik modeline geçtiği için bıraktım" türünde yorumlar](https://apps.apple.com/be/app/id967805235?l=en-gb) var; bazı kullanıcılar [senkronun çalışmadığını](https://apps.apple.com/ae/app/id967805235) ve [çökmeleri](https://apps.apple.com/sg/app/id967805235) yazıyor.

### PastePal: abonelik istemeyen Paste alternatifi

- **Güçlü:** [Tek seferlik ödeme, Mac/iPhone/iPad, k](https://apps.apple.com/au/app/id1503446680?l=en-au)[oleksiyonlar](https://apps.apple.com/au/app/id1503446680?l=en-au)[, queue stack, hot edge, gelişmiş filtre](https://apps.apple.com/au/app/id1503446680?l=en-au). Bazı kullanıcılar [Paste'ten daha iyi senkron](https://apps.apple.com/gb/app/id1503446680) yazmış.
- **Zayıf:** [iPad'te klavye ile arka plan izleme iOS sınırlaması yüzünden kısıtlı](https://apps.apple.com/za/app/id1503446680).

### Pastebot: otomasyon ve filtre

- **Güçlü:** [Filtreler en iyi özelliği saydırılıyor](https://andersnoren.se/gear/software/pastebot-review/); [Sequential Paste ve iCloud senkron](https://tidbits.com/2017/10/30/pastebot-supercharges-your-macos-clipboard/). [Pastebot 3'te Shortcuts eylemleri ve 1.500 kayda kadar geçmiş](https://macstories.net/reviews/pastebot-3-doubles-down-on-mac-clipboard-automation-and-introduces-two-new-business-models/) var.

### Raycast ve Alfred: launcher içindeki clipboard

- **Raycast:** [Metin, resim, dosya, link, e-posta ve renk türlerine göre filtre](https://manual.raycast.com/clipboard-history.md). [Ücretsiz sürümde geçmiş 3 ayla sınırlı, Pro'da 6 ay, 1 yıl veya sınırsız](https://manual.raycast.com/clipboard-history); clipboard geçmişi [güvenlik için bulut senkronuna dahil değil](https://raycast.com/blog/introducing-raycast-pro).
- **Alfred:** [Clipboard geçmişi ve Snippets Powerpack'te](https://textexpander.com/blog/alfred-free-vs-powerpack); [gizlilik için varsayılan olarak kapalı](https://www.alfredapp.com/help/features/clipboard/), uygulama istisnaları ve otomatik snippet genişletme var.

### CleanClip: sıralı yapıştırma ve hız

- **Güçlü:** [Paste Stack, yazıp anlık arama, iPhone kayıtlarını Mac'te görme](https://alternativeto.net/software/cleanclip/about). [Hex renk desteği ve Pinyin arama](https://cleanclip.cc/pages/a-feature-rich-alternative-to-maccy) da var.

### Açık kaynak yeni dalga: ClipBook, Clipbara, PasteBar

- **ClipBook:** [Swift/SwiftUI ile sıfırdan yazıldı, açık kaynak](https://mac.softpedia.com/get/Utilities/ClipBook.shtml); geliştirici [kendin derlersen imzasız olacağını ve güncelleme kontrolünün çalışmayacağını](https://www.producthunt.com/products/clipbook) yazıyor.
- **Clipbara:** [Kart tarzı arayüz, Pinboard'lar, Quick Look, %100 yerel saklama; metin, resim, dosya, renk ve kaynak uygulamaya göre arama](https://github.com/mobrava/Clipbara/wiki). 229 yıldızlı küçük bir proje.
- **PasteBar:** [Koleksiyonlar, sekmeler, PIN koruması, yedekleme, syntax highlighting](https://www.alternativeto.net/software/pastebar/about/); bir kullanıcı Mac'te [yavaş açıldığını ve yarım saniye beklettiğini](https://www.alternativeto.net/software/pastebar/about/) yazıyor.

### macOS Spotlight: artık sıfırınıcı rakip

- [⌘Space sonra ⌘4 ile açılıyor, varsayılan olarak kapalı; 26.1 ile 30 dakika, 8 saat veya 7 gün seçilebiliyor, tek tıkla temizleme var](https://dev.to/jrw0ng/macos-tahoe-has-built-in-clipboard-history-heres-what-its-still-missing-for-developers-2026-4eko).
- Eksikleri: [pinleme yok, geçmiş paneli için şifre koruma yok](https://dev.to/jrw0ng/macos-tahoe-has-built-in-clipboard-history-heres-what-its-still-missing-for-developers-2026-4eko). Bir rehbere göre [Universal Clipboard'dan gelen kopyalar geçmişe kaydedilmiyor](https://macmost.com/?p=34596).

## Özellik karşılaştırma matrisi

Hiçbir uygulama tüm satırlarda önde değil: sadelik Maccy'de, görsel ve senkron Paste'te, sıralı yapıştırma CleanClip/PastePal/Pastebot'ta, OCR ve şifreleme ise yeni çıkan araçlarda (SaneClip, PasteDaemon). "?" kaynaklarda bulamadığım anlamına geliyor, "Yok" yoksa kaynak açıkça söylüyor.

| Uygulama | Pin / koleksiyon | Snippet | Paste Queue | Cihazlar arası senkron | OCR / AI | Gizlilik koruma | Açık kaynak |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Maccy | Var (listeyle karışık) | ? | ? | Yok | ? | Uygulama istisnası | Evet |
| Paste | Pinboard'lar, paylaşılan | Pinboard'da şablonlar | ? | iCloud | MCP, Apple Intelligence | Yerel + özel iCloud | Hayır |
| PastePal | Koleksiyonlar | Var | Var | iCloud | ? | "Private by design" | Hayır |
| Pastebot | Özel pasteboard'lar | ? | Sequential Paste | iCloud | ? | Uygulama kara listesi | Hayır |
| CleanClip | Bookmark listesi | ? | Paste Stack | iPhone kayıtları Mac'te | ? | ? | Hayır |
| Raycast | ? | Var (ücretsiz) | ? | Clipboard senkron edilmiyor | AI ayrı ürün | ? | Hayır |
| Alfred | ? | Var, otomatik genişletme | ? | ? | ? | Varsayılan kapalı, istisna listesi | Hayır |
| SaneClip | Var | Var | Var (FIFO/LIFO) | İsteğe bağlı iCloud | OCR | AES-256, Touch ID | ? |
| Spotlight (Tahoe) | Yok | Yok | ? | Universal Clipboard kopyaları kaydedilmiyor | Yok | Süre ayarı, Passwords uygulaması hariç | Hayır |

Kaynaklar: [Maccy](https://www.opensourcealternatives.to/item/maccy), [Paste](https://apps.apple.com/app/paste-clipboard-manager/id967805235), [PastePal](https://apps.apple.com/au/app/id1503446680?l=en-au), [Pastebot](https://alternativeto.net/software/pastebot/?p=3), [CleanClip](https://cleanclip.cc/gb/), [Raycast](https://manual.raycast.com/clipboard-history), [Alfred](https://support.alfredapp.com/features:clipboard), [SaneClip](https://project-awesome.org/r/sane-apps-SaneClip), [Spotlight](https://macmost.com/?p=34596).

## Kullanıcı şikayetleri ve pazardaki boşluklar

En net sinyal fiyat modeli: Paste abonelik getirince App Store yorumlarında ciddi tepki oluştu ve kullanıcılar tek seferlik alternatiflere geçti. Diğer şikayetler aşağıda.

| Şikayet | Hangi uygulamada | Kaynak |
| --- | --- | --- |
| Abonelik modeli çok pahalı veya gereksiz | Paste | [App Store yorumları](https://apps.apple.com/es/app/paste-2/id967805235?mt=12), [MacRumors forumu](https://forums.macrumors.com/threads/cross-platform-shelf-copy-paste-apps.2222671) |
| Senkron çalışmıyor veya çok yavaş | Paste | [App Store yorumu](https://apps.apple.com/ae/app/id967805235) |
| Uygulama çöküyor veya donuyor | Paste | [App Store yorumu](https://apps.apple.com/sg/app/id967805235) |
| iOS sürümü Mac ile aynı seviyede değil | Paste | [App Store yorumu](https://apple.co/3CUsn9k) |
| Pin'ler normal geçmişle karışık | Maccy | [AlternativeTo yorumu](https://alternativeto.net/software/maccy/about/) |
| Pencere açılışı yavaş, akicı değil | PasteBar | [AlternativeTo yorumu](https://www.alternativeto.net/software/pastebar/about/) |
| iPad'te klavye varken arka plan izleme sınırlı | PastePal | [Geliştirici yanıtı](https://apps.apple.com/za/app/id1503446680) |
| Geçmiş 8 saat ile sınırlı, pin yok, şifre koruması yok | Spotlight | [DEV topluluk yazısı](https://dev.to/jrw0ng/macos-tahoe-has-built-in-clipboard-history-heres-what-its-still-missing-for-developers-2026-4eko), [MacRumors forumu](https://forums.macrumors.com/threads/tahoe-clipboard-manager-has-an-8-hour-memory-why.2458897) |

Gizlilik ayrı bir başlık: bir DEV yazısına göre [çoğu clipboard yöneticisi geçmişi diske düz metin olarak yazıyor](https://dev.to/alokt/macos-clipboard-history-what-gets-logged-what-leaks-and-how-to-audit-it-4knj). Apple ise macOS'ta, [kullanıcı yapıştırma işlemi yapmadan clipboard'u okuyan uygulamalar için uyarı gösterecek](https://www.macrumors.com/2025/05/12/apple-mac-apps-clipboard-change/) bir değişiklik duyurdu. [Bunun clipboard yöneticilerini nasıl etkilediği o sırada belirsizdi](https://9to5mac.com/2025/05/12/macos-16-clipboard-privacy-protection/); kendi uygulamanda bunu mutlaka test etmelisin.

### Boşluklar (benim yorumum)

1. **Sade ama güzel ve abonelik olmayan seçenek.** Maccy hızlı ama görsel zenginlik sınırlı; Paste güzel ama abonelik. Aradaki alan boşa yakın.
2. **Gizlilik varsayılan olsun.** Şifrelenmiş saklama, Touch ID kilidi, parola yöneticisi algılama ([SaneClip](https://project-awesome.org/r/sane-apps-SaneClip) ve [Deck](https://alternativeto.net/software/cleanclip) gibi yeni ürünlerde var) henüz yaygın değil.
3. **Ekran görüntülerinde OCR arama.** [PasteDaemon](https://alternativeto.net/software/pastedaemon/about/) ve SaneClip sunuyor; Maccy ve Paste'in bu yönde özelliği kaynaklarda görünmüyor.
4. **Açık kaynak + iyi tasarım + iPhone.** Açık kaynak araçların çoğu yalnız Mac; Maccy geliştiricisi iPhone ve iCloud'un artık mümkün olduğunu söylüyor ama henüz bir sürüm bulamadım.

## Senin uygulaman için MVP ve farklılaşma

**Konumlandırma önerisi (benim yorumum):** "Maccy'nin hızı + Paste'in görselliği, abonelik yok, açık kaynak, gizlilik varsayılan." Bu, yukarıdaki şikayetlerin en çok çakıştığı boşluk.

### v1: masa üstü özellikler (olmazsa kimse geçmez)

1. Kısayolla açılan panel, yazıp arama, 1-9 ile hızlı yapıştırma (Maccy ve CleanClip'in çekirdek deneyimi).
2. Metin, link, resim, dosya ve renk geçmişi; kart görünümü ve önizleme.
3. Pin'ler geçmişten **ayrı bölümde** (Maccy kullanıcısının şikayeti).
4. Düz metin olarak yapıştır.
5. Uygulama istisna listesi ve gizli işaretli kopyaları kaydetmeme. [PasteDaemon bu tür işaretli öğeleri kaydetmiyor](https://alternativeto.net/software/pastedaemon/about/), [Maccy de parola yöneticisi silerse kendisi de siliyor](https://sourceforge.net/directory/clipboard-managers/mac/).
6. Tüm veri yerelde.

### v1.1: fark yaratan ilk özellikler

- Paste Queue (sırayla yapıştırma): CleanClip, PastePal, Pastebot ve SaneClip'te var, bir kullanıcı "en iyi Paste Queue" diye övüyor (CleanClip için).
- Snippet'ler ve metin genişletme.
- Ekran görüntüsü OCR araması.
- Şifreli saklama ve Touch ID kilidi.

### v2: büyük özellikler

- iCloud senkron ve iPhone uygulaması (Paste'in aslı üstünlüğü; en zor ve en çok şikayet alan kısım).
- AI asistanlarına MCP erişimi: Paste ekledi, diğer açık kaynak araçlarda görmedim.

### Teknoloji seçimi

Aşağıdaki önerim kaynaklardan çıkarım, kesin bilgi değil: bu pazarda adı geçen hızlı uygulamaların çoğu Swift ile yazılmış. [Maccy](https://alternativeto.net/software/maccy/about), [ClipBook 2](https://mac.softpedia.com/get/Utilities/ClipBook.shtml), [Clipbara](https://github.com/mobrava/Clipbara/wiki) ve [PastePal](https://apps.apple.com/au/app/id1503446680?l=en-au) bunların arasında. Global kısayol, menu bar, clipboard izleme ve otomatik yapıştırma için macOS'a yakın olmak avantaj. Web bilginle SwiftUI başlangıçta yabancı gelir ama bu proje için ana yol bence bu. Tauri ile denemek de mümkün, ancak hız ve izin (permission) tarafta daha fazla emek ister.

### Riskler

- **macOS clipboard gizlilik değişikliği:** Apple, kullanıcı etkileşimi olmadan clipboard'u okuyan uygulamalar için uyarı getiriyor. Clipboard yöneticileri sürekli okuduğu için bunu güncel macOS'ta erken test et ([haber](https://www.macrumors.com/2025/05/12/apple-mac-apps-clipboard-change/)).
- **Spotlight:** Basit ihtiyaç duyanları ücretsiz alacak; sen onun eksikleriyle (pin, uzun geçmiş, kilit) yarışmalısın.
- **Dağıtım:** [ClipBook geliştiricisi, kendin derlediğinde uygulamanın imzasız olacağını ve güncelleme kontrolünün çalışmayacağını yazıyor](https://www.producthunt.com/products/clipbook). Yani düzgün dağıtım için Apple Developer hesabı gerekecek.
- **Gelir (isteğe bağlı):** [Maccy App Store'da destek için yaklaşık 10 dolara satılıyor, GitHub'dan ücretsiz](https://alternativeto.net/software/maccy/about/); [Clipbara App Store sürümü ayrı lisansla dağıtılıyor](https://github.com/mobrava/Clipbara/wiki). İkisi de açık kaynak kalıp gelir getirmenin örneği.

## Araştırmanın sınırları ve kaynaklar

**Neye dayanıyor:** App Store yorumları, Product Hunt, AlternativeTo, MacRumors forumu, inceleme siteleri, geliştirici sayfaları ve resmi fiyat sayfaları. Arama sonuç özetlerini okudum; her sayfayı tek tek tam açmadım.

**Eksikler (açık söylüyorum):**

- Reddit'i doğrudan tarayamadım: Reddit alanıyla filtreli arama aracı tarafından reddedildi, filtresiz aramalarda da Reddit konusu çıkmadı. Yani "Reddit ne diyor" kısmı bu raporda yok. İstersen Reddit'te kendin "clipboard manager mac" arayıp öne çıkan yorumları bana yapıştırabilirsin, raporu güncelleyeyim.
- **İndirme sayıları** hiçbir yerde açıkça yayınlanmıyor. Popülerlik için yalnız GitHub yıldızı (Maccy yaklaşık 15 bin, Clipy yaklaşık 8,9 bin; ikisi de eski bir görüntüden) ve listelerdeki sıralamayı kullandım.
- Fiyatlar ülke ve tarihe göre değişiyor; tabloda başlıca bakılan sayfadaki rakam var. CleanClip için iki farklı fiyat gördüm (App Store 19,99 dolar, kendi eski makalesi 12,99 dolar).
- Tablodaki "?" hücreleri bilgi bulamadığım anlamına geliyor, "yok" demek değil.

**Ana kaynaklar:**

- [Paste'in kendi Mac rehberi](https://pasteapp.io/blog/best-clipboard-manager-for-mac) (Paste'in kendi sitesi, taraf tutabilir)
- [Switching to Mac, 7 en iyi clipboard yöneticisi](https://www.switchingtomac.com/best-clipboard-managers-mac/)
- [Digital Trends, Maccy yazısı](https://www.digitaltrends.com/computing/i-used-a-free-app-to-fix-my-biggest-problem-with-macos/)
- [Product Hunt, Paste yorumları](https://www.producthunt.com/products/paste/reviews)
- [Raycast fiyatlandırma](https://www.raycast.com/pricing) ve [Alfred Powerpack](https://alfredapp.com/powerpack)
- [MacRumors, Spotlight clipboard ayarları](https://www.macrumors.com/2025/11/04/more-spotlight-clipboard-settings-macos-26-1/)
- [MacRumors, clipboard gizlilik değişikliği](https://www.macrumors.com/2025/05/12/apple-mac-apps-clipboard-change/)
- [Maccy GitHub README](https://raw.githubusercontent.com/p0deje/Maccy/master/README.md) ve [Clipy GitHub](https://github.com/Clipy/Clipy)
