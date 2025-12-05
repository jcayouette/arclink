---
sidebar_position: 6
---

# Boot Customization and Branding

Customize the Raspberry Pi 5 boot experience with branded splash screens, custom boot messages, and professional visual presentation for Arclink deployments.

## Overview

Professional deployments benefit from branded boot screens that identify systems, provide visual feedback during startup, and reinforce organizational identity. This guide covers customizing every aspect of the Pi 5 boot process.

## Boot Sequence Overview

Understanding the boot stages helps target customization:

```text
1. Firmware Boot (0-2s)
   - Raspberry Pi logo (rainbow square)
   - EEPROM controlled
   
2. Bootloader (2-5s)
   - Kernel loading
   - Initial ramdisk

3. Plymouth Splash (5-20s)
   - Graphical boot screen
   - Progress animation
   
4. Console Boot Messages (5-30s)
   - System initialization
   - Service startup

5. Login Prompt or Auto-login
   - TTY console or display manager
```

## Disable Rainbow Splash Screen

The firmware rainbow splash can be disabled via EEPROM configuration:

```bash
# Edit EEPROM config
sudo rpi-eeprom-config --edit
```

Add or modify:

```ini
[all]
DISABLE_SPLASH=1
```

Apply and reboot:

```bash
sudo reboot
```

## Custom Boot Splash with Plymouth

Plymouth provides smooth graphical boot screens with themes and animations.

### Install Plymouth

```bash
# Install Plymouth and tools
sudo apt install -y plymouth plymouth-themes

# Install image tools for custom graphics
sudo apt install -y imagemagick
```

### Create Custom Arclink Theme

Create a directory for your custom theme:

```bash
# Create theme directory
sudo mkdir -p /usr/share/plymouth/themes/arclink
cd /usr/share/plymouth/themes/arclink
```

#### Design Your Logo

Create or convert your logo to PNG format:

**Requirements**:
- PNG format with transparency
- Recommended size: 512x512 pixels
- Keep file size reasonable (< 500KB)

```bash
# Example: Convert and resize logo
convert arclink-logo.png -resize 512x512 -background none -gravity center -extent 512x512 logo.png

# Create a background (optional solid color)
convert -size 1920x1080 xc:#1a1a1a background.png
```

#### Create Plymouth Theme Script

Create the theme configuration:

```bash
sudo nano /usr/share/plymouth/themes/arclink/arclink.plymouth
```

Add the following:

```ini
[Plymouth Theme]
Name=Arclink
Description=Arclink Tactical Communications Boot Theme
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/arclink
ScriptFile=/usr/share/plymouth/themes/arclink/arclink.script
```

#### Create Animation Script

Create the Plymouth script:

```bash
sudo nano /usr/share/plymouth/themes/arclink/arclink.script
```

**Simple static logo with spinner**:

```javascript
// Arclink Plymouth Theme Script

// Screen dimensions
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();

// Background color
Window.SetBackgroundTopColor(0.10, 0.10, 0.10);
Window.SetBackgroundBottomColor(0.05, 0.05, 0.05);

// Load logo
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);

// Center logo
logo.x = screen_width / 2 - logo.image.GetWidth() / 2;
logo.y = screen_height / 2 - logo.image.GetHeight() / 2;
logo.sprite.SetPosition(logo.x, logo.y, 0);

// Progress spinner
spinner.image = Image("spinner.png");
spinner.sprite = Sprite();
spinner.sprite.SetImage(spinner.image);

// Position spinner below logo
spinner.x = screen_width / 2 - spinner.image.GetWidth() / 2;
spinner.y = logo.y + logo.image.GetHeight() + 50;
spinner.sprite.SetPosition(spinner.x, spinner.y, 1);

// Animate spinner
fun refresh_callback() {
    spinner.angle += 0.1;
    spinner.sprite.SetImage(spinner.image.Rotate(spinner.angle));
}
Plymouth.SetRefreshFunction(refresh_callback);

// Boot progress text
message_sprite = Sprite();
message_sprite.SetPosition(screen_width / 2, screen_height - 100, 2);

fun message_callback(text) {
    my_image = Image.Text(text, 1, 1, 1);
    message_sprite.SetImage(my_image);
}
Plymouth.SetMessageFunction(message_callback);

// Display status
fun display_normal_callback() {
    status = "normal";
}

fun display_password_callback(prompt, bullets) {
    status = "password";
}

Plymouth.SetDisplayNormalFunction(display_normal_callback);
Plymouth.SetDisplayPasswordFunction(display_password_callback);
```

**Create a spinner graphic**:

```bash
# Simple spinning circle
convert -size 64x64 xc:none -fill white -draw "circle 32,32 32,8" spinner.png

# Or download from a icon library
wget https://example.com/spinner.png -O spinner.png
```

