def parse_yarn_lock(content):
    packages = []
    package_lines = []
    for line in content.split("\n"):
        if line.startswith("#"):
            continue
        if line == "":
            if len(package_lines) > 0:
                packages.append(_parse_package(package_lines))
                package_lines = []
            continue
        package_lines.append(line)
    if len(package_lines) > 0:
        packages.append(_parse_package(package_lines))

    return packages

def _parse_package(lines):
    package = dict(
        name = _package_name(lines[0]),
    )
    for line in lines[1:]:
        if line.startswith('  version "'):
            package["version"] = line[len('  version "'):-1]
            # package["filename"] = _yarn_lock_filename(current)
        elif line.startswith('  resolved "'):
            resolved = line[len('  resolved "'):-1]
            if '#' in resolved:
                resolved = resolved[:resolved.index('#')]
            package["resolved"] = resolved
        elif line.startswith('  integrity '):
            integrity = line[len('  integrity '):]
            if integrity.startswith('"'):
                for item in integrity.strip('"').split(' '):
                    if item.startswith("sha512-"):
                        package["integrity"] = item
                        break
            elif integrity.startswith('sha512-'):
                package["integrity"] = integrity

    return package

def _package_name(line):
    start = 0
    if line.startswith('"'):
        start = 1
    terminus = line.index("@", start + 1)
    return line[start:terminus]
