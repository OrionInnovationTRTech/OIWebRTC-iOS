#!/bin/sh

#  Script.sh
#
#
#  Created by bmaden on 5.08.2022.
#


# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White


# Reset
Color_Off='\033[0m'       # Text Reset


#Debug/Prod

DEBUG="${DEBUG:-false}"

# Branch

BRANCH="${BRANCH:-master}"

## Example usage: MACOS=true IOS=true BUILD_VP9=true sh build.sh


#Platforms

IOS="${IOS:-false}"
MACOS="${IOS:-false}"
MAC_CATALYST="${MAC_CATALYST:-false}"
RELEASE_NOTE="Test"

OUTPUT_DIR="./out"
XCFRAMEWORK_DIR="out/WebRTC.xcframework"
COMMON_GN_ARGS="is_debug=${DEBUG} is_component_build=false rtc_include_tests=false rtc_enable_objc_symbol_export=true enable_stripping=true enable_dsyms=false use_lld=true rtc_libvpx_build_vp9=true"
PLISTBUDDY_EXEC="/usr/libexec/PlistBuddy" # Can be store in opt dir instead of usr in M1



createGitHubRelease(){
cd ..
    git status
    if [ "$(git status --porcelain)" ]; then
    echo "There are uncommited files"
    echo "Enter Commit Message"
    read commitMessage
    git add .
    git commit -m "$commitMessage"
    git tag v3.0.2 -m "$RELEASE_NOTE" || echo "the tag already exists"
    git push origin v3.0.2
    gh release create v3.0.2

    else
    git add .
    git commit -m "No Changes"
    git push origin
    fi

}
build_iOS() {
    local arch=$1
    local environment=$2
    local gen_dir="${OUTPUT_DIR}/ios-${arch}-${environment}"
    local gen_args="${COMMON_GN_ARGS} target_cpu=\"${arch}\" target_os=\"ios\" target_environment=\"${environment}\" ios_deployment_target=\"12.0\" ios_enable_code_signing=false"
    gn gen "${gen_dir}" --args="${gen_args}"
    ninja -C "${gen_dir}" framework_objc || exit 1
}

build_macOS() {
    local arch=$1
    local gen_dir="${OUTPUT_DIR}/macos-${arch}"
    local gen_args="${COMMON_GN_ARGS} target_cpu=\"${arch}\" target_os=\"mac\""
    gn gen "${gen_dir}" --args="${gen_args}"
    ninja -C "${gen_dir}" mac_framework_objc || exit 1
}

# Catalyst builds are not working properly yet.
# See: https://groups.google.com/g/discuss-webrtc/c/VZXS4V4mSY4
build_catalyst() {
    local arch=$1
    local gen_dir="${OUTPUT_DIR}/catalyst-${arch}"
    local gen_args="${COMMON_GN_ARGS} target_cpu=\"${arch}\" target_environment=\"catalyst\" target_os=\"ios\" ios_deployment_target=\"14.0\" ios_enable_code_signing=false"
    gn gen "${gen_dir}" --args="${gen_args}"
    ninja -C "${gen_dir}" framework_objc || exit 1
}

plist_add_library() {
    local index=$1
    local identifier=$2
    local platform=$3
    local platform_variant=$4
    "$PLISTBUDDY_EXEC" -c "Add :AvailableLibraries: dict"  "${INFO_PLIST}"
    "$PLISTBUDDY_EXEC" -c "Add :AvailableLibraries:${index}:LibraryIdentifier string ${identifier}"  "${INFO_PLIST}"
    "$PLISTBUDDY_EXEC" -c "Add :AvailableLibraries:${index}:LibraryPath string WebRTC.framework"  "${INFO_PLIST}"
    "$PLISTBUDDY_EXEC" -c "Add :AvailableLibraries:${index}:SupportedArchitectures array"  "${INFO_PLIST}"
    "$PLISTBUDDY_EXEC" -c "Add :AvailableLibraries:${index}:SupportedPlatform string ${platform}"  "${INFO_PLIST}"
    if [ ! -z "$platform_variant" ]; then
    "$PLISTBUDDY_EXEC" -c "Add :AvailableLibraries:${index}:SupportedPlatformVariant string ${platform_variant}" "${INFO_PLIST}"
    fi
}

