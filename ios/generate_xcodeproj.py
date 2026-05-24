#!/usr/bin/env python3
"""
Generate a minimal Xcode project for HearthstoneTracker iOS app.
"""
import os
import uuid
import plistlib
import json

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(PROJECT_DIR, "HearthstoneTracker-iOS")
PROJECT_FILE = os.path.join(PROJECT_DIR, "HearthstoneTracker.xcodeproj", "project.pbxproj")

def uid():
    return uuid.uuid4().hex.upper()[:24]

def collect_files(base_dir, subdir=""):
    """Collect all Swift files and resource files."""
    swift_files = []
    resource_files = []
    info_plist = None
    
    target_dir = os.path.join(base_dir, subdir) if subdir else base_dir
    for root, dirs, files in os.walk(target_dir):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, PROJECT_DIR)
            if f.endswith(".swift"):
                swift_files.append(rel)
            elif f == "Info.plist":
                info_plist = rel
            elif f.endswith(".json") or f.endswith(".png"):
                resource_files.append(rel)
    
    return swift_files, resource_files, info_plist

def build_project():
    swift_files, resource_files, info_plist = collect_files(SRC_DIR)
    
    # Generate all UUIDs
    file_refs = {}
    build_files = {}
    source_file_refs = []
    
    for sf in swift_files:
        fid = uid()
        file_refs[sf] = fid
        bfid = uid()
        build_files[sf] = bfid
        source_file_refs.append(bfid)
    
    # Project structure
    root_group_id = uid()
    src_group_id = uid()
    product_group_id = uid()
    main_group_id = uid()
    
    target_id = uid()
    product_ref_id = uid()
    
    sources_phase_id = uid()
    resources_phase_id = uid()
    
    debug_config_id = uid()
    release_config_id = uid()
    config_list_id = uid()
    target_debug_config_id = uid()
    target_release_config_id = uid()
    target_config_list_id = uid()
    
    project_id = uid()
    
    # Build PBXBuildFile entries
    pbx_build_file = {}
    for sf in swift_files:
        pbx_build_file[build_files[sf]] = {
            "isa": "PBXBuildFile",
            "fileRef": file_refs[sf],
        }
    
    # Build PBXFileReference entries
    pbx_file_ref = {}
    for sf in swift_files:
        pbx_file_ref[file_refs[sf]] = {
            "isa": "PBXFileReference",
            "lastKnownFileType": "sourcecode.swift",
            "path": os.path.relpath(os.path.join(PROJECT_DIR, sf), SRC_DIR),
            "sourceTree": "<group>",
        }
    # Add Info.plist ref
    info_plist_id = uid()
    pbx_file_ref[info_plist_id] = {
        "isa": "PBXFileReference",
        "lastKnownFileType": "text.plist.xml",
        "path": "Info.plist",
        "sourceTree": "<group>",
    }
    # Product ref
    pbx_file_ref[product_ref_id] = {
        "isa": "PBXFileReference",
        "explicitFileType": "wrapper.application",
        "includeInIndex": 0,
        "path": "HearthstoneTracker.app",
        "sourceTree": "BUILT_PRODUCTS_DIR",
    }
    
    # Build PBXGroup entries
    # Main group (source files)
    children = [fid for sf_name, fid in sorted(file_refs.items())]
    children.append(info_plist_id)
    children.sort(key=lambda x: pbx_file_ref.get(x, {}).get("path", ""))
    
    pbx_group = {
        src_group_id: {
            "isa": "PBXGroup",
            "children": children + [product_ref_id],
            "name": "HearthstoneTracker-iOS",
            "sourceTree": "<group>",
        },
        root_group_id: {
            "isa": "PBXGroup",
            "children": [src_group_id],
            "sourceTree": "<group>",
        },
    }
    
    # Build phases
    pbx_sources_phase = {
        sources_phase_id: {
            "isa": "PBXSourcesBuildPhase",
            "buildActionMask": 2147483647,
            "files": source_file_refs,
            "runOnlyForDeploymentPostprocessing": 0,
        }
    }
    
    pbx_resources_phase = {
        resources_phase_id: {
            "isa": "PBXResourcesBuildPhase",
            "buildActionMask": 2147483647,
            "files": [],
            "runOnlyForDeploymentPostprocessing": 0,
        }
    }
    
    # Native target
    pbx_target = {
        target_id: {
            "isa": "PBXNativeTarget",
            "buildConfigurationList": target_config_list_id,
            "buildPhases": [sources_phase_id, resources_phase_id],
            "buildRules": [],
            "dependencies": [],
            "name": "HearthstoneTracker",
            "productName": "HearthstoneTracker",
            "productReference": product_ref_id,
            "productType": "com.apple.product-type.application",
        }
    }
    
    # Build configurations
    pbx_build_config = {
        debug_config_id: {
            "isa": "XCBuildConfiguration",
            "buildSettings": {
                "ALWAYS_SEARCH_USER_PATHS": "NO",
                "CLANG_ENABLE_MODULES": "YES",
                "INFOPLIST_FILE": "HearthstoneTracker-iOS/Info.plist",
                "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
                "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
                "PRODUCT_BUNDLE_IDENTIFIER": "com.hearthstonetracker.ios",
                "PRODUCT_NAME": "$(TARGET_NAME)",
                "SWIFT_VERSION": "5.0",
                "TARGETED_DEVICE_FAMILY": "1,2",
                "CODE_SIGN_STYLE": "Automatic",
            },
            "name": "Debug",
        },
        release_config_id: {
            "isa": "XCBuildConfiguration",
            "buildSettings": {
                "ALWAYS_SEARCH_USER_PATHS": "NO",
                "CLANG_ENABLE_MODULES": "YES",
                "INFOPLIST_FILE": "HearthstoneTracker-iOS/Info.plist",
                "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
                "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
                "PRODUCT_BUNDLE_IDENTIFIER": "com.hearthstonetracker.ios",
                "PRODUCT_NAME": "$(TARGET_NAME)",
                "SWIFT_VERSION": "5.0",
                "TARGETED_DEVICE_FAMILY": "1,2",
                "CODE_SIGN_STYLE": "Automatic",
            },
            "name": "Release",
        },
        target_debug_config_id: {
            "isa": "XCBuildConfiguration",
            "buildSettings": {
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                "CODE_SIGN_STYLE": "Automatic",
                "CURRENT_PROJECT_VERSION": "1",
                "GENERATE_INFOPLIST_FILE": "NO",
                "INFOPLIST_FILE": "HearthstoneTracker-iOS/Info.plist",
                "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
                "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
                "MARKETING_VERSION": "1.0.0",
                "PRODUCT_BUNDLE_IDENTIFIER": "com.hearthstonetracker.ios",
                "PRODUCT_NAME": "$(TARGET_NAME)",
                "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
                "SWIFT_VERSION": "5.0",
                "TARGETED_DEVICE_FAMILY": "1,2",
            },
            "name": "Debug",
        },
        target_release_config_id: {
            "isa": "XCBuildConfiguration",
            "buildSettings": {
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                "CODE_SIGN_STYLE": "Automatic",
                "CURRENT_PROJECT_VERSION": "1",
                "GENERATE_INFOPLIST_FILE": "NO",
                "INFOPLIST_FILE": "HearthstoneTracker-iOS/Info.plist",
                "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
                "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
                "MARKETING_VERSION": "1.0.0",
                "PRODUCT_BUNDLE_IDENTIFIER": "com.hearthstonetracker.ios",
                "PRODUCT_NAME": "$(TARGET_NAME)",
                "SWIFT_VERSION": "5.0",
                "TARGETED_DEVICE_FAMILY": "1,2",
            },
            "name": "Release",
        },
    }
    
    # Configuration lists
    pbx_config_list = {
        config_list_id: {
            "isa": "XCConfigurationList",
            "buildConfigurations": [debug_config_id, release_config_id],
            "defaultConfigurationIsVisible": 0,
            "defaultConfigurationName": "Release",
        },
        target_config_list_id: {
            "isa": "XCConfigurationList",
            "buildConfigurations": [target_debug_config_id, target_release_config_id],
            "defaultConfigurationIsVisible": 0,
            "defaultConfigurationName": "Release",
        },
    }
    
    # Project
    pbx_project = {
        project_id: {
            "isa": "PBXProject",
            "attributes": {
                "BuildIndependentTargetsInParallel": 1,
                "LastSwiftUpdateCheck": 1600,
                "LastUpgradeCheck": 1600,
            },
            "buildConfigurationList": config_list_id,
            "compatibilityVersion": "Xcode 14.0",
            "developmentRegion": "zh-Hans",
            "hasScannedForEncodings": 0,
            "knownRegions": ["zh-Hans", "en", "Base"],
            "mainGroup": root_group_id,
            "productRefGroup": src_group_id,
            "projectDirPath": "",
            "projectRoot": "",
            "targets": [target_id],
        }
    }
    
    # Combine everything into the pbxproj dictionary
    pbxproj = {
        "archiveVersion": 1,
        "classes": {},
        "objectVersion": 56,
        "objects": {
            **pbx_build_file,
            **pbx_file_ref,
            **pbx_group,
            **pbx_sources_phase,
            **pbx_resources_phase,
            **pbx_target,
            **pbx_build_config,
            **pbx_config_list,
            **pbx_project,
        },
        "rootObject": project_id,
    }
    
    # Write as plist
    os.makedirs(os.path.dirname(PROJECT_FILE), exist_ok=True)
    with open(PROJECT_FILE, "wb") as f:
        plistlib.dump(pbxproj, f)
    
    print(f"✅ Xcode project generated: {PROJECT_FILE}")
    print(f"   - {len(swift_files)} Swift files")
    print(f"   - {len(resource_files)} resource files")

if __name__ == "__main__":
    build_project()