#### Advanced Theme with Animation

For a more sophisticated fade-in effect:

```javascript
// Arclink Advanced Plymouth Theme

screen_width = Window.GetWidth();
screen_height = Window.GetHeight();

// Gradient background
Window.SetBackgroundTopColor(0.10, 0.15, 0.20);  // Dark blue-gray
Window.SetBackgroundBottomColor(0.05, 0.07, 0.10);

// Load and fade in logo
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.opacity = 0;
logo.target_opacity = 1;

logo.x = screen_width / 2 - logo.image.GetWidth() / 2;
logo.y = screen_height / 2.5 - logo.image.GetHeight() / 2;
logo.sprite.SetPosition(logo.x, logo.y, 10);

// Text label
text.image = Image.Text("ARCLINK", 1, 1, 1, 1, "Sans 24");
text.sprite = Sprite(text.image);
text.x = screen_width / 2 - text.image.GetWidth() / 2;
text.y = logo.y + logo.image.GetHeight() + 30;
text.sprite.SetPosition(text.x, text.y, 10);
text.sprite.SetOpacity(0);

// Subtitle
subtitle.image = Image.Text("Tactical Communications Platform", 0.8, 0.8, 0.8, 1, "Sans 14");
subtitle.sprite = Sprite(subtitle.image);
subtitle.x = screen_width / 2 - subtitle.image.GetWidth() / 2;
subtitle.y = text.y + 40;
subtitle.sprite.SetPosition(subtitle.x, subtitle.y, 10);
subtitle.sprite.SetOpacity(0);

// Progress bar
progress_bar.width = 300;
progress_bar.height = 4;
progress_bar.x = screen_width / 2 - progress_bar.width / 2;
progress_bar.y = screen_height - 100;

// Background bar
progress_bg = Image("progress_bg.png");
progress_bg_sprite = Sprite(progress_bg);
progress_bg_sprite.SetPosition(progress_bar.x, progress_bar.y, 1);

// Foreground bar
progress_fg = Image("progress_fg.png");
progress_fg_sprite = Sprite(progress_fg);
progress_fg_sprite.SetPosition(progress_bar.x, progress_bar.y, 2);

progress = 0;
fade_stage = 0;

fun refresh_callback() {
    // Fade in animation
    if (fade_stage < 50) {
        logo.opacity = fade_stage / 50;
        logo.sprite.SetOpacity(logo.opacity);
        fade_stage++;
    }
    if (fade_stage >= 20 && fade_stage < 70) {
        text_opacity = (fade_stage - 20) / 50;
        text.sprite.SetOpacity(text_opacity);
    }
    if (fade_stage >= 40 && fade_stage < 90) {
        subtitle_opacity = (fade_stage - 40) / 50;
        subtitle.sprite.SetOpacity(subtitle_opacity);
    }
    
    // Progress animation
    progress += 0.01;
    if (progress > 1) progress = 0;
    
    progress_width = progress_bar.width * progress;
    # Update progress bar width here
}

Plymouth.SetRefreshFunction(refresh_callback);

// Boot messages
message_sprite = Sprite();
message_sprite.SetPosition(screen_width / 2, progress_bar.y + 30, 3);

fun message_callback(text) {
    my_image = Image.Text(text, 0.7, 0.7, 0.7, 1, "Sans 10");
    message_sprite.SetImage(my_image);
}
Plymouth.SetMessageFunction(message_callback);
```

**Create progress bar images**:

```bash
# Background bar (gray)
convert -size 300x4 xc:#404040 progress_bg.png

# Foreground bar (blue/brand color)
convert -size 300x4 xc:#4A8FC7 progress_fg.png
```

### Install and Activate Theme

```bash
# Set permissions
sudo chmod 644 /usr/share/plymouth/themes/arclink/*

# Install theme
sudo plymouth-set-default-theme -R arclink

# Rebuild initramfs
sudo update-initramfs -u

# Test (optional - will show preview)
sudo plymouthd
sudo plymouth --show-splash
# Press Ctrl+C to exit after viewing
sudo plymouth --quit
```

### Verify Installation

```bash
# Check current theme
plymouth-set-default-theme

# Should output: arclink

# Reboot to see splash
sudo reboot
```

## Customize Console Boot Messages

### Hide Boot Messages (Clean Boot)

For a cleaner, quieter boot:

```bash
sudo nano /boot/firmware/cmdline.txt
```

Add these parameters to the end of the line (single line, space-separated):

```
quiet splash loglevel=3 logo.nologo vt.global_cursor_default=0
```

