#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成器：把 QianJi/ 下所有 .swift 收进一个标准 .xcodeproj（OpenStep plist）。
用程序化 Core Data 模型，所以工程里只有 .swift + Assets.xcassets，
不需要 xcdatamodeld 的编译规则，也不需要 codegen / XcodeGen 等外部工具。

对标工具链：Xcode 15.4（macOS Sonoma 14.x + iOS 17.5 SDK，Swift 5.10）。
工程元数据刻意不写成 Xcode 16 标记，避免 15.4 打开时弹「由更新版本创建」的提示。
objectVersion 保持 56（Xcode 14.0 格式）：14 / 15 / 16 都能读，兼容性最广。

用法：python3 scripts/generate_xcodeproj.py
新增/删除 Swift 文件后重跑一次即可（会整体重建 project.pbxproj）。
"""
import hashlib
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJ = ROOT / "MoneyNote.xcodeproj"
TARGET_NAME = "QianJi"
PRODUCT = "QianJi.app"
BUNDLE_ID = "com.qianji.local"
DISPLAY_NAME = "钱迹"
DEPLOY = "16.0"

# Xcode 15.4 对应的工具链标记（用在 LastUpgradeCheck / scheme 上）
XCODE_BUILD = "1540"
XCODE_VERSION = "15.4"
# objectVersion 56 = Xcode 14.0 工程格式，14/15/16 均可打开
PROJECT_OBJECT_VERSION = 56

_counter = [0x1000]


def nid():
    _counter[0] += 1
    return format(_counter[0], "024X")


def oid(key):
    return hashlib.sha1(key.encode("utf-8")).hexdigest()[:24].upper()


objects = {}
sources = []   # PBXBuildFile ids for Sources phase
resources = []  # PBXBuildFile ids for Resources phase


def add(ident, body):
    assert ident not in objects, "ID 冲突: " + ident
    objects[ident] = {"isa": body["isa"], **{k: v for k, v in body.items() if k != "isa"}}
    return ident


# ---- 收集 Swift 文件 ----
swift_files = sorted(
    p.relative_to(ROOT).as_posix()
    for p in ROOT.rglob("*.swift")
    if "MoneyNote.xcodeproj" not in p.parts and ".github" not in p.parts
)

by_dir = {}
swift_dirs = set()
for rel in swift_files:
    d = str(pathlib.PurePosixPath(rel).parent)
    by_dir.setdefault(d, []).append(rel)
    parts = list(pathlib.PurePosixPath(d).parts)
    for i in range(len(parts)):
        swift_dirs.add("/".join(parts[: i + 1]))
    if d == ".":
        swift_dirs.add(".")

EXCLUDED_DIRS = {"Assets.xcassets", "Icons", "scripts", ".github", "MoneyNote.xcodeproj"}


def build_group(dir_rel):
    children = []

    base = ROOT / dir_rel if dir_rel != "." else ROOT
    for sub in sorted(p for p in base.iterdir() if p.is_dir()):
        if sub.name in EXCLUDED_DIRS or sub.name.startswith("."):
            continue
        child_rel = sub.name if dir_rel == "." else dir_rel + "/" + sub.name
        if child_rel in swift_dirs:
            children.append(build_group(child_rel))

    for rel in by_dir.get(dir_rel, []):
        ref = oid("ref:" + rel)
        bld = oid("build:" + rel)
        add(ref, {
            "isa": "PBXFileReference",
            "lastKnownFileType": "sourcecode.swift",
            "path": pathlib.PurePosixPath(rel).name,
            "sourceTree": "<group>",
        })
        add(bld, {
            "isa": "PBXBuildFile",
            "fileRef": ref,
        })
        sources.append(bld)
        children.append(ref)

    gid = oid("group:" + dir_rel)
    body = {
        "isa": "PBXGroup",
        "children": children,
        "sourceTree": "<group>",
    }
    if dir_rel != ".":
        body["path"] = pathlib.PurePosixPath(dir_rel).name
    add(gid, body)
    return gid


MAIN_GROUP = build_group(".")

# ---- 资源目录 ----
# 故意不把 Assets.xcassets 加进 Resources build phase：
# Xcode 15.4 的 actool 在缺少 iOS 17.5 Simulator Runtime 时会硬失败
#（"Failed to locate any simulator runtime ... iphonesimulator 17.5"），
# 即使 -sdk iphoneos 也绕不过去。图标改由 Icons/ 松散 PNG +
# Info.plist 的 CFBundleIcons 提供，打包脚本在组装 Payload/ 时拷进 .app。
# Assets.xcassets 仅作为素材留在磁盘上，不参与编译。

# ---- Info.plist ----
# 只加文件引用，让 Xcode 里能点开编辑；由 INFOPLIST_FILE 构建设置处理，
# 不能加进 Resources build phase，否则会被当资源重复拷贝。
INFOPLIST_REF = oid("ref:Info.plist")
add(INFOPLIST_REF, {
    "isa": "PBXFileReference",
    "lastKnownFileType": "text.plist.xml",
    "path": "Info.plist",
    "sourceTree": "<group>",
})
objects[MAIN_GROUP]["children"].append(INFOPLIST_REF)

# ---- 产品 ----
PRODUCT_REF = nid()
add(PRODUCT_REF, {
    "isa": "PBXFileReference",
    "explicitFileType": "wrapper.application",
    "includeInIndex": 0,
    "path": PRODUCT,
    "sourceTree": "BUILT_PRODUCTS_DIR",
})
PRODUCTS_GROUP = nid()
add(PRODUCTS_GROUP, {
    "isa": "PBXGroup",
    "children": [PRODUCT_REF],
    "name": "Products",
    "sourceTree": "<group>",
})
objects[MAIN_GROUP]["children"].append(PRODUCTS_GROUP)

# ---- Build phases ----
SOURCES_PHASE = nid()
add(SOURCES_PHASE, {
    "isa": "PBXSourcesBuildPhase",
    "buildActionMask": 2147483647,
    "files": sources,
    "runOnlyForDeploymentPostprocessing": 0,
})
FRAMEWORKS_PHASE = nid()
add(FRAMEWORKS_PHASE, {
    "isa": "PBXFrameworksBuildPhase",
    "buildActionMask": 2147483647,
    "files": [],
    "runOnlyForDeploymentPostprocessing": 0,
})
RESOURCES_PHASE = nid()
add(RESOURCES_PHASE, {
    "isa": "PBXResourcesBuildPhase",
    "buildActionMask": 2147483647,
    "files": resources,
    "runOnlyForDeploymentPostprocessing": 0,
})

# ---- Build configurations ----
project_common = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu11",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOY,
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "SDKROOT": "iphoneos",
    "SWIFT_VERSION": "5.0",
}
target_common = {
    # 彻底不编译 Assets.xcassets：Xcode 15.4 的 actool 在没装 iOS 17.5
    # Simulator Runtime 时会报 "Failed to locate any simulator runtime ..."，
    # 即使 -sdk iphoneos 也绕不过去。把 .xcassets 从 Resources phase 拿掉，
    # 改用 Icons/ 松散 PNG + Info.plist 的 CFBundleIcons，从根上不触发
    # CompileAssetCatalog，也不需要下载几个 GB 的模拟器。
    "ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS": "NO",
    "ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS": "",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "NO",
    "ENABLE_PREVIEWS": "NO",
    # 巨魔路线：产出未签名包，TrollStore 安装时自行伪签名
    "CODE_SIGN_IDENTITY": "",
    "CODE_SIGNING_ALLOWED": "NO",
    "CODE_SIGNING_REQUIRED": "NO",
    "CURRENT_PROJECT_VERSION": "2",
    # 显式 Info.plist：GENERATE_INFOPLIST_FILE 在自定义 SYMROOT 的 build 产物里
    # 可能不落地（或落成符号链接），TrollStore 会报「解析错误 302 / 找不到 Info.plist」。
    # 用真实文件最稳，且便于出包前自检。
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": "Info.plist",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOY,
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    "MARKETING_VERSION": "2.0.0",
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1,2",
}


def make_config(name, base, extra):
    cid = nid()
    add(cid, {
        "isa": "XCBuildConfiguration",
        "buildSettings": {**base, **extra},
        "name": name,
    })
    return cid


PROJ_DEBUG = make_config("Debug", project_common, {
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
})
PROJ_RELEASE = make_config("Release", project_common, {
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": "-O",
    "VALIDATE_PRODUCT": "YES",
})
TGT_DEBUG = make_config("Debug", target_common, {})
TGT_RELEASE = make_config("Release", target_common, {})


def make_config_list(items, default):
    cid = nid()
    add(cid, {
        "isa": "XCConfigurationList",
        "buildConfigurations": items,
        "defaultConfigurationIsVisible": 0,
        "defaultConfigurationName": default,
    })
    return cid


PROJ_LIST = make_config_list([PROJ_DEBUG, PROJ_RELEASE], "Release")
TGT_LIST = make_config_list([TGT_DEBUG, TGT_RELEASE], "Release")

# ---- Target / Project ----
TARGET = nid()
add(TARGET, {
    "isa": "PBXNativeTarget",
    "buildConfigurationList": TGT_LIST,
    "buildPhases": [SOURCES_PHASE, FRAMEWORKS_PHASE, RESOURCES_PHASE],
    "buildRules": [],
    "dependencies": [],
    "name": TARGET_NAME,
    "productName": TARGET_NAME,
    "productReference": PRODUCT_REF,
    "productType": "com.apple.product-type.application",
})

PROJECT = nid()
add(PROJECT, {
    "isa": "PBXProject",
    "attributes": {
        "BuildIndependentTargetsInParallel": 1,
        "LastSwiftUpdateCheck": XCODE_BUILD,
        "LastUpgradeCheck": XCODE_BUILD,
        "TargetAttributes": {TARGET: {"CreatedOnToolsVersion": XCODE_VERSION}},
    },
    "buildConfigurationList": PROJ_LIST,
    "compatibilityVersion": "Xcode 14.0",
    "developmentRegion": "en",
    "hasScannedForEncodings": 0,
    "knownRegions": ["en", "Base", "zh-Hans"],
    "mainGroup": MAIN_GROUP,
    "productRefGroup": PRODUCTS_GROUP,
    "projectDirPath": "",
    "projectRoot": "",
    "targets": [TARGET],
})


# ---- OpenStep plist 序列化 ----
def q(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return '"' + s + '"'


def key(s):
    # 纯标识符 / 24 位对象 ID 按 Xcode 原生写法不加引号
    return s if re.fullmatch(r"[A-Za-z0-9_$./]+", s) else q(s)


def ser(value, indent=0):
    pad = "\t" * indent
    if isinstance(value, bool):
        return "YES" if value else "NO"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return q(value)
    if isinstance(value, list):
        if not value:
            return "()"
        inner = "".join("\t" * (indent + 1) + ser(v, indent + 1) + ",\n" for v in value)
        return "(\n" + inner + pad + ")"
    if isinstance(value, dict):
        if not value:
            return "{}"
        inner = ""
        for k, v in value.items():
            inner += "\t" * (indent + 1) + key(k) + " = " + ser(v, indent + 1) + ";\n"
        return "{\n" + inner + pad + "}"
    raise TypeError(type(value))


root_doc = {
    "archiveVersion": 1,
    "classes": {},
    "objectVersion": PROJECT_OBJECT_VERSION,
    "objects": objects,
    "rootObject": PROJECT,
}

pbx = "// !$*UTF8*$!\n" + ser(root_doc) + "\n"
(PROJ / "project.pbxproj").write_text(pbx, encoding="utf-8")

# ---- Shared scheme（CI 里 xcodebuild -scheme 必须要有）----
scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="{XCODE_BUILD}" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{TARGET}" BuildableName="{PRODUCT}" BlueprintName="{TARGET_NAME}" ReferencedContainer="container:MoneyNote.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
      <Testables/>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{TARGET}" BuildableName="{PRODUCT}" BlueprintName="{TARGET_NAME}" ReferencedContainer="container:MoneyNote.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{TARGET}" BuildableName="{PRODUCT}" BlueprintName="{TARGET_NAME}" ReferencedContainer="container:MoneyNote.xcodeproj"/>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug"/>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
"""
scheme_path = PROJ / "xcshareddata" / "xcschemes" / "QianJi.xcscheme"
scheme_path.write_text(scheme, encoding="utf-8")

