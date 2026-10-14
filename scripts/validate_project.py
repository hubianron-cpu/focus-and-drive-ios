#!/usr/bin/env python3
"""Portable file/XML consistency check. Does not compile or test iOS behavior."""
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
project = (root / "FocusDrive.xcodeproj/project.pbxproj").read_text()
objects = set(re.findall(r"^([0-9A-F]{24}) =", project, re.M))
references = set(re.findall(r"\b[0-9A-F]{24}\b", project))
assert objects == references, "Unresolved project object reference"
# Follow build-phase references instead of treating every PBXBuildFile as Swift.
entries = dict(re.findall(r"^([0-9A-F]{24}) = \{ (.*) \};$", project, re.M))
def phase_files(isa):
    phases = [entry for entry in entries.values() if f"isa = {isa};" in entry]
    assert len(phases) == 1, f"Expected one {isa}"
    build_ids = re.search(r"files = \(([^)]*)\);", phases[0]).group(1)
    paths = []
    for build_id in re.findall(r"[0-9A-F]{24}", build_ids):
        file_id = re.search(r"fileRef = ([0-9A-F]{24});", entries[build_id]).group(1)
        path = re.search(r"path = ([^;]+);", entries[file_id]).group(1)
        assert (root / "FocusDrive" / path).is_file(), f"Missing build input: {path}"
        paths.append(path)
    assert len(paths) == len(set(paths)), "Duplicate build input"
    return set(paths)

sources = {p.name for p in (root / "FocusDrive").glob("*.swift")}
assert sources == phase_files("PBXSourcesBuildPhase"), "Source build membership mismatch"
source_count = len(sources)
assert phase_files("PBXResourcesBuildPhase") == {"PrivacyInfo.xcprivacy"}
privacy = plistlib.loads((root / "FocusDrive/PrivacyInfo.xcprivacy").read_bytes())
assert privacy["NSPrivacyTracking"] is False
assert privacy["NSPrivacyTrackingDomains"] == []
assert privacy["NSPrivacyCollectedDataTypes"] == []
assert privacy["NSPrivacyAccessedAPITypes"] == [{
    "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
    "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
}]
entitlements = plistlib.loads((root / "FocusDrive/FocusDrive.entitlements").read_bytes())
assert entitlements == {"com.apple.developer.family-controls": True}
scheme = ET.parse(root / "FocusDrive.xcodeproj/xcshareddata/xcschemes/FocusDrive.xcscheme")
targets = re.findall(r"^([0-9A-F]{24}) = \{ isa = PBXNativeTarget;", project, re.M)
assert len(targets) == 1
for buildable in scheme.findall(".//BuildableReference"):
    assert buildable.attrib["BlueprintIdentifier"] == targets[0]
    assert buildable.attrib["ReferencedContainer"] == "container:FocusDrive.xcodeproj"
assert "IPHONEOS_DEPLOYMENT_TARGET = 16.0" in project
assert "CODE_SIGN_ENTITLEMENTS = FocusDrive/FocusDrive.entitlements" in project
assert "developmentRegion = he" in project
print(f"PASS: {len(objects)} project objects, {source_count} source files, scheme references, privacy resource and entitlement XML.")
print("NOT RUN: Apple SDK compilation, signing, iPhone UI, authorization and shielding.")
