# TGoshake / 火車搖起來 V0.0.1－研究資料表

- 整理日期：2026-09-08
- 用途：將開發前蒐集的技術文件、程式、期刊、論文及標準集中表列
- 詳細規劃：[TGoshake_V0.0.1_Planning.md](TGoshake_V0.0.1_Planning.md)
- 系統設計：[TGoshake_V0.0.1_System_Design.md](TGoshake_V0.0.1_System_Design.md)

## 一、Apple 原生技術資料

| 編號 | 技術／文件 | 可取得資料或能力 | TGoshake 用途 | V0.0.1 決策 |
|---|---|---|---|---|
| A01 | [Core Motion](https://developer.apple.com/documentation/coremotion/) | 加速度計、陀螺儀、磁力計及處理後的 Device Motion | 感知列車三軸振動與手機姿態 | 採用 |
| A02 | [`CMDeviceMotion`](https://developer.apple.com/documentation/coremotion/cmdevicemotion) | `userAcceleration`、gravity、attitude、rotation rate、magnetic field | 分離重力，保留三軸線性加速度、姿態與旋轉速度 | 作為主要 Motion 資料源 |
| A03 | [`CMMotionManager`](https://developer.apple.com/documentation/coremotion/cmmotionmanager) | 啟停感測、設定更新間隔、選擇姿態參考框架 | 建立記錄器並把資料送到背景工作佇列 | 採用獨立 serial queue |
| A04 | [Getting raw accelerometer events](https://developer.apple.com/documentation/coremotion/getting-raw-accelerometer-events) | iPhone 三軸加速度、硬體支援頻率限制、MotionGraphs 概念 | 了解軸向、單位、取樣上限及即時圖 | 作技術與測試參考 |
| A05 | [`deviceMotionUpdateInterval`](https://developer.apple.com/documentation/coremotion/cmmotionmanager/devicemotionupdateinterval) | 設定要求間隔；實際上限依硬體而定；須檢查資料時間戳 | 請求 0.01 秒、約 100 Hz，並計算真實取樣率 | 不把 100 Hz 視為保證值 |
| A06 | [`CMAttitudeReferenceFrame`](https://developer.apple.com/documentation/coremotion/cmattitudereferenceframe) | 垂直、磁北、真北及任意水平參考框架 | 將手機姿態轉成列車縱向、橫向、垂直方向 | 優先 `.xArbitraryCorrectedZVertical` |
| A07 | [Core Location](https://developer.apple.com/documentation/corelocation) | GPS、Wi-Fi、行動網路等來源整合的位置資訊 | 記錄行車位置、速度、方向及定位狀態 | 採用 |
| A08 | [`CLLocationManager`](https://developer.apple.com/documentation/corelocation/cllocationmanager) | 啟停位置更新、精度與距離篩選、權限狀態 | 管理乘車 GPS 記錄 | V0.0.1 前景使用 |
| A09 | [`CLLocation`](https://developer.apple.com/documentation/corelocation/cllocation) | 座標、高度、速度、course、時間戳及各項精度 | 與 Motion 依時間戳對齊，並保存 GPS 品質 | 保存完整欄位 |
| A10 | [`horizontalAccuracy`](https://developer.apple.com/documentation/corelocation/cllocation/horizontalaccuracy) | 以公尺表示座標可能誤差半徑；負值代表無效 | 決定地圖圓圈及是否能配置振動事件位置 | 必須顯示／保存，不隱藏誤差 |
| A11 | [Background location updates](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background) | 背景定位 capability、權限、系統限制與透明提示 | 後續處理鎖屏記錄 | V0.0.1 暫緩；先採前景記錄 |
| A12 | [MapKit for SwiftUI](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui) | Map、Marker、Annotation、MapPolyline、MapCircle | 畫行車軌跡、著色區段及圈選熱點 | 採用，不依賴第三方地圖 SDK |
| A13 | [Swift Charts](https://developer.apple.com/documentation/charts) | SwiftUI 原生圖表 | 即時三軸波形及事後回看 | 畫面降採樣至約 10–20 Hz |
| A14 | [SwiftData](https://developer.apple.com/documentation/swiftdata) | 本機持久化模型 | 保存工作階段索引、摘要、備註與檔案位置 | 高頻樣本不逐筆寫入 SwiftData |
| A15 | [GameController](https://developer.apple.com/documentation/gamecontroller) | 接收相容藍牙遊戲控制器的按下與放開事件 | 不碰觸 iPhone 即可建立主觀晃動標記 | V0.0.1 支援 A 鍵短按點標記及按住區間標記 |
| A16 | [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth) | 與具有已知 BLE service／characteristic 的自訂周邊通訊 | 後續支援指定型號的簡易 BLE 按鍵 | 未有硬體 UUID 前不宣稱支援所有自拍器 |

## 二、參考程式與量測工具

| 編號 | 程式／工具 | 類型 | 可參考內容 | 對 TGoshake 的用途 | 注意事項 |
|---|---|---|---|---|---|
| P01 | [Apple MotionGraphs 概念範例](https://developer.apple.com/documentation/coremotion/getting-raw-accelerometer-events) | Apple 技術範例 | 三軸取樣、更新頻率與即時繪圖 | 建立 Motion 資料流與圖表原型 | 範例概念需改寫為目前 Swift／SwiftUI 架構 |
| P02 | [Apple Seismometer](https://developer.apple.com/tutorials/sample-apps/seismometer) | Apple 教學範例 | 震動數值、指針及線圖 | 參考即時震動 UI 與資料更新方式 | Apple 已註明不代表最新 SwiftUI／Xcode 實務 |
| P03 | [phyphox](https://phyphox.org/) | 免費 iOS／Android 感測 App | 加速度、陀螺儀、GPS、FFT、CSV／Excel 匯出、遠端控制 | 開發前先導量測及完工後對照測試 | 不嵌入產品；不同 App／手機須分開做對照趟 |
| P04 | [SensorLog](https://apps.apple.com/us/app/sensorlog/id388014573) | iOS 感測記錄 App | 多感測器、最高約 100 Hz、CSV／JSON、TCP／UDP | 核對欄位、取樣量級與匯出格式 | 商業 App，只作方法參考 |
| P05 | [GPS-Logger-iOS](https://github.com/esripdx/GPS-Logger-iOS) | 開源 iOS 專案 | 離線位置、Motion State、電池及批次資料記錄 | 參考行程生命週期與離線保存 | 專案較舊；先查依賴與授權，不直接複製程式碼 |
| P06 | [LocoKit](https://github.com/sobri909/LocoKit) | 開源 iOS framework | 定位、Motion 與活動記錄 | 參考定位記錄架構 | LGPL；功能超出第一版，TGoshake 優先用 Apple 原生框架 |

## 三、期刊、論文與學術資料

| 編號 | 年份 | 作者／題名 | 研究內容 | 與 TGoshake 直接相關的發現 | 導入方式 | 來源 |
|---|---:|---|---|---|---|---|
| R01 | 2019 | Paixão, Fortunato & Calçada－*Smartphone’s Sensing Capabilities for On-Board Railway Track Monitoring* | 以列車內手機三軸 MEMS 量測約 11 km 鐵道路段 | 使用約 100 Hz；垂直加速度統計與縱向軌面幾何呈高相關，但量測條件受到控制 | 採 100 Hz 等級、固定手機、垂直振動與分段統計；不直接推論故障 | [DOI 10.1155/2019/1729153](https://doi.org/10.1155/2019/1729153) |
| R02 | 2021 | Rodríguez et al.－*Smartphones and tablets applications in railways, ride comfort and track quality* | 手機鐵路量測綜述及軌道轉換區案例 | 手機可找出橋梁、隧道、道岔或轉換區等特殊區段；同列車、同裝置、同位置及不移動是比較前提 | 將車型、車廂、位置、方向、固定方式列為必填中繼資料 | [DOI 10.1016/j.measurement.2021.109644](https://doi.org/10.1016/j.measurement.2021.109644) |
| R03 | 2018 | Zoccali, Loprencipe & Lupascu－*Acceleration measurements inside vehicles: Passengers’ comfort mapping on railways* | 慣性感測器結合 GPS，依 ISO 2631 做列車舒適度地圖 | 以 10 m 子區段計算頻率加權垂直加速度並映射至 GIS，可找出局部劇烈區域 | V0.0.1 先用時間窗；後續增加固定距離窗及合法取得的頻率加權 | [DOI 10.1016/j.measurement.2018.07.079](https://doi.org/10.1016/j.measurement.2018.07.079) |
| R04 | 2017 | Azzoug & Kaewunruen－*RideComfort: A Development of Crowdsourcing Smartphones in Measuring Train Ride Quality* | 智慧型手機量測列車乘坐品質與 Sperling 指標 | 顯示可行性，也指出手機效能、取樣率波動、安裝方式及群眾參與會造成誤差 | 保存真實時間戳、計算缺樣率，第一版不做群眾上傳 | [DOI 10.3389/fbuil.2017.00003](https://doi.org/10.3389/fbuil.2017.00003) |
| R05 | 2025 | Urbaniak et al.－*The Application of Mobile Devices for Measuring Accelerations in Rail Vehicles* | 以市售手機在多個城市的電車路線實測 | 手機 MEMS 加 GPS 可將動態衝擊連到特定軌道區段；速度與行車條件會影響結果 | 同步保留速度、GPS 與三軸值；分析時按方向與速度分層 | [DOI 10.3390/s25154635](https://doi.org/10.3390/s25154635) |
| R06 | 2019 | Tsunashima－*Condition Monitoring of Railway Tracks from Car-Body Vibration Using a Machine Learning Technique* | 車體振動、GNSS 與機器學習的軌道狀態監測 | 研究系統結合垂直／橫向加速度、roll rate、速度、位置及參考資料後才分類軌道不整 | V0.0.1 只保存未來模型需要的特徵，不先做故障分類 | [DOI 10.3390/app9132734](https://doi.org/10.3390/app9132734) |
| R07 | 2022 | Oliveira et al.－*Experimental investigation on the use of multiple very low-cost inertial-based devices for comfort assessment and rail track monitoring* | 多個消費級慣性感測器在列車上的實驗 | 多感測器融合可提高穩健性；時間對齊及排除暫時異常感測器很重要 | 第一版建立嚴格時間軸、缺口及品質旗標；多手機融合留待後續 | [DOI 10.1016/j.measurement.2022.111549](https://doi.org/10.1016/j.measurement.2022.111549) |
| R08 | 2022 | Matsumoto et al.－*Relationship between train vibration and track irregularity for condition-based track maintenance* | 營運列車振動與軌道不整、位置補償及長期維護 | 重複量測及位置波形比對可提高定位一致性，並觀察劣化趨勢 | 後續加入同路段多趟疊圖與 map matching；V0.0.1 先確保可重複匯出 | [DOI 10.4203/ccc.1.31.13](https://doi.org/10.4203/ccc.1.31.13) |
| R09 | 2017 | George et al.－*Sensing discomfort of standing passengers in public rail transportation systems using a smart phone* | 手機加速度與站立乘客主觀不適的關係 | 可用加速度建立不適機率模型，但它描述人的感受，不等同軌道安全 | 供未來乘坐舒適度分數參考；不作 V0.0.1 安全指標 | [arXiv 1705.08012](https://arxiv.org/abs/1705.08012) |

## 四、標準與規範

| 編號 | 標準 | 主題 | TGoshake 關聯 | V0.0.1 處理方式 | 來源／狀態 |
|---|---|---|---|---|---|
| S01 | ISO 2631-1:1997 | 全身振動對健康、舒適及感知的量測與評估 | 提供軸向、量測位置、頻率加權、RMS／VDV 等正式方法背景 | 保留未濾波來源資料；未取得全文、校正及驗證前，不標示符合 ISO | [ISO 官方頁](https://www.iso.org/standard/7612.html)；1997 第二版，2021 再確認，目前仍有效但已有新版草案 |
| S02 | EN 12299:2024 | 鐵路乘客乘坐舒適度的量測與評估 | 提供重軌乘客車體運動及舒適度的可重複評估方法 | 列為後續研究模式依據；V0.0.1 不輸出 EN 合規分數 | [標準資訊頁](https://www.nen.nl/en/nen-en-12299-2024-en-331057)；2024 現行版 |

> 標準全文受版權保護，正式實作頻率加權、舒適度分數或合規聲明前，必須合法取得完整標準並確認版本。

## 五、研究結果轉成 V0.0.1 功能

| 研究共識／限制 | 對產品的影響 | V0.0.1 功能或資料欄位 |
|---|---|---|
| 手機可量到有用的列車振動，但不是校正過的軌檢儀器 | 只能標示相對熱點，不直接宣稱故障 | 「相對劇烈程度」、研究用途說明、安全免責文字 |
| 手機固定方式會大幅影響三軸值 | 必須規範手機方向並保留安裝資訊 | 5 秒靜止檢查、`mountPosition`、`phoneOrientation` |
| 車型、車速、車廂位置及方向都是混雜因素 | 不同條件不可直接比較 | `trainType`、`carNumber`、`direction`、`speed_m_s` |
| Motion 更新頻率可能波動 | 不可用樣本序號假設固定時間 | `elapsed_s`、實際中位取樣率、缺樣估計、資料缺口旗標 |
| GPS 更新較慢且存在誤差 | Motion 與 GPS 必須依時間對齊，地圖需呈現不確定性 | `utc_time`、`horizontal_accuracy_m`、灰色待定位事件 |
| 隧道或遮蔽區可能沒有 GPS | 不可把最後座標硬套給後續振動 | 保留無座標事件、標示「位置不確定」 |
| 相同路段的重複量測比單次峰值更可信 | 第一版須保存完整原始行程，方便後續疊圖 | 每趟獨立 package、schema 及 analysis version |
| 高振動可能來自道岔、橋梁、彎道、手機被碰觸或車輛本身 | 單一峰值不能推論軌道缺陷 | 手動事件註記、波形回看、資料品質旗標 |
| 固定距離窗適合跨速度與空間比較 | 只有固定時間窗仍可能受速度影響 | V0.0.1 先做 1 秒窗；後續加入 10 m 等距離窗 |
| 正式舒適度評估需要標準規定的頻率加權及量測條件 | 不能自創數值後掛上 ISO／EN 名稱 | 第一版採單趟 percentile 與 robust z-score 分級 |

## 六、V0.0.1 採用結論

| 項目 | 決定 |
|---|---|
| 英文檔名／專案名 | `TGoshake` |
| 中文名稱 | 火車搖起來 |
| 版本 | V0.0.1 |
| 產品定位 | 列車乘坐振動熱點篩查器 |
| Motion 來源 | `CMDeviceMotion` |
| Motion 要求頻率 | 100 Hz 等級，保存實際時間戳及真實取樣率 |
| GPS | Core Location，保存位置、速度、方向及所有可用精度欄位 |
| 地圖 | MapKit 彩色 `MapPolyline` 加可點選 `MapCircle` |
| 分析 | 1 秒窗、50% 重疊、RMS／峰值／jerk／百分位數／robust z-score |
| 地圖分級 | 綠 0–50%、黃 50–80%、橘 80–95%、紅 95–100% |
| 儲存 | SwiftData 存行程索引；CSV／JSON 檔案串流存高頻資料 |
| 隱私 | 預設只存本機，匯出前確認是否包含精確 GPS |
| 背景記錄 | 第一版不做，記錄中保持前景與螢幕喚醒 |
| 安全判定 | 不提供，不宣稱能取代鐵路專業檢測 |
