#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Speedster 日志体检脚本 (check_diag.py)

用法:  python check_diag.py <SpeedsterDiag.log 路径> [--expect 进程bundleID1,bundleID2]

自动检查已知的事故签名:
  1. 版本/注入确认        (Fluid-XX loaded / injected 行)
  2. 开机自检             ([selfcheck] 功能开关快照)
  3. 胶囊污染             (锁屏期间出现非原版 response/dampingRatio 值)
  4. 双层缩放             (UIView.animate 缩完内部 CAAnimation 又缩)
  5. 雪球                 (文件夹弹簧 stiffness 输入跨周期增长)
  6. restore 失效         (restore failed 行)
  7. 登记表膨胀           (restore(l...) registered 数 > 400)
  8. 日志撕裂             (行尾异常截断统计)
  9. 注入缺失             (--expect 指定的进程没有注入行)
"""
import re
import sys
import collections

STOCK_RESPONSE = {0.531, 0.513, 0.512, 0.0}          # SBFFluidBehaviorSettings response 原版值
STOCK_DR = {0.845, 0.816, 0.0}                       # dampingRatio 原版值
POISON_RESPONSE = {0.37: "开关动画1档", 0.25: "开关动画2档", 0.19: "开关动画3档",
                   0.1: "开关动画4档", 0.07: "开关动画5档", 0.350828: "文件夹加速"}
TAIL_FRAGMENTS = re.compile(r"\[app-timed\] [A-Za-z]?$")

def fnum(s):
    try:
        return float(s)
    except ValueError:
        return None

def near(x, y, tol=1e-4):
    return x is not None and y is not None and abs(x - y) < tol

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    path = sys.argv[1]
    expect = []
    if "--expect" in sys.argv:
        i = sys.argv.index("--expect")
        expect = [p.strip() for p in sys.argv[i + 1].split(",") if p.strip()]

    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    issues, warns, infos = [], [], []

    # --- 1. 版本与注入 ---
    version = None
    injected = []
    for l in lines:
        m = re.search(r"Speedster (Fluid-\d+) loaded in SpringBoard", l)
        if m:
            version = m.group(1)
        m = re.search(r"Speedster (Fluid-\d+) injected into app process: (\S+)", l)
        if m:
            version = m.group(1)
            injected.append(m.group(2))
    if version:
        infos.append(f"版本: {version}; 注入进程: {len(injected)} 个")
        for p in injected:
            infos.append(f"  注入: {p}")
    else:
        issues.append("没有找到任何 Fluid 版本行 - 日志可能不完整或插件未加载")

    # --- 2. 开机自检 ---
    for l in lines:
        if "[selfcheck]" in l:
            infos.append("开机自检: " + l.split("[selfcheck]", 1)[1].strip())
            break
    else:
        if version and version >= "Fluid-32":
            warns.append("有 Fluid-32+ 版本行但没有 [selfcheck] 行")

    # --- 锁屏状态机 ---
    locked = False
    lock_events = 0
    pill_poison = []
    restore_counts = []
    restore_failed = 0

    for l in lines:
        m = re.search(r"deviceLocked (\d) -> (\d)", l)
        if m:
            if m.group(1) == "0" and m.group(2) == "1":
                locked = True
                lock_events += 1
            elif m.group(1) == "1" and m.group(2) == "0":
                locked = False
            continue
        m = re.search(r"restore\(l\w*\): .*registered (\d+)/(\d+)/(\d+)/(\d+)", l)
        if not m:
            m = re.search(r"restore\(l\w*\): response=(\d+) dampingRatio=(\d+) damping=(\d+) mass=(\d+)", l)
        if m:
            counts = [int(x) for x in m.groups()[-4:]]
            restore_counts.append(max(counts))
            continue
        if "restore failed" in l:
            restore_failed += 1
        if not locked:
            continue
        # --- 3. 胶囊污染: 锁屏期间的 get/set 值 ---
        for metric, stocks, poisons in (
            ("response", STOCK_RESPONSE, POISON_RESPONSE),
            ("dampingRatio", STOCK_DR, {0.9: "开关回弹1档", 0.8: "开关回弹2档",
                                        0.6: "开关回弹3档", 0.4: "开关回弹4档", 0.2: "开关回弹5档"}),
        ):
            m = re.search(r"\[locked\] (?:get-|set)" + metric + r"(?: on \S+)? value=([\d.eE+-]+)", l)
            if not m:
                continue
            v = fnum(m.group(1))
            if v is None:
                continue
            stock_hit = any(near(v, s) for s in stocks)
            poison_hit = any(near(v, p, 5e-3) for p in poisons)
            ratio_hit = any(near(v, s * r, 5e-3) for s in stocks
                            for r in (0.1, 0.01, 0.66, 0.7)) and v > 1e-6
            if not stock_hit and (poison_hit or ratio_hit):
                pill_poison.append(l.strip())

    if pill_poison:
        issues.append(f"锁屏期间发现 {len(pill_poison)} 处可疑非原版值 (胶囊污染嫌疑):")
        for p in pill_poison[:8]:
            issues.append("  " + p)
    elif lock_events:
        infos.append(f"胶囊检查: {lock_events} 次锁屏, 锁屏期间所有值均为原版 - 通过")

    # --- 7. 登记表膨胀 ---
    if restore_counts:
        peak = max(restore_counts)
        if peak > 400:
            issues.append(f"登记表峰值 {peak} (>400) - 锁屏瞬间批量重写过大 (Fluid-32 前的构建)")
        else:
            infos.append(f"登记表峰值: {peak} - 正常范围")

    # --- 4. 双层缩放 ---
    dbl = 0
    prev_uia = False
    for l in lines:
        if "[app-timed] UIView.animate" in l or "[app-timed] UIView.keyframes" in l \
           or "[app-timed] UIView.transition" in l:
            prev_uia = True
            continue
        if prev_uia and "[app-timed] CA duration" in l:
            m = re.search(r"CA duration ([\d.]+)->", l)
            if m and fnum(m.group(1)) is not None and fnum(m.group(1)) < 1:
                dbl += 1
            prev_uia = False
        elif "[app-timed]" in l:
            prev_uia = False
    if dbl > 5:
        issues.append(f"双层缩放 {dbl} 处 (UIView.animate 后 CA duration 再缩) - 快过头签名")
    elif dbl:
        warns.append(f"双层缩放 {dbl} 处 (少量可能是独立的 CA 动画, 非必然)")
    else:
        infos.append("双层缩放: 无 - 通过")

    # --- 5. 雪球: 文件夹 SPRING stiffness 输入应每轮从原版起步 ---
    k_inputs = []
    for l in lines:
        m = re.search(r"SPRING k ([\d.]+)->", l)
        if m:
            v = fnum(m.group(1))
            if v is not None and v > 1:
                k_inputs.append(v)
    snowball = False
    for a, b in zip(k_inputs, k_inputs[1:]):
        if b > a * 1.5:
            snowball = True
            break
    if k_inputs:
        if snowball:
            issues.append(f"雪球签名: SPRING stiffness 输入跨周期增长 ({len(k_inputs)} 次缩放)")
        else:
            infos.append(f"雪球检查: {len(k_inputs)} 次缩放均从原版值起步 - 通过")

    # --- 6. restore 失效 ---
    if restore_failed:
        issues.append(f"restore failed 行 {restore_failed} 处")

    # --- 8. 日志撕裂 ---
    torn = sum(1 for l in lines if TAIL_FRAGMENTS.search(l))
    if torn > 3:
        warns.append(f"疑似日志撕裂 {torn} 行 (多进程并发追加, 正式版修复)")

    # --- 9. 注入缺失 ---
    for p in expect:
        if not any(p in x for x in injected):
            warns.append(f"预期进程未注入: {p} (注意: 需从多任务杀掉后重开才会注入)")

    print("=" * 56)
    print(f"Speedster 日志体检: {path}")
    print("=" * 56)
    for i in infos:
        print("  [信息] " + i)
    for w in warns:
        print("  [警告] " + w)
    if issues:
        for it in issues:
            print("  [问题] " + it)
        print("-" * 56)
        print(f"结论: 发现 {sum(1 for i in issues if not i.startswith('  '))} 类问题, 需要处理")
        sys.exit(1)
    print("-" * 56)
    print("结论: 全部通过")

if __name__ == "__main__":
    main()
