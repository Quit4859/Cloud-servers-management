# Cloud Servers Management

Manage multiple VPS servers directly

src/file_000000006ba082118bd1f6b42b97aa06.png

## Features

- SSH key authentication
- Persistent tmux sessions
- Multiple user support (`root`, `abc`, or custom users)
- Interactive VPS management menu
- Add, delete, test, and edit server connections

## 1. Setup Termux

Install SSH and generate a key:

```bash
pkg update -y && pkg install openssh -y
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

Copy your public key. Never share your private key (`~/.ssh/id_ed25519`).

## 2. Setup the VPS

Run the `setup.sh` script on your VPS:

```bash
sudo bash setup.sh
```

Paste your Termux public key when prompted. Copy the generated `ADD:` line.

If needed, use the Base64 command provided in `Create the file via Base64.txt` to create `setup.sh`. Review scripts before running them with root privileges.

## 3. Setup the Termux Menu

Run the `Menu.sh` script in Termux using the installation method provided by that script. Then launch:

```bash
vps
```

Select `a` to add a VPS and paste the `ADD:` line.

## 4. Menu Commands

| Command | Action |
|---|---|
| Number | Connect to a VPS |
| `a` | Add a VPS |
| `d` | Delete a VPS |
| `t` | Test connectivity |
| `e` | Edit SSH configuration |
| `q` | Quit |

The exact options depend on the implementation in `Menu.sh`.

## 5. Switch Users

From root, switch to the `abc` user:

```bash
su - abc
```

Check the current user:

```bash
whoami
```

Return to the previous shell:

```bash
exit
```

The `abc` account must already exist on the VPS. An administrator can create it on Debian/Ubuntu with:

```bash
adduser abc
```

## 6. Persistent Sessions

Create a tmux session:

```bash
tmux new -s main
```

Detach with `Ctrl+b`, then `d`. Reconnect using:

```bash
tmux attach -t main
```

`tmux` sessions can survive SSH disconnections, but normally do not survive a VPS reboot or an ephemeral container being reset.

## 7. Ephemeral VPS Warning

Some providers erase server data when containers restart. If SSH configuration, user accounts, or installed packages are lost, rerun the setup script and verify the connection. Check the script before rerunning it.

## Security

- Never share your private SSH key.
- Review scripts before running them as root.
- Use regular accounts for routine tasks.
- Restrict SSH access with appropriate firewall rules.

## Compatibility

These instructions assume Termux on Android and a Debian-based VPS with SSH and tmux support. Actual behavior depends on the included `setup.sh` and `Menu.sh` scripts.
