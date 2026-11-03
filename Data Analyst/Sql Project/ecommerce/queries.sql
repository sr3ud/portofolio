-- 1 | CEK INTEGRITAS DATA
--Apakah datanya layak dianalisis? Sebelum menghitung apa pun, pastikan tabel saling konsisten.

WITH total_item AS (
    SELECT order_id, SUM(unit_price * quantity + freight_value) AS nilai_item
    FROM order_items
    GROUP BY order_id
),
total_bayar AS (
    SELECT order_id, SUM(payment_value) AS nilai_bayar
    FROM payments
    GROUP BY order_id
),
hasil AS (
    SELECT 'Pesanan tanpa item' AS cek, COUNT(*) AS pelanggaran
    FROM orders o LEFT JOIN order_items oi ON oi.order_id = o.order_id
    WHERE oi.order_id IS NULL
    UNION ALL
    SELECT 'Total pembayaran <> total item + ongkir', COUNT(*)
    FROM total_item ti JOIN total_bayar tb ON tb.order_id = ti.order_id
    WHERE tb.nilai_bayar <> ti.nilai_item
    UNION ALL
    SELECT 'Tiba sebelum dikirim', COUNT(*)
    FROM orders WHERE order_delivered_ts < order_shipped_ts
    UNION ALL
    SELECT 'Pesanan batal tetapi punya tanggal tiba', COUNT(*)
    FROM orders WHERE order_status = 'canceled' AND order_delivered_ts IS NOT NULL
    UNION ALL
    SELECT 'Review untuk pesanan batal', COUNT(*)
    FROM reviews r JOIN orders o ON o.order_id = r.order_id
    WHERE o.order_status = 'canceled'
    UNION ALL
    SELECT 'Pesanan sebelum tanggal daftar pelanggan', COUNT(*)
    FROM orders o JOIN customers c ON c.customer_id = o.customer_id
    WHERE DATE(o.order_purchase_ts) < c.signup_date
)
SELECT cek, pelanggaran,
       CASE WHEN pelanggaran = 0 THEN 'OK' ELSE 'PERIKSA' END AS status
FROM hasil;

-- 2 | TREN PENJUALAN BULANAN
-- Bagaimana pertumbuhan penjualan per bulan, dan apakah ada pola musiman (Nov-Des)?

WITH bulanan AS (
    SELECT DATE_FORMAT(o.order_purchase_ts, '%Y-%m') AS bulan,
           COUNT(DISTINCT o.order_id)                AS pesanan,
           SUM(oi.unit_price * oi.quantity)          AS gmv
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_ts, '%Y-%m')
)
SELECT bulan,
       pesanan,
       gmv,
       ROUND(gmv * 1.0 / pesanan, 0)                                          AS aov,
       ROUND(100.0 * (gmv - LAG(gmv)     OVER (ORDER BY bulan))
                    / LAG(gmv)     OVER (ORDER BY bulan), 1)                  AS mom_pct,
       ROUND(100.0 * (gmv - LAG(gmv, 12) OVER (ORDER BY bulan))
                    / LAG(gmv, 12) OVER (ORDER BY bulan), 1)                  AS yoy_pct,
       SUM(gmv) OVER (PARTITION BY SUBSTR(bulan, 1, 4) ORDER BY bulan)        AS gmv_kumulatif_tahun
FROM bulanan
ORDER BY bulan;

-- 3 | KONSENTRASI SELLER (PARETO / ABC)
-- Berapa persen seller yang menghasilkan 80% penjualan? Seberapa bergantung platform pada segelintir seller?
-- Kelas A = seller yang, diurutkan dari terbesar, masih dibutuhkan untuk mencapai 80% GMV kumulatif; B = sampai 95%; C = sisanya.

