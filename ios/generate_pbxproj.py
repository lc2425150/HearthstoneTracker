#!/usr/bin/env python3
"""Generate Xcode project.pbxproj in OpenStep ASCII plist format (the format Xcode expects)."""
import os
import uuid

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(PROJECT_DIR, "HearthstoneTracker-iOS")

def uid():
    return uuid.uuid4().hex.upper()[:24]

def q(s):
    """Quote a string for OpenStep plist format."""
    if s is None:
        return ""
    s = str(s)
    if '"' in s or '{' in s or '}' in s or '(' in s or ')' in s or ';' in s or '//' in s or s.startswith('_') or ' ' in s or '=' in s:
        return f'"{s}"'
    return s

def write_pbxproj(filepath, content):
    with open(filepath, 'w') as f:
        f.write(content)

def generate():
    # Collect files
    swift_files = []
    for root, dirs, files in os.walk(SRC_DIR):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, PROJECT_DIR)
            if f.endswith(".swift"):
                swift_files.append(rel)
    swift_files.sort()

    # Generate all UUIDs
    file_refs = {}
    build_files = {}
    for sf in swift_files:
        file_refs[sf] = uid()
        build_files[sf] = uid()
    
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

    lines = [
        '// !$*UTF8*$!',
        '{',
        '\tarchiveVersion = 1;',
        '\tclasses = {',
        '\t};',
        '\tobjectVersion = 56;',
        '\tobjects = {',
    ]

    # PBXBuildFile
    for sf in swift_files:
        basename = os.path.basename(sf)
        fid = file_refs[sf]
        bid = build_files[sf]
        lines.append(f'\t\t{bid} /* {basename} in Sources */ = {{')
        lines.append(f'\t\t\tisa = PBXBuildFile;')
        lines.append(f'\t\t\tfileRef = {fid} /* {basename} */;')
        lines.append(f'\t\t}};')

    # PBXFileReference
    for sf in swift_files:
        basename = os.path.basename(sf)
        fid = file_refs[sf]
        rel = os.path.relpath(os.path.join(PROJECT_DIR, sf), SRC_DIR)
        lines.append(f'\t\t{fid} /* {basename} */ = {{')
        lines.append(f'\t\t\tisa = PBXFileReference;')
        lines.append(f'\t\t\tlastKnownFileType = sourcecode.swift;')
        lines.append(f'\t\t\tpath = {q(rel)};')
        lines.append(f'\t\t\tsourceTree = "<group>";')
        lines.append(f'\t\t}};')

    # Info.plist reference
    lines.append(f'\t\t{info_plist_id} /* Info.plist */ = {{')
    lines.append(f'\t\t\tisa = PBXFileReference;')
    lines.append(f'\t\t\tlastKnownFileType = text.plist.xml;')
    lines.append(f'\t\t\tpath = Info.plist;')
    lines.append(f'\t\t\tsourceTree = "<group>";')
    lines.append(f'\t\t}};')

    # Product reference
    lines.append(f'\t\t{product_ref_id} /* HearthstoneTracker.app */ = {{')
    lines.append(f'\t\t\tisa = PBXFileReference;')
    lines.append(f'\t\t\texplicitFileType = wrapper.application;')
    lines.append(f'\t\t\tincludeInIndex = 0;')
    lines.append(f'\t\t\tpath = HearthstoneTracker.app;')
    lines.append(f'\t\t\tsourceTree = BUILT_PRODUCTS_DIR;')
    lines.append(f'\t\t}};')

    # Source group
    children = [file_refs[sf] for sf in swift_files]
    comments = [os.path.basename(sf) for sf in swift_files]
    all_children = children + [info_plist_id, product_ref_id]
    all_comments = comments + ['Info.plist', 'HearthstoneTracker.app']
    children_str = ',\n\t\t\t\t'.join(f'{c} /* {cm} */' for c, cm in zip(all_children, all_comments))
    
    lines.append(f'\t\t{src_group_id} = {{')
    lines.append(f'\t\t\tisa = PBXGroup;')
    lines.append(f'\t\t\tchildren = (')
    lines.append(f'\t\t\t\t{children_str},')
    lines.append(f'\t\t\t);')
    lines.append(f'\t\t\tpath = HearthstoneTracker-iOS;')
    lines.append(f'\t\t\tsourceTree = "<group>";')
    lines.append(f'\t\t}};')

    # Root group
    lines.append(f'\t\t{root_group_id} = {{')
    lines.append(f'\t\t\tisa = PBXGroup;')
    lines.append(f'\t\t\tchildren = (')
    lines.append(f'\t\t\t\t{src_group_id} /* HearthstoneTracker-iOS */,')
    lines.append(f'\t\t\t);')
    lines.append(f'\t\t\tsourceTree = "<group>";')
    lines.append(f'\t\t}};')

    # Sources phase
    source_files = ',\n\t\t\t\t'.join(f'{build_files[sf]} /* {os.path.basename(sf)} in Sources */' for sf in swift_files)
    lines.append(f'\t\t{sources_phase_id} /* Sources */ = {{')
    lines.append(f'\t\t\tisa = PBXSourcesBuildPhase;')
    lines.append(f'\t\t\tbuildActionMask = 2147483647;')
    lines.append(f'\t\t\tfiles = (')
    lines.append(f'\t\t\t\t{source_files},')
    lines.append(f'\t\t\t);')
    lines.append(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
    lines.append(f'\t\t}};')

    # Resources phase
    lines.append(f'\t\t{resources_phase_id} /* Resources */ = {{')
    lines.append(f'\t\t\tisa = PBXResourcesBuildPhase;')
    lines.append(f'\t\t\tbuildActionMask = 2147483647;')
    lines.append(f'\t\t\tfiles = (')
    lines.append(f'\t\t\t);')
    lines.append(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
    lines.append(f'\t\t}};')

    # Target
    lines.append(f'\t\t{target_id} /* HearthstoneTracker */ = {{')
    lines.append(f'\t\t\tisa = PBXNativeTarget;')
    lines.append(f'\t\t\tbuildConfigurationList = {t_config_list_id} /* Build configuration list for PBXNativeTarget "HearthstoneTracker" */;')
    lines.append(f'\t\t\tbuildPhases = (')
    lines.append(f'\t\t\t\t{sources_phase_id} /* Sources */,')
    lines.append(f'\t\t\t\t{resources_phase_id} /* Resources */,')
    lines.append(f'\t\t\t);')
    lines.append(f'\t\t\tbuildRules = (')
    lines.append(f'\t\t\t);')
    lines.append(f'\t\t\tdependencies = (')
    lines.append(f'\t\t\t);')
    lines.append(f'\t\t\tname = HearthstoneTracker;')
    lines.append(f'\t\t\tproductName = HearthstoneTracker;')
    lines.append(f'\t\t\tproductReference = {product_ref_id} /* HearthstoneTracker.app */;')
    lines.append(f'\t\t\tproductType = "com.apple.product-type.application";')
    lines.append(f'\t\t}};')

    # Build configs - project level
    for pid, pname in [(config_list_id, 'Debug'), (config_list_id, 'Release')]:
        pass  # handled below

    proj_debug = {
        'ALWAYS_SEARCH_USER_PATHS': 'NO',
        'CLANG_ENABLE_MODULES': 'YES',
        'CODE_SIGN_STYLE': 'Automatic',
        'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
        'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks',
        'PRODUCT_BUNDLE_IDENTIFIER': 'com.hearthstonetracker.ios',
        'PRODUCT_NAME': '$(TARGET_NAME)',
        'SWIFT_VERSION': '5.0',
        'TARGETED_DEVICE_FAMILY': '1,2',
    }
    proj_release = dict(proj_debug)
    del proj_release['CODE_SIGN_STYLE']

    target_debug = {
        'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
        'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME': 'AccentColor',
        'CODE_SIGN_STYLE': 'Automatic',
        'CURRENT_PROJECT_VERSION': '1',
        'GENERATE_INFOPLIST_FILE': 'NO',
        'INFOPLIST_FILE': 'HearthstoneTracker-iOS/Info.plist',
        'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
        'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks',
        'MARKETING_VERSION': '1.0.0',
        'PRODUCT_BUNDLE_IDENTIFIER': 'com.hearthstonetracker.ios',
        'PRODUCT_NAME': '$(TARGET_NAME)',
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG',
        'SWIFT_VERSION': '5.0',
        'TARGETED_DEVICE_FAMILY': '1,2',
    }
    target_release = dict(target_debug)
    del target_release['SWIFT_ACTIVE_COMPILATION_CONDITIONS']

    def write_config(cfg_id, cfg_name, settings):
        lines.append(f'\t\t{cfg_id} /* {cfg_name} */ = {{')
        lines.append(f'\t\t\tisa = XCBuildConfiguration;')
        lines.append(f'\t\t\tbuildSettings = {{')
        for k, v in sorted(settings.items()):
            lines.append(f'\t\t\t\t{k} = {q(v)};')
        lines.append(f'\t\t\t}};')
        lines.append(f'\t\t\tname = {q(cfg_name)};')
        lines.append(f'\t\t}};')

    write_config(debug_config_id, 'Debug', proj_debug)
    write_config(release_config_id, 'Release', proj_release)
    write_config(t_debug_config_id, 'Debug', target_debug)
    write_config(t_release_config_id, 'Release', target_release)

    # Config lists
    def write_config_list(cl_id, name, config_ids):
        lines.append(f'\t\t{cl_id} /* {name} */ = {{')
        lines.append(f'\t\t\tisa = XCConfigurationList;')
        lines.append(f'\t\t\tbuildConfigurations = (')
        for cid, cname in config_ids:
            lines.append(f'\t\t\t\t{cid} /* {cname} */,')
        lines.append(f'\t\t\t);')
        lines.append(f'\t\t\tdefaultConfigurationIsVisible = 0;')
        lines.append(f'\t\t\tdefaultConfigurationName = Release;')
        lines.append(f'\t\t}};')

    write_config_list(config_list_id, 'Build configuration list for PBXProject "HearthstoneTracker"',
                      [(debug_config_id, 'Debug'), (release_config_id, 'Release')])
    write_config_list(t_config_list_id, 'Build configuration list for PBXNativeTarget "HearthstoneTracker"',
                      [(t_debug_config_id, 'Debug'), (t_release_config_id, 'Release')])

    # Project
    lines.append(f'\t\t{project_id} /* Project object */ = {{')
    lines.append(f'\t\t\tisa = PBXProject;')
    lines.append(f'\t\t\tattributes = {{')
    lines.append(f'\t\t\t\tBuildIndependentTargetsInParallel = 1;')
    lines.append(f'\t\t\t\tLastSwiftUpdateCheck = 2605;')
    lines.append(f'\t\t\t\tLastUpgradeCheck = 2605;')
    lines.append(f'\t\t\t}};')
    lines.append(f'\t\t\tbuildConfigurationList = {config_list_id} /* Build configuration list for PBXProject "HearthstoneTracker" */;')
    lines.append(f'\t\t\tcompatibilityVersion = "Xcode 14.0";')
    lines.append(f'\t\t\tdevelopmentRegion = "zh-Hans";')
    lines.append(f'\t\t\thasScannedForEncodings = 0;')
    lines.append(f'\t\t\tknownRegions = (')
    lines.append(f'\t\t\t\t"zh-Hans",')
    lines.append(f'\t\t\t\ten,')
    lines.append(f'\t\t\t\tBase,')
    lines.append(f'\t\t\t);')
    lines.append(f'\t\t\tmainGroup = {root_group_id};')
    lines.append(f'\t\t\tproductRefGroup = {src_group_id} /* HearthstoneTracker-iOS */;')
    lines.append(f'\t\t\tprojectDirPath = "";')
    lines.append(f'\t\t\tprojectRoot = "";')
    lines.append(f'\t\t\ttargets = (')
    lines.append(f'\t\t\t\t{target_id} /* HearthstoneTracker */,')
    lines.append(f'\t\t\t);')
    lines.append(f'\t\t}};')

    lines.append('\t};')
    lines.append(f'\trootObject = {project_id} /* Project object */;')
    lines.append('}')

    return '\n'.join(lines)

if __name__ == "__main__":
    content = generate()
    outpath = os.path.join(PROJECT_DIR, "HearthstoneTracker.xcodeproj", "project.pbxproj")
    with open(outpath, 'w') as f:
        f.write(content)
    os.chmod(outpath, 0o644)
    print(f"✅ Generated OpenStep pbxproj: {outpath}")
    print(f"   Lines: {content.count(chr(10))}")
    print(f"   Swift files: {content.count('PBXBuildFile')}")
