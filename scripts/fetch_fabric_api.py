"""Fetch the Fabric API jar for the same Minecraft version and drop it as fabric-api.jar.

The version comes from mc/gradle.properties (fabric_api_version) so the mod and the API
always ship together. Only used by the GitHub Actions build; the jar lands next to the
repo root as fabric-api.jar.
"""
import json
import os
import urllib.parse
import urllib.request

MC_VERSION = "26.3"


def prop(name: str) -> str:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(root, "mc", "gradle.properties"), encoding="utf-8") as fh:
        for line in fh:
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip()
    raise SystemExit(f"{name} not found in mc/gradle.properties")


def main() -> None:
    want = prop("fabric_api_version")
    query = urllib.parse.urlencode(
        {"game_versions": json.dumps([MC_VERSION]), "loaders": json.dumps(["fabric"])}
    )
    url = f"https://api.modrinth.com/v2/project/fabric-api/version?{query}"
    req = urllib.request.Request(url, headers={"User-Agent": "mc-in-gta/ci (build script)"})
    with urllib.request.urlopen(req) as resp:
        versions = json.load(resp)
    if not versions:
        raise SystemExit(f"Modrinth has no Fabric API for Minecraft {MC_VERSION}")
    pick = next((v for v in versions if v["version_number"] == want), versions[0])
    if pick["version_number"] != want:
        print(f"warning: {want} not on Modrinth, using {pick['version_number']}")
    f = pick["files"][0]
    print(f"Fabric API {f['filename']} <- {f['url']}")
    req = urllib.request.Request(f["url"], headers={"User-Agent": "mc-in-gta/ci (build script)"})
    with urllib.request.urlopen(req) as resp, open("fabric-api.jar", "wb") as out:
        out.write(resp.read())


if __name__ == "__main__":
    main()
