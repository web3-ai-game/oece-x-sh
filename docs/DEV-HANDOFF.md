# oece-x.sh 開發回執（DEV HANDOFF）

> **交接目的**：你 SSH 到 VPS 後換任意 IDE 就能無縫續開發。本文檔記錄 2026-07-17/18 從零到上線的全部狀態、決策、坑與 SOP。
> **一句話定位**：腳本 = 影片道具 = 頻道獲客入口（oece-x.sh ↔ YouTube @oece-x ↔ oece-x.com 三位一體）。

---

## 0. 續開發第一步（在 VPS 上）

```bash
# SSH 進來（roo 就是 uid=0 真 root，root 帳戶是蜜罐，不要用）
ssh DO-vps-one          # 或 ssh roo@157.230.249.136

# 克隆倉庫到工作區（如果 /root/oece-x-sh 不存在）
git clone https://github.com/web3-ai-game/oece-x-sh.git /root/oece-x-sh
cd /root/oece-x-sh

# 推薦編輯器（VPS 上）
apt install -y micro    # 比 nano 好用的 TUI 編輯器；或直接 vim
# 本機 VS Code Remote-SSH 也行：連 DO-vps-one，注意本機 ~/.ssh/id_ed25519
# 帶 passphrase，連接前先 ssh-add（或在 Termius 裡存好）

# GitHub 推送憑證（首次）
gh auth login           # 選 HTTPS + token/瀏覽器授權
```

---

## 1. 交付物清單（全部已上線）

| 交付物 | 位置 | 狀態 |
|--------|------|------|
| 主腳本 v1.1.0（~1600 行單檔） | 倉庫 `oece-x.sh` | ✅ ShellCheck 0 告警 · 含 Sub2API 模塊 |
| GitHub 倉庫 | github.com/web3-ai-game/oece-x-sh | ✅ main 分支 |
| 短命令 | `bash <(curl -sL oece-x.com/x)` | ✅ 全球可用（含大陸，不依賴 GitHub） |
| 備用命令 | `bash <(curl -sSL https://raw.githubusercontent.com/web3-ai-game/oece-x-sh/main/oece-x.sh)` | ✅ |
| 首頁「代表作品」展示區 | oece-x.com/#script | ✅ kejilion 風終端擬真 + 複製按鈕 |
| 高規格 README | 倉庫 `README.md` | ✅ 真機輸出預覽 |
| GitHub profile README | web3-ai-game/web3-ai-game | ✅ 已加 oece-x.sh 精選卡 + 頻道徽章 |

---

## 2. 真機測試結果（DO-vps-one，2026-07-18，五模塊全過）

| 模塊 | 結果 |
|------|------|
| 1 系統體檢 | KVM / DO-Regular 2核 / SG / AS14061 / cubic 全部正確 |
| 2 網路測速 | 延遲 4.4ms · 下載 1217 Mbps · 上傳 189 Mbps |
| 3 回程路由 | NextTrace amd64 SHA256 校驗過；**電信**走 NTT→163 骨幹 ~300ms、**聯通**繞美 TATA→4837 ~366ms、**移動** CMI 香港直連 ~60ms（本機對移動用戶最優——可做影片素材） |
| 4 環境安裝 | 正確識別已裝 Docker 29.6.2 + Compose 5.3.1 並跳過 |
| 5 部署 Demo | 8888 部署 → 雙端 HTTP 200 → `yes` 確認移除，無殘留 |

容器矩陣（本機 OrbStack）：ubuntu:22.04 / debian:12 / rockylinux:9 全過，含「拒絕 NextTrace → 自動裝 traceroute」降級鏈驗證。

---

## 3. 基礎設施地圖（DO-vps-one = 157.230.249.136）

```
nginx 1.24（80/443）
├── oece-x.com          → 靜態根 /opt/oece-x-web（首頁項目）
│   ├── location = /x   → alias /opt/oece-x-web/oece-x.sh（短命令核心！）
│   └── index.html      → 含 #script 展示區
├── api.oece-x.com      → proxy 127.0.0.1:8080（docker: sub2api）
docker
├── sub2api             （0.0.0.0:8080，weishaw/sub2api）
├── sub2api-postgres    （內網 5432）
└── sub2api-redis       （內網 6379）
```

**關鍵路徑**：
- nginx 配置：`/etc/nginx/sites-available/oece-x`（sites-enabled 是軟鏈）
- 備份：`/root/oece-x.nginx.bak`（改壞了 cp 回去 + `nginx -t` + `systemctl reload nginx`）
- 首頁備份：`/root/index.html.bak`
- 測試留檔：`/root/oece-x.sh`（可刪）、`/root/.oece-x/bin/nexttrace`（已校驗）
- Cloudflare：橙雲代理；`/x` 無副檔名不在 CF 默認快取清單，發版即時生效
- 帳戶：`roo` = uid 0 真 root（**root 是蜜罐別登**）；自動化公鑰 `claude-automation-temp` 在 authorized_keys（撤銷=刪那行）

---

## 4. 腳本架構導讀（改代碼前必讀）

檔內分區順序：常量 → 顏色/UI → 確認交互 → trap → 環境檢測 → safe_download/verify_sha256 → 模塊1-5 → 更新/卸載 → 主選單。

