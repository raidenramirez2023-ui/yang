# MANUSKRIPTO: SISTEMA NG SALES FORECASTING
**Yang Chow Dimsum & Tea House**  
*Modyul ng Pagtataya sa Benta, Pag-order ng Sangkap, at Pag-iskedyul ng Tauhan*

---

## 1. INTRODUKSYON: ANO ANG SALES FORECASTING?

Ang **Sales Forecasting** ay ang matalinong pagtataya o paghula sa **papasok na benta at dami ng customer** sa mga darating na araw (susunod na **7 araw**, **14 araw**, o **30 araw**).

Katulad ito ng **ulat sa panahon (weather forecast)**:
* Kung paanong nagdadala tayo ng payong kapag sinabing uulan, ang sales forecast naman ay nagbibigay-alam sa manedyer kung kailan magiging abala o maluwag ang restaurant upang makapaghanda nang maaga.

### Bakit ito mahalaga sa Yang Chow?
1. **Iwas-Tapon sa Pagkain (Food Spoilage Prevention):** Alam ng kusina kung gaano karaming karne, dimsum, gulay, at bigas ang bibilhin sa supplier upang laging sariwa at walang masayang.
2. **Tamang Dami ng Empleyado (Staff Roster & Scheduling):** Alam kung aling araw ang dapat may dagdag na waiter at kusinero, at kung aling araw ang maluwag.
3. **Paghahanda sa Pera at Budget (Cashflow Planning):** Alam ng may-ari kung magkano ang papasok na benta linggo-linggo at buwan-buwan.

---

## 2. BAKIT 7, 14, AT 30 ARAW LANG ANG NAKALAGAY?
*(Paboritong itanong ng mga panelist sa defense)*

May **tatlong (3) matitibay na operational at statistical na dahilan**:

1. **Pang-araw-araw na Operasyon sa Restaurant (Perishables Shelf-Life):**
   * Karamihan sa sangkap ng Yang Chow (karne, gulay, seafoods) ay binibili linggo-linggo o kada 2 hanggang 4 na linggo. Ang pag-forecast nang lampas 30 araw ay hindi na praktikal para sa pamimili ng sangkap dahil may expiry date at limitasyon sa freezer.
2. **Pang-Buwanang Ikot ng Negosyo (Monthly Business Cycle):**
   * Ang **30 araw** ay sumasakop sa eksaktong isang buong buwan ng negosyo. Sakop nito ang:
     * Apat (4) na buong weekend (Biyernes hanggang Linggo).
     * Dalawang araw ng sahod o paydays (ika-15 at ika-30 ng buwan).
     * Buwanang pagkwenta ng budget para sa kuryente, renta, at pasahod.
3. **Mataas na Katumpakan (Forecast Accuracy vs Noise):**
   * Sa loob ng 7 hanggang 30 araw, mataas ang accuracy (75%–95%) dahil sariwa ang datos ng customer behavior. Kapag ginawang 60, 90, o 365 araw, bumababa ang katumpakan ng walk-in estimates dahil marami pang maaaring magbago (panahon, holiday promos, inflation, kompetisyon).
   * *Paalala:* Para sa nakaraan at taunang pagsusuri (past annual data), ginagamit ang hiwalay na **Sales Report Page** (Daily, Weekly, Monthly, Annually, annully,monthly).

---

## 3. ANG DALAWA (2) PANGUNAHING BAHAGI NG FORMULA

Hindi hula sa hangin ang ginagawa ng programa. Diretso itong kumukuha ng datos mula sa Supabase database:

```
┌─────────────────────────────────────────────────────────────────┐
│              1. SIGURADONG BENTA (BOOKINGS PIPELINE)             │
│    Mula sa approved 'reservations' at bayad na 'advance_orders' │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 ┼ (PLUS)
                                 │
┌────────────────────────────────▼────────────────────────────────┐
│             2. TANTYANG WALK-IN (STOCHASTIC DEMAND)             │
│    Mula sa 'orders' (DOW 90-day baseline) × Trend Multiplier    │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 ▼
                 KABUUANG INAASAHANG BENTA (TOTAL)
```