**Parameter explanations**:
- `quiet` - Suppress most boot messages
- `splash` - Enable Plymouth splash screen
- `loglevel=3` - Only show errors and critical messages
- `logo.nologo` - Hide Tux penguin logo
- `vt.global_cursor_default=0` - Hide blinking cursor

### Custom Boot Messages

Add branded messages that appear during boot:

```bash
# Create custom message script
sudo nano /etc/rc.local
```

Add before `exit 0`:

```bash
#!/bin/bash

# Clear screen
clear

# Display Arclink banner
cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║     █████╗ ██████╗  ██████╗██╗     ██╗███╗   ██╗██╗  ██╗  ║
║    ██╔══██╗██╔══██╗██╔════╝██║     ██║████╗  ██║██║ ██╔╝  ║
║    ███████║██████╔╝██║     ██║     ██║██╔██╗ ██║█████╔╝   ║
║    ██╔══██║██╔══██╗██║     ██║     ██║██║╚██╗██║██╔═██╗   ║
║    ██║  ██║██║  ██║╚██████╗███████╗██║██║ ╚████║██║  ██╗  ║
║    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝  ║
║                                                            ║
║            Tactical Communications Platform                ║
║                    Node: $(hostname)                       ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

EOF

echo "System initialized: $(date)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo ""

exit 0
```

Make executable:

```bash
sudo chmod +x /etc/rc.local
```

### Custom MOTD (Message of the Day)

Customize what users see when they login:

```bash
# Disable default MOTD scripts
sudo chmod -x /etc/update-motd.d/*

# Create custom MOTD
sudo nano /etc/motd
```

Add your custom message:

```
═══════════════════════════════════════════════════════════════

    ▄▀█ █▀█ █▀▀ █░░ █ █▄░█ █▄▀
    █▀█ █▀▄ █▄▄ █▄▄ █ █░▀█ █░█

    Tactical Communications Platform
    Node: {HOSTNAME}
    
═══════════════════════════════════════════════════════════════

WARNING: Authorized access only. All activity is monitored.

System Information:
  • K3s Cluster Node
  • Arclink Services Enabled
  • Documentation: https://docs.arclink.io

For support: support@arclink.io

═══════════════════════════════════════════════════════════════
```

### Dynamic System Information MOTD

For real-time system info on login:

```bash
# Create custom script
sudo nano /etc/profile.d/arclink-motd.sh
```

Add:

```bash
#!/bin/bash

# Only show on interactive shells
if [ -n "$PS1" ]; then
    clear
    
    # Colors
    BLUE='\033[0;34m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
    
    echo -e "${BLUE}"
    cat << 'EOF'
    ▄▀█ █▀█ █▀▀ █░░ █ █▄░█ █▄▀
    █▀█ █▀▄ █▄▄ █▄▄ █ █░▀█ █░█
    Tactical Communications Platform
EOF
    echo -e "${NC}"
    
    # System info
    echo -e "${GREEN}Node:${NC} $(hostname)"
    echo -e "${GREEN}IP Address:${NC} $(hostname -I | awk '{print $1}')"
    echo -e "${GREEN}Uptime:${NC} $(uptime -p)"
    echo -e "${GREEN}Load:${NC} $(uptime | awk -F'load average:' '{print $2}')"
    
    # Temperature
    TEMP=$(vcgencmd measure_temp | cut -d= -f2)
    echo -e "${GREEN}Temperature:${NC} $TEMP"
    
    # K3s status (if installed)
    if command -v kubectl &> /dev/null; then
        NODES=$(kubectl get nodes 2>/dev/null | grep -c Ready || echo "N/A")
        echo -e "${GREEN}K3s Nodes:${NC} $NODES"
    fi
    
    # Storage
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    echo -e "${GREEN}Disk Usage:${NC} $DISK_USAGE"
    
    echo ""
    echo -e "${YELLOW}Documentation:${NC} https://docs.arclink.io"
    echo ""
fi
```

Make executable:

```bash
sudo chmod +x /etc/profile.d/arclink-motd.sh
```

## TTY Console Branding

### Custom Getty Message

Change the login prompt message:

```bash
# Create custom issue file
sudo nano /etc/issue
```

Add:

```
Arclink Node \n
Tactical Communications Platform

Hostname: \n
IP Address: \4
Kernel: \r

```

**Escape sequences**:
- `\n` - Hostname
- `\4` - IPv4 address
- `\r` - Kernel version
- `\d` - Current date
- `\t` - Current time

### Custom Console Font

Change console font for better readability:

```bash
# List available fonts
ls /usr/share/consolefonts/

# Set console font
sudo dpkg-reconfigure console-setup

# Or directly edit
sudo nano /etc/default/console-setup
```

Set:

