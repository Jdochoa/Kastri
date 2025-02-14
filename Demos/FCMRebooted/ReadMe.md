# FCM Rebooted Demo

## Description

This incarnation of FCM support is a substantial reworking of the original FCM support in Kastri, however some elements remain.

**NOTE: The demo has been updated (on Nov 8th, 2023) to align it with the Firebase iOS SDK v10.8.0**. See the [iOS](#ios) section below.

In this implementation, support has been added for a customised notification **on Android**, using RemoteViews, similar to the [CustomNotification demo in the Playground repo](https://github.com/DelphiWorlds/Playground/tree/main/Demos/CustomNotification). This allows multiple lines of text in the notification banner, and an optional image, placed to the right of the text.

The unit `DW.FCMManager` handles management of FCM, which is exposed as a reference to an interface: `IFCMManager`. Now you do not need to create any classes; just assign event handlers, and call the `Start` method on the `FCM` reference. 

**NOTE: The `DW.FCMManager` unit requires the `FMX.PushNotification.FCM.iOS` unit from the Delphi source to be patched**. See [below for details](#delphi-source-patch).

There are 2 demos: 

* A regular FCM demo, and
* A demo of using a service to handle the message regardless of whether or not the app is running

**In order for messages to be received properly on Android, FCM message payloads will need to omit `notification` elements, and include `title`, `body` and `imageUrl` (if needed) properties in the `data` element.** Please refer to the [Sending test messages](#sending-test-messages) section.

## Supported Delphi versions

Delphi 12, Delphi 11.x. _There is no support for 10.4.x or earlier_

## Project Configuration

In order to use FCM in Delphi, you will need to:

### [Apple Developer portal](http://developer.apple.com/account) (iOS)

* Create an APNs key for use with Firebase Cloud Messaging in your Firebase project
* Create an App ID and enable Push Notifications for it
* Create a Provisioning Profile that has the App ID attached to it
* Download the Provisioning Profile on to the Mac

### [Firebase Console](https://console.firebase.google.com) (both platforms)

* Create a Firebase project that you can use for FCM
* Add iOS support to the project
* Add the APNs key to the Cloud Messaging iOS support
* Add Android support to the project


### iOS

#### Delphi source patch

Due to changes in how the newer Firebase SDK works, it is necessary to patch the Delphi source file `FMX.PushNotification.FCM.iOS` located in the `source\fmx` folder of Delphi. 

If you have [Git](https://git-scm.com/) installed on your system, you can use the following to create a patched version of the unit. In a command-line window, execute these commands:

```
cd <Kastri>\Features\Firebase
FCMPatch.cmd
```
  
where `<Kastri>` is the root of your copy of Kastri. This should work for Delphi 11.3 and Delphi 12.0

If you need to patch `FMX.PushNotification.FCM.iOS` manually, please see [these instructions](../../Features/Firebase/FCMManualPatch.md).

#### Firebase SDK

Firebase support in Kastri has now been aligned with Firebase SDK for iOS version 10.8.0. Firebase SDK versions 9.x and older have now been **deprecated*, and are not guaranteed to work, so support for them has been removed entirely.

Please [download the SDK from here](https://github.com/firebase/firebase-ios-sdk/releases/download/10.8.0/Firebase-10.8.0.zip), and unzip it somewhere, preferably in a folder that can be common to other projects that use the SDK. Create an [Environment Variable User System Override](https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Environment_Variables) called `Firebase`, and set it to the folder where the SDK was unzipped to. This corresponds to the `$(Firebase)` macro in the Project Options of the demo. You can use the framework search path value from the Project Options in your own project.

In order to compile successfully for iOS, it's also necessary to add [Swift Support Files in Delphi's SDK Manager](https://github.com/DelphiWorlds/HowTo/tree/main/Solutions/AddSwiftSupport) (follow the link for instructions)

#### Deployment of GoogleServices-info.plist

Download the `GoogleServices-info.plist` file from your project configured in [Firebase Console](https://console.firebase.google.com/), and save it to the Resources folder in the demo. Add `GoogleServices-info.plist` to the deployment, as per the demo, as described above.

#### Linker Options

Ensure you have a value of: `-ObjC -rpath /usr/lib/swift` for the `Options passed to the LD linker` option in the Project Options for iOS Device 64-bit:

   <img src="../AdMob//Screenshots/ObjCLinkerOption.png" alt="ObjC linker option" height="400">

### Android

If you are creating your own project:

FCM Rebooted relies on:

* Delphi 12: `dw-kastri-base-3.0.0.jar` and `dw-fcm-3.0.0.jar`
* Delphi 11.x: `dw-kastri-base-2.0.0.jar` and `dw-fcm-2.0.0.jar` 
 
from the `Lib` folder, so add them to the `Libraries` node under the Android platform in Project Manager.

**Note**:

Due to a bug in Delphi 11.3 **ONLY**, if you need to compile for Android 64-bit, you will either need to apply [this workaround](https://docs.code-kungfu.com/books/hotfix-113-alexandria/page/fix-jar-libraries-added-to-android-64-bit-platform-target-are-not-compiled) (which will apply to **all** projects), **OR** copy the jar file(s) to _another folder_, and add them to the Libraries node of the Android 64-bit target. (Adding the same `.jar` file(s) to Android 64-bit does _not_ work)

### Relay Demo

The "Relay" demo uses metadata that is merged into the Android manifest (using `AndroidManifest.merge.xml` in that demo), to specify the service to relay the notification to - in this case: `com.embarcadero.services.FCMRelayService`, i.e. the fully qualified name of the service.
Use the `AndroidIntentServiceHandleIntent` event in the service to handle the notification.

Please ensure that the `Receive push notifications` checkbox is checked in the Entitlements Section of the Project Options.

In the `Build Events` section of Project Options, please ensure that you configure the `Post Build` event to execute the `manifestmerge` tool (as per the demo), which ensures that the correct overridden `FirebaseMessageingService` is configured in the manifest when the project is built.

For your own project, **or** the demo:

In the `Services` section of the Project Options, import the google-services.json file that you download from your project configured in [Firebase Console](https://console.firebase.google.com/).

## Sending test messages

Test messages can be sent using the [PushIt](https://github.com/DelphiWorlds/PushIt) tool. Please take note of the section on how to obtain the service account file from the [Cloud Console](https://console.cloud.google.com/iam-admin/serviceaccounts).

**On Android, for this implementation of FCM to work, you will need to check the "Data Only Notification" checkbox.** If you do not check this checkbox, the title and body of the notification will be blank.

This is due to a limitation in FCM where messages that contain a "notification" property (regardless of whether it contains a "data" property) do not cause the customized FCM service to be invoked when the app is not running or is in the background. 

Added bonus: images can be included in the customised notification (they will appear on the left). Use the Image URL edit box to include a URL to an image, e.g: https://sd.keepcalms.com/i/keep-calm-and-love-delphi-26.png

With PushIt, you can see what the resulting payload looks like by selecting the `JSON` tab, which can help guide you in constructing message payloads in your server.

## Troubleshooting

### iOS

#### Compiler Errors

If you receive compiler errors during the linking phase, it is likely that the framework paths have not been configured correctly, or you may be using an unsupported Firebase SDK. Please check the [Project Configuration](#project-configuration) section above.

#### FCM messages not being received

If your app is receiving a Firebase token, but does not appear to be receiving messages, it is likely to be either:

* The App ID being used for the Provisioning Profile does not have Push Notifications enabled
* The payload being used for the message being sent is incorrect

You can check that the App ID/Provisioning Profile is correct by examining the `AppName.entitlements` file that Delphi creates when deploying the app (where `AppName` is the name of your app) in the `iOSDevice64\Config` folder (where `Config` is the active config e.g. `Debug` or `Release`). It should contain the following:

```
<key>aps-environment</key>
<string>development</string>
```

Where `development` will be replaced by `production` when using an App Store Provisioning Profile. For info regarding provisioning profile configuration, please refer to the [instructions in the original FCM demo](https://github.com/DelphiWorlds/Kastri/blob/master/Demos/FirebaseCloudMessaging/Readme.md)