plist_add_architecture() {
    local index=$1
    local arch=$2
    "$PLISTBUDDY_EXEC" -c "Add :AvailableLibraries:${index}:SupportedArchitectures: string ${arch}"  "${INFO_PLIST}"
}




# Step 1 : Install depot_tools or update if already exists

if [ ! -d depot_tools ]; then

printf "${Yellow} depot_tools not found, Cloning... ${Color_Off}"

git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git

else

printf "${Green} depot_tools found , so Pulling from remote  ${Color_Off}"
cd depot_tools
git pull origin main
cd ..
fi
export PATH=$(pwd)/depot_tools:$PATH

# Step 2 : Build WebRTC
if [ ! -d src ]; then
printf "${Yellow} Downloading WebRTC Source Code... ${Color_Off}"
fetch --nohooks webrtc_ios
fi
cd src
printf "${Yellow} Fetching All Branches...${Color_Off}"
git fetch --all
printf "${Yellow} Checkout Requested Branch... ${Color_Off}"
git checkout $BRANCH
cd ..
printf "${Yellow} gclient Syncing... ${Color_Off}"
gclient sync --with_branch_heads --with_tags
cd src



# Step 3 : Compile Requested Platforms

rm -rf $OUTPUT_DIR

if [ "$IOS" = true ]; then
printf "${Yellow} Building iOS Architectures ... ${Color_Off}"

build_iOS "x64" "simulator"
build_iOS "arm64" "simulator"
build_iOS "arm64" "device"
fi

if [ "$MACOS" = true ]; then
printf "${Yellow} Building MacOS Architectures ... ${Color_Off}"

build_macOS "x64"
build_macOS "arm64"
fi

if [ "$MAC_CATALYST" = true ]; then
printf "${Yellow} Building MacCataltys Architectures ... ${Color_Off}"

build_catalyst "x64"
build_catalyst "arm64"
fi



# Step 4 : Create XCFramework


INFO_PLIST="${XCFRAMEWORK_DIR}/Info.plist"
rm -rf "${XCFRAMEWORK_DIR}"
mkdir "${XCFRAMEWORK_DIR}"
"$PLISTBUDDY_EXEC" -c "Add :CFBundlePackageType string XFWK"  "${INFO_PLIST}"
"$PLISTBUDDY_EXEC" -c "Add :XCFrameworkFormatVersion string 1.0"  "${INFO_PLIST}"
"$PLISTBUDDY_EXEC" -c "Add :AvailableLibraries array" "${INFO_PLIST}"

LIB_COUNT=0
if [[ "$IOS" = true ]]; then

IOS_LIB_IDENTIFIER="ios-arm64"
IOS_SIM_LIB_IDENTIFIER="ios-x86_64_arm64-simulator"

mkdir "${XCFRAMEWORK_DIR}/${IOS_LIB_IDENTIFIER}"
mkdir "${XCFRAMEWORK_DIR}/${IOS_SIM_LIB_IDENTIFIER}"
LIB_IOS_INDEX=0
LIB_IOS_SIMULATOR_INDEX=1
plist_add_library $LIB_IOS_INDEX $IOS_LIB_IDENTIFIER "ios"
plist_add_library $LIB_IOS_SIMULATOR_INDEX $IOS_SIM_LIB_IDENTIFIER "ios" "simulator"

cp -r out/ios-arm64-device/WebRTC.framework "${XCFRAMEWORK_DIR}/${IOS_LIB_IDENTIFIER}"
cp -r out/ios-x64-simulator/WebRTC.framework "${XCFRAMEWORK_DIR}/${IOS_SIM_LIB_IDENTIFIER}"

