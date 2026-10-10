# ============================================
# 洁净管家 · 系统清理与优化技能 · win_scan.ps1（只读检查，不删任何文件）
# 用途：分级汇报可清理项（🟢可直接清 / 🟡需确认·默认保留 / 🔴绝不碰）
# 规范：UTF-8 BOM；全程只读；不执行任何删除；System32 等系统目录不进扫描范围
# ============================================
param(
    [string]$Drive = "C",          # 扫描盘符
    [switch]$IncludeYellow          # 是否展示黄色需确认项明细
)

$ErrorActionPreference = "SilentlyContinue"
$results = @{ Green = 0; Yellow = 0; Red = 0; GreenMB = 0.0; YellowMB = 0.0; LogMB = 0.0 }

function Get-DirSizeMB {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $bytes = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    if ($null -eq $bytes -or $bytes -le 0) { return 0 }
    return [math]::Round($bytes / 1MB, 1)
}

# 日志/会话类识别：只统计常见日志类扩展名，默认保留，永不入执行清单
function Get-LogSizeMB {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $logExts = @(".log", ".etl", ".dmp")
    $bytes = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $logExts -contains $_.Extension.ToLower() } |
        Measure-Object -Property Length -Sum).Sum
    if ($null -eq $bytes) { return 0 }
    return [math]::Round($bytes / 1MB, 1)
}

Write-Host "洁净管家检查：正在检查 $Drive 盘可安全清理的内容（只读，不会删除任何文件）..." -ForegroundColor Cyan

# ---- 🟢 绿色：可再生缓存（cleanup_rules.json 白名单内，日志除外）----
$greenPaths = @(
    "$env:TEMP",
    "C:\Windows\Temp",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker"
)

foreach ($p in $greenPaths) {
    if (Test-Path -LiteralPath $p) {
        $mb = Get-DirSizeMB $p
        if ($mb -gt 0) {
            $results.Green++
            $results.GreenMB += $mb
            Write-Host "  [可直接清理] $p  ($mb MB)" -ForegroundColor Green
        }
    }
}

# ---- 🟡 黄色：需用户确认（默认保留；日志/会话类、回收站）----
$recycleBinPath = "C:\`$Recycle.Bin"
if ($IncludeYellow) {
    $mb = Get-DirSizeMB $recycleBinPath
    if ($mb -gt 0) {
        $results.Yellow++
        $results.YellowMB += $mb
        Write-Host "  [需您确认·默认保留] 回收站  ($mb MB)（删除后无法恢复，仅您明确点名才清）" -ForegroundColor Yellow
    }

    # 日志/会话类数据：可扫描、可汇报大小，默认保留（红线4）
    foreach ($p in @("$env:TEMP", "C:\Windows\Temp")) {
        $logMb = Get-LogSizeMB $p
        if ($logMb -gt 0) {
            $results.LogMB += $logMb
        }
    }
    if ($results.LogMB -gt 0) {
        Write-Host ("  [日志/会话类·默认保留] 检测到日志类文件约 {0} MB，我默认保留，不会动它；您确认不需要，我再单独处理。" -f $results.LogMB) -ForegroundColor Yellow
    }
}

# ---- 🔴 红色：绝不碰（仅识别存在，永不入执行清单）----
$redDirs = @(
    @{ Path = "$env:USERPROFILE\Documents";  Label = "您的文档" },
    @{ Path = "$env:USERPROFILE\Desktop";    Label = "您的桌面文件" },
    @{ Path = "$env:USERPROFILE\Pictures";   Label = "您的图片" },
    @{ Path = "$env:USERPROFILE\Videos";     Label = "您的视频" },
    @{ Path = "$env:USERPROFILE\Downloads";  Label = "您的下载文件" }
)
foreach ($d in $redDirs) {
    if (Test-Path -LiteralPath $d.Path) {
        $results.Red++
    }
}

# ---- 汇总 ----
Write-Host ""
Write-Host "=== 检查完成 ===" -ForegroundColor Cyan
Write-Host "可直接清理：$($results.Green) 项，约 $([math]::Round($results.GreenMB,1)) MB"
Write-Host "需您确认（默认保留）：$($results.Yellow) 项，约 $([math]::Round($results.YellowMB,1)) MB"
Write-Host "日志/会话类数据默认保留，您确认不需要才单独处理。"
Write-Host "以下内容洁净管家永远不会碰：您的文档、聊天记录、工作文件、杀毒核心、D盘核心数据（已识别 $($results.Red) 处受保护目录）。"
Write-Host "执行权永远在您手上：您说确认，我才动手。"