WITH gmv_seller AS (
    SELECT oi.seller_id, SUM(oi.unit_price * oi.quantity) AS gmv
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
),
berurut AS (
    SELECT seller_id, gmv,
           SUM(gmv) OVER (ORDER BY gmv DESC, seller_id) AS gmv_kumulatif,
           SUM(gmv) OVER ()                             AS gmv_total
    FROM gmv_seller
),
berkelas AS (
    SELECT seller_id, gmv, gmv_total,
           CASE WHEN 100.0 * (gmv_kumulatif - gmv) / gmv_total < 80 THEN 'A'
                WHEN 100.0 * (gmv_kumulatif - gmv) / gmv_total < 95 THEN 'B'
                ELSE 'C' END AS kelas
    FROM berurut
)
SELECT kelas,
       COUNT(*)                                          AS jumlah_seller,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_seller,
       SUM(gmv)                                          AS gmv,
       ROUND(100.0 * SUM(gmv) / MAX(gmv_total), 1)       AS pct_gmv
FROM berkelas
GROUP BY kelas
ORDER BY kelas;

-- 4 | KINERJA KATEGORI DAN TINGKAT RETUR
-- Kategori mana yang paling besar penjualannya, dan kategori mana yang paling sering diretur?
-- Tingkat retur = baris item berstatus 'returned' / semua baris item yang diproses (delivered + returned); batal dikeluarkan.

WITH kategori AS (
    SELECT c.category_name,
           SUM(CASE WHEN o.order_status = 'delivered' THEN oi.unit_price * oi.quantity ELSE 0 END) AS gmv,
           SUM(CASE WHEN o.order_status = 'delivered' THEN oi.quantity ELSE 0 END)                 AS unit_terjual,
           COUNT(*)                                                                                AS baris_diproses,
           SUM(CASE WHEN o.order_status = 'returned' THEN 1 ELSE 0 END)                            AS baris_retur
    FROM order_items oi
    JOIN orders     o ON o.order_id    = oi.order_id
    JOIN products   p ON p.product_id  = oi.product_id
    JOIN categories c ON c.category_id = p.category_id
    WHERE o.order_status IN ('delivered', 'returned')
    GROUP BY c.category_id, c.category_name
)
SELECT category_name,
       gmv,
       ROUND(100.0 * gmv / SUM(gmv) OVER (), 1)               AS pct_gmv,
       RANK() OVER (ORDER BY gmv DESC)                        AS peringkat_gmv,
       unit_terjual,
       ROUND(100.0 * baris_retur / baris_diproses, 1)         AS retur_pct,
       RANK() OVER (ORDER BY baris_retur * 1.0 / baris_diproses DESC) AS peringkat_retur
FROM kategori
ORDER BY gmv DESC;

-- 5 | RETENSI KOHORT BULANAN
-- Dari pelanggan yang daftar di bulan tertentu, berapa persen yang masih berbelanja 1, 2, ... 6 bulan kemudian?
-- Kohort = bulan daftar. M0 = bulan daftar itu sendiri. Pesanan batal tidak dihitung.
-- Sel dikosongkan (NULL) jika bulan tersebut belum terjadi dalam data (data berakhir 2024-12).