```
FONTFACE="Terminus"
FONTSIZE="12x24"
```

Apply:

```bash
sudo setupcon
```

## Suppress Firmware Messages

Reduce kernel log verbosity on console:

```bash
# Edit kernel command line
sudo nano /boot/firmware/cmdline.txt
```

Ensure these parameters:

```
console=serial0,115200 console=tty3 loglevel=3 quiet
```

**Note**: `console=tty3` moves messages to tty3 instead of tty1, keeping tty1 clean.

## Graphical Splash for HDMI Displays

### Using fbi (Framebuffer Image Viewer)

Display a static image during early boot:

```bash
# Install fbi
sudo apt install -y fbi

# Create splash directory
sudo mkdir -p /opt/arclink/splash

# Copy your splash image (1920x1080 recommended)
sudo cp arclink-splash.png /opt/arclink/splash/boot.png
```

Create systemd service:

```bash
sudo nano /etc/systemd/system/arclink-splash.service
```

Add:

```ini
[Unit]
Description=Arclink Boot Splash Screen
DefaultDependencies=no
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/fbi -d /dev/fb0 -T 1 -noverbose -a /opt/arclink/splash/boot.png
ExecStartPost=/bin/sleep 5
ExecStop=/usr/bin/killall fbi
StandardInput=tty
StandardOutput=tty
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
```

Enable and test:

```bash
sudo systemctl daemon-reload
sudo systemctl enable arclink-splash.service

# Test
sudo systemctl start arclink-splash.service

# Stop
sudo systemctl stop arclink-splash.service
```

## Logo and Branding Assets

### Create ASCII Art Logo

Generate ASCII art from your logo:

```bash
# Install jp2a for image to ASCII conversion
sudo apt install -y jp2a

# Convert logo
jp2a --width=80 arclink-logo.png > arclink-ascii.txt

# View result
cat arclink-ascii.txt
```

Or use online tools:
- https://www.text-image.com/convert/
- https://ascii-generator.site/

### Figlet Text Banners

Create stylized text banners:

```bash
# Install figlet
sudo apt install -y figlet toilet

# Generate banner
figlet -f big "ARCLINK"

# Or with colors (using toilet)
toilet -f bigmono12 -F metal "ARCLINK"

# Save to file
figlet -f big "ARCLINK" > /opt/arclink/banner.txt
```

## Troubleshooting

### Plymouth Theme Not Showing

```bash
# Check theme installation
plymouth-set-default-theme

# Verify initramfs updated
ls -la /boot/initrd.img*

# Rebuild if needed
sudo update-initramfs -u

# Check kernel parameters
cat /boot/firmware/cmdline.txt
# Should include: splash
```

### Console Still Shows Messages

```bash
# Verify cmdline.txt
cat /boot/firmware/cmdline.txt

# Should have: quiet loglevel=3

# Reduce verbosity further
# Add: systemd.show_status=0
```

### Custom MOTD Not Displaying

```bash
# Check if dynamic MOTD enabled
ls -la /etc/update-motd.d/

# Verify script is executable
ls -la /etc/profile.d/arclink-motd.sh

# Test manually
bash /etc/profile.d/arclink-motd.sh
```

### Splash Image Not Centered

```javascript
// In Plymouth script, adjust positioning:
logo.x = screen_width / 2 - logo.image.GetWidth() / 2;
logo.y = screen_height / 3;  // Adjust this value

// Or use different anchor point:
logo.y = screen_height * 0.35;  // 35% from top
```

## Best Practices

1. **Keep it simple**: Avoid complex animations that delay boot
2. **Test thoroughly**: Verify on actual hardware, not just preview
3. **Maintain consistency**: Use same branding across all nodes
4. **Document changes**: Keep notes on customizations
5. **Backup originals**: Save original configs before modifying
6. **Consider headless**: Many nodes won't have displays attached

## Example Assets

Create a branding assets directory:

```bash
sudo mkdir -p /opt/arclink/branding
cd /opt/arclink/branding

# Store your assets:
# - logo.png (original high-res)
# - logo-512.png (Plymouth size)
# - splash-1920x1080.png (full screen)
# - ascii-logo.txt (console)
# - banner.txt (figlet text)
```

## Next Steps

1. [System Preparation](./preparation.md) - Continue K3s setup
2. Deploy consistent branding across all cluster nodes
3. Create documentation with branded screenshots

## References

- [Plymouth Theme Guide](https://www.freedesktop.org/wiki/Software/Plymouth/)
- [Raspberry Pi Boot Options](https://www.raspberrypi.com/documentation/computers/config_txt.html)
- [Linux Console Customization](https://wiki.archlinux.org/title/Linux_console)
- [Figlet Font Database](http://www.figlet.org/)
