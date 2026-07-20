#!/usr/bin/env python3
"""Idempotently link Poing's generated local Swift package into an Xcode project."""

import argparse
from pathlib import Path


LOCAL_REF = "AD0000000000000000000001"
PRODUCT_DEP = "AD0000000000000000000002"
BUILD_FILE = "AD0000000000000000000003"


def replace_required(content, needle, replacement):
    if needle not in content:
        raise SystemExit(f"AdMob Xcode patch anchor missing: {needle}")
    return content.replace(needle, replacement, 1)


def patch(path):
    content = path.read_text(encoding="utf-8")
    if LOCAL_REF in content:
        print("AdMob Swift package already linked")
        return

    if "/* Begin XCLocalSwiftPackageReference section */" not in content:
        content = replace_required(
            content,
            "/* End PBXGroup section */",
            "/* End PBXGroup section */\n\n"
            "/* Begin XCLocalSwiftPackageReference section */\n"
            "/* End XCLocalSwiftPackageReference section */",
        )
    if "/* Begin XCSwiftPackageProductDependency section */" not in content:
        content = replace_required(
            content,
            "/* End XCLocalSwiftPackageReference section */",
            "/* End XCLocalSwiftPackageReference section */\n\n"
            "/* Begin XCSwiftPackageProductDependency section */\n"
            "/* End XCSwiftPackageProductDependency section */",
        )

    local_ref_def = (
        f'\t\t{LOCAL_REF} /* XCLocalSwiftPackageReference "." */ = {{\n'
        "\t\t\tisa = XCLocalSwiftPackageReference;\n"
        '\t\t\trelativePath = ".";\n'
        "\t\t};\n"
    )
    content = replace_required(
        content,
        "/* End XCLocalSwiftPackageReference section */",
        local_ref_def + "/* End XCLocalSwiftPackageReference section */",
    )

    product_dep_def = (
        f"\t\t{PRODUCT_DEP} /* PoingGodotAdMobDeps */ = {{\n"
        "\t\t\tisa = XCSwiftPackageProductDependency;\n"
        f'\t\t\tpackage = {LOCAL_REF} /* XCLocalSwiftPackageReference "." */;\n'
        '\t\t\tproductName = "PoingGodotAdMobDeps";\n'
        "\t\t};\n"
    )
    content = replace_required(
        content,
        "/* End XCSwiftPackageProductDependency section */",
        product_dep_def + "/* End XCSwiftPackageProductDependency section */",
    )

    build_file_def = (
        f"\t\t{BUILD_FILE} /* PoingGodotAdMobDeps in Frameworks */ = "
        f"{{isa = PBXBuildFile; productRef = {PRODUCT_DEP} /* PoingGodotAdMobDeps */; }};\n"
    )
    content = replace_required(
        content,
        "/* Begin PBXBuildFile section */",
        "/* Begin PBXBuildFile section */\n" + build_file_def,
    )

    if "packageReferences = (" in content:
        content = content.replace(
            "packageReferences = (",
            f'packageReferences = (\n\t\t\t\t{LOCAL_REF} /* XCLocalSwiftPackageReference "." */,',
            1,
        )
    else:
        content = replace_required(
            content,
            "productRefGroup =",
            "packageReferences = (\n"
            f'\t\t\t\t{LOCAL_REF} /* XCLocalSwiftPackageReference "." */,\n'
            "\t\t\t);\n\t\t\tproductRefGroup =",
        )

    if "packageProductDependencies = (" in content:
        content = content.replace(
            "packageProductDependencies = (",
            f"packageProductDependencies = (\n\t\t\t\t{PRODUCT_DEP} /* PoingGodotAdMobDeps */,",
            1,
        )
    else:
        content = replace_required(
            content,
            "buildRules = (",
            "packageProductDependencies = (\n"
            f"\t\t\t\t{PRODUCT_DEP} /* PoingGodotAdMobDeps */,\n"
            "\t\t\t);\n\t\t\tbuildRules = (",
        )

    frameworks_start = content.find("isa = PBXFrameworksBuildPhase;")
    if frameworks_start < 0:
        raise SystemExit("AdMob Xcode patch could not find PBXFrameworksBuildPhase")
    files_start = content.find("files = (", frameworks_start)
    if files_start < 0:
        raise SystemExit("AdMob Xcode patch could not find framework files list")
    insert_at = files_start + len("files = (")
    content = (
        content[:insert_at]
        + f"\n\t\t\t\t{BUILD_FILE} /* PoingGodotAdMobDeps in Frameworks */,"
        + content[insert_at:]
    )

    path.write_text(content, encoding="utf-8")
    print(f"AdMob Swift package linked: {path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("pbxproj", type=Path)
    args = parser.parse_args()
    if not args.pbxproj.is_file():
        raise SystemExit(f"Xcode project file missing: {args.pbxproj}")
    patch(args.pbxproj)


if __name__ == "__main__":
    main()