WITH kohort AS (
    SELECT customer_id, signup_date, DATE_FORMAT(signup_date, '%Y-%m') AS cohort_bulan
    FROM customers
),
ukuran AS (
    SELECT cohort_bulan,
           COUNT(*) AS pelanggan,
           (2024 - YEAR(MIN(signup_date))) * 12 + (12 - MONTH(MIN(signup_date))) AS bulan_tersedia
    FROM kohort
    GROUP BY cohort_bulan
),
aktif AS (
    SELECT k.cohort_bulan,
           (YEAR(o.order_purchase_ts) - YEAR(k.signup_date)) * 12
             + MONTH(o.order_purchase_ts) - MONTH(k.signup_date) AS m,
           COUNT(DISTINCT k.customer_id) AS aktif
    FROM kohort k
    JOIN orders o ON o.customer_id = k.customer_id
    WHERE o.order_status <> 'canceled'
    GROUP BY k.cohort_bulan,
             (YEAR(o.order_purchase_ts) - YEAR(k.signup_date)) * 12
               + MONTH(o.order_purchase_ts) - MONTH(k.signup_date)
)
SELECT u.cohort_bulan, u.pelanggan,
       CASE WHEN u.bulan_tersedia >= 0 THEN ROUND(100.0 * COALESCE(SUM(CASE WHEN a.m = 0 THEN a.aktif END), 0) / u.pelanggan, 1) END AS m0,
       CASE WHEN u.bulan_tersedia >= 1 THEN ROUND(100.0 * COALESCE(SUM(CASE WHEN a.m = 1 THEN a.aktif END), 0) / u.pelanggan, 1) END AS m1,
       CASE WHEN u.bulan_tersedia >= 2 THEN ROUND(100.0 * COALESCE(SUM(CASE WHEN a.m = 2 THEN a.aktif END), 0) / u.pelanggan, 1) END AS m2,
       CASE WHEN u.bulan_tersedia >= 3 THEN ROUND(100.0 * COALESCE(SUM(CASE WHEN a.m = 3 THEN a.aktif END), 0) / u.pelanggan, 1) END AS m3,
       CASE WHEN u.bulan_tersedia >= 4 THEN ROUND(100.0 * COALESCE(SUM(CASE WHEN a.m = 4 THEN a.aktif END), 0) / u.pelanggan, 1) END AS m4,
       CASE WHEN u.bulan_tersedia >= 5 THEN ROUND(100.0 * COALESCE(SUM(CASE WHEN a.m = 5 THEN a.aktif END), 0) / u.pelanggan, 1) END AS m5,
       CASE WHEN u.bulan_tersedia >= 6 THEN ROUND(100.0 * COALESCE(SUM(CASE WHEN a.m = 6 THEN a.aktif END), 0) / u.pelanggan, 1) END AS m6
FROM ukuran u
LEFT JOIN aktif a ON a.cohort_bulan = u.cohort_bulan
GROUP BY u.cohort_bulan, u.pelanggan, u.bulan_tersedia
ORDER BY u.cohort_bulan;

-- 6 | PEMBELIAN ULANG PER KANAL AKUISISI
-- Channel akuisisi mana yang menghasilkan pelanggan yang kembali belanja, dan seberapa cepat?
-- Repeat 90 hari = pelanggan yang order ke-2 (bukan batal) terjadi <= 90 hari setelah order pertama.
-- Hanya pelanggan dengan order pertama sebelum 2024-10-02, supaya semua punya jendela 90 hari penuh (data berakhir 2024-12-31).
-- Median hari dihitung di antara pelanggan yang repeat dalam 90 hari.

WITH urut AS (
    SELECT customer_id, order_purchase_ts,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_purchase_ts, order_id) AS n
    FROM orders
    WHERE order_status <> 'canceled'
),
jarak AS (
    SELECT c.acquisition_channel AS kanal,
           c.customer_id,
           DATEDIFF(k.order_purchase_ts, p.order_purchase_ts) AS hari_ke_order2
    FROM customers c
    JOIN urut p ON p.customer_id = c.customer_id AND p.n = 1
    LEFT JOIN urut k ON k.customer_id = c.customer_id AND k.n = 2
    WHERE p.order_purchase_ts < '2024-10-02'
),
berurut AS (
    SELECT kanal, hari_ke_order2,
           ROW_NUMBER() OVER (PARTITION BY kanal ORDER BY hari_ke_order2) AS rn,
           COUNT(*)     OVER (PARTITION BY kanal)                         AS cnt
    FROM jarak
    WHERE hari_ke_order2 <= 90
),
median AS (
    SELECT kanal, AVG(hari_ke_order2) AS median_hari
    FROM berurut
    WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
    GROUP BY kanal
)
SELECT j.kanal,
       COUNT(*)                                                                    AS pelanggan,
       SUM(CASE WHEN j.hari_ke_order2 <= 90 THEN 1 ELSE 0 END)                     AS repeat_90_hari,
       ROUND(100.0 * SUM(CASE WHEN j.hari_ke_order2 <= 90 THEN 1 ELSE 0 END) / COUNT(*), 1) AS repeat_90_pct,
       m.median_hari                                                               AS median_hari_ke_order2