| 關鍵點 | 位置/值 | 說明 |
|--------|---------|------|
| `SCRIPT_VERSION` | 檔頭 `"1.1.0"` | 發版必 bump；更新檢查靠它比對 |
| Sub2API 安裝根 | `/opt/oece-sub2api` | **故意不是** `/opt/sub2api`（生產 api.oece-x.com 佔用） |
| Sub2API 容器前綴 | `oece-sub2api*` | compose project `oece-sub2api`；與官方默認名隔離 |
| `SCRIPT_RAW_URL` | GitHub raw | 腳本內建「檢查更新」的來源 |
| NextTrace 釘版 | `NEXTTRACE_VERSION="v1.7.1"` + amd64/arm64 兩個 SHA256 | **升級 NextTrace 必須重新下載算哈希改這三個常量**（上游 release 不出 checksums 檔） |
| 三網節點 | `ROUTE_NODES_FULL/QUICK` 數組 | 北上廣×三網 9 個公開 landmark IP，加節點改這裡 |
| CF 測速 | `cf_download/cf_upload/cf_latency` | **坑：`__down` 超過 ~64MB 回 403**，所以用 50MB×2 取大；curl 超時不算失敗（`speed_download` 是部分平均值） |
| 嚴格模式 | `set -Eeuo pipefail` | 新代碼注意：可失敗的命令必須 `|| true` 或放條件語境，否則整腳本退出 |
| 對齊輸出 | `kv()` + `display_width()` | 中文按 3 bytes=2 列計算，別用裸 printf %-Ns 對齊中文 |
| 下載紀律 | `safe_download()` | HTTPS-only + 打印來源 + 重試；新增下載一律走它 |
| 危險操作 | `confirm_danger()` | 需輸完整 `yes`；執行外部腳本/刪除類必須套 |

**合規紅線（勿破）**：不加任何代理/翻牆功能；不硬編碼任何 key/token；回程檢測只用公開節點。

---

## 5. 發版 SOP（每次改完照做）

```bash
cd /root/oece-x-sh                              # 或本機 ~/GCP/oece-x-sh
# 1. 改代碼 + bump SCRIPT_VERSION（如 1.0.1）
# 2. 靜態檢查（VPS 上可 docker 跑）
docker run --rm -v "$PWD":/mnt koalaman/shellcheck:stable /mnt/oece-x.sh
bash -n oece-x.sh
# 3. 快速自測（本機就是 Linux，直接跑）
bash oece-x.sh
# 4. 提交推送
git add -A && git commit -m "feat: xxx" && git push
# 5. 同步到短命令（關鍵一步！不做 /x 還是舊版）
cp oece-x.sh /opt/oece-x-web/oece-x.sh
# 6. 驗證
curl -s https://oece-x.com/x | grep SCRIPT_VERSION | head -1
```

> 首頁展示區的版本號寫死在 index.html 的終端擬真裡（現 `v1.1.0`），大版本更新時記得順手改。

---

## 6. Sub2API 模塊注意（v1.1）

- **生產實例**：本 VPS `/opt/sub2api` + 容器 `sub2api` → `api.oece-x.com`（nginx 反代 8080）。**禁止**在本機對腳本模塊做真實 `compose up` E2E 測裝，避免撞端口/容器名。
- **腳本實例**：`/opt/oece-sub2api` + `oece-sub2api*`；默認端口仍 8080（佔用則換）。
- **無域名**：IP 直連 + sslip.io/nip.io 展示 + DuckDNS（token 半自動）。HTTPS 一鍵未做。
- **驗證策略**：本倉庫發版以 `bash -n` + ShellCheck 為準；實裝 E2E 請用乾淨測試機。

---

## 7. Roadmap（優先級建議）

1. ~~Sub2API 傻瓜式部署（v1.1 已交付）~~
2. **裝機計數器**（kejilion 的 496,211 次同款）：`grep -c 'GET /x ' /var/log/nginx/oece-x.access.log` 起步
3. **`x` 快捷命令**：腳本首跑時問「安裝快捷方式？」→ 寫 `/usr/local/bin/x`
4. 更多回程節點（成都/教育網）+ IPv6 路由 + 結果導出 Markdown
5. Sub2API 可選一鍵 HTTPS（Caddy）
6. **oece-x.sh 域名決策**：不必需；要品牌質感再買
7. Ookla / iperf3 自建節點模式

---

## 8. 安全待辦（非腳本，這台 VPS 的）

- [ ] **Docker 繞過 ufw**：sub2api 的 8080 是 `0.0.0.0` 發佈，全網可直連（nginx 反代形同虛設的防護）。建議 compose 裡改綁 `127.0.0.1:8080:8080`，或上 ufw-docker
- [ ] 10 個安全更新未裝：`apt update && apt upgrade`
- [ ] BBR 未開（cubic）：做站無所謂，要開就 `net.core.default_qdisc=fq` + `net.ipv4.tcp_congestion_control=bbr` 進 sysctl.conf
- [ ] 自動化公鑰 `claude-automation-temp` 用完可刪（authorized_keys 裡那行）
- [ ] vps.md 舊密碼已從文檔移除，記得把新密碼存進密碼管理器而不是 md 檔