# ---- 自检：引用完整性 ----
errors = []
for k, v in objects.items():
    if "isa" not in v:
        errors.append(f"对象 {k} 缺 isa")
    if v.get("isa") == "PBXBuildFile" and v["fileRef"] not in objects:
        errors.append(f"PBXBuildFile {k} 引用了不存在的 {v['fileRef']}")
    if v.get("isa") == "PBXGroup":
        for c in v.get("children", []):
            if c not in objects:
                errors.append(f"PBXGroup {k} 引用了不存在的 {c}")
for key in ("buildConfigurationList", "mainGroup", "productRefGroup"):
    if objects[PROJECT][key] not in objects:
        errors.append(f"PBXProject 的 {key} 引用不存在")
for t in objects[PROJECT]["targets"]:
    if t not in objects:
        errors.append("target 引用不存在")

text = pbx
for ch_open, ch_close in [("{", "}"), ("(", ")")]:
    if text.count(ch_open) != text.count(ch_close):
        errors.append(f"括号不配对: {ch_open}{ch_close}")

if errors:
    print("校验失败：")
    for e in errors:
        print(" -", e)
    sys.exit(1)

print(f"OK: {len(swift_files)} 个 Swift 文件, {len(objects)} 个工程对象")
print(f"    {PROJ / 'project.pbxproj'}")
print(f"    {scheme_path}")
