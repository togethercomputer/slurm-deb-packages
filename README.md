# Slurm Debian Package Builder

This repository automates the process of building Debian packages for [Slurm](https://www.schedmd.com/slurm/why-slurm/) and [NVIDIA NCCL](https://github.com/NVIDIA/nccl). It also builds binary files for running [NCCL tests](https://github.com/NVIDIA/nccl-tests).

Slurm is built using default options, with support for some additional libraries, such as [OpenPMIx (v5)](https://github.com/openpmix/openpmix).

## Overview

Slurm is a highly scalable cluster management and job scheduling system for Linux clusters. To facilitate its installation and integration into Debian-based systems, this repository provides automated scripts to build `.deb` packages for Slurm and some of its key dependencies, including OpenPMIx and NCCL.

Additionally, binary files for running NCCL tests are built to verify and benchmark the performance of the NCCL library in various configurations.


### Dependencies

The build process includes the following components:
- **Slurm**: A workload manager that facilitates resource management and scheduling in HPC environments.
- **OpenPMIx**: The Open Process Management Interface for Exascale, which provides a set of interfaces for managing the execution of applications at large scales.
- **NVIDIA NCCL**: NVIDIA's collective communication library optimized for multi-GPU and multi-node systems.
- **NCCL tests**: A suite of tests provided by NVIDIA to validate and benchmark the performance of the NCCL library across different hardware configurations.


## Download packages

To explore and download available packages, go to the [Releases page](https://github.com/nebius/slurm-deb-packages/releases) in this GitHub repository.

## Publishing to forge.together.xyz (apt repo)

The GitHub Release artifacts above are also republished into the R2-backed apt repo
served at `forge.together.xyz`, so the bare-metal Forge ansible
(`togethercomputer/infra`) can install Slurm with `apt`.

- Workflow: [`.github/workflows/publish-forge-r2.yml`](.github/workflows/publish-forge-r2.yml)
  (manual `workflow_dispatch`). Inputs: `slurm_major` (e.g. `25`), `distribution`
  (`ubuntu24.04` / `ubuntu22.04`), `include_pyxis`.
- Layout: `forge.together.xyz/slurm<major>/dists/<suite>/...` — an
  [aptly](https://www.aptly.info/) publish at bucket prefix `slurm<major>/` in the
  Cloudflare R2 bucket `together-forge`. `ubuntu24.04 -> noble`, `ubuntu22.04 -> jammy`.
- Each run gathers **all** releases for the chosen major + distribution and
  republishes the repo from scratch (idempotent), so re-running after a new minor
  (e.g. `25.11.5`) refreshes `forge.together.xyz/slurm25` with every `25.x` build.
- The repo is published **unsigned** (the infra `slurm-node` role adds the apt
  source with `trusted: true`).

### Required secrets

A Cloudflare **R2 API token** (S3 access key/secret) scoped to write the
`together-forge` bucket, stored as repo or org secrets:

- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`

Tracked in Linear **SRE-5009**.
