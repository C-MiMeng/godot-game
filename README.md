# Godot 4 团队游戏仓库

面向 3–4 人并行开发的 Godot 4.x 项目骨架。`main` 只接受 Pull Request，至少 1 人批准，并且必须通过 `godot --headless --import` 检查。

- 引擎版本：**Godot 4.7.2**（与 CI 固定版本一致）
- 资源版本管理：**Git LFS**（图片、音频、3D、字体、压缩包等）
- CI：只做 `godot --headless --path . --import`，不做导出和测试
- 分支保护：PR + 1 approval + `godot-import` 状态检查

## 环境要求

| 工具 | 版本 | 用途 |
| --- | --- | --- |
| Godot | 4.7.2 | 打开项目和本地验证 |
| Git | 2.40+ | 版本控制 |
| Git LFS | 3.x | 大文件存储 |
| GitHub CLI | 2.x | 初始化仓库、配置分支保护（可选） |

## 第一次克隆

```bash
# 每台机器只需要执行一次
git lfs install

git clone https://github.com/OWNER/REPO.git
cd REPO
git lfs pull
```

用 Godot 4.7.2 打开 `project.godot`。第一次打开会生成 `.godot/`，该目录已被 `.gitignore` 忽略。

## 目录结构

```text
.
├─ .github/
│  ├─ workflows/godot-import.yml   # 唯一的 CI：headless import
│  └─ pull_request_template.md
├─ assets/                         # 图片/音频/模型/字体（Git LFS）
├─ scenes/                         # 场景
├─ scripts/                        # GDScript
├─ project.godot
├─ icon.svg
├─ .gitignore
├─ .gitattributes
└─ scripts/Setup-GitHubRepo.ps1    # 创建仓库 + 推送 + 分支保护
```

## 日常协作流程

1. 从最新 `main` 开分支：

   ```bash
   git switch main
   git pull
   git switch -c feat/player-dash
   ```

2. 小步提交，只提交源文件和 `.import`。不要提交 `.godot/`、导出产物或本机配置。
3. 推送分支并开 PR，CI 会自动运行 import。
4. 至少 1 位队友 approve，且 `godot-import` 通过后才能合并。
5. 合并后删除远端分支。

分支命名建议：`feat/...`、`fix/...`、`art/...`、`audio/...`、`ui/...`。

### 并行开发约定

- 按场景/模块拆分工作，尽量不同时修改同一个 `.tscn`。Godot 场景是文本，冲突可读，但不要无脑覆盖对方的节点。
- 二进制资源（PSD、Blend、WAV 等）走 LFS；需要独占编辑时先 `git lfs lock <path>`，完成后 `git lfs unlock <path>`。
- PR 尽量小，一次只做一件事；大重构拆成多个 PR。
- 每天开始工作前同步一次 `main`，减少最后集中冲突。
- 场景冲突解决后，务必用 Godot 打开并运行一次，确认节点和资源引用没有断。

## CI 只做 import

`.github/workflows/godot-import.yml` 在 PR 和 push 到 `main` 时运行：

```bash
godot --headless --path . --import
```

它不导出、不跑测试，只验证项目能被引擎完整导入：资源、脚本、场景依赖没有断。这样 3–4 人提交的 `.tscn`/`.tres`/资源引用问题会在合并前暴露。

- Godot 版本固定在 workflow 的 `env.GODOT_VERSION`（`4.7.2`）。升级时同时修改 `project.godot` 的 `config/features`。
- 本地复现：安装同版本 Godot，在仓库根目录执行 `godot --headless --path . --import`。
- 首次运行会下载 Godot，约 1–2 分钟；之后使用 action 缓存。
- `checkout` 已开启 `lfs: true`，否则 CI 只会拿到 LFS 指针文件，import 会失败。

## Git LFS

`.gitattributes` 已跟踪以下常见二进制类型：

