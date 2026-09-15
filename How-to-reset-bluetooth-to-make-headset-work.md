# How to reset the bluetooth stack to make a headset work

Headset Bosse Quiet Comfort 35 II

## OSX Mojave

I. To fix a Bluetooth headset not connecting on macOS Mojave, reset the Bluetooth module:

```sh
sudo pkill bluetoothd
```
and

II. clear corrupted preference files:

```sh
sudo rm -f /Library/Preferences/com.apple.Bluetooth.plist
sudo rm -f ~/Library/Preferences/ByHost/com.apple.Bluetooth*
```
Restart your Mac.


III. To fix a Bluetooth headset that shows as connected but has no sound on macOS Mojave,
you must manually select the headset in your Sound output settings or restart the Mac's
audio daemon:

```sh
sudo killall coreaudiod
```

IV. Reset the Bluetooth Module.
 * Hold down the <kbd>Shift</kbd>+<kbd>Option</kbd> keys on your keyboard and click the Bluetooth
   icon in the menu bar.
 * Click Reset the Bluetooth module.
 * Restart your Mac and pair your headset again.
