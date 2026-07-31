# Latchkey Dev Workbench

Toolkit and playbook for building and live-testing a custom latchkey connector (with a Playwright browser-login flow) from a Minds agent, including how to hot-mod a running Minds gateway to prove it end-to-end.

This is a developer toolkit, not a user-facing app. It gives a Minds agent
everything it needs to add a brand-new latchkey connector for a third-party
service -- a TypeScript connector with a Playwright browser-login flow, the
catalog entry that lets the permission be requested and approved, and the
Detent enforcement schema that lets authenticated calls actually go through --
and then prove the whole thing works live against a running Minds gateway
before any of it ships. It ships a worked example (ngrok, taken end-to-end from
browser login to a real authenticated tunnel) plus the reusable tooling that
made it possible: a file-share shell channel to the developer's Mac, a
one-call remote-command helper, a self-restart loop for the desktop app, and
the hot-mod tricks (patching uv's package cache, writing the SIP-protected app
bundle via a Terminal-backed session) that let you iterate on a live gateway.

This repository is a published **minds inspiration**: a clean, bootable
snapshot of the apps and features a mind built, ready to adapt into your own.
It is NOT the generic workspace template -- it is this specific project.

## Use it

- **Create a new mind from it:** point a new minds workspace at this repo's
  URL. On first boot the mind reads the inspiration and helps you connect your
  own accounts and adapt it.
- **Bring it into an existing mind:** run `/use-inspiration <this repo's URL>`.

## What's inside

- **Latchkey Dev Workbench** -- [`inspiration-latchkey-dev-workbench.md`](inspiration-latchkey-dev-workbench.md) (published now)

Each `inspiration-<slug>.md` is the full manifest for that inspiration: what
it is, how it works, the prerequisites it needs, and how to adapt it.