FROM jarak j
LEFT JOIN median m ON m.kanal = j.kanal
GROUP BY j.kanal, m.median_hari
ORDER BY repeat_90_pct DESC;

-- 7 | SEGMENTASI RFM
-- Bagaimana pelanggan terbagi menurut update, frekuensi, dan nilai belanja, dan segmen mana yang paling bernilai?
-- Hanya pesanan 'delivered'. Tanggal acuan 2025-01-01 (sehari setelah data berakhir).
-- R = NTILE(5) atas recency (skor 5 = paling baru); customer_id ditambahkan sebagai pembeda urutan agar hasil identik di setiap engine. F = batas tetap (1, 2, 3-4, 5-7, 8+): NTILE tidak cocok untuk frekuensi
-- karena banyak pelanggan berfrekuensi sama, dan NTILE akan memecah nilai yang sama ke skor berbeda secara acak.
-- Segmen memakai R dan F; M ditampilkan sebagai nilai.

WITH rfm AS (
    SELECT o.customer_id,
           DATEDIFF('2025-01-01', MAX(o.order_purchase_ts)) AS recency_hari,
           COUNT(DISTINCT o.order_id)                       AS frekuensi,
           SUM(oi.unit_price * oi.quantity)                 AS monetari
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.customer_id
),
skor AS (
    SELECT customer_id, recency_hari, frekuensi, monetari,
           NTILE(5) OVER (ORDER BY recency_hari DESC, customer_id) AS r,
           CASE WHEN frekuensi >= 8 THEN 5 WHEN frekuensi >= 5 THEN 4
                WHEN frekuensi >= 3 THEN 3 WHEN frekuensi = 2 THEN 2 ELSE 1 END AS f
    FROM rfm
),
segmen AS (
    SELECT customer_id, monetari,
           CASE WHEN r >= 4 AND f >= 4 THEN '1. Champions'
                WHEN r >= 3 AND f >= 3 THEN '2. Loyal'
                WHEN r >= 4 AND f <= 2 THEN '3. Promising'
                WHEN r  = 3 AND f <= 2 THEN '4. Need Attention'
                WHEN r <= 2 AND f >= 3 THEN '5. At Risk'
                ELSE '6. Hibernating' END AS segmen
    FROM skor
)
SELECT segmen,
       COUNT(*)                                          AS pelanggan,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_pelanggan,
       ROUND(AVG(monetari), 0)                           AS rata_rata_belanja,
       ROUND(100.0 * SUM(monetari) / SUM(SUM(monetari)) OVER (), 1) AS pct_total_belanja
FROM segmen
GROUP BY segmen
ORDER BY segmen;

-- 8 | KETERLAMBATAN DAN SKOR REVIEW
-- Seberapa besar keterlambatan pengiriman menurunkan kepuasan pelanggan?
-- Keterlambatan = tanggal tiba - tanggal estimasi, dalam hari kalender (negatif = lebih cepat dari estimasi).
-- Hanya pesanan 'delivered' yang punya review (retur dikeluarkan karena skornya dipengaruhi alasan lain).
-- Ini korelasi pada data observasi, bukan bukti sebab-akibat.

