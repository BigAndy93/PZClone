# PZClone — Steam Integration Spec v2

## Goals
- Invite-only co-op
- NAT traversal support
- Seamless session joining

## Flow
1. Host creates Steam session
2. Friends accept invite
3. Game launches into session

## Requirements
- Steam session ID mapping
- Lobby metadata (version, player count)
- Graceful disconnect handling

Transport layer must remain abstracted from gameplay logic.
