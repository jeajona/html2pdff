[app]
title = Cevirici
package.name = cevirici
package.domain = org.example
source.dir = .
source.include_exts = py,png,jpg,kv,atlas,ttf
version = 0.1
orientation = portrait

requirements = python3,kivy==2.2.1,beautifulsoup4,fpdf,plyer

android.api = 33
android.minapi = 21
android.permissions = READ_EXTERNAL_STORAGE,WRITE_EXTERNAL_STORAGE
android.enable_androidx = True

p4a.branch = master

[buildozer]
log_level = 2
warn_on_root = 1