$$\mathbf{Kabuuang\;Forecast} = \mathbf{Siguradong\;Bookings} + (\mathbf{Dating\;Average\;sa\;Araw} \times \mathbf{Trend\;Multiplier})$$

* Sa madaling salita:
  * **Tantyang Walk-In** = $\text{Dating Average sa Araw (DOW)} \times \text{Trend Multiplier}$
  * **Kabuuang Inaasahang Benta** = $\text{Siguradong Bookings} + \text{Tantyang Walk-In}$

---

## 4. HAKBANG-HAKBANG NA PAGKWENTA (ARITHMETIC EXPLANATION)

### HAKBANG 1: Pagkuha sa Baseline ng Araw (Day-of-Week Average)
Kinukuha ng system ang mga nakaraang benta sa loob ng 90 araw mula sa `orders` table. Inihihiwalay ang bawat araw ng linggo (Lunes hanggang Linggo).
* **Proteksyon sa Datos:** Hindi isinasama ang kasalukuyang araw (incomplete hours) upang hindi humatak pababa sa average.
* **Kabuuang Benta sa Nakaraang 90 Araw:** **₱577,551.78** (kabuuang benta mula sa 91 araw na naitala sa database).

#### 📊 Talaan ng 90-Araw na Rekord ng Benta (DOW Baseline Table):

| Araw ng Linggo | Kabuuang Benta sa 90 Araw | Bilang ng Araw | Pormula ng Average | 90-Day Baseline (DOW Average) |
| :--- | :--- | :--- | :--- | :--- |
| **Lunes** | ₱87,870.77 | 13 na araw | ₱87,870.77 ÷ 13 | **₱6,759.29** / araw |
| **Martes** | ₱94,385.98 | 13 na araw | ₱94,385.98 ÷ 13 | **₱7,260.46** / araw |
| **Miyerkules** | ₱71,125.34 | 13 na araw | ₱71,125.34 ÷ 13 | **₱5,471.18** / araw |
| **Huwebes** | ₱81,244.41 | 13 na araw | ₱81,244.41 ÷ 13 | **₱6,249.57** / araw |
| **Biyernes** | ₱103,279.02 | 13 na araw | ₱103,279.02 ÷ 13 | **₱7,944.54** / araw *(Pinakamalakas)* |
| **Sabado** | ₱73,231.21 | 13 na araw | ₱73,231.21 ÷ 13 | **₱5,633.17** / araw |
| **Linggo** | ₱66,415.05 | 13 na araw | ₱66,415.05 ÷ 13 | **₱5,108.85** / araw |
| **KABUUAN** | **₱577,551.78** | **91 araw** | ₱577,551.78 ÷ 91 | **~₱6,346.72 / araw** (Pangkalahatang Daily Average) |

> **Paliwanag sa Talaan:**  
> Makikita rito na hindi pantay-pantay ang benta sa bawat araw. Ang Biyernes ang may pinakamataas na naipong benta (₱103,279.02) sa 13 Biyernes, kaya ang baseline nito ay ₱7,944.54. Kapag hinuhulaan ang darating na Biyernes, ang ₱7,944.54 ang gagamitin at hindi ang pangkalahatang average na ₱6,346.72.

---

### HAKBANG 2: Pagkwenta sa Trend Multiplier (Momentum Factor)
Kinukumpara ang benta ng **nakalipas na 14 na araw** laban sa **naunang 14 na araw**:
$$\text{Trend Multiplier} = \frac{\text{Benta sa Huling 14 Araw}}{\text{Benta sa Naunang 14 Araw}}$$

* **Halimbawa sa totoong benta:**
  * Benta nitong nakaraang 14 araw = ₱77,349.00
  * Benta noong naunang 14 araw = ₱82,456.04
  * Ratio: $\text{₱77,349} \div \text{₱82,456.04} = \mathbf{0.9381}$ (bumaba ng -6.2%).
* **Proteksyon Laban sa Labis na Pagbabago (Clamping):**
  * Naka-lock ang multiplier sa pagitan ng **0.85** (-15%) at **1.25** (+25%). Kahit magkaroon ng isang araw na napakalaking benta, hindi magiging sobra-sobra ang projection ng system.

