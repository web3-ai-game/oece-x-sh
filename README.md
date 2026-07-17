<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=12&height=200&section=header&text=oece-x.sh&fontSize=64&fontColor=ffffff&animation=fadeIn&fontAlignY=32&desc=VPS%20Toolkit%20%C2%B7%20Check%20%C2%B7%20Speed%20%C2%B7%20Route%20%C2%B7%20Deploy&descAlignY=56&descSize=18" width="100%"/>

# 🚀 oece-x.sh

**幫你在 3 分鐘內判斷一台 VPS 到底能不能用、值不值。**

*A single-file VPS inspection & deployment toolkit — check it, speed it, trace it, ship it.*

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash%204%2B-4EAA25?logo=gnubash&logoColor=white)](oece-x.sh)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen?logo=gnu&logoColor=white)](https://www.shellcheck.net/)
[![Version](https://img.shields.io/badge/Version-1.0.0-7c4dff)](oece-x.sh)
[![Platform](https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu%20%7C%20CentOS-informational?logo=linux&logoColor=white)](#-系統需求)
[![Arch](https://img.shields.io/badge/Arch-amd64%20%7C%20arm64-orange)](#-系統需求)

[![Single File](https://img.shields.io/badge/單檔-One%20Script-success)](oece-x.sh)
[![No Build](https://img.shields.io/badge/依賴-curl%20%2B%20tar-lightgrey)](#-安全性設計)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-ff69b4)](https://github.com/web3-ai-game/oece-x-sh/pulls)
[![YouTube](https://img.shields.io/badge/YouTube-%40oece--x-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/@oece-x)
[![Website](https://img.shields.io/badge/Web-oece--x.com-7c4dff?logo=googlechrome&logoColor=white)](https://oece-x.com)

<br/>

**繁體中文介面 · 單檔 · 一鍵執行 · 開源可審計**

</div>

---

## ⚡ 快速開始

```bash
bash <(curl -sL oece-x.com/x)
```

大陸海外均可直連。備用（GitHub raw，大陸需科學上網）：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/web3-ai-game/oece-x-sh/main/oece-x.sh)
```

> 需要 root（或 `sudo`）。腳本內所有安裝 / 下載 / 寫入系統的操作，執行前都會逐一向你確認。

---

## 🧰 功能總覽

| 模塊 | 功能 | 一句話說明 |
|:---:|:-----|:-----------|
| 🩺 | **系統體檢** | CPU / 記憶體 / 磁碟 / 虛擬化類型 / BBR / 公網 IP 與 ASN，一屏看完 |
| 🚄 | **網路測速** | Cloudflare 公開端點純 curl 測速（零依賴），可選 Ookla CLI 深度測速 |
| 🗺️ | **回程路由** | 三網（電信/聯通/移動）回程線路檢測，NextTrace 標註 AS 路徑與線路類型 |
| 🐳 | **環境安裝** | Docker + Compose 官方腳本一鍵裝，常用工具包一鍵補齊 |
| ✅ | **部署 Demo** | 一鍵拉起 nginx 驗證頁，實測「這台 VPS 真的能跑服務」 |

外加：檢查更新、一鍵卸載（只刪自己的檔案，不動你的系統）。

---

## 📸 效果預覽

<!-- PREVIEW:BEGIN -->
以下均為真實運行輸出節選（測試環境：加德滿都家寬，數值僅示意）。

**主選單**

```text
   ____  ______ ____ ______      __  __
  / __ \|  ____/ ___|  ____|     \ \/ /
 | |  | | |__ | |   | |__   _____ \  /
 | |  | |  __|| |   |  __| |_____|/  \
 | |__| | |___| |___| |____      /  /\ \
  \____/|______\____|______|    /__/  \_\
  oece-x.sh v1.0.0 · VPS 體檢與一鍵部署測試工具

────────────────────────────────────────────────────────
 1) 系統體檢       CPU / 記憶體 / 虛擬化 / BBR / IP 資訊
 2) 網路測速       Cloudflare 標準 + Ookla 深度（可選）
 3) 回程路由檢測   三網回程線路（NextTrace 標註 AS）
 4) 環境一鍵安裝   Docker / 常用工具
 5) 部署 Demo      一鍵拉起 nginx 驗證頁
────────────────────────────────────────────────────────
 6) 檢查更新    7) 卸載    0) 退出
```

**系統體檢 + 網路測速**

```text
◆ 系統體檢
 系統          Ubuntu 22.04.5 LTS
 虛擬化        container (docker)
 記憶體        708 MB / 8998 MB
 磁碟 (/)      232M / 234G（已用 1%）
 TCP 擁塞      cubic
 IPv4          27.34.xxx.xxx
 ASN / ISP     AS17501 WorldLink Communications Pvt Ltd
 地理位置      NP · Kathmandu

◆ 網路測速
 延遲          221.4 ms（到 Cloudflare 最近邊緣）
 抖動          319.1 ms
 下載          25.61 Mbps
 上傳          14.63 Mbps
```

**回程路由（NextTrace 標註 AS 與線路歸屬）**

```text
▶ 上海移動（211.136.112.200）
────────────────────────────────────────────────────────
16  149.14.199.194  AS174    [COGENT-149]  英國 斯勞  Cogent-CMI-Peer
17  223.120.11.50   AS58453  [CMI-INT]     英國 倫敦  cmi.chinamobile.com  移動
20  221.183.89.33   AS9808   [CMNET]       中國 上海  chinamobileltd.com   移動
24  211.136.112.252 AS24400  [CMNET]       中國 上海  sh.10086.cn          移動
25  211.136.112.200 AS24400  [CMNET]       中國 上海  浦東新區 sh.10086.cn  移動

[資訊] 線路速查：CN2 GIA(59.43.*且少跳) > CN2 GT(59.43.*) ≈ 聯通9929(AS9929)
       ≈ 移動CMIN2(AS58807) > 電信163(202.97.*) ≈ 聯通4837 ≈ 移動CMI(AS58453)
```

一眼看穿：這條線在倫敦交接給移動國際（CMI，AS58453）——普通線路，不是 CMIN2。
<!-- PREVIEW:END -->

---

## 📖 功能詳解

### 🩺 系統體檢

純只讀操作，直接讀 `/proc` 與 `sysctl`，不依賴 `free` 等可能缺失的命令：

- CPU 型號 / 核數 / 頻率、記憶體與 Swap、磁碟用量
- **虛擬化類型**（KVM / OpenVZ / LXC…）——判斷超售嫌疑的第一步
- **TCP 擁塞控制**是否已開 BBR、默認隊列算法
- 公網 IPv4 / IPv6（Cloudflare → ip.sb → ifconfig.me 三級降級）
- ASN / ISP / 地理位置

### 🚄 網路測速

| 方式 | 實現 | 適用 |
|:-----|:-----|:-----|
| **標準測速**（默認） | Cloudflare `speed.cloudflare.com` 公開端點，純 `curl` 完成延遲 ×5 / 下載 50MB×2 / 上傳 20MB | 零依賴、快速判斷國際出口帶寬 |
| **深度測速**（可選） | 官方 Ookla Speedtest CLI（下載前確認，明示 EULA） | 就近節點、更權威的數值 |

> Cloudflare 邊緣就近接入，標準測速反映的是**國際出口帶寬上限**；到特定地區的實際體驗，請結合回程路由一起看。

### 🗺️ 回程路由（核心功能）

到中國三大運營商公開測試節點的回程線路檢測：

- **快速模式**：上海 電信 / 聯通 / 移動（3 節點）
- **完整模式**：北京 / 上海 / 廣州 × 三網（9 節點）

首選開源 [NextTrace](https://github.com/nxtrace/NTrace-core) 進行探測（版本釘死 + SHA256 校驗，見安全性設計），能直接標出每一跳的 **AS 號與線路歸屬**。看不懂路由表？記住這張速查表：

| 線路 | 特徵 | 等級 |
|:-----|:-----|:----:|
| 電信 CN2 GIA | `59.43.*` 且跳數少、全程低延遲 | 🏆 頂級 |
| 電信 CN2 GT | `59.43.*` 出現但混跑 `202.97.*` | ⭐ 優 |
| 聯通 9929 | AS9929（CUII） | ⭐ 優 |
| 移動 CMIN2 | AS58807 | ⭐ 優 |
| 電信 163 | 全程 `202.97.*` | 普通 |
| 聯通 4837 | AS4837 | 普通 |
| 移動 CMI | AS58453 | 普通 |

**降級鏈**：拒絕下載 NextTrace（或下載失敗）→ 自動改用系統 `traceroute` → 沒有就用 `mtr` → 都沒有時提示安裝。工具鏈斷在哪一級，功能就降到哪一級，**絕不中斷整個檢測**。

### 🐳 環境一鍵安裝

- **Docker + Compose**：使用官方 `get.docker.com` 腳本——先下載到臨時目錄、顯示大小與路徑供你審查、**二次確認後才執行**；裝完自動 `systemctl enable --now` 並驗證
- **常用工具包**：git / vim / htop / unzip / wget / tar，一次補齊

自動識別 `apt` / `dnf` / `yum`，Debian 系與 RHEL 系同一套體驗。

### ✅ 部署 Demo

驗證鏈路的最後一步——**「能跑分」不等於「能跑服務」**：

1. 生成一頁帶主機名 / 公網 IP / 部署時間的靜態驗證頁
2. `nginx:alpine` 容器掛載啟動（端口可自定義，默認 8888，佔用檢測）
3. 本機 `curl` 自檢 HTTP 200 後，回顯公網訪問地址
4. 隨時一鍵移除，不留垃圾

---

## 🛡️ 安全性設計

這個腳本的每一行都經得起你審查——也希望你真的去審查：

| 設計 | 說明 |
|:-----|:-----|
| **單檔開源** | 全部邏輯就在 `oece-x.sh` 一個檔案裡，無混淆、無編譯產物 |
| **下載校驗** | NextTrace 二進制**版本釘死 + SHA256 內嵌校驗**，哈希不符立即刪檔中止 |
| **HTTPS-only** | `safe_download()` 拒絕任何非 HTTPS 來源，下載前打印完整 URL |
| **二次確認** | 執行外部腳本 / 刪除操作需完整輸入 `yes`，回車或按錯直接取消 |
| **嚴格模式** | `set -Eeuo pipefail` + ERR trap 行號報錯 + 臨時目錄 trap 清理 |
| **無密鑰** | 不含任何 API key / token / 統計上報，你的資料只屬於你 |
| **無封鎖繞過** | 不含任何代理 / 翻牆功能，回程檢測僅用公開測試節點做路由探測 |
| **ShellCheck 0 告警** | 每次發版通過 `shellcheck` 靜態檢查 |
| **可乾淨卸載** | 所有下載物集中在 `~/.oece-x/`，卸載一鍵清空，不碰系統其他檔案 |

---

## 📦 系統需求

- **系統**：Debian 10+ / Ubuntu 20.04+ / CentOS · Rocky · Alma 8+（其他發行版會提示後盡力兼容）
- **架構**：amd64（x86_64）/ arm64（aarch64）
- **權限**：root 或 sudo
- **依賴**：僅 `curl` + `tar`（缺失時腳本會詢問並自動安裝）

---

## ❓ FAQ

<details>
<summary><b>為什麼需要 root？</b></summary>

安裝依賴 / Docker 需要包管理器權限，路由探測需要 raw socket。純體檢與測速理論上不需要 root，但為保持體驗一致統一要求。介意的話——單檔腳本，代碼就在那裡，歡迎審查後再跑。
</details>

<details>
<summary><b>測速結果和商家宣傳差很多？</b></summary>

標準測速走 Cloudflare 就近邊緣，反映**國際出口**能力；商家宣傳的往往是內網口速率。另外測速受時段、鄰居、線路擁塞影響，建議不同時段多測幾次，並結合回程路由判斷到你目標地區的真實質量。
</details>

<details>
<summary><b>ARM 的 VPS 能用嗎？</b></summary>

能。amd64 / arm64 都支持，NextTrace 會按架構下載對應二進制並分別校驗。
</details>

<details>
<summary><b>為什麼 NextTrace 版本是釘死的？</b></summary>

上游 release 不提供 checksums 檔，所以我們把**特定版本的 SHA256 直接寫進腳本**。這意味著即使上游倉庫被入侵替換了二進制，校驗也會失敗並中止——代價是升級 NextTrace 需要發新版腳本，我們認為值得。
</details>

<details>
<summary><b>會蒐集我的任何數據嗎？</b></summary>

不會。腳本無統計上報、無遙測。對外請求只有：測速端點、IP 查詢 API、GitHub（下載工具/檢查更新）、以及你主動選擇的路由探測目標。
</details>

---

## 🗺️ Roadmap

- [ ] v1.1 — 更多回程節點（成都 / 教育網）、IPv6 回程路由
- [ ] v1.2 — 體檢結果導出（Markdown / JSON，方便發帖與存檔）
- [ ] v1.3 — 常見面板 / 服務一鍵部署模板擴充
- [ ] 長期 — 保持單檔 · 保持可審計 · 保持不臃腫

有想法？[開個 Issue](https://github.com/web3-ai-game/oece-x-sh/issues) 聊聊。

---

## ⚠️ 免責聲明

本工具僅供 VPS 測試與學習用途。測速與路由結果受網路環境、時段、線路調度影響，**僅供參考**，不構成任何購買建議。

本工具**不含任何繞過網路封鎖之功能**。

---

## 📺 相關教學

- 影片教學 → [YouTube @oece-x](https://www.youtube.com/@oece-x)
- 更多內容 → [oece-x.com](https://oece-x.com)

---

## 📄 License

[MIT](LICENSE) © oece-x

---

<div align="center">

**如果這個腳本幫你避開了一台垃圾 VPS，請點個 ⭐**

<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=12&height=120&section=footer" width="100%"/>

</div>
