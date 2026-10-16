this repo contains all steps and scripts to install on a pc without an operating system an advanced, high performance, safe kiosksystem based on linux

for development we can
* control everything via remote (ssh...)
* use system helper like caja etc
* on-site control by keyboard/mouse (if offline)

we need a good central configuration system
* audio level
* screen config (multiscreen, screen spanning, placing windows)
* touchscreens

we need monitoring for heat problems etc to find problems in the long run


possibility to have an external monitoring

handle problems like nvidia screen tearing

benchmarks for performance / web performance (motionmark?)

autoconnect to a service wlan if available

overlayroot on/off

status helper to have a summary for this kiosk


# suggested workflow
* install operating system
* install git + openssh
* connect via remote
* install default script for main settings, cleanup, user setup
* install app script (each type (web app) has own installer)
* install helper (vscode etc), as installer with checkboxes



# System
* custom backgrounds and startup images
* 


* fullscreen kiosk (no screensaver etc...)
* multiple apps possible:
 
  * static nuxt with nginx
  * videoplayer
  * slideshow
  * universal app launcher

  
* touch

# Auto Test
* simulate heavy usage of the app by clicks or touches


# Software 
* dotool 
* optional node, vscode etc

# Services
* autossh tunnel to external server
* detect usb stick and execute action
* autoupdate app repo on systemstart


# Optional
* transform video output via projector to fit on a wall