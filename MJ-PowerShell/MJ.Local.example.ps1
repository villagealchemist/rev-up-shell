# Optional settings. This file is copied to MJ.Local.ps1 on first installation.
# Keep credentials and tokens out of this file.
$global:MJConfig.PromptName = 'alchemist'
$global:MJConfig.EditMode = 'Emacs'
$global:MJConfig.ShowGit = $true
$global:MJConfig.ShowGreeting = $true
$global:MJConfig.Predictions = $true

# Pick an editor executable (no flags); blank means automatic detection.
# $global:MJConfig.Editor = 'code'

# Named project folders; cproj lists them and cproj app enters one.
# $global:MJConfig.Projects['app'] = 'C:\work\app'

# Add your own functions here with explicit global scope so reload works.
# function global:myshortcut { Get-ChildItem -Force }
