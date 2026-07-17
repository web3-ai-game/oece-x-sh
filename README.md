<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=12&height=200&section=header&text=oece-x.sh&fontSize=64&fontColor=ffffff&animation=fadeIn&fontAlignY=32&desc=VPS%20Toolkit%20%C2%B7%20Check%20%C2%B7%20Speed%20%C2%B7%20Route%20%C2%B7%20Sub2API&descAlignY=56&descSize=18" width="100%"/>

# 🚀 oece-x.sh

**幫你在 3 分鐘內判斷一台 VPS 到底能不能用、值不值；並可一鍵部署 Sub2API。**

*A single-file VPS inspection & deployment toolkit — check it, speed it, trace it, ship Sub2API without a domain.*

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash%204%2B-4EAA25?logo=gnubash&logoColor=white)](oece-x.sh)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen?logo=gnu&logoColor=white)](https://www.shellcheck.net/)
[![Version](https://img.shields.io/badge/Version-1.1.0-7c4dff)](oece-x.sh)
[![Platform](https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu%20%7C%20CentOS-informational?logo=linux&logoColor=white)](#-系統需求)
[![Arch](https://img.shields.io/badge/Arch-amd64%20%7C%20arm64-orange)](#-系統需求)

[![Single File](https://img.shields.io/badge/單檔-One%20Script-success)](oece-x.sh)
[![No Build](https://img.shields.io/badge/依賴-curl%20%2B%20tar-lightgrey)](#-安全性設計)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-ff69b4)](https://github.com/web3-ai-game/oece-x-sh/pulls)
[![YouTube](https://img.shields.io/badge/YouTube-%40oece--x-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/@oece-x)
[![Website](https://img.shields.io/badge/Web-oece--x.com-7c4dff?logo=googlechrome&logoColor=white)](https://oece-x.com)

<br/>

**繁體中文介面 · 單檔 · 一鍵執行 · 開源可審計 · 無域名可部署 Sub2API**

</div>

---

## ⚡ 快速開始 / Quick Start

```bash
bash <(curl -sL oece-x.com/x)
```

大陸海外均可直連。備用（GitHub raw，大陸需科學上網）：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/web3-ai-game/oece-x-sh/main/oece-x.sh)
```

> 需要 root（或 `sudo`）。腳本內所有安裝 / 下載 / 寫入系統的操作，執行前都會逐一向你確認。  
> *Root (or sudo) required. Every install / download / destructive step asks for confirmation first.*

---

## 🧰 功能總覽 / Feature Overview

| 模塊 | 功能 | 一句話說明 | One-liner |
|:---:|:-----|:-----------|:----------|
| 🩺 | **系統體檢** | CPU / 記憶體 / 磁碟 / 虛擬化 / BBR / 公網 IP 與 ASN | Full host snapshot in one screen |
| 🚄 | **網路測速** | Cloudflare 純 curl 測速，可選 Ookla CLI | Zero-deps CF speed + optional Ookla |
| 🗺️ | **回程路由** | 三網回程，NextTrace 標 AS 與線路 | CN ISP return-path with AS labels |
| 🐳 | **環境安裝** | Docker + Compose、常用工具包 | Official get.docker.com path |
| ✅ | **部署 Demo** | nginx 驗證頁，證明「能跑服務」 | One-shot deploy proof page |
| 🔌 | **部署 Sub2API** | 傻瓜式 AI API 中轉，**無域名也能用** | Foolproof Sub2API, no domain needed |

外加：檢查更新、一鍵卸載（只刪腳本自己的檔案；Sub2API 業務實例需在模塊 6 內單獨卸載）。

---

## 📸 效果預覽 / Preview

<!-- PREVIEW:BEGIN -->
以下均為真實運行輸出節選（路由段：新加坡 DigitalOcean 真機）。

**主選單 / Main menu**

```text
   ____  ______ ____ ______      __  __
  / __ \|  ____/ ___|  ____|     \ \/ /
 | |  | | |__ | |   | |__   _____ \  /
 | |  | |  __|| |   |  __| |_____|/  \
 | |__| | |___| |___| |____      /  /\ \
  \____/|______\____|______|    /__/  \_\
  oece-x.sh v1.1.0 · VPS 體檢 · 部署測試 · Sub2API

────────────────────────────────────────────────────────
 1) 系統體檢       CPU / 記憶體 / 虛擬化 / BBR / IP 資訊
 2) 網路測速       Cloudflare 標準 + Ookla 深度（可選）
 3) 回程路由檢測   三網回程線路（NextTrace 標註 AS）
 4) 環境一鍵安裝   Docker / 常用工具
 5) 部署 Demo      一鍵拉起 nginx 驗證頁
 6) 部署 Sub2API   AI API 中轉 · 無域名友好
────────────────────────────────────────────────────────
 7) 檢查更新    8) 卸載    0) 退出
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

**回程路由（NextTrace 標註 AS 與線路歸屬，新加坡 DigitalOcean 真機）**

```text
▶ 上海移動（211.136.112.200）
────────────────────────────────────────────────────────
1   103.253.144.131 AS14061  [DIGITALOCEAN-AP]  新加坡              1.31 ms
10  223.120.2.117   AS58453  [CMI-INT]   中國 香港  cmi.chinamobile.com  移動   32.62 ms
11  223.120.3.202   AS58453  [CMI-INT]   中國 上海  cmi.chinamobile.com  移動   56.94 ms
13  221.183.89.33   AS9808   [CMNET]     中國 上海  chinamobileltd.com   移動   61.25 ms
18  211.136.112.200 AS24400  [CMNET]     中國 上海  浦東新區 sh.10086.cn  移動  210.11 ms

[資訊] 線路速查：CN2 GIA(59.43.*且少跳) > CN2 GT(59.43.*) ≈ 聯通9929(AS9929)
       ≈ 移動CMIN2(AS58807) > 電信163(202.97.*) ≈ 聯通4837 ≈ 移動CMI(AS58453)
```

一眼看穿：這台新加坡機到移動走 **CMI 香港直連（~60ms 進上海）**，同機到電信卻走 163 骨幹 ~300ms、聯通繞美 ~366ms——**同一台 VPS，三網體驗天差地別**，這正是買機前要自測回程的原因。
<!-- PREVIEW:END -->

---

## 📖 功能詳解 / Features in Detail

### 🩺 系統體檢 / System Inspection

純只讀操作，直接讀 `/proc` 與 `sysctl`，不依賴 `free` 等可能缺失的命令：

- CPU 型號 / 核數 / 頻率、記憶體與 Swap、磁碟用量  
- **虛擬化類型**（KVM / OpenVZ / LXC…）——判斷超售嫌疑的第一步  
- **TCP 擁塞控制**是否已開 BBR、默認隊列算法  
- 公網 IPv4 / IPv6（Cloudflare → ip.sb → ifconfig.me 三級降級）  
- ASN / ISP / 地理位置  

*Read-only snapshot from `/proc` and sysctl — virt type, BBR, public IP/ASN, disk and memory.*

### 🚄 網路測速 / Network Speed

| 方式 | 實現 | 適用 |
|:-----|:-----|:-----|
| **標準測速**（默認） | Cloudflare `speed.cloudflare.com` 公開端點，純 `curl` 完成延遲 ×5 / 下載 50MB×2 / 上傳 20MB | 零依賴、快速判斷國際出口帶寬 |
| **深度測速**（可選） | 官方 Ookla Speedtest CLI（下載前確認，明示 EULA） | 就近節點、更權威的數值 |

> Cloudflare 邊緣就近接入，標準測速反映的是**國際出口帶寬上限**；到特定地區的實際體驗，請結合回程路由一起看。  
> *CF test ≈ international egress ceiling. Pair with return-path for regional reality.*

### 🗺️ 回程路由 / Return-Path Trace（核心功能）

到中國三大運營商公開測試節點的回程線路檢測：

- **快速模式**：上海 電信 / 聯通 / 移動（3 節點）  
- **完整模式**：北京 / 上海 / 廣州 × 三網（9 節點）  

首選開源 [NextTrace](https://github.com/nxtrace/NTrace-core)（版本釘死 + SHA256 校驗）。看不懂路由表？記住這張速查表：

| 線路 | 特徵 | 等級 |
|:-----|:-----|:----:|
| 電信 CN2 GIA | `59.43.*` 且跳數少、全程低延遲 | 🏆 頂級 |
| 電信 CN2 GT | `59.43.*` 出現但混跑 `202.97.*` | ⭐ 優 |
| 聯通 9929 | AS9929（CUII） | ⭐ 優 |
| 移動 CMIN2 | AS58807 | ⭐ 優 |
| 電信 163 | 全程 `202.97.*` | 普通 |
| 聯通 4837 | AS4837 | 普通 |
| 移動 CMI | AS58453 | 普通 |

**降級鏈**：拒絕 NextTrace → 系統 `traceroute` → `mtr` → 提示安裝。工具鏈斷在哪一級，功能就降到哪一級，**絕不中斷整個檢測**。

### 🐳 環境一鍵安裝 / Environment Setup

- **Docker + Compose**：官方 `get.docker.com`——先下載到臨時目錄、顯示大小與路徑供你審查、**二次確認後才執行**  
- **常用工具包**：git / vim / htop / unzip / wget / tar  

自動識別 `apt` / `dnf` / `yum`。

### ✅ 部署 Demo / Deploy Demo

驗證鏈路的最後一步——**「能跑分」不等於「能跑服務」**：

1. 生成帶主機名 / 公網 IP / 部署時間的靜態驗證頁  
2. `nginx:alpine` 容器掛載啟動（默認端口 8888，佔用檢測）  
3. 本機 `curl` 自檢 HTTP 200 後回顯公網地址  
4. 隨時一鍵移除  

### 🔌 部署 Sub2API / Foolproof Sub2API（v1.1 新增）

封裝開源項目 [Wei-Shaw/sub2api](https://github.com/Wei-Shaw/sub2api)：把 Claude / OpenAI / Gemini 等訂閱統一成可管理的 API 中轉平台（拼車、配額、後台）。

*Wraps upstream Sub2API (Docker Compose): unified AI API gateway with admin UI — no custom domain required.*

#### 為什麼要做「傻瓜式」？

官方已有 `docker-deploy.sh`，但對「剛買的雜牌 VPS、沒域名、記憶體只有 2–4G」仍有門檻：要懂 Compose、要自己改端口、要自己生成密鑰、小機器套 8G 默認參數容易 OOM。本模塊把這些收成選單：

| 能力 | 說明 |
|:-----|:-----|
| **一鍵安裝 / 重裝** | 下載官方 compose + `.env` 模板，自動生成 JWT / TOTP / DB / 管理員密碼 |
| **小 VPS 資源檔** | 按 `MemTotal` 分檔調低 Postgres / Redis 連接池與 `shared_buffers` |
| **端口佔用檢測** | 8080 被佔（例如已有反代）會要求換端口 |
| **實例隔離** | 默認目錄 `/opt/oece-sub2api`，容器名 `oece-sub2api*`，**不覆蓋**常見的 `/opt/sub2api` 手工實例 |
| **生命週期** | 狀態 / 日誌 / 更新鏡像 / 改綁定與端口 / 卸載（可選刪數據） |
| **無域名訪問** | 見下一節 |

#### 無域名三種訪問方式 / Access without your own domain

| 方式 | 是否要註冊 | 自動化程度 | 說明 |
|:-----|:----------|:-----------|:-----|
| **純 IP:端口** | 否 | 全自動 | 默認。`http://公網IP:端口` 立刻能開管理後台 |
| **sslip.io / nip.io** | 否（零申請） | 全自動生成 URL | 把 IP 寫進主機名，如 `157-230-249-136.sslip.io`，全球可解析 |
| **DuckDNS** | 要免費帳號 + token | 半自動 | 真·免費子域 `名字.duckdns.org`；貼 token 後腳本調 API 寫 A 記錄，可選 cron 保活 |

**沒有**可靠的「一條命令白嫖正式 `.com/.sh` 域名」腳本；Freenom 等已不可用。若你已有域名：腳本只打印 nginx / Caddy 反代示例，**不自動改系統 nginx**，避免誤傷其他站點。

*There is no trustworthy fully-automatic free real TLD registrar in a shell script. We support IP, zero-signup wildcard DNS (sslip/nip), and DuckDNS. HTTPS one-click is intentionally deferred — use Caddy/certbot yourself when ready.*

#### 安裝後你會得到

- 管理後台 URL（本機 / 公網 IP / sslip.io）  
- 管理員郵箱 + 密碼（同時寫入 `~/.oece-x/sub2api-credentials.txt`，`chmod 600`）  
- `.env` 內固定 `JWT_SECRET` / `TOTP_ENCRYPTION_KEY`（重啟不會掉登錄 / 2FA）  

#### 子選單一覽

```text
1) 一鍵安裝 / 重裝
2) 訪問方式（IP / sslip.io / DuckDNS）
3) 狀態 / 帳號與地址
4) 日誌
5) 更新鏡像
6) 修改綁定與端口（0.0.0.0 ↔ 127.0.0.1）
7) 卸載本腳本實例
```

#### 與「已有 Sub2API」共存

若機器上**已經**跑著官方目錄 `/opt/sub2api` 或容器名 `sub2api`（例如本頻道生產站 `api.oece-x.com`），腳本會**警告並隔離安裝**到 `/opt/oece-sub2api`。請選空閒端口，不要在同一台生產機上為了「試腳本」去撞 8080。

*If you already run a production Sub2API on the host, this module installs a separate project (`oece-sub2api`) and never targets `/opt/sub2api` by default.*

---

## 🛡️ 安全性設計 / Security Design

這個腳本的每一行都經得起你審查——也希望你真的去審查：

| 設計 | 說明 |
|:-----|:-----|
| **單檔開源** | 全部邏輯就在 `oece-x.sh` 一個檔案裡，無混淆、無編譯產物 |
| **下載校驗** | NextTrace 二進制**版本釘死 + SHA256 內嵌校驗**，哈希不符立即刪檔中止 |
| **HTTPS-only** | `safe_download()` 拒絕任何非 HTTPS 來源，下載前打印完整 URL |
| **二次確認** | 執行外部腳本 / 刪除操作需完整輸入 `yes` |
| **嚴格模式** | `set -Eeuo pipefail` + ERR trap 行號報錯 + 臨時目錄 trap 清理 |
| **無密鑰進倉庫** | 不含任何 API key / token / 統計上報；Sub2API 密鑰只寫本機 600 檔 |
| **無封鎖繞過** | 不含任何代理 / 翻牆功能；回程檢測僅用公開測試節點 |
| **ShellCheck 0 告警** | 每次發版通過 `shellcheck` 靜態檢查 |
| **可乾淨卸載** | 下載物集中在 `~/.oece-x/`；Sub2API 在模塊內卸載，主選單「卸載」不動業務容器 |

---

## 📦 系統需求 / Requirements

- **系統**：Debian 10+ / Ubuntu 20.04+ / CentOS · Rocky · Alma 8+  
- **架構**：amd64（x86_64）/ arm64（aarch64）  
- **權限**：root 或 sudo  
- **依賴**：僅 `curl` + `tar`（缺失時可詢問安裝）  
- **Sub2API 建議**：≥2GB RAM（&lt;1.5GB 會警告仍可強裝）、已裝或允許安裝 Docker  

---

## ❓ FAQ

<details>
<summary><b>為什麼需要 root？</b></summary>

安裝依賴 / Docker 需要包管理器權限，路由探測需要 raw socket。純體檢與測速理論上不需要 root，但為保持體驗一致統一要求。
</details>

<details>
<summary><b>測速結果和商家宣傳差很多？</b></summary>

標準測速走 Cloudflare 就近邊緣，反映**國際出口**能力；商家宣傳的往往是內網口速率。建議不同時段多測，並結合回程路由。
</details>

<details>
<summary><b>ARM 的 VPS 能用嗎？</b></summary>

能。amd64 / arm64 都支持，NextTrace 會按架構下載對應二進制並分別校驗。
</details>

<details>
<summary><b>為什麼 NextTrace 版本是釘死的？</b></summary>

上游 release 不提供 checksums 檔，所以我們把**特定版本的 SHA256 直接寫進腳本**。即使上游二進制被替換，校驗也會失敗並中止。
</details>

<details>
<summary><b>會蒐集我的任何數據嗎？</b></summary>

不會。無統計上報、無遙測。對外請求只有：測速端點、IP 查詢 API、GitHub（工具/更新）、你主動選的路由目標、以及你主動部署時拉取的 Docker 鏡像 / DuckDNS API。
</details>

<details>
<summary><b>沒有域名能跑 Sub2API 嗎？</b></summary>

能。默認就是 `http://公網IP:端口`。還可使用零註冊的 sslip.io / nip.io 偽域名，或 DuckDNS 免費子域。HTTPS 請自行用 Caddy / Let’s Encrypt。
</details>

<details>
<summary><b>腳本會動我已經在跑的 Sub2API 嗎？</b></summary>

不會主動動。本腳本實例固定前綴 `oece-sub2api` 與目錄 `/opt/oece-sub2api`。主選單「卸載」也不刪 Sub2API；只有模塊 6 → 卸載 才會動本腳本實例。
</details>

<details>
<summary><b>要不要買 oece-x.sh 這種 .sh 域名？</b></summary>

不需要。短命令 `bash <(curl -sL oece-x.com/x)` 已等效 kejilion 風格「根路徑下腳本」。`.sh` TLD 僅品牌質感，可日後再決定。
</details>

---

## 🗺️ Roadmap

- [x] **v1.1** — Sub2API 傻瓜式部署（無域名：IP / sslip.io / DuckDNS）  
- [ ] 更多回程節點（成都 / 教育網）、IPv6 回程路由  
- [ ] 體檢結果導出（Markdown / JSON）  
- [ ] Sub2API 可選一鍵 HTTPS（Caddy）  
- [ ] 裝機計數器 / `x` 快捷命令  
- [ ] 長期 — 保持單檔 · 保持可審計 · 保持不臃腫  

有想法？[開個 Issue](https://github.com/web3-ai-game/oece-x-sh/issues) 聊聊。

---

## ⚠️ 免責聲明 / Disclaimer

本工具僅供 VPS 測試與學習用途。測速與路由結果受網路環境、時段、線路調度影響，**僅供參考**，不構成任何購買建議。

本工具**不含任何繞過網路封鎖之功能**。

Sub2API 為第三方開源項目，請遵守其許可與各 AI 服務商服務；自行保管 API 密鑰與管理員密碼。

---

## 📺 相關連結 / Links

- 官網展示 → [oece-x.com](https://oece-x.com/#script)（首頁「代表作品」區，一鍵複製命令）  
- 影片教學 → [YouTube @oece-x](https://www.youtube.com/@oece-x)  
- Sub2API 上游 → [Wei-Shaw/sub2api](https://github.com/Wei-Shaw/sub2api)  
- 開發文檔 → [docs/DEV-HANDOFF.md](docs/DEV-HANDOFF.md)（架構導讀 · 發版 SOP · 基礎設施地圖）  

---

## 📄 License

[MIT](LICENSE) © oece-x

---

<div align="center">

**如果這個腳本幫你避開了一台垃圾 VPS，或省下一個下午的部署時間，請點個 ⭐**

<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=12&height=120&section=footer" width="100%"/>

</div>
