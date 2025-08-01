#!/usr/bin/env python3
"""
Clone Packer plugins at pinned commits and pre‑install Mason packages.

Usage inside Dockerfile:
    RUN python3 /tmp/build_nvim_assets.py /tmp/nvim-build.yaml
"""
from __future__ import annotations
import argparse, os, subprocess, sys, yaml, textwrap
from pathlib import Path

# ── helpers ─────────────────────────────────────────────────────────
def sh(cmd: list[str], cwd: Path | None = None):
    print("+", " ".join(cmd))
    subprocess.check_call(cmd, cwd=cwd)

def ensure_dir(p: Path): p.mkdir(parents=True, exist_ok=True)

def have_commit(repo_dir: Path, commit: str) -> bool:
    return subprocess.call(
        ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
        cwd=repo_dir,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ) == 0

def clone_at_commit(url: str, dest: Path, commit: str):
    if not dest.exists():
        sh(["git", "clone", "--depth", "1", url, str(dest)])
    if not have_commit(dest, commit):
        sh(["git", "fetch", "--depth", "1", "origin", commit], cwd=dest)
    sh(["git", "checkout", "--quiet", commit], cwd=dest)

# ── main ────────────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest")
    args = ap.parse_args()
    sys.stdout.flush()

    cfg = yaml.safe_load(Path(args.manifest).read_text("utf-8"))

    # ── figure out HOME (reliable, no placeholders) ────────────────
    home = Path.home()                      # /home/<BUILD_USER>
    nvim_data   = home / ".local" / "share" / "nvim"
    packer_root = nvim_data / "site" / "pack" / "packer"
    start_dir   = packer_root / "start"
    opt_dir     = packer_root / "opt"
    for d in (start_dir, opt_dir): ensure_dir(d)

    # packer manager
    mgr = cfg["packer"]["manager"]
    clone_at_commit(mgr["repo"], start_dir / "packer.nvim", mgr["commit"])

    # plugins
    packer_plugins = cfg["packer"]["plugins"]
    for plug in packer_plugins:
        repo  = plug["name"]
        url   = repo if repo.startswith("http") else f"https://github.com/{repo}.git"
        dest_parent = opt_dir if plug.get("opt") else start_dir
        clone_at_commit(url, dest_parent / repo.split("/")[-1], plug["commit"])

    # stub packer_compiled.lua (quiet first launch)
    stub = home / ".config" / "nvim" / "plugin" / "packer_compiled.lua"
    ensure_dir(stub.parent)
    if not stub.exists():
        stub.write_text("-- autogenerated stub (container build)\nreturn {}\n")

    # Mason install
    mason_pkgs = [p["name"] for p in cfg.get("mason", {}).get("packages", [])]
    if mason_pkgs:
        mason_lua = (
            "require('mason').setup(); "
            "require('mason.api.command').MasonInstall("
            "{ " + ", ".join([f'\"{pkg}\"' for pkg in mason_pkgs]) + " })"
        )
        cmd = ["nvim", "--headless", "-u", "NORC",
               "-c", "packadd mason.nvim",
               "-c", f"lua {mason_lua}",
               "-c", "qa"]
        sh(cmd)
    else:
        print("No Mason packages specified – skipping")

    # ── Tree‑sitter parser compilation ────────────────────────────
    ts_langs = cfg.get("treesitter", {}).get("ensure_installed", [])
    if ts_langs:
        lua_cmd = (
            "require('nvim-treesitter.configs').setup({"
            "ensure_installed = { "
            + ", ".join([f"'{l}'" for l in ts_langs])
            + " }, sync_install = true })"
        )
        sh([
            "nvim",
            "--headless",
            "-u",
            "NORC",
            "-c",
            f"lua {lua_cmd}",
            "-c",
            "qa",
        ])
    else:
        print("No Tree‑sitter languages requested – skipping")

if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit(f"[bootstrap] failed: {' '.join(e.cmd)} (code {e.returncode})")

