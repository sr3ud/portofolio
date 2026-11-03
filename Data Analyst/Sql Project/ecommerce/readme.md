# Analisis E-Commerce dengan SQL

## Project Overview

Sepuluh query SQL (MySQL / MariaDB) untuk menganalisis database e-commerce 8 tabel: 6.000 pelanggan, 120 seller, 21.368 pesanan, periode 2023–2024. Query memakai JOIN, agregasi bersyarat, CTE (`WITH`), dan window function (`LAG`, `NTILE`, `ROW_NUMBER`, `SUM() OVER`). Seluruh query sudah dijalankan di MariaDB (XAMPP) dan hasilnya tersimpan di file `output_queries.txt`.

> **Data sintetis**: dibuat acak, bukan data bisnis nyata. Beberapa pola (misalnya keterlambatan menurunkan skor review) disesuaikan untuk kebutuhan analisis.

## Business Questions

| # | Pertanyaan | File |
|---|---|---|
| 1 | Apakah datanya konsisten? | `01_integrity_checks.sql` |
| 2 | Bagaimana tren penjualan bulanan? | `02_monthly_revenue_mom.sql` |
| 3 | Seberapa terkonsentrasi penjualan pada seller? | `03_seller_pareto.sql` |
| 4 | Kategori mana yang terbesar dan paling sering diretur? | `04_category_performance_returns.sql` |
| 5 | Berapa persen pelanggan baru yang kembali belanja? | `05_cohort_retention.sql` |
| 6 | Kanal akuisisi mana yang pelanggannya paling sering kembali? | `06_channel_repeat_rate.sql` |
| 7 | Segmen pelanggan mana yang paling bernilai? | `07_rfm_segmentation.sql` |
| 8 | Apakah keterlambatan menurunkan kepuasan pelanggan? | `08_delay_vs_review.sql` |
| 9 | Seberapa berbeda pengiriman dalam vs antarprovinsi? | `09_same_vs_cross_province.sql` |
| 10 | Produk andalan apa di tiap kategori? | `10_top3_products_per_category.sql` |

## KPI

GMV = harga satuan x qty pesanan berstatus `delivered` (tanpa ongkir; batal dan retur dikeluarkan).

| KPI | Hasil |
|---|---|
| Pesanan terkirim per bulan | 100 (Jan 2023) → 1.643 (Des 2024) |
| Pertumbuhan GMV Des 2024 vs Des 2023 (YoY) | **+60,0%** |
| Konsentrasi seller | 29 dari 120 seller (24,2%) = **80,3%** GMV |
| Porsi kategori terbesar | Komputer & Laptop **38,8%** GMV |
| Tingkat retur tertinggi / terendah | Fashion Wanita **10,9%** / Kesehatan **2,0%** |
| Retensi kohort (rata-rata) | Bulan ke-1 **36,0%**, ke-3 **27,8%**, ke-6 **22,1%** |
| Repeat purchase 90 hari per kanal | Referral **81,6%**, organic 68,2%, marketplace 62,9%, ads **54,2%** |
| Segmen RFM | Champions 14,3% pelanggan = **31,1%** belanja; At Risk 18,1% pelanggan = 24,6% belanja |
| Skor review vs keterlambatan | **4,46** (tepat waktu) → **2,17** (terlambat 6+ hari) |
| Waktu kirim antarprovinsi vs dalam provinsi | **6,70** vs **4,51** hari; terlambat 28,6% vs 21,5% |

## Cara Penggunaan

Impor database.sql melalui phpmyadmin dan jalankan query pada tab sql. Impor akan menimpa database bernama `ecommerce_sql` jika sudah ada. Jika impor gagal karena ukuran file, naikkan `upload_max_filesize` dan `post_max_size` di `php.ini`, lalu restart Apache. Query memakai CTE dan window function, jadi butuh MySQL 8 atau MariaDB 10.2+ (cek dengan `SELECT VERSION();`).
Versi ini belum dicoba menggunakan sqlite, namun kemungkinan tetap compatible.

## Isi Folder

| Folder / file | Isi |
|---|---|
| `dataset/` | 8 file CSV: `customers`, `sellers`, `categories`, `products`, `orders`, `order_items`, `payments`, `reviews` |
| `database.sql` | Database lengkap (skema + semua data) |
| `queries/` | 10 file query, diawali pertanyaan bisnis |
| `output_queries.txt` | Hasil tiap query |
