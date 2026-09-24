# TGoshake / 火車搖起來 V0.0.3

TGoshake 將 iPhone 作為列車乘坐振動熱點篩查器，同步記錄 Device Motion、GPS、速度、定位精度與使用者主觀感受打卡。

## 已完成

- SwiftUI 首頁、行程設定、5 秒固定檢查、記錄、結果、歷史及設定頁
- `CMDeviceMotion` 100 Hz 等級請求，保存實際 timestamp
- Core Location 座標、速度、方向與精度欄位
- 即時三軸 Swift Charts 波形及取樣／GPS 狀態；以最近 10 秒時間窗向前移動並自動調整振幅尺度，避免長時間記錄後波形被壓縮
- 圖表可切換三排、疊圖、橫向、縱向或垂直單軸顯示
- 紫色手動打卡按鈕位於記錄狀態下方；最新打卡紀錄可點選查看時間、來源、備註與 GPS
- 記錄畫面最上方固定顯示暫停與結束；計時維持單行，打卡按鈕置於狀態列下方
- 新增 X／Y／Z 三排同步圖卡模式，並保留三軸疊圖及單軸模式
- 晃動記錄卡只顯示最新一筆摘要，避免新增標記後把下方資訊持續往下推
- 畫面與藍牙手動打卡不觸發 App 觸覺回饋，避免手機自行產生的震動進入量測波形
- Apple Game Controller profile 藍牙控制器 A 鍵：短按建立感受點、按住建立區間
- 每趟 `motion.csv`、`location.csv`、`markers.json`、`events.json`、`metadata.json`、`manifest.json`
- 0.5–30 Hz 零相位分析通道、1 秒窗／50% 重疊、RMS、P95、peak、jerk、rotation rate 與相對百分位分級
- MapKit 彩色軌跡、GPS 誤差圓與紫色人工標記
- 歷史行程可點選查看列車、座位、放置位置、紀錄數量及匯出項目
- 路線、南北向、車種及對應車廂數預設選單；例外車種與車廂可手動輸入
- 放置位置支援機車頭、機車尾，座位維持手動輸入
- 歷史行程支援向左滑動刪除，刪除前會再次確認並說明無法復原
- 使用專屬 1024 × 1024 不透明 App 圖示
- 來源資料與分析結果分離；無 GPS 時仍保存 Motion

## 開啟與建置

用 Xcode 開啟：

```text
TGoshake.xcodeproj
```

命令列建置：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project TGoshake.xcodeproj \
  -scheme TGoshake \
  -sdk iphonesimulator26.5 \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

實機安裝需要可用的 Apple Development identity、Development Team 與 provisioning profile。Core Motion、真實 GPS 與藍牙按鍵必須用實體 iPhone 驗證，模擬器只能檢查 UI、儲存及演算法。

## 已執行驗證

- Xcode 26.6／iOS Simulator 26.5：Build succeeded
- Xcode static analysis：Analyze succeeded
- XCTest：4 項通過
  - 明顯合成振動 burst 會落入紅色分析窗
  - 過短資料不建立分析窗
  - 濾波遇到時間缺口仍保持數量及有限數值
  - 車種對應車廂上限及「其他」手動輸入規則正確
- iPhone 16 模擬器：安裝及啟動成功，首頁已目視檢查

## 目前限制

- iOS deployment target 為 17.0，使用 SwiftUI MapKit overlays。
- 模擬器沒有可代表實機的 Device Motion。
- 目前藍牙輸入支援 Apple Game Controller profile；一般自拍器不保證相容。
- V0.0.3 採前景記錄，沒有鎖屏背景持續 Motion 保證。
- 車種與廂數是操作用預設值，實際編組異動時請使用「其他」手動輸入。
- 分享目前以完整 `.tgoshake` session package 為單位，尚未加入可移除 GPS 的 ZIP 匯出器。
- 相對顏色不是軌道故障、安全或 ISO／EN 合規判定。
- 鐵路正式圖資、股道、起訖里程、巡查速度分層及里程可信度規劃於後續版本。

## 專案文件

- [總體規劃](docs/Planning.md)
- [研究資料表](docs/Research_Table.md)
- [系統設計規格](docs/System_Design.md)