LIPO_IOS_FLAGS="out/ios-arm64-device/WebRTC.framework/WebRTC"
LIPO_IOS_SIM_FLAGS="out/ios-x64-simulator/WebRTC.framework/WebRTC out/ios-arm64-simulator/WebRTC.framework/WebRTC"

plist_add_architecture $LIB_IOS_INDEX "arm64"
plist_add_architecture $LIB_IOS_SIMULATOR_INDEX "arm64"
plist_add_architecture $LIB_IOS_SIMULATOR_INDEX "x86_64"

lipo -create -output  "${XCFRAMEWORK_DIR}/${IOS_LIB_IDENTIFIER}/WebRTC.framework/WebRTC" ${LIPO_IOS_FLAGS}
lipo -create -output "${XCFRAMEWORK_DIR}/${IOS_SIM_LIB_IDENTIFIER}/WebRTC.framework/WebRTC" ${LIPO_IOS_SIM_FLAGS}

LIB_COUNT=$((LIB_COUNT+2))
fi

if [ "$MACOS" = true ]; then

MAC_LIB_IDENTIFIER="macos-x86_64_arm64"

mkdir "${XCFRAMEWORK_DIR}/${MAC_LIB_IDENTIFIER}"
plist_add_library $LIB_COUNT "${MAC_LIB_IDENTIFIER}" "macos"
plist_add_architecture $LIB_COUNT "x86_64"
plist_add_architecture $LIB_COUNT "arm64"

cp -RP out/macos-x64/WebRTC.framework "${XCFRAMEWORK_DIR}/${MAC_LIB_IDENTIFIER}"
lipo -create -output "${XCFRAMEWORK_DIR}/${MAC_LIB_IDENTIFIER}/WebRTC.framework/Versions/A/WebRTC" out/macos-x64/WebRTC.framework/WebRTC out/macos-arm64/WebRTC.framework/WebRTC
LIB_COUNT=$((LIB_COUNT+1))
fi

if [ "$MAC_CATALYST" = true ]; then

CATALYST_LIB_IDENTIFIER="ios-x86_64_arm64-maccatalyst"

mkdir "${XCFRAMEWORK_DIR}/${CATALYST_LIB_IDENTIFIER}"
plist_add_library $LIB_COUNT "${CATALYST_LIB_IDENTIFIER}" "ios" "maccatalyst"
plist_add_architecture $LIB_COUNT "x86_64"
plist_add_architecture $LIB_COUNT "arm64"

cp -RP out/catalyst-x64/WebRTC.framework "${XCFRAMEWORK_DIR}/${CATALYST_LIB_IDENTIFIER}"
lipo -create -output "${XCFRAMEWORK_DIR}/${CATALYST_LIB_IDENTIFIER}/WebRTC.framework/WebRTC" out/catalyst-x64/WebRTC.framework/WebRTC out/catalyst-arm64/WebRTC.framework/WebRTC
LIB_COUNT=$((LIB_COUNT+1))
fi


# Step 6 - Add license file to the framework
cp LICENSE ${XCFRAMEWORK_DIR}

# Step 7 - archive the framework
cd out
NOW=$(date -u +"%Y-%m-%dT%H-%M-%S")
OUTPUT_NAME=WebRTC-$NOW.xcframework.zip
zip --symlinks -r $OUTPUT_NAME WebRTC.xcframework/

# Step 8 calculate SHA256 checksum
CHECKSUM=$(shasum -a 256 $OUTPUT_NAME | awk '{ print $1 }')
COMMIT_HASH=$(git rev-parse HEAD)

echo "{ \"file\": \"${OUTPUT_NAME}\", \"checksum\": \"${CHECKSUM}\", \"commit\": \"${COMMIT_HASH}\", \"branch\": \"${BRANCH}\" }" > metadata.json
cat metadata.json
createGitHubRelease








