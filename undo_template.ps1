# ============================================
# 洁净管家 · 系统清理与优化技能 · undo_template.ps1（撤销脚本 · 真实恢复实现）
# 用途：撤销最近一次/前几次清理（保留最近3次）；按 manifest 原路移回并校验
# 规范：UTF-8 BOM；只恢复本技能备份区内的文件；恢复后逐项校验，如实汇报
# ============================================
param(
    [int]$Level = 1   # 撤销层级：1=最近一次，2=前一次，3=再前一次
)

$ErrorActionPreference = "Continue"

$undoRoot = "$env:LOCALAPPDATA\CleanKeeper\reports\undo"

if (-not (Test-Path -LiteralPath $undoRoot)) {
    Write-Host "目前没有可撤销的清理记录。" -ForegroundColor Yellow
    return
}

$batches = @(Get-ChildItem -LiteralPath $undoRoot -Directory -Filter 'backup_*' -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending)

if ($batches.Count -eq 0) {
    Write-Host "目前没有可撤销的清理记录。" -ForegroundColor Yellow
    return
}
if ($Level -lt 1 -or $Level -gt $batches.Count) {
    Write-Host "没有第 $Level 次的可撤销记录（当前可撤销 $($batches.Count) 次）。" -ForegroundColor Yellow
    return
}

$batch = $batches[$Level - 1]
$manifest = Join-Path $batch.FullName "manifest.csv"
if (-not (Test-Path -LiteralPath $manifest)) {
    Write-Host "该清理批次（$($batch.Name)）缺少撤销登记表，无法恢复。请联系技术支持核查。" -ForegroundColor Red
    return
}

Write-Host "洁净管家撤销：正在恢复第 $Level 次清理（批次 $($batch.Name)）..." -ForegroundColor Cyan

$rows = Import-Csv -LiteralPath $manifest -Delimiter "`t"
$restored = 0
$failed = @()

foreach ($row in $rows) {
    $backupPath = $row.backup
    $originalPath = $row.original
    if (-not (Test-Path -LiteralPath $backupPath)) {
        $failed += "$originalPath（备份文件缺失）"
        continue
    }
    $origDir = Split-Path -Parent $originalPath
    try {
        if (-not (Test-Path -LiteralPath $origDir)) {
            New-Item -ItemType Directory -Path $origDir -Force | Out-Null
        }
        if (Test-Path -LiteralPath $originalPath) {
            # 原位置已被同名文件占用：如实报告，不覆盖
            $failed += "$originalPath（原位置已存在同名文件，未覆盖）"
            continue
        }
        Move-Item -LiteralPath $backupPath -Destination $originalPath -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $originalPath) {
            $restored++
        } else {
            $failed += "$originalPath（移动后校验失败）"
        }
    } catch {
        $failed += "$originalPath（$($_.Exception.Message)）"
    }
}

# 恢复后清理空批次目录
$remaining = @(Get-ChildItem -LiteralPath $batch.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
if ($remaining.Count -eq 0) {
    Remove-Item -LiteralPath $batch.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

# 如实汇报，不报假成功
Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "已撤销第 $Level 次清理：恢复 $restored 个文件，全部校验通过，内容完整。" -ForegroundColor Green
} else {
    Write-Host "撤销完成，但为部分恢复：成功 $restored 个，未恢复 $($failed.Count) 个：" -ForegroundColor Yellow
    foreach ($f in $failed) { Write-Host "  - $f" -ForegroundColor Yellow }
    Write-Host "未恢复的文件仍保留在撤销备份区，您可以再次尝试或联系技术支持。" -ForegroundColor Yellow
}
