<p align="center">
    <img src="https://raw.githubusercontent.com/Fmstrat/sxncd-flutter/main/assets/logo.svg" width="600">
</p>
<br>

# SxncD Flutter Library

The Flutter library for [SxncD](https://github.com/Fmstrat/SxncD), an Open Source Synchronization Server for use with any apps that that support a standard file import/export.

## Usage

```dart
import 'package:sxncd/sxncd.dart';

// When settings are changed:
String savedTs = DateTime.now().toIso8601String();
String settings = '{ "bool": true }';

// When it's time to sync
SxncdResponse syncResponse = await sxncdSync(
    "http://host.tld", // The URL of the SxncD server
    "730bd41d5df...",  // The API key
    "My Device",       // The device name
    settings,          // The settings data
    savedTs,           // The last time settings were saved
    "password",        // An optional password to E2E encrypt data
);
```

## Response object

**success**

*bool*

Values:
```
true
false
```
<br>

**data**

*String?*

Values:
```
<the most recent settings data>
```
<br>

**action**

*String?*

Values:
```
created       | A new settings entry was created.
none          | The server-side data and device data are already up to date.
existingNewer | The server-side data is newer than what was sent by the device.
incomingNewer | The devices data is newer than the server-side data, so the
                server has stored this new data.
```
<br>

**error**

*String?*

Values:
```
<If success is false, the reason why>
```
<br>