# TGoshake / 火車搖起來

- 版本：V0.0.1
- 文件性質：開發前規劃與研究整理
- 建立日期：2026-09-08
- 目標平台：iPhone、SwiftUI、原生 Apple frameworks
- 研究資料表：[TGoshake_V0.0.1_Research_Table.md](TGoshake_V0.0.1_Research_Table.md)
- 系統設計規格：[TGoshake_V0.0.1_System_Design.md](TGoshake_V0.0.1_System_Design.md)

## 1. 產品定位

TGoshake 是以 iPhone 作為攜帶式感測器的「列車乘坐振動熱點篩查器」。它在乘車期間同步記錄：

- GPS 位置、速度、方向與定位精度
- 三軸線性加速度
- 三軸旋轉速度
- 手機姿態與重力方向
- 感測時間戳、實際取樣間隔及資料缺口

完成一趟記錄後，App 將行車軌跡依振動強度著色，並在地圖上圈選相對劇烈的區段，讓使用者回看波形及匯出原始資料。

### V0.0.1 的正確宣稱

本 App 可用於初步篩查、重複量測、比較乘坐感受及找出值得進一步檢查的區段，但不是經校正的鐵路檢測儀器，也不能單靠車廂內手機資料判定軌道故障或行車安全。車型、車速、車廂位置、手機型號、固定方式、旅客碰觸、彎道、道岔、橋梁及隧道都會影響量測結果。