WITH ulasan AS (
    SELECT r.review_score,
           DATEDIFF(o.order_delivered_ts, o.estimated_delivery_date) AS terlambat_hari
    FROM reviews r
    JOIN orders o ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
),
bucket AS (
    SELECT review_score,
           CASE WHEN terlambat_hari <= 0 THEN 1
                WHEN terlambat_hari <= 2 THEN 2
                WHEN terlambat_hari <= 5 THEN 3
                ELSE 4 END AS urut,
           CASE WHEN terlambat_hari <= 0 THEN 'Tepat waktu / lebih cepat'
                WHEN terlambat_hari <= 2 THEN 'Terlambat 1-2 hari'
                WHEN terlambat_hari <= 5 THEN 'Terlambat 3-5 hari'
                ELSE 'Terlambat 6+ hari' END AS kelompok
    FROM ulasan
)
SELECT kelompok,
       COUNT(*)                                                     AS jumlah_review,
       ROUND(AVG(review_score), 2)                                  AS rata_rata_skor,
       ROUND(100.0 * SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_skor_1_2
FROM bucket
GROUP BY urut, kelompok
ORDER BY urut;

-- 9 | PENGIRIMAN DALAM PROVINSI VS ANTARPROVINSI
-- Seberapa lebih lama dan lebih sering terlambat pengiriman antarprovinsi, dan apakah ongkir dan kepuasannya berbeda?
-- Satu pesanan = satu seller, tetapi tabel order_items punya banyak baris per pesanan, maka dibuat dulu satu baris per (order, seller)
-- dengan ongkir yang sudah dijumlahkan, supaya pesanan tidak terhitung berkali-kali.
-- Waktu kirim = hari kalender dari tanggal pesan sampai tanggal tiba. Hanya pesanan 'delivered'.

WITH pasangan AS (
    SELECT order_id, seller_id, SUM(freight_value) AS ongkir
    FROM order_items
    GROUP BY order_id, seller_id
),
rute AS (
    SELECT o.order_id,
           CASE WHEN cu.province = s.province THEN 'Dalam provinsi' ELSE 'Antarprovinsi' END AS jenis_rute,
           DATEDIFF(o.order_delivered_ts, o.order_purchase_ts)       AS hari_kirim,
           DATEDIFF(o.order_delivered_ts, o.estimated_delivery_date) AS terlambat_hari,
           p.ongkir
    FROM orders o
    JOIN pasangan  p  ON p.order_id    = o.order_id
    JOIN customers cu ON cu.customer_id = o.customer_id
    JOIN sellers   s  ON s.seller_id    = p.seller_id
    WHERE o.order_status = 'delivered'
)
SELECT r.jenis_rute,
       COUNT(*)                                                         AS pesanan,
       ROUND(AVG(r.hari_kirim), 2)                                      AS rata_rata_hari_kirim,
       ROUND(100.0 * SUM(CASE WHEN r.terlambat_hari > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_terlambat,
       ROUND(AVG(r.ongkir), 0)                                          AS rata_rata_ongkir,
       ROUND(AVG(rv.review_score), 2)                                   AS rata_rata_skor_review
FROM rute r
LEFT JOIN reviews rv ON rv.order_id = r.order_id
GROUP BY r.jenis_rute
ORDER BY r.jenis_rute DESC;

-- 10 | 3 PRODUK TERLARIS PER KATEGORI
-- Pertanyaan: produk apa yang menjadi andalan tiap kategori, dan seberapa besar andalan itu terhadap kategorinya?

WITH produk AS (
    SELECT c.category_name, p.product_name,
           SUM(oi.unit_price * oi.quantity) AS gmv,
           SUM(oi.quantity)                 AS unit_terjual
    FROM order_items oi
    JOIN orders     o ON o.order_id    = oi.order_id
    JOIN products   p ON p.product_id  = oi.product_id
    JOIN categories c ON c.category_id = p.category_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.category_id, c.category_name, p.product_id, p.product_name
),
berperingkat AS (
    SELECT category_name, product_name, gmv, unit_terjual,
           ROW_NUMBER() OVER (PARTITION BY category_name ORDER BY gmv DESC, product_name) AS peringkat,
           SUM(gmv)     OVER (PARTITION BY category_name)                                 AS gmv_kategori
    FROM produk
)
SELECT category_name, peringkat, product_name, gmv, unit_terjual,
       ROUND(100.0 * gmv / gmv_kategori, 1) AS pct_dari_kategori
FROM berperingkat
WHERE peringkat <= 3
ORDER BY category_name, peringkat;
