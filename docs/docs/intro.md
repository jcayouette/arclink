---
sidebar_position: 1
---

# Welcome to Arclink

Arclink is a resilient mobile tactical operations platform designed for disaster recovery, search and rescue, military operations, and off-grid communications.

## What is Arclink?

Arclink provides enterprise-grade deployment automation and infrastructure for [OpenTAK Server](https://github.com/brian7704/OpenTAKServer) on Kubernetes (K3s). It transforms lightweight hardware into reliable, portable tactical communication systems that maintain functionality when power, cellular networks, or internet connectivity are unavailable.

## Key Features

- **Production-Ready Kubernetes Deployment**: Optimized K3s configuration for edge devices and servers
- **Automated Setup**: Single-command deployment with automatic configuration generation
- **Portable Configuration**: Works on any K3s cluster - development laptops to production servers
- **Persistent Storage**: Reliable data persistence with support for Longhorn or local-path-provisioner
- **Fast Deployment**: Pods start in ~10 seconds with pre-built images
- **Multi-Architecture Support**: Runs on ARM64 (Raspberry Pi) and AMD64 platforms

## About OpenTAK Server

Arclink deploys and manages [OpenTAK Server](https://github.com/brian7704/OpenTAKServer), an open source TAK Server for ATAK, iTAK, and WinTAK. OpenTAK Server is developed and maintained by brian7704 and is licensed under GPL-3.0.

## Getting Started

Ready to deploy? Check out the repository [README](https://github.com/jcayouette/arclink) for installation instructions.

## License

Arclink deployment configurations and automation tools are licensed under the MIT License. OpenTAK Server is licensed separately under GPL-3.0.
