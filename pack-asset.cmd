@echo off
del MinGW64.7z
call 7z a -mx9 MinGW64.7z D:\MinGW64
del Vendor.7z
call 7z a -mx9 Vendor.7z Vendor