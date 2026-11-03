# E-Commerce Customer & Sales Analytics (Excel)

## Project Overview

Analisis ±2,5 juta transaksi e-commerce tahun 2024 di empat provinsi (Jawa Timur, Sulawesi Barat, Gorontalo, Maluku) menggunakan Excel dengan rumus hidup (SUMIFS, INDEX/MATCH, RANK, PERCENTILE) dan dropdown provinsi interaktif. Workbook mencakup analisis kategori produk, diskon, wilayah, profil pelanggan, segmentasi RFM, dan refund, lengkap dengan log pembersihan data.

Data mentah tidak dipublikasikan. Workbook hanya memuat tabel agregat (sheet `Data *`) yang menjadi sumber semua rumus.


## Business Questions

1. Kategori produk mana yang menyumbang mayoritas gross?
2. Apakah transaksi berdiskon lebih besar, dan kategori mana yang paling banyak diberi diskon?
3. Di kabupaten mana pelanggan terkonsentrasi?
4. Siapa pelanggannya (gender, umur), dan bagaimana segmentasi RFM-nya?
5. Seberapa besar refund, dan di mana datanya anomali?

## KPI

| KPI | Definisi | Hasil |
|---|---|---|
| Konsentrasi kategori | Porsi gross 3 kategori teratas | Jawa Timur: **49,7%**; 7 dari 18 kategori = 80% gross |
| Tingkat diskon | Total diskon / total gross | Keperluan Anak **33,3%** vs Top Up Game **10,8%** (Jawa Timur) |
| Rasio nilai transaksi berdiskon | Rata-rata nilai transaksi berdiskon / tanpa diskon | **1,5x–1,9x** (korelasi, bukan sebab-akibat) |
| Konsentrasi wilayah | Porsi pelanggan 3 kabupaten teratas | Maluku 76%, Sulawesi Barat 68%, Gorontalo 65%, Jawa Timur 19% |
| Proporsi pelanggan perempuan | Pelanggan perempuan / total pelanggan | **74,7%** |
| Segmen RFM (Jawa Timur) | Persentase pelanggan per segmen | Champions 20,2%, Loyal 20,4%, Promising 12,6%, Need Attention 7,2%, At Risk 21,2%, Hibernating 18,3% |
| Tingkat refund | Total refund / total belanja | **9,7%**; tertinggi Kalimantan Selatan 12,4%, terendah Sulawesi Selatan 4,9% |
| Stabilitas volume bulanan | Koefisien variasi transaksi per bulan | Maks. **1,69%** (tidak ada pola musiman) |

## Isi Workbook

`Ringkasan` · `Kategori` · `Diskon` · `Wilayah` · `Pelanggan` · `RFM` · `Refund_Wallet` · `Data_Quality` · `Param` · `Data *` (data agregat)

## Keterbatasan

- Karena keterbatasan sumber dataset, satuan nominal data Jawa Timur tidak diketahui, sehingga antarprovinsi hanya rasio yang dibandingkan, bukan nominal.
- Data satu tahun dan tanpa kolom biaya, jadi profit tidak dapat dihitung.
