# CheckMk Monitoring Solution

This repository contains documentation and scripts for setting up and configuring CheckMk monitoring.

## Team Members

- Rui Monteiro - rui.monteiro@eduvaud.ch
- Romain Humbert-Droz-Laurent - romain.humbert-droz-laurent@eduvaud.ch
- Nuno Ribeiro Pereira - nuno.ribeiro@eduvaud.ch

## Project Overview

This project implements a monitoring solution using CheckMk 2.4.0 running on Ubuntu Server 22.04. The implementation monitors:

- The CheckMk server itself
- A Debian 12 machine
- A Windows Server 2022 machine

## Documentation

Detailed documentation is available in the [docs](./docs) directory:

- [System Requirements](./docs/01_SystemRequirements.md) - Hardware and software requirements
- [Installation Guide](./docs/02_InstallationGuide.md) - Step-by-step installation instructions
- [Configuration Guide](./docs/03_ConfigurationGuide.md) - CheckMk configuration steps
- [Monitoring Debian](./docs/04_MonitoringDebian.md) - Setting up Debian 12 monitoring
- [Monitoring Windows](./docs/05_MonitoringWindows.md) - Setting up Windows Server 2022 monitoring
- [Performance Analysis](./docs/06_PerformanceAnalysis.md) - Performance comparison before and after installation
- [Scripts Overview](./docs/07_ScriptsOverview.md) - Documentation for automation scripts

## Quick Start

1. Follow the [Installation Guide](./docs/02_InstallationGuide.md) to set up CheckMk
2. Configure your monitoring environment using the [Configuration Guide](./docs/03_ConfigurationGuide.md)
3. Set up monitoring for [Debian](./docs/04_MonitoringDebian.md) and [Windows](./docs/05_MonitoringWindows.md) hosts

## Scripts

Automation scripts are available in the [scripts](./scripts) directory:

- [install_checkmk.sh](./scripts/install_checkmk.sh) - Automated installation script for CheckMk
