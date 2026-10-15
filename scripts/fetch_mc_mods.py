"""Fetch the Minecraft-side mods into place for the GitHub Actions build.

  fabric-api.jar  required; the version pinned in mc/gradle.properties so the mod
                  and the API always ship together (falls back to the newest for
                  this Minecraft version)
  optional/       mods the passthrough does not need but that help it: Sodium
                  (newest stable, no alphas) raises Minecraft's frame rate, and a
                  Minecraft frame that lags GTA by several frames is what smears
                  blocks when the camera moves fast

Only the Modrinth API is used; nothing from the user's install.
"""
import json
import os
import urllib.parse
import urllib.request

MC_VERSION = "26.3"
UA = {"User-Agent": "mc-in-gta/ci (build script)"}


def prop(name: str) -> str:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(root, "mc", "gradle.properties"), encoding="utf-8") as fh:
        for line in fh:
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip()
    raise SystemExit(f"{name} not found in mc/gradle.properties")


def versions(project: str) -> list:
    query = urllib.parse.urlencode(
        {"game_versions": json.dumps([MC_VERSION]), "loaders": json.dumps(["fabric"])}
    )
    url = f"https://api.modrinth.com/v2/project/{project}/version?{query}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as resp:
        vs = json.load(resp)
    if not vs:
        raise SystemExit(f"Modrinth has no {project} for Minecraft {MC_VERSION}")
    return vs


def download(url: str, path: str) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as resp, open(path, "wb") as out:
        out.write(resp.read())


def fetch_fabric_api() -> None:
    want = prop("fabric_api_version")
    pick = next((v for v in versions("fabric-api") if v["version_number"] == want), versions("fabric-api")[0])
    if pick["version_number"] != want:
        print(f"warning: {want} not on Modrinth, using {pick['version_number']}")
    f = pick["files"][0]
    print(f"Fabric API {f['filename']} <- {f['url']}")
    download(f["url"], "fabric-api.jar")


def fetch_optional() -> None:
    stable = [
        v
        for v in versions("sodium")
        if "alpha" not in v["version_number"].lower()
        and "beta" not in v["version_number"].lower()
    ]
    if not stable:
        print("warning: no stable Sodium for this version; skipping the optional mod")
        return
    f = stable[0]["files"][0]
    print(f"Sodium {f['filename']} <- {f['url']}")
    download(f["url"], os.path.join("optional", f["filename"]))


def main() -> None:
    fetch_fabric_api()
    fetch_optional()
    for root, _dirs, files in os.walk("."):
        if "optional" in root or root == ".":
            for name in sorted(files):
                if name.endswith(".jar"):
                    print(f"  {os.path.join(root, name)}  {os.path.getsize(os.path.join(root, name)) / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
