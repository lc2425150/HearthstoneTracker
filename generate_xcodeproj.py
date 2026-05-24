#!/usr/bin/env python3
"""Generate HearthstoneTracker.xcodeproj for Xcode incremental builds."""
import os, json

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_NAME = "HearthstoneTracker"
XCODE_PATH = "/Volumes/T7/Applications/Xcode.app/Contents/Developer"

def gen_pbxproj():
    sources = []
    for root, dirs, files in os.walk(os.path.join(PROJECT_DIR, "Sources")):
        dirs.sort()
        for f in sorted(files):
            if f.endswith(".swift"):
                full = os.path.join(root, f)
                rel = os.path.relpath(full, PROJECT_DIR)
                sources.append(rel)
    
    # Simple xcodeproj generation
    project = f"""// !$*UTF8*$!
{{archiveVersion = 1; classes = {{}}; objectVersion = 56; objects = {{

/* Begin PBXBuildFile section */
"""
    build_files = ""
    file_refs = ""
    sources_build = ""
    
    for i, src in enumerate(sources):
        uuid = f"DEADBEEF{i:04X}"
        build_files += f'\t\t{uuid} /* {src} in Sources */ = {{isa = PBXBuildFile; fileRef = DEADCODE{i:04X}; }};\n'
        file_refs += f'\t\tDEADCODE{i:04X} /* {src} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {src}; sourceTree = "<group>"; }};\n'
        sources_build += f'\t\t\t\t{uuid},\n'
    
    build_config = f"""\t\tBABABABAAAAA /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = Sources/Resources/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "炉石记牌器";
\t\t\t\tINFOPLIST_KEY_LSUIElement = NO;
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tMARKETING_VERSION = 1.0.2;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.hearthstonetracker.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1,2;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
"""
    
    return f"""// !$*UTF8*$!
{{archiveVersion = 1; classes = {{}}; objectVersion = 56; objects = {{
{build_files}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_refs}
/* End PBXFileReference section */

/* Begin PBXGroup section */
\t\tCHILD00000001 = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{"".join(f'\t\t\t\tDEADCODE{i:04X},\n' for i in range(len(sources)))}
\t\t\t);
\t\t\tpath = Sources;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\tCHILD00000002 = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tCHILD00000001,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\tTARGET00000001 = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = TARGETCONFIG0001;
\t\t\tbuildPhases = (
\t\t\t\tPHASE00000001,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = {PROJECT_NAME};
\t\t\tproductName = {PROJECT_NAME};
\t\t\tproductReference = PRODUCTREF0001;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\tPROJECT000001 = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{}};
\t\t\tbuildConfigurationList = PROJCONFIG0001;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = "zh-Hans";
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\t"zh-Hans",
\t\t\t);
\t\t\tmainGroup = CHILD00000002;
\t\t\tproductRefGroup = CHILD00000002;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\tTARGET00000001,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
\t\tPHASE00000001 = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{sources_build}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
{build_config}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\tPROJCONFIG0001 = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\tBABABABAAAAA,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Debug;
\t\t}};
\t\tTARGETCONFIG0001 = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\tBABABABAAAAA,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Debug;
\t\t}};
/* End XCConfigurationList section */
}};
"""

if __name__ == "__main__":
    xcodeproj_dir = os.path.join(PROJECT_DIR, f"{PROJECT_NAME}.xcodeproj")
    os.makedirs(xcodeproj_dir, exist_ok=True)
    pbxproj_path = os.path.join(xcodeproj_dir, "project.pbxproj")
    with open(pbxproj_path, "w") as f:
        f.write(gen_pbxproj())
    print(f"✅ Generated {pbxproj_path}")
    print(f"   Found {len([f for f in os.listdir(os.path.join(PROJECT_DIR,'Sources')) if os.path.isfile(os.path.join(PROJECT_DIR,'Sources',f)) or os.path.isdir(os.path.join(PROJECT_DIR,'Sources',f))])} source files")