研究支持這個保守定位：在控制相同列車、裝置、放置位置、路段及避免手機移動時，消費型手機可定位特殊或異常振動區段，但相關方法應作為專業量測的補充，而不是替代品。[Rodríguez et al., 2021](https://doi.org/10.1016/j.measurement.2021.109644)

## 2. V0.0.1 範圍

### 必做功能

1. 建立、開始、暫停、繼續及結束一趟記錄。
2. 開始前顯示固定方式：手機平放、螢幕朝上、手機頂端朝列車前進方向，並輸入行車方向、車種、車廂與座位備註。
3. 同步記錄 Core Motion 與 Core Location 來源資料及各自時間戳。
4. 顯示即時三軸波形、合成強度、GPS 狀態、目前速度、記錄時間及取樣狀態。
5. 記錄結束後計算每個短時間窗的振動特徵與相對強度。
6. 在 MapKit 顯示軌跡，以綠、黃、橘、紅標示由平穩至劇烈的區段，並以可點選圓圈標示事件群。
7. 點選地圖區段後，顯示其時間、位置精度、速度、三軸數值、峰值及前後波形。
8. 保留未套用分析濾波的來源資料，並匯出 CSV 加 JSON 中繼資料；分享前讓使用者確認是否包含精確 GPS。
9. 所有資料預設只存本機，不需要帳號、雲端或伺服器。
10. 支援藍牙控制器手動標記使用者主觀感受到的劇烈晃動；標記與自動偵測結果分開保存及顯示。

### 暫不納入

- 軌道故障分類、安全警報或維修結論
- ISO 2631 或 EN 12299 合規認證分數
- 機器學習模型與群眾資料上傳
- 地下路段的慣性導航及完整路線圖匹配
- 背景鎖屏長時間記錄
- Apple Watch、外接 IMU、後端網站或跨裝置同步

V0.0.1 採前景記錄，記錄中保持螢幕喚醒。背景持續定位牽涉額外 capability、權限說明、耗電及 App Store 審查；Apple 也要求只在確有即時需求時使用背景定位。[Apple：Handling location updates in the background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)

## 3. 技術方案

### 技術棧

| 項目 | 選擇 | 用途 |
|---|---|---|
| UI | SwiftUI | 記錄、波形、歷史與設定 |
| 動態感測 | Core Motion / `CMMotionManager` | 加速度、重力、旋轉速度、姿態 |
| 定位 | Core Location / `CLLocationManager` | 經緯度、速度、方向、精度與時間戳 |
| 地圖 | MapKit for SwiftUI | 軌跡、分段著色、事件圓圈與註記 |
| 工作階段索引 | SwiftData | 行程清單、摘要、備註、檔案位置 |
| 高頻資料 | 檔案串流 | 避免每秒大量 SwiftData 寫入；以 CSV/JSON 儲存 |
| 圖表 | Swift Charts | 即時降採樣顯示及事後波形 |

Core Motion 能提供原始或經處理的三軸資料；`CMDeviceMotion` 可分開重力與 `userAcceleration`，並提供姿態及去偏差旋轉速度。[Apple：CMDeviceMotion](https://developer.apple.com/documentation/coremotion/cmdevicemotion) MapKit for SwiftUI 原生支援 `MapPolyline`、`MapCircle`、Marker 與 Annotation，足以完成第一版熱點地圖。[Apple：MapKit for SwiftUI](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui)

### 建議取樣策略

- Device Motion：請求 100 Hz（`deviceMotionUpdateInterval = 0.01`）。硬體實際上限因機型而異，Apple 明確要求以每筆時間戳判斷真實間隔，不能假定一定是 100 Hz。[Apple：deviceMotionUpdateInterval](https://developer.apple.com/documentation/coremotion/cmmotionmanager/devicemotionupdateinterval)
- GPS：使用 `kCLLocationAccuracyBestForNavigation`、不以固定 Hz 作假設；保存每筆 `timestamp`、`horizontalAccuracy`、`speedAccuracy` 與 `courseAccuracy`。
- 即時圖表：只繪製 10–20 Hz 的降採樣畫面，未套用 App 分析濾波的 100 Hz 等級來源資料照常寫檔。
- 計算與寫檔：使用獨立 serial queue；UI 只接收節流後摘要，避免主執行緒掉幀。
- 單位：來源加速度保存 g，同時輸出換算值 m/s²（1 g 採 9.80665 m/s²）。
- 時間：同存 Core Motion 單調時間與 UTC wall-clock；用記錄起始錨點建立兩者對應。

Apple 文件指出所有 iOS 裝置都有三軸加速度計，請求頻率超過硬體能力時系統會改用支援上限。[Apple：Getting raw accelerometer events](https://developer.apple.com/documentation/coremotion/getting-raw-accelerometer-events) `CLLocation` 則同時帶有位置、速度、方向、精度及量測時間，可供資料品質判斷。[Apple：CLLocation](https://developer.apple.com/documentation/corelocation/cllocation)

### 座標與手機固定

第一版同時保存兩組資料：

1. 手機座標：保存 `CMDeviceMotion` 未套用本 App 分析濾波的 x、y、z，保留可追溯性；總加速度由 `userAcceleration + gravity` 計得，不冒稱硬體 raw accelerometer。
2. 分析座標：使用姿態將 `userAcceleration` 轉到重力垂直參考框架，再依開始時的固定方向標示為列車縱向、橫向、垂直。

建議採 `.xArbitraryCorrectedZVertical`；它讓 Z 軸保持垂直並改善旋轉穩定性，但水平 X 軸仍是任意起始方向，因此「手機頂端朝行進方向」和行車方向欄位不可省略。[Apple：CMAttitudeReferenceFrame](https://developer.apple.com/documentation/coremotion/cmattitudereferenceframe)

開始記錄前執行 5 秒靜止檢查：

- 確認裝置可提供 Device Motion。
- 估計靜止雜訊及基線。
- 若手機傾斜過大或持續被移動，顯示警告而不直接宣告校正成功。
- 記錄固定位置，例如桌板、座椅、車廂地板；不同位置的資料不可直接混合比較。

## 4. 資料設計

### 工作階段 `Session`

```text
id, schemaVersion, appVersion, deviceModel, osVersion
startTimeUTC, endTimeUTC, duration
routeName, direction, trainType, carNumber, seatNote
mountPosition, phoneOrientation, userNote
motionRequestedHz, motionActualMedianHz
locationPermission, preciseLocationEnabled
motionSampleCount, locationSampleCount, droppedSampleEstimate
analysisVersion, overallRelativeScore
```

### 動態資料 `motion.csv`

```text
elapsed_s, utc_time
total_accel_x_g, total_accel_y_g, total_accel_z_g
user_accel_x_g, user_accel_y_g, user_accel_z_g
gravity_x_g, gravity_y_g, gravity_z_g
rotation_x_rad_s, rotation_y_rad_s, rotation_z_rad_s
roll_rad, pitch_rad, yaw_rad
train_longitudinal_m_s2, train_lateral_m_s2, train_vertical_m_s2
```

### 定位資料 `location.csv`

```text
utc_time, latitude, longitude, altitude_m
horizontal_accuracy_m, vertical_accuracy_m
speed_m_s, speed_accuracy_m_s
course_deg, course_accuracy_deg
```

### 分析事件 `events.json`

每筆包含時間範圍、代表座標、定位精度、速度、三軸 RMS、合成 RMS、峰值、jerk RMS、百分位數、相對嚴重度、資料品質旗標及所屬事件群。

建議每趟資料存成一個 package：

```text
<session-uuid>/
  metadata.json
  motion.csv
  location.csv
  events.json
```

## 5. 第一版分析方法

### 處理流程

1. 依 Core Motion 時間戳檢查排序、實際取樣率與缺口，不先假定等間隔。
2. 將 `userAcceleration` 轉成列車縱向、橫向、垂直加速度。
3. 以插值重採樣成固定時間序列；遇到過長缺口則切段，不跨缺口補值。
4. 先保留未套用 App 分析濾波的來源訊號；另建立 0.5–30 Hz 的研究用分析通道。濾波參數及版本必須寫入 metadata。
5. 使用 1 秒窗、50% 重疊計算：各軸 RMS、合成 RMS、最大絕對值、peak-to-peak、jerk RMS、95 百分位數。
6. 以同一趟行程的 rolling median 與 MAD 建立 robust z-score，先做「相對熱點」而非宣稱通用安全門檻。
7. 依振動時間戳尋找前後 GPS 點並插值；只有定位有效、精度足夠且時間間隔不過長才配置座標。
8. 將連續或相距很近的高分窗合併為事件群，避免地圖塞滿圓點。
9. 軌跡依分位數分四級著色；圓圈半徑至少反映 `horizontalAccuracy`，定位不可靠時以灰色及「位置不確定」標示。

### 初始分級

V0.0.1 不寫死工程判定值，而以單趟有效窗的分布分級：

- 綠：0–50 百分位
- 黃：50–80 百分位
- 橘：80–95 百分位
- 紅：95–100 百分位

這只代表「相對於本趟較劇烈」。若要跨趟比較，必須先依路段、方向、速度帶、車型、車廂位置、手機型號及固定方式分組，待實測建立基線後才加入可重現的絕對門檻。

### 為何不在第一版直接判故障

車體振動確實能與軌道幾何狀態相關：Paixão 等人在 11 km 路段以 100 Hz 級手機量測，報告垂直加速度統計值與縱向軌面幾何有高相關；但其設置、列車與參考軌檢資料均受控制。[Paixão et al., 2019](https://doi.org/10.1155/2019/1729153) 專用研究系統也會結合垂直、橫向加速度、roll rate、GNSS、速度與既有軌道資料後才進行故障分類。[Tsunashima, 2019](https://doi.org/10.3390/app9132734) 因此 TGoshake 的第一步應是穩定記錄、找熱點及建立可重複資料，而不是先套模型。

## 6. GPS 與地圖限制

- `horizontalAccuracy` 是以座標為中心的可能誤差半徑；負值代表無效。每個事件都必須顯示其精度，不能只畫看似精準的小點。[Apple：horizontalAccuracy](https://developer.apple.com/documentation/corelocation/cllocation/horizontalaccuracy)
- 地下、長隧道、車站遮蔽處可能缺少可靠 GPS。V0.0.1 不以最後位置硬貼整段振動，也不把無定位事件丟棄；事件仍保留時間與里程估計欄位，但地圖顯示為待定位。
- GPS 更新遠慢於動態感測，必須以時間戳對齊，不可按陣列索引配對。
- MapKit 顯示的是量測軌跡，不保證貼合官方鐵道路線。正式 map matching 留到後續版本。
- 高速下固定時間窗代表的距離會改變；跨速度比較時應增加 10 m 或其他固定距離分段。已有鐵路研究採用 10 m 子區段將頻率加權振動映射至 GIS。[Zoccali et al., 2018](https://doi.org/10.1016/j.measurement.2018.07.079)

## 7. 畫面規劃

### 首頁

- App 名稱：「火車搖起來」
- 版本：「V0.0.1」
- 主要按鈕：「開始新記錄」
- 最近行程、日期、路線、時間及最高相對強度

### 設置確認

- 圖示說明手機平放方向
- 路線、方向、車種、車廂、固定位置及備註
- GPS 權限、精確位置、Motion 可用性及 5 秒靜止檢查

### 記錄中

- 大型停止鍵，避免誤觸
- 計時、速度、GPS 精度、實際取樣率與資料品質燈號
- 三軸即時圖及合成強度
- 「手動標記事件」按鈕，可加入道岔、橋梁、明顯搖晃等備註
- 藍牙控制器狀態與按鍵測試結果；單按標記感受熱點，按住可標記完整晃動區間

### 行程結果

- 地圖：彩色軌跡、事件圓圈、圖例與 GPS 不確定區段
- 波形：點選地圖後同步移到該時段
- 摘要：有效時間、距離、最高峰、紅色區段數、資料缺口
- 匯出：原始資料、分析資料、是否包含精確 GPS

### 歷史與設定

- 歷史行程搜尋、重新命名、刪除與匯出
- 取樣請求值、濾波開關、顯示單位、隱私說明
- 研究模式參數需清楚標示「實驗性」，一般使用者不直接修改門檻

## 8. 實測與驗收計畫

### A. 桌面測試

- 靜置 10 分鐘，檢查基線、漂移、取樣間隔、檔案寫入及溫度。
- 人工輕敲三個方向，驗證軸向、事件時間與波形一致。
- 旋轉手機，確認原始座標改變但垂直參考框架仍合理。
- 模擬 GPS 拒絕、降低精確度、暫時中斷及舊位置資料。

### B. 實車先導測試

- 同一支 iPhone、同一固定位置、同車型、同方向、相近速度，至少重複 3 趟。
- 第一階段優先選地面路段，包含已知道岔、橋梁、彎道或站間區段。
- 每趟開始前做 5 秒靜止檢查，途中不得拿起手機。
- 比較相同熱點是否在允許的 GPS 誤差範圍內重現。
- 另以 phyphox 或 SensorLog 做獨立對照趟，檢查原始數值量級與頻譜趨勢。

### C. V0.0.1 驗收條件

- 30 分鐘前景記錄不中斷、不明顯卡頓，原始檔可正常關閉及再次讀取。
- 每筆 motion 與 location 都保留來源時間戳；能報告實際取樣率與缺口。
- App 強制中止後，已落盤資料可恢復為「未完成行程」。
- 地圖點選事件可準確跳到相同時間的波形。
- 藍牙按鍵能建立獨立的主觀感受標記；控制器斷線時仍可使用畫面按鈕，且事件不遺失或重複。
- 無 GPS 時仍保存振動資料，不偽造座標。
- 同一輸入資料重跑分析會得到相同事件與分級。
- 匯出的 CSV/JSON 可由 Numbers、Excel、Python 或 MATLAB 讀取。

## 9. 可參考程式與工具

| 資源 | 可參考內容 | 注意事項 |
|---|---|---|
| [Apple MotionGraphs / raw accelerometer example](https://developer.apple.com/documentation/coremotion/getting-raw-accelerometer-events) | Core Motion 更新頻率、三軸資料與即時圖 | 範例概念需改寫為目前 Swift/SwiftUI 架構 |
| [Apple Seismometer sample](https://developer.apple.com/tutorials/sample-apps/seismometer) | 振動儀表與線圖呈現 | Apple 已標示它不代表最新 SwiftUI/Xcode 實務，只作 UI/資料流參考 |
| [phyphox](https://phyphox.org/) | 免費感測、資料匯出、FFT、遠端控制 | 很適合先做實驗與對照，不直接嵌入產品 |
| [SensorLog](https://apps.apple.com/us/app/sensorlog/id388014573) | iPhone 多感測器、最高約 100 Hz、CSV/JSON | 商業 App，只作欄位與量測流程參考 |
| [GPS-Logger-iOS](https://github.com/esripdx/GPS-Logger-iOS) | 離線 GPS、活動與批次資料記錄 | 舊專案且有既有授權/依賴，僅閱讀設計，不複製程式碼 |
| [LocoKit](https://github.com/sobri909/LocoKit) | iOS 定位、動態與活動記錄框架 | LGPL 授權且功能超出本案；V0.0.1 優先使用原生框架 |

## 10. 期刊、論文與標準資料

### 優先閱讀

1. Paixão, Fortunato & Calçada, **Smartphone’s Sensing Capabilities for On-Board Railway Track Monitoring**, 2019. 手機三軸 MEMS、100 Hz 級量測、垂直振動與軌道幾何關聯。[DOI](https://doi.org/10.1155/2019/1729153)
2. Rodríguez et al., **Smartphones and tablets applications in railways, ride comfort and track quality**, 2021. 手機鐵路量測綜述、轉換區案例及控制量測條件的重要性。[DOI](https://doi.org/10.1016/j.measurement.2021.109644)
3. Zoccali, Loprencipe & Lupascu, **Acceleration measurements inside vehicles: Passengers’ comfort mapping on railways**, 2018. 慣性感測器加 GPS、ISO 2631 頻率加權、10 m 區段與 GIS 熱點。[DOI](https://doi.org/10.1016/j.measurement.2018.07.079)
4. Azzoug & Kaewunruen, **RideComfort: A Development of Crowdsourcing Smartphones in Measuring Train Ride Quality**, 2017. 手機列車舒適度、Sperling 指標、取樣率波動與群眾量測限制。[DOI](https://doi.org/10.3389/fbuil.2017.00003)
5. Urbaniak et al., **The Application of Mobile Devices for Measuring Accelerations in Rail Vehicles**, 2025. 多城市電車實測、手機 MEMS 與 GPS 的近期方法案例。[DOI](https://doi.org/10.3390/s25154635)
6. Tsunashima, **Condition Monitoring of Railway Tracks from Car-Body Vibration Using a Machine Learning Technique**, 2019. 車體垂直/橫向加速度、roll rate、GNSS 與受控故障分類。[DOI](https://doi.org/10.3390/app9132734)
7. Oliveira et al., **Experimental investigation on the use of multiple very low-cost inertial-based devices for comfort assessment and rail track monitoring**, 2022. 多個消費級感測器、時間對齊、離群感測器排除及訊號融合。[DOI](https://doi.org/10.1016/j.measurement.2022.111549)
8. Matsumoto et al., **Relationship between train vibration and track irregularity for condition-based track maintenance**, 2022. 重複列車振動量測、位置補償及維護趨勢。[DOI](https://doi.org/10.4203/ccc.1.31.13)
9. George et al., **Sensing discomfort of standing passengers in public rail transportation systems using a smart phone**, 2017. 三軸加速度與站立乘客主觀不適模型。[arXiv](https://arxiv.org/abs/1705.08012)

### 標準參考

- [ISO 2631-1:1997](https://www.iso.org/standard/7612.html)：全身振動量測與健康、舒適、感知的評估框架；目前版仍有效，但 ISO 已有新版草案進程。
- [EN 12299:2024](https://www.nen.nl/en/nen-en-12299-2024-en-331057)：鐵路乘客乘坐舒適度的量測與評估方法。

上述標準全文受版權保護且需合法取得。V0.0.1 只保留日後導入頻率加權與舒適度算法所需的原始資料，不在未取得完整標準、未校正及未驗證時標示「符合 ISO/EN」。

## 11. 開發順序

1. 建立 TGoshake Xcode 專案、資料模型與權限文案。
2. 完成可靠的 Core Motion / Core Location 記錄器及檔案復原。
3. 完成即時狀態與波形，先以實機驗證取樣和耗電。
4. 建立可重跑的離線分析器與單元測試。
5. 完成 MapKit 彩色軌跡、熱點圈選及波形聯動。
6. 完成歷史、匯出、GPS 隱私提示及異常中止復原。
7. 做桌面測試、至少 3 趟同條件實車先導測試，再凍結 V0.0.1 的初始參數。

## 12. 後續版本候選

- V0.0.2：背景/鎖屏記錄、電量與熱狀態管理、距離窗分析。
- V0.0.3：同一路段多趟疊圖、方向與速度分層、基線比較。
- V0.1.0：合法授權的鐵路線形圖資、股道／方向辨識、起訖里程範圍、map matching、巡查速度統計、GPS／貼線／里程可信度、隧道定位補強及研究級頻率加權。
- V0.2.0：外接校正 IMU、多手機同步、參考軌檢資料匯入與模型驗證。

## 13. 建議結論

TGoshake V0.0.1 技術上可行。最重要的不是先做複雜 AI，而是先確保四件事：固定方式一致、感測時間戳可靠、GPS 不確定性被保留、原始資料可重現分析。完成這個基礎後，手機才有機會成為可信的簡易篩查裝置，而不是只會顯示晃動數字的玩具。
