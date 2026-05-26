#!/usr/bin/env python3
"""Generate Xcode project.pbxproj in JSON format (Xcode 15+ compatible)."""
import os, json, uuid, shutil

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(PROJECT_DIR, "HearthstoneTracker-iOS")
XCODE_PROJ_DIR = os.path.join(PROJECT_DIR, "HearthstoneTracker.xcodeproj")

def uid():
    return uuid.uuid4().hex.upper()[:24]

def generate():
    swift_files = []
    for root, dirs, files in os.walk(SRC_DIR):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, PROJECT_DIR)
            if f.endswith(".swift"):
                swift_files.append(rel)
    swift_files.sort()

    file_ref_ids = {}
    build_file_ids = {}
    source_file_refs = []
    
    for sf in swift_files:
        fid = uid()
        bfid = uid()
        file_ref_ids[sf] = fid
        build_file_ids[sf] = bfid
        source_file_refs.append(bfid)
    
    info_plist_id = uid()
    product_ref_id = uid()
    root_group_id = uid()
    src_group_id = uid()
    target_id = uid()
    sources_phase_id = uid()
    resources_phase_id = uid()
    debug_config_id = uid()
    release_config_id = uid()
    config_list_id = uid()
    t_debug_config_id = uid()
    t_release_config_id = uid()
    t_config_list_id = uid()
    project_id = uid()

    objects = {}

    for sf in swift_files:
        objects[build_file_ids[sf]] = {"isa": "PBXBuildFile", "fileRef": file_ref_ids[sf]}

    for sf in swift_files:
        rel_path = os.path.relpath(os.path.join(PROJECT_DIR, sf), SRC_DIR)
        objects[file_ref_ids[sf]] = {"isa": "PBXFileReference", "lastKnownFileType": "sourcecode.swift", "path": rel_path, "sourceTree": "<group>"}

    objects[info_plist_id] = {"isa": "PBXFileReference", "lastKnownFileType": "text.plist.xml", "path": "Info.plist", "sourceTree": "<group>"}
    objects[product_ref_id] = {"isa": "PBXFileReference", "explicitFileType": "wrapper.application", "includeInIndex": 0, "path": "HearthstoneTracker.app", "sourceTree": "BUILT_PRODUCTS_DIR"}

    children_ids = [file_ref_ids[sf] for sf in swift_files] + [info_plist_id, product_ref_id]
    objects[src_group_id] = {"isa": "PBXGroup", "children": children_ids, "path": "HearthstoneTracker-iOS", "sourceTree": "<group>"}
    objects[root_group_id] = {"isa": "PBXGroup", "children": [src_group_id], "sourceTree": "<group>"}

    objects[sources_phase_id] = {"isa": "PBXSourcesBuildPhase", "buildActionMask": "2147483647", "files": source_file_refs, "runOnlyForDeploymentPostprocessing": 0}
    objects[resources_phase_id] = {"isa": "PBXResourcesBuildPhase", "buildActionMask": "2147483647", "files": [], "runOnlyForDeploymentPostprocessing": 0}

    objects[target_id] = {
        "isa": "PBXNativeTarget",
        "buildConfigurationList": t_config_list_id,
        "buildPhases": [sources_phase_id, resources_phase_id],
        "buildRules": [],
        "dependencies": [],
        "name": "HearthstoneTracker",
        "productName": "HearthstoneTracker",
        "productReference": product_ref_id,
        "productType": "com.apple.product-type.application"
    }

    # Project-level settings
    proj_settings = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_MODULES": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "SDKROOT": "iphoneos",
        "SUPPORTED_PLATFORMS": "iphonesimulator iphoneos",
        "TARGETED_DEVICE_FAMILY": "1,2",
        "SWIFT_VERSION": "5.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.hearthstonetracker.ios",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
        "INFOPLIST_FILE": "HearthstoneTracker-iOS/Info.plist",
        "CODE_SIGN_STYLE": "Automatic",
        "CODE_SIGN_IDENTITY": "Apple Development",
        "CODE_SIGNING_REQUIRED": "NO",
        "CODE_SIGNING_ALLOWED": "NO"
    }
    
    p_debug = dict(proj_settings)
    p_debug["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
    
    objects[debug_config_id] = {"isa": "XCBuildConfiguration", "buildSettings": p_debug, "name": "Debug"}
    objects[release_config_id] = {"isa": "XCBuildConfiguration", "buildSettings": proj_settings, "name": "Release"}

    # Target-level settings
    target_settings = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CODE_SIGN_IDENTITY": "Apple Development",
        "CODE_SIGNING_REQUIRED": "NO",
        "CODE_SIGNING_ALLOWED": "NO",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "HearthstoneTracker-iOS/Info.plist",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
        "MARKETING_VERSION": "1.0.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.hearthstonetracker.ios",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SDKROOT": "iphoneos",
        "SUPPORTED_PLATFORMS": "iphonesimulator iphoneos",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1,2"
    }
    
    t_debug = dict(target_settings)
    t_debug["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
    
    objects[t_debug_config_id] = {"isa": "XCBuildConfiguration", "buildSettings": t_debug, "name": "Debug"}
    objects[t_release_config_id] = {"isa": "XCBuildConfiguration", "buildSettings": target_settings, "name": "Release"}

    objects[config_list_id] = {"isa": "XCConfigurationList", "buildConfigurations": [debug_config_id, release_config_id], "defaultConfigurationIsVisible": 0, "defaultConfigurationName": "Release"}
    objects[t_config_list_id] = {"isa": "XCConfigurationList", "buildConfigurations": [t_debug_config_id, t_release_config_id], "defaultConfigurationIsVisible": 0, "defaultConfigurationName": "Release"}

    objects[project_id] = {
        "isa": "PBXProject",
        "attributes": {"BuildIndependentTargetsInParallel": 1, "LastSwiftUpdateCheck": 2605, "LastUpgradeCheck": 2605},
        "buildConfigurationList": config_list_id,
        "compatibilityVersion": "Xcode 14.0",
        "developmentRegion": "zh-Hans",
        "hasScannedForEncodings": 0,
        "knownRegions": ["zh-Hans", "en", "Base"],
        "mainGroup": root_group_id,
        "productRefGroup": src_group_id,
        "projectDirPath": "",
        "projectRoot": "",
        "targets": [target_id]
    }

    pbxproj = {
        "archiveVersion": "1",
        "classes": {},
        "objectVersion": "56",
        "objects": objects,
        "rootObject": project_id
    }

    if os.path.exists(XCODE_PROJ_DIR):
        shutil.rmtree(XCODE_PROJ_DIR)
    os.makedirs(XCODE_PROJ_DIR, exist_ok=True)
    
    outpath = os.path.join(XCODE_PROJ_DIR, "project.pbxproj")
    with open(outpath, 'w') as f:
        json.dump(pbxproj, f, indent=2, ensure_ascii=False)
    
    print(f"✅ Generated JSON pbxproj: {outpath}")
    print(f"   {len(swift_files)} Swift files")

if __name__ == "__main__":
    generate()
