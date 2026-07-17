<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=12&height=200&section=header&text=oece-x.sh&fontSize=64&fontColor=ffffff&animation=fadeIn&fontAlignY=32&desc=VPS%20Toolkit%20%C2%B7%20Ops%20%C2%B7%20Docker%20%C2%B7%20Top3%20Scripts&descAlignY=56&descSize=18" width="100%"/>

# 🚀 oece-x.sh

**幫你在 3 分鐘內判斷一台 VPS 到底能不能用、值不值；精選運維 + 全網 Top3 漢化腳本入口。**

*A single-file VPS inspection & ops toolkit — check it, speed it, tune it, and launch the best Chinese one-click scripts.*

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash%204%2B-4EAA25?logo=gnubash&logoColor=white)](oece-x.sh)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen?logo=gnu&logoColor=white)](https://www.shellcheck.net/)
[![Version](https://img.shields.io/badge/Version-1.3.1-7c4dff)](oece-x.sh)
[![Platform](https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu%20%7C%20CentOS-informational?logo=linux&logoColor=white)](#-系統需求)
[![Arch](https://img.shields.io/badge/Arch-amd64%20%7C%20arm64-orange)](#-系統需求)

[![YouTube](https://img.shields.io/badge/YouTube-%40oece--x-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/@oece-x)
[![Website](https://img.shields.io/badge/Web-oece--x.com-7c4dff?logo=googlechrome&logoColor=white)](https://oece-x.com)

<br/>

**繁體中文介面 · 單檔 · 酷炫開場動畫 · 開源可審計**

</div>

---

## ⚡ 快速開始 / Quick Start

```bash
bash <(curl -sL oece-x.com/x)
```

備用（GitHub raw）：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/web3-ai-game/oece-x-sh/main/oece-x.sh)
```

跳過開場動畫：

```bash
OECE_NO_ANIM=1 bash <(curl -sL oece-x.com/x)
```

> 需要 root（或 `sudo`）。危險操作需完整輸入 `yes`。  
> *Root required. Destructive steps need full `yes` confirmation.*

---

## 🧰 功能總覽 / Feature Overview

| # | 模塊 | 說明 | EN |
|:-:|:-----|:-----|:---|
| 1 | **系統體檢** ★ | CPU / 記憶體 / 虛擬化 / BBR / 公網 IP·ASN | Host snapshot |
| 2 | **網路測速** | Cloudflare 純 curl；可選 Ookla | CF speed + Ookla |
| 3 | **回程路由** | 三網 · NextTrace（SHA256 釘版） | CN return-path |
| 4 | **系統更新** | apt / dnf / yum | Distro upgrade |
| 5 | **系統清理** | 包緩存 · journal | Cleanup |
| 6 | **BBR 加速** ★ | fq + bbr · sysctl.d | Enable BBR |
| 7 | **Swap** | 建立 / 刪除 swapfile | Virtual memory |
| 8 | **時區 / DNS** | timedatectl · 公共 DNS | Timezone & DNS |
| 9 | **常用工具** | git vim htop… | Essentials |
| **10→19** | **精選腳本入口** ★ | 融合怪·換源·kejilion·**vps-audit**·**nench** | Audit + nench + CN tools |
| **12** | **SSH 安全加固** ★ | 改端口 · 禁密碼 root · fail2ban · UFW · 審計 | SSH harden |
| **2** | **性能跑分** ★ | CPU/磁碟/記憶體 + nench | Bench |
| **3** | **解鎖/IP 質量** ★ | Netflix/ChatGPT 可達性（無代理） | Unlock probe |
| 11–13 | **Docker** | 安裝 · 容器 · prune | Docker lite |
| 14–16 | **站點** | nginx 反代 · SSL · Demo | Proxy / cert / demo |
| 17–19 | **維護** | 更新腳本 · 快捷 `x` · 卸載 | Maintain |

---

## 🌐 精選腳本入口（選單 19）

按 **GitHub 熱度 + 中文界面 + 有 VPS 即可 curl 安裝** 篩選（非付費推廣，star 數隨時間浮動）：

| 排名 | 項目 | 約 stars | 用途 | 官方一鍵 |
|:---:|:-----|:--------:|:-----|:---------|
| 1 | [SuperManito/LinuxMirrors](https://github.com/SuperManito/LinuxMirrors) | ~7.6k | 換軟體源 / Docker 源 | `bash <(curl -sSL https://linuxmirrors.cn/main.sh)` |
| 2 | [spiritLHLS/ecs](https://github.com/spiritLHLS/ecs) 融合怪 | ~7.0k | 綜合伺服器測評（中文菜單） | `curl -L …/ecs.sh -o ecs.sh && bash ecs.sh` |
| 3 | [kejilion/sh](https://github.com/kejilion/sh) | ~3.0k | 全能運維工具箱（**繁中 tw**） | `bash <(curl -sL kejilion.sh) tw` |
| 4 | [vernu/vps-audit](https://github.com/vernu/vps-audit) | ~2.3k | **無依賴安全審計**（差異化） | raw `vps-audit.sh` |
| 5 | [n-st/nench](https://github.com/n-st/nench) | classic | CPU/IO/網路經典測評 | `nench.sh` |

**oece-x 的做法**：下載 → `bash -n` 語法校驗 → 二次 `yes` 確認 → 執行；**不內嵌**對方源碼。  
第三方腳本可能含本項目刻意不做的功能（如 WARP 等），請自行甄別。

*We only launch trusted upstream one-liners after syntax check + confirmation. Their code is not vendored.*

---

## 🎬 開場動畫 / Intro

TTY 下約 1.5–2.5 秒：

1. 大號 **OECE-X** 塊字 + 256 色彩虹色波（類 hydra/lolcat 經典工具開場）  
2. 底部蛇形 loading 條  
3. 定格雙色 Logo + 版本框  

`OECE_NO_ANIM=1` 或 `OECE_FAST=1` 或非 TTY（管道）→ 直接進選單。

---

## 📸 主選單預覽

```text
   ____  ______ ____ ______      __  __
  / __ \|  ____/ ___|  ____|     \ \/ /
 | |  | | |__ | |   | |__   _____ \  /
 | |  | |  __|| |   |  __| |_____|/  \
 | |__| | |___| |___| |____      /  /\ \
  \____/|______\____|______|    /__/  \_\
  oece-x.sh v1.3.1 · VPS 體檢與運維精選

── 體檢與網路 ──
 1) 系統體檢 ★    2) 網路測速    3) 回程路由
── 系統運維 ──
 4) 系統更新  5) 清理  6) BBR ★  7) Swap  8) 時區/DNS  9) 工具
10) 全網 Top3 腳本 ★
── Docker ──
11) 環境 ★  12) 容器  13) 清理
── 站點輕量 ──
14) nginx 反代 ★  15) SSL  16) Demo
── 維護 ──
17) 檢查更新  18) 快捷 x  19) 卸載  0) 退出
```

---

## 📖 功能詳解（摘要）

### 體檢與網路
- **系統體檢**：只讀 `/proc`、虛擬化類型、BBR 狀態、公網 IP 三級降級  
- **測速**：CF 50MB×2 下載（避開 64MB 403）；可選 Ookla  
- **回程**：NextTrace 釘版 + SHA256；拒絕則 traceroute/mtr 降級  

### 系統運維
- **BBR**：寫入 `/etc/sysctl.d/99-oece-bbr.conf` 並立即生效  
- **Swap**：`/swapfile` + fstab  
- **DNS**：systemd-resolved drop-in 或 resolv.conf（有備份）  

### Docker / 站點
- Docker 官方 `get.docker.com`（下載後二次確認）  
- nginx 反代寫獨立 conf（`oece-proxy-域名.conf`），**默認不覆蓋** `oece-x.com` 生產站  
- certbot nginx / standalone 輔助  

### 安全設計
| 項 | 說明 |
|:---|:-----|
| 單檔開源 | 無混淆 |
| HTTPS-only | `safe_download` |
| 釘版校驗 | NextTrace SHA256 |
| 危險操作 | 完整 `yes` |
| 無遙測 | 不收集數據 |
| 無翻牆 | 不含代理/WARP 功能 |

---

## 📦 系統需求

- Debian 10+ / Ubuntu 20.04+ / RHEL 系 8+  
- amd64 / arm64 · root · `curl` + `tar`  

---

## ❓ FAQ

<details><summary>為什麼要接第三方腳本而不是全抄進來？</summary>

融合怪 / 換源 / kejilion 體量巨大且更新快。做**校驗後啟動器**更安全、更好維護，也尊重上游。
</details>

<details><summary>會不會動我現有的生產站？</summary>

反代模塊對 `oece-x.com` / `api.oece-x.com` 會額外危險確認。主卸載不動業務 Docker 容器。
</details>

<details><summary>v1.1 的 Sub2API 呢？</summary>

已在 v1.2 **整段移除**（體驗與定位不符）。生產環境的 Sub2API 請繼續用你自己的 compose，與本腳本無關。
</details>

---

## 🗺️ Roadmap

- [x] v1.2 精選運維 + 酷炫動畫 + Top3 漢化入口  
- [ ] 裝機計數器 / 更多回程節點  
- [ ] 體檢結果 Markdown 導出  

---

## ⚠️ 免責

僅供 VPS 測試與合法運維。測速/路由結果僅供參考。  
**不含任何繞過網路封鎖之功能。**  
第三方腳本的行為與授權以其項目為準。

---

## 📺 連結

- 官網 → [oece-x.com/#script](https://oece-x.com/#script)  
- YouTube → [@oece-x](https://www.youtube.com/@oece-x)  
- 開發回執 → [docs/DEV-HANDOFF.md](docs/DEV-HANDOFF.md)  

## 📄 License

[MIT](LICENSE) © oece-x
