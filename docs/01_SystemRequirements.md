# System Requirements

This document outlines the hardware and software requirements for our CheckMk monitoring implementation, with justification for each choice based on official support and best practices.

## CheckMk Server Requirements

### Hardware Specifications

| Component | Minimum Requirement | Recommended       | Our Setup       | Justification                                                                    |
| --------- | ------------------- | ----------------- | --------------- | -------------------------------------------------------------------------------- |
| CPU       | 2 cores, 2.0GHz     | 4+ cores, 2.4GHz+ | 4 cores, 2.4GHz | Official Checkmk docs recommend at least 2-4 cores for up to 100 hosts/services. |
| RAM       | 4 GB                | 8+ GB             | 8 GB            | 8 GB is recommended for smooth operation and future scaling.                     |
| Storage   | 20 GB               | 50+ GB SSD        | 50 GB SSD       | SSD recommended for performance; 50 GB allows for logs and growth.               |
| Network   | 1 Gbps              | 1 Gbps            | 1 Gbps          | Standard networking for lab environment.                                         |

[Recommended system resources](https://checkmk.com/product/checkmk-system-requirements)

### Software Requirements

| Software      | Version   | Justification                                                                                                                                                                                 |
| ------------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ubuntu Server | 22.04 LTS | Most Checkmk support and documentation is for 22.04. Version 24.04 is only recently supported (since late 2024), so 22.04 is preferred for stability and compatibility. See screenshot below. |
| CheckMk       | 2.4.0     | Latest stable version with all required features and security updates.                                                                                                                        |

## Supported OS Versions

![Supported OS versions](../.github/assets/supported_os_versions.png)

_Ubuntu 22.04 is the most widely supported LTS version as of May 2025. Ubuntu 24.04 support was only added between August 2023 and November 2024._

## Monitored Hosts Requirements

### Debian Host

| Component | Specification     | Notes                                      |
| --------- | ----------------- | ------------------------------------------ |
| OS        | Debian 12         | Officially supported by Checkmk 2.4.0      |
| Agent     | CheckMk Agent 2.4 | Compatible with our CheckMk server version |

### Windows Host

| Component | Specification       | Notes                                      |
| --------- | ------------------- | ------------------------------------------ |
| OS        | Windows Server 2022 | Officially supported by Checkmk 2.4.0      |
| Agent     | CheckMk Agent 2.4   | Compatible with our CheckMk server version |

## Network Requirements

| Requirement          | Configuration                                         |
| -------------------- | ----------------------------------------------------- |
| Firewall Access      | TCP port 80/443 for web interface                     |
|                      | TCP port 6556 for CheckMk agents                      |
| Network Connectivity | All hosts must be able to reach the monitoring server |

## Version Selection Rationale

### Why CheckMk 2.4.0?

- Latest stable version with enhanced security features
- Bug fixes from previous versions
- Compatible with our monitored systems

### Why Ubuntu Server 22.04?

- Most widely supported LTS version for Checkmk as of May 2025
- Long-term support (until 2027)
- Extensive documentation and community support
- Ubuntu 24.04 support is very recent (added between August 2023 and November 2024), so 22.04 is preferred for stability