- 图片：`png` `jpg` `jpeg` `webp` `gif` `bmp` `tga` `tif` `tiff` `psd` `psb` `kra` `exr` `hdr` `dds` `ktx` `ktx2` `aseprite` `ase`
- 3D：`glb` `fbx` `obj` `blend` `dae` `3ds` `stl` `ply`（`.gltf` 是文本，正常入库；外部 `.bin` 缓冲走 LFS）
- 音频：`wav` `ogg` `mp3` `flac` `m4a` `aac` `opus`
- 视频：`mp4` `webm` `mov` `avi`
- 字体：`ttf` `otf` `woff` `woff2`
- Godot 二进制资源：`res` `scn` `pck`
- 压缩包：`zip` `7z` `rar`

新增文件会被自动交给 LFS。检查：

```bash
git lfs ls-files
git check-attr filter -- assets/foo.png
```

**已有历史中的二进制文件不会自动迁移。** 团队开始前（还没有分支保护、其他人还没克隆时）执行：

```bash
git lfs migrate import --include="*.png,*.jpg,*.jpeg,*.webp,*.psd,*.wav,*.ogg,*.mp3,*.glb,*.fbx,*.blend,*.ttf" --everything
git push --force-with-lease
```

迁移会改写历史，必须先和所有协作者协调。GitHub 的 LFS 存储和流量有免费额度，导出产物、缓存和临时文件不要入库。

`export_presets.cfg` 默认被 `.gitignore` 忽略（可能包含签名密码）。需要团队共享导出配置时，提交一份不含密钥的模板，而不是把本机配置直接入库。

## 分支保护

`main` 的目标规则：

- 禁止直接 push，必须走 PR
- 至少 1 个 approval
- 新提交会 dismiss 旧 approval
- 必须通过 `godot-import` 状态检查
- 必须解决所有 review conversation
- 禁止 force push 和删除分支
- 管理员可应急绕过（`enforce_admins=false`），日常请自觉走 PR

### 用脚本创建仓库并自动配置

需要本机安装 GitHub CLI 并登录：

```powershell
winget install --id GitHub.cli -e
gh auth login
```

在仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-GitHubRepo.ps1 -RepoName godot-game -Visibility private
```

脚本会：

1. 确认/初始化 `main` 分支并提交本地文件；
2. 创建远端仓库（已存在则复用）；
3. 推送 `main` 并设为默认分支；
4. 调用 GitHub API 写入分支保护：PR + 1 approval + `godot-import`。

已有仓库也可以重复执行（会推送并重设保护）。只推送、不配置保护：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-GitHubRepo.ps1 -RepoName godot-game -SkipProtection
```

> **套餐限制**：GitHub Free 的**私有**仓库通常不支持分支保护，需要 GitHub Pro/Team/Enterprise。如果 API 返回 403，把仓库改为 public，或升级计划。公有仓库免费可用。

### 手动配置

1. 在 GitHub 新建空仓库（不要勾选 README、.gitignore、license）。
2. 关联并推送：

   ```bash
   git remote add origin https://github.com/OWNER/REPO.git
   git push -u origin main
   ```

3. 打开 Actions，手动运行一次 `Godot Import`，让 `godot-import` 检查出现在仓库里。
4. Settings → Branches → Add branch protection rule：
   - Branch name pattern：`main`
   - Require a pull request before merging → Require approvals：`1`
   - Dismiss stale pull request approvals when new commits are pushed
   - Require status checks to pass before merging → 选择 `godot-import`
   - Require conversation resolution before merging
   - 取消 Allow force pushes / Allow deletions
   - 可选：Do not allow bypassing the above settings

## 常见问题

**CI 报 `Can't open project.godot`**

确认 workflow 在仓库根目录运行，且 `project.godot` 已提交，没有被 `.gitignore` 误伤。

**CI 报 LFS 文件是 pointer**

`checkout` 必须带 `lfs: true`（已配置）。本地执行 `git lfs pull` 后再打开项目。

**CI 通过但本地打不开**

确认本地 Godot 版本与 CI 一致（4.7.2）。版本不一致时，删除本地 `.godot/` 后重新导入，或升级项目配置。

**多人同时改 `.tscn` 冲突**

保留双方节点，手动合并 `[node]` 段和 `ExtResource` id。解决后必须用 Godot 打开场景并运行一次；必要时由一个人重新在编辑器里保存。

**分支保护配置失败（403）**

私有仓库的套餐限制。改为 public 或升级 GitHub 计划；也可以在 Settings → Branches 里手动配置。
