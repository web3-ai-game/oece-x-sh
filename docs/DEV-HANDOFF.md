# oece-x.sh 開發回執（DEV HANDOFF）

> **交接目的**：SSH 到 VPS 後可無縫續開發。  
> **一句話定位**：腳本 = 影片道具 = 頻道獲客入口（oece-x.sh ↔ YouTube @oece-x ↔ oece-x.com）。

---

## 0. 續開發

```bash
ssh DO-vps-one   # 或 roo@157.230.249.136
cd /root/oece-x-sh
# 真 root 是 roo；root 帳戶是蜜罐
```

當前版本：**v1.3.1**（Sub2API 模塊已撤回）。

---

## 1. 交付物

| 交付物 | 位置 | 狀態 |
|--------|------|------|
| 主腳本 v1.3.1 | `oece-x.sh` | ShellCheck 0 · 運維精選 + Top3 入口 + 動畫 |
| 短命令 | `bash <(curl -sL oece-x.com/x)` | `/opt/oece-x-web/oece-x.sh` |
| 首頁展示 | oece-x.com/#script | 終端擬真 |
| 倉庫 | github.com/web3-ai-game/oece-x-sh | main |

---

## 2. 基礎設施（DO-vps-one）

```
nginx → oece-x.com 靜態 /opt/oece-x-web
      location = /x → oece-x.sh
api.oece-x.com → 127.0.0.1:8080 docker sub2api（生產，與腳本無關）
```

**禁止**：在本機用腳本「再裝一遍 Sub2API」或對 8080 做衝突測試。

---

## 3. v1.2 架構導讀

| 區段 | 內容 |
|------|------|
| 常量 | NextTrace 釘版哈希、Demo、OECE_HOME |
| UI | `intro_animation` / `menu_group` / `menu_item` |
| 1–3 | 體檢 / 測速 / 回程 |
| 4–9 | 更新 / 清理 / BBR / Swap / 時區DNS / 工具 |
| **10** | **Top3 漢化腳本啟動器**（LinuxMirrors / ecs / kejilion-tw） |
| 11–13 | Docker 精簡 |
| 14–16 | 反代 / SSL / Demo |
| 17–19 | 更新腳本 / 快捷 x / 卸載 |

### Top3 入口（選單 10）

| # | 項目 | URL |
|---|------|-----|
| 1 | LinuxMirrors | `https://linuxmirrors.cn/main.sh` |
| 2 | 融合怪 ecs | `https://raw.githubusercontent.com/spiritLHLS/ecs/main/ecs.sh` |
| 3 | kejilion 繁中 | `https://raw.githubusercontent.com/kejilion/sh/main/tw/kejilion.sh` |

流程：`safe_download` → `bash -n` → `confirm_danger` → `bash script`。  
**不** vendor 源碼；對方若含 WARP 等，用戶自擔。

### 動畫開關

- 默認 TTY 播放  
- `OECE_NO_ANIM=1` / `OECE_FAST=1` / 非 TTY → 跳過  

### 合規紅線

不加代理/翻牆；不硬編碼 key；不遙測；不 DD 重裝；不覆蓋生產 nginx 除非用戶對生產域名二次確認。

---

## 4. 發版 SOP

```bash
cd /root/oece-x-sh
# 1. 改代碼 + bump SCRIPT_VERSION
# 2. docker run --rm -v "$PWD":/mnt koalaman/shellcheck:stable /mnt/oece-x.sh
# 3. bash -n oece-x.sh
# 4. git add -A && git commit && git push
# 5. cp oece-x.sh /opt/oece-x-web/oece-x.sh   # 關鍵！
# 6. curl -s https://oece-x.com/x | grep SCRIPT_VERSION | head -1
# 7. 首頁 index.html 終端擬真版本號/菜單同步
```

---

## 5. 版本史

| 版本 | 說明 |
|------|------|
| 1.0.0 | 體檢五件套 |
| 1.1.0 | Sub2API（**已撤回**，勿再合入） |
| 1.3.1 | 精選運維 + 酷炫動畫 + Top3 漢化入口 |

---

## 6. Roadmap

1. 裝機計數器  
2. 快捷 `x` 已做；可擴參數子命令  
3. 更多回程節點 / 結果導出  
4. oece-x.sh 域名非必須  

---

## 7. 安全待辦（本 VPS）

- [ ] sub2api 8080 改綁 127.0.0.1  
- [ ] apt 安全更新  
- [ ] BBR（可用腳本選單 6）  
- [ ] 撤銷臨時 automation 公鑰  

## v1.3.x 增補

- 彩虹塊字 Logo 開場（OECE_NO_ANIM=1 可關）
- SSH 加固 + vernu/vps-audit 入口
- 跑分 + nench；解鎖/IP 質量檢測（無 WARP）
- 精選腳本入口：LinuxMirrors / ecs / kejilion / vps-audit / nench
- **不做** WARP / Argo 隧道（合規紅線）；無域名場景用 IP:端口 + 反代
