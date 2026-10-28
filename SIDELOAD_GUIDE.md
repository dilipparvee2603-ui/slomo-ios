# Slo-Mo Creator Pro — iOS Sideloading & Installation Guide

This guide explains how to install **Slo-Mo Creator Pro** on your iPhone 17 (or any iPhone running iOS 15+) using **SideStore** or **Sideloadly** with a **free Apple ID** (Personal Team account).

---

## 1. Free Apple ID: Provisioning Limitations & Rules

Apple imposes specific constraints on free developer accounts that you must keep in mind:

| Restriction | Limitation | Explanation / Workaround |
| :--- | :--- | :--- |
| **Certificate Validity** | **7 Days** | Apps signed with a free Apple ID stop opening after 7 days. **SideStore** refreshes the app automatically over Wi-Fi before expiration. |
| **Max Active Apps** | **3 Apps** | Apple allows at most 3 sideloaded apps at a time per device. (SideStore uses 1 slot, leaving 2 slots for apps like Slo-Mo Creator Pro). |
| **App ID Quota** | **10 App IDs / 7 days** | You can register at most 10 bundle identifiers per 7-day rolling window. |
| **Developer Mode** | **Required on iOS 16, 17 & 18** | Must be manually enabled in iOS Settings (instructions below). |
| **Unsigned IPAs** | **Cannot be installed directly** | An unsigned IPA produced by Xcode / GitHub Actions cannot be installed until cryptographically signed by your Apple ID via SideStore or Sideloadly. |

---

## 2. Enabling Developer Mode on iPhone (iOS 16, 17, 18)

1. Open **Settings** on your iPhone.
2. Tap **Privacy & Security**.
3. Scroll all the way down to the bottom and tap **Developer Mode**.
4. Toggle **Developer Mode** to **ON**.
5. Tap **Restart** when prompted.
6. After your iPhone reboots and you unlock it, tap **Turn On** and enter your device passcode.

---

## 3. Method A: Installing via SideStore (Directly on iPhone, No Computer Needed After Setup)

SideStore is an on-device app store that cryptographically signs and refreshes IPAs directly on your iPhone using a local WireGuard VPN loopback to communicate with `lockdownd`.

### Initial SideStore Setup (One-Time)
1. Ensure SideStore is installed on your device with your `.mobiledevicepairing` file configured.
2. Connect to the **SideStore WireGuard VPN** widget or switch in iOS Settings.

### Installing Slo-Mo Creator Pro
1. On your iPhone, open **Safari** and go to your GitHub repository:
   - Navigate to **Releases** (or Actions > Artifacts).
   - Tap **`SloMoCreatorPro.ipa`** and download it to your Files app / Downloads.
2. Open the **SideStore** app on your iPhone.
3. Tap the **My Apps** tab at the bottom.
4. Tap the **`+`** icon in the top-left corner.
5. Select **`SloMoCreatorPro.ipa`** from your Downloads.
6. SideStore signs the app with your Apple ID and installs it onto your Home Screen.
7. Tap the **Slo-Mo Creator Pro** icon to launch!

### Automatic 7-Day Refreshing with SideStore
- While connected to your home Wi-Fi and the SideStore WireGuard VPN, SideStore will automatically refresh the 7-day certificate in the background.
- You can also open SideStore anytime and tap **Refresh All**.

---

## 4. Method B: Installing via Sideloadly (from Windows PC or Mac)

If you prefer installing from your PC over USB:

1. Download **Sideloadly** from [sideloadly.io](https://sideloadly.io) and install it.
2. Connect your iPhone to your PC using a USB cable.
3. Tap **"Trust This Computer"** on your iPhone screen and enter your device passcode.
4. Download **`SloMoCreatorPro.ipa`** from your GitHub Actions build artifacts or Releases.
5. Open **Sideloadly**:
   - Your iPhone will appear in the **Device** selector.
   - Drag and drop **`SloMoCreatorPro.ipa`** into the large IPA icon.
   - Enter your **Apple ID** email address.
6. Click **Start**.
   - If prompted, enter your Apple ID password and 2-Factor Authentication code.
   - Sideloadly signs and installs the app onto your iPhone within 30 seconds.

---

## 5. First-Time Trust Verification on iPhone

The first time you sideload an app signed with your free Apple ID, iOS requires verifying the developer certificate:

1. Open **Settings** on your iPhone.
2. Go to **General** > **VPN & Device Management**.
3. Under **Developer App**, tap on your **Apple ID email**.
4. Tap **"Trust [your Apple ID]"** and confirm **Trust**.
5. Return to your home screen and open **Slo-Mo Creator Pro**!

---

## 6. Verifying Optical Flow & High-Framerate Hardware

Once installed on your iPhone:
- Tap **Photos Library** to import any 30, 60, or 120/240 FPS video.
- Test **25% Speed**: the duration calculator will immediately show 4× source duration.
- Select **60 FPS** or **120 FPS** export target: the app will synthesize intermediate motion vectors using Apple Vision and Metal GPU acceleration.
- Exported slow-motion videos can be saved directly to the Camera Roll or shared via the iOS Share Sheet.
