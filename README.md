# Brothers in ARMs' project

The goal of this git repo is to provide the tools needed to setup an environment that matches the Brother In ARMS' projects requirements.

The easiest way to launch install the Brothers In ARMS's project to launch that command on a supported OS:
```
curl -fsSL https://raw.githubusercontent.com/biarms/bootstrap/master/entrypoint.sh | sh
```
An alternative to the first command could be:
```
bash <(curl -fsSL https://raw.githubusercontent.com/biarms/bootstrap/master/entrypoint.bash)
```

The Supported OS are currently:
- Raspbian (running on a Raspberry 1)
- Raspbian (running on a Raspberry 3)
- Ubuntu (running on an Odroid XU4)
- Ubuntu (running on an Orange PI Win)

Are planned to be supported in the future:
- Hypriot
- Armbian
- Debian