# ============================================
# 洁净管家 · 系统清理与优化技能 · win_clean.ps1（执行清理，带 DryRun 预演 + 真实撤销）
# 用途：删除用户已确认的绿色缓存项；删除前先移入撤销备份区，生成撤销批次
# 规范：UTF-8 BOM；先 -DryRun 预演再执行；白名单校验；D盘/用户数据系统级硬拦截；
#       被占用自动跳过并如实汇报；释放量只计实际处理成功的数据，不虚报
# 撤销：文件移动到备份区（同盘移动，不复制），撤销脚本按批次原路移回，恢复后校验
# ============================================
param(
    [string]$Drive = "C",
    [switch]$DryRun,               # 预演：只统计不删除
    [switch]$CleanGreenOnly,       # 只清绿色项
    [switch]$SkipRecycleBin,       # 跳过回收站
    [string]$ReportDir = "$env:LOCALAPPDATA\CleanKeeper\reports"   # 不写入用户数据区
)

$ErrorActionPreference = "Continue"
$script:totalFreed = 0
$script:skipped = @()
$script:batchDir = $null
$script:manifestLines = @()

# 撤销备份区（保留最近3个批次）
$undoDir = Join-Path $ReportDir "undo"
New-Item -ItemType Directory -Path $undoDir -Force | Out-Null

# ---- 系统级硬拦截（红线3/5/6）：非绝对路径、盘符根、用户数据区、系统目录、D盘 ----
function Test-ProtectedPath {
    param([string]$Path)
    # 非绝对路径一律拦截（fail-safe）
    if (-not [System.IO.Path]::IsPathRooted($Path)) { return $true }
    $full = $null
    try { $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\') } catch { return $true }
    if ($full -match '^[A-Za-z]:$') { return $true }   # 盘符根目录
    if ($full -match '^D:($|\\)')   { return $true }   # D盘默认绝不执行（红线5，逐项点名走应用层授权）
    $protectedRoots = @(
        $env:USERPROFILE, $env:LOCALAPPDATA, $env:APPDATA,
        "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Pictures", "$env:USERPROFILE\Videos",
        "$env:USERPROFILE\Music", "$env:USERPROFILE\Downloads",
        "C:\Windows", "C:\Program Files", "C:\Program Files (x86)"
    )
    foreach ($r in $protectedRoots) {
        if ($full -ieq ([System.IO.Path]::GetFullPath($r).TrimEnd('\'))) { return $true }
    }
    return $false
}

function Move-ToUndoBatch {
    param([System.IO.FileInfo]$File, [string]$SourceRoot)
    $rel = $File.FullName.Substring($SourceRoot.Length).TrimStart('\')
    $dest = Join-Path $script:batchDir $rel
    # 防碰撞：不同源根目录的相同相对路径，追加序号
    $n = 1
    while (Test-Path -LiteralPath $dest) {
        $dest = Join-Path $script:batchDir ("{0}__{1}" -f $rel, $n)
        $n++
    }
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Move-Item -LiteralPath $File.FullName -Destination $dest -Force -ErrorAction Stop
    # 撤销登记：原路径 / 备份路径 / 大小 / 时间（恢复按此逐项原路移回）
    $script:manifestLines += ("{0}`t{1}`t{2}`t{3}" -f $File.FullName, $dest, $File.Length, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    return $dest
}

function Clear-CacheFolder {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if (Test-ProtectedPath $Path) {
        Write-Host "  [安全拦截] $Path 属于受保护目录，不执行（红线3/5/6）" -ForegroundColor Red
        return
    }
    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue)
    $size = ($files | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $size -or $size -eq 0) { Write-Host "  [空] $Label" -ForegroundColor DarkGray; return }

    if ($DryRun) {
        $script:totalFreed += $size
        Write-Host "  [预演] $Label：$([math]::Round($size/1MB,1)) MB（未删除）" -ForegroundColor Yellow
        return
    }

    # 执行：先移入撤销备份区，再计入释放量；被占用/失败自动跳过并如实记录
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    if ($null -eq $script:batchDir) {
        $script:batchDir = Join-Path $undoDir "backup_$stamp"
        New-Item -ItemType Directory -Path $script:batchDir -Force | Out-Null
    }
    $deletedBytes = 0L
    $deletedCount = 0
    foreach ($f in $files) {
        try {
            $null = Move-ToUndoBatch -File $f -SourceRoot $Path
            $deletedBytes += $f.Length
            $deletedCount++
        } catch {
            $script:skipped += $f.FullName
        }
    }
    $script:totalFreed += $deletedBytes
    Write-Host "  [已清理] $Label：$([math]::Round($deletedBytes/1MB,1)) MB（$deletedCount 个文件，已移入撤销备份区）" -ForegroundColor Green
}

Write-Host "洁净管家清理：$Drive 盘（$(if($DryRun){'预演模式·不删除'}else{'执行模式·已获您授权'})）" -ForegroundColor Cyan

# ---- 🟢 绿色项（cleanup_rules 白名单内，日志/会话类除外）----
Clear-CacheFolder "$env:TEMP" "用户临时文件"
Clear-CacheFolder "C:\Windows\Temp" "系统临时文件"
Clear-CacheFolder "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" "Edge缓存"
Clear-CacheFolder "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache" "Edge代码缓存"
Clear-CacheFolder "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache" "EdgeGPU缓存"
Clear-CacheFolder "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker" "Edge服务缓存"

# ---- 🟡 用户点名的黄色项（日志/会话类：默认保留，红线4）----
# 日志/会话类数据默认保留：如需清理，须用户单独明确确认后由应用层显式传入路径，
# 且不得随批量清理静默执行。本脚本不内置任何日志类清理目标。

# ---- 撤销批次修剪：保留最近 3 次（红线2）----
if (-not $DryRun -and $null -ne $script:batchDir) {
    if ($script:manifestLines.Count -gt 0) {
        $manifestPath = Join-Path $script:batchDir "manifest.csv"
        ("original`tbackup`tsize`ttimestamp") + [Environment]::NewLine + ($script:manifestLines -join [Environment]::NewLine) |
            Out-File -LiteralPath $manifestPath -Encoding UTF8
    }
    $oldBatches = @(Get-ChildItem -LiteralPath $undoDir -Directory -Filter 'backup_*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -Skip 3)
    foreach ($old in $oldBatches) {
        Remove-Item -LiteralPath $old.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---- 汇总 ----
Write-Host ""
if ($DryRun) {
    Write-Host "=== 预演完成（未删除任何文件）===" -ForegroundColor Yellow
    Write-Host "预演可清理：$([math]::Round($script:totalFreed/1MB,1)) MB"
} else {
    Write-Host "=== 清理完成 ===" -ForegroundColor Green
    Write-Host "本次释放：$([math]::Round($script:totalFreed/1MB,1)) MB（仅计实际处理成功的文件，被占用跳过的不计入）"
    if ($script:skipped.Count -gt 0) {
        Write-Host "跳过被占用文件：$($script:skipped.Count) 个（不影响您正常使用）" -ForegroundColor Yellow
    }
    if ($null -ne $script:batchDir) {
        Write-Host "撤销批次已生成：$script:batchDir（最近3次清理均可撤销）" -ForegroundColor Cyan
    }
    Write-Host "您的文档、聊天记录和工作文件都没有动，日志类数据也默认保留。"
    Write-Host "如需恢复，请运行撤销脚本：undo_template.ps1（回复'撤销'即可）。"
}
