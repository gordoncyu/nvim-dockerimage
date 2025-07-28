# PURPOSE
IT says I need to get software approved. Unless it's on docker with limited network access. Hence this repo to grab everything needed over network at build time so I can restrict network access at runtime.

# CONFIG
## USER INFO
- Resolved at build time (so idk you can't just set root at runtime and do whatever)
## PACKAGES
- Built for packer.nvim. Put all needed packages there
## MASON
- Put needed lsps there
## TREESITTER
- Same story

# USAGE
Must mount nvim config at runtime. The build time stuff is meant to give you all the things you need to run that you can't get at runtime (no network access). Hence, run whatever ultimate configuration you want to with the built image.