---

### HAKBANG 3: Pagkwenta sa Tantyang Walk-in Customers
Kapag hinulaan ang isang Martes:
$$\text{₱7,260.46 (Average ng Martes)} \times \mathbf{0.9381 (Trend)} = \mathbf{₱6,811.04}$$
*(Inaasahang may ₱6,811.04 na papasok mula sa mga regular na walk-in customer).*

---

### HAKBANG 4: Pagsasama ng Siguradong Bookings (Pipeline)
Sinisiyasat ng system ang `reservations` at `advance_orders` sa database na may `status = confirmed` o `paid`.
* Halimbawa noong Martes (Setyembre 29):
  * May kumpirmadong Corporate Event (Onel Diaz) na may contract value na **₱143.80**.
* **Pagsasamahin:**
  $$\text{₱143.80 (Sigurado)} + \text{₱6,811.04 (Walk-in)} = \mathbf{₱6,954.84}$$
*(Ang kabuuang forecast para sa araw na iyon ay **₱6,954.84**).*

---

### HAKBANG 5: Pagkwenta sa Confidence Score
Paano nalalaman ng system kung gaano ito kasigurado sa projection?
$$\text{Confidence Score} = 0.75 + \left(\frac{\text{Siguradong Bookings}}{\text{Kabuuang Forecast}} \times 0.23\right)$$

* Nagsisimula sa **0.75 (75%)** base accuracy dahil sa 90-araw na historical data.
* Tumataas hanggang **0.98 (98%)** habang lumalaki ang bahagi ng mga kumpirmadong advance bookings na may bayad na.

---

### HAKBANG 6: Pagtukoy sa Katayuan sa Kusina (Operational Load)
Kinukumpara ang total forecast laban sa karaniwang benta bawat araw (`historicalDailyAvg`):
* 🟢 **Maluwag na Araw (Light):** Mas mababa sa 90% ng normal na benta.
* 🔵 **Normal na Daloy (Steady):** 90% hanggang 124% ng normal na benta.
* 🟡 **Abala ang Kusina (Busy):** 125% hanggang 159% o mayroong nakatakdang catering event.
* 🔴 **Sobrang Dagsa (Peak):** 160% pataas o 2 o higit pang malalaking event reservation sa parehong araw.

---

## 5. MGA PINAKAMADALAS NA TANONG SA DEFENSE (Q&A CHEATSHEET)

| Tanong ng Panelist | Mabilis at Tamang Sagot |
| :--- | :--- |
| **Bakit hindi buong taon (1 year) ang forecast?** | "Dahil ang modyul na ito ay isang **Operational Forecast** para sa pang-araw-araw na imbentaryo at staffing ng kusina. Ang mga sangkap ay may shelf-life at hindi ini-stock nang lampas 30 araw. Para sa taunang benta, may hiwalay tayong **Sales Report Page**." |
| **Paano kung may holiday o biglang umulan?** | "May **14-day trend momentum** ang formula na awtomatikong nag-a-adjust kapag lumalakas o humihina ang pasok ng customer nitong nakaraang dalawang linggo." |
| **Kasama ba ang mga unpaid bookings sa kita?** | "Hindi po. Tanging ang may status na `confirmed`, `approved`, o may bayad na (`deposit_paid`/`paid`) ang itinuturing na Siguradong Benta upang hindi umasa ang kusina sa hindi pa kumpirmado." |
| **Saan galing ang datos ng walk-in?** | "Mula sa totoong historical POS orders sa nakaraang 90 araw na naka-index bawat araw ng linggo (Day-of-Week pattern)." |

---

## 6. BUOD NG MGA BENEPISYO SA RESTAURANT

1. **Zero Over-ordering:** Hindi masisira ang mga sariwang sangkap sa ref dahil sapat lang ang nabibili.
2. **Smooth Kitchen Flow:** Alam ng chef kung aling araw ang dapat mag-pre-cut at magpausok ng dimsum bago pa magbukas ang pinto.
3. **Export Ready:** Isang click lang, nade-download agad ang buong ulat sa **Excel (.xlsx)** o **PDF** para sa meeting ng may-ari at accounting.
