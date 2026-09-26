# System Optimizer

Windows sistemlerde oyun ve genel kullanım performansını artırmak, gecikmeleri (ping/latency) düşürmek ve gereksiz arka plan yüklerini temizlemek için geliştirilmiş hafif bir optimizasyon aracıdır.

Hem PowerShell hem de Python tabanlı arayüz seçenekleri sunar.

## Öne Çıkan Özellikler

- Performans Profilleri: Dengeli, Oyun ve Maksimum (Extreme) olmak üzere hazır optimizasyon seçenekleri.
- Güç Planı Yönetimi: Windows Nihai Performans (Ultimate Performance) planını etkinleştirme.
- Bellek (RAM) Temizliği: Geçici bellek yükünü ve Standby RAM listesini güvenle temizleme.
- Arka Plan Hizmetleri: SysMain, Windows Search ve Telemetri gibi performans tüketen servisleri geçici olarak durdurma.
- Ağ ve Ping Optimizasyonu: DNS temizliği, TCP/IP sıfırlama, TCP Nagle algoritmasını kapatma ve Ağ Kısıtlamasını (Network Throttling) devre dışı bırakma.
- Gelişmiş Ayarlar: HAGS (Donanım Hızlandırmalı GPU Zamanlaması), Yüksek Çözünürlüklü Zamanlayıcı (HPET) ve Windows Oyun Modu yapılandırmaları.
- Hedef Uygulama İyileştirmesi: Seçilen oyun veya uygulamanın (.exe) CPU önceliğini artırma ve tam ekran iyileştirmelerini kapatma.
- Güvenli Kapanış: Uygulama kapatıldığında durdurulan hizmetler ve orijinal güç planı otomatik olarak eski haline döndürülür.
- Sistem Analizi: CPU yükü, RAM kullanımı, GPU ve çalışan işlem sayılarını canlı olarak izleme.

## Gereksinimler

- Windows 10 veya Windows 11 (64-bit)
- Yönetici Yetkileri (Registry ve servis müdahaleleri için gereklidir)
- PowerShell 5.1 veya üzeri (Windows ile dahili olarak gelir)
- (İsteğe bağlı) Python 3.x (Python arayüzünü tercih edenler için)

## Kullanım

1. Projeyi bilgisayarınıza indirin veya klonlayın.
2. Klasör içindeki `baslat.bat` dosyasına çift tıklayarak çalıştırın.
3. Yönetici izni istendiğinde onay verin.
4. Açılan arayüzden istediğiniz profili seçin veya ayarları özelleştirin.
5. "Yapılandırmayı Uygula" butonuna basarak optimizasyonu başlatın.

`baslat.bat` dosyası öncelikle PowerShell arayüzünü başlatır. PowerShell bulunamazsa varsayılan Python sürümünü devreye sokar.

## Uyarılar ve Notlar

- Arka plan servislerinin kapatılması geçicidir; optimizasyon aracı kapatıldığında servisler tekrar başlatılır.
