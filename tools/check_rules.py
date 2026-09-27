#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Speedster 铁律自检 (check_rules.py)

用法:  python check_rules.py <Speedster.x 路径>

在推送/构建前检查三条动画钩子铁律 (Fluid-18 死机 / Fluid-25 崩溃的教训):
  铁律1  getter 严禁缩放   - 无参 getter 的 %orig 不允许收到计算值 (Fluid-18 冻结死机)
  铁律2  严禁传新对象      - %orig 不允许收到内联构造的对象 (Fluid-25 安全模式崩溃)
  铁律3  缩放需配套还原    - setter 内缩放写入应伴随 restore/markTouched (警告级)

退出码: 0=通过, 1=有 FAIL 级违规
"""
import re
import sys

SIG = re.compile(r"^[\t ]*[-+]\s*\([^)]*\)\s*(\S+)")
HOOK = re.compile(r"%hook\s+(\w+)")

def method_blocks(text):
    """yield (hook_class, signature_line, body_text, start_lineno)"""
    cur_hook = None
    cur_sig = None
    cur_start = 0
    cur_body = []
    for lineno, line in enumerate(text.splitlines(), 1):
        m = HOOK.search(line)
        if m:
            cur_hook = m.group(1)
            continue
        if re.match(r"[\t ]*%end", line):
            if cur_sig is not None:
                yield cur_hook, cur_sig, "\n".join(cur_body), cur_start
                cur_sig = None
            cur_hook = None
            continue
        if SIG.match(line) and not line.lstrip().startswith(("//", "*")):
            if cur_sig is not None:
                yield cur_hook, cur_sig, "\n".join(cur_body), cur_start
            cur_sig = line.strip()
            cur_start = lineno
            cur_body = []
            continue
        if cur_sig is not None:
            cur_body.append(line)
    if cur_sig is not None:
        yield cur_hook, cur_sig, "\n".join(cur_body), cur_start

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    path = sys.argv[1]
    text = open(path, encoding="utf-8", errors="replace").read()
    fails, warns = [], []

    for hook, sig, body, lineno in method_blocks(text):
        is_getter = ":" not in sig          # ObjC 无参方法 = 属性 getter
        orig_calls = re.findall(r"%orig\s*\(([^)]*)\)", body)
        orig_calls += re.findall(r"%orig\s*;", body)

        # 铁律1: getter 的 %orig 不得携带计算值
        if is_getter:
            for call in re.findall(r"%orig\s*\((.+)\)", body):
                arg = call.strip().rstrip(";").strip()
                if arg and arg != "arg1":
                    fails.append(f"铁律1(getter缩放) 行{lineno} [{hook}] {sig} -> %orig({arg})")

        # 铁律2: %orig 不得收到内联构造的对象
        if re.search(r"%orig\s*\(\s*\[", body):
            fails.append(f"铁律2(传新对象) 行{lineno} [{hook}] {sig} -> %orig 收到内联构造对象")

        # 铁律3: setter 内缩放应伴随还原/登记 (警告级)
        if not is_getter:
            scaled = re.search(r"%orig\s*\(\s*[^);]*[\*/]", body) or \
                     re.search(r"%orig\s*\(\s*(reverse|folder|zeta)\w*\(", body)
            has_restore = re.search(r"restore|Restore|markTouched|removeAllObjects", body)
            if scaled and not has_restore:
                warns.append(f"铁律3(缩放未还原?) 行{lineno} [{hook}] {sig}")

    print("=" * 56)
    print("Speedster 铁律自检:", path)
    print("=" * 56)
    for w in warns:
        print("  [警告] " + w)
    for f in fails:
        print("  [违规] " + f)
    if fails:
        print("-" * 56)
        print(f"结论: {len(fails)} 处 FAIL 级违规, 禁止推送")
        sys.exit(1)
    print("-" * 56)
    print(f"结论: 通过 ({len(warns)} 条警告)")

if __name__ == "__main__":
    main()
