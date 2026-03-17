#!/usr/bin/env python3
"""Render a deterministic AppDelegate.swift with APNs + FCM debug bridge."""

from __future__ import annotations

import sys
from pathlib import Path


APP_DELEGATE_TEMPLATE = """import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  private let pushDebugChannelName = "satelitrack/push_debug"
  private let defaults = UserDefaults.standard

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    GeneratedPluginRegistrant.register(with: self)
    Messaging.messaging().delegate = self
    UNUserNotificationCenter.current().delegate = self
    registerRemoteNotifications(application: application)

    let launchResult = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: pushDebugChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "push_debug_unavailable", message: "AppDelegate unavailable", details: nil))
          return
        }

        switch call.method {
        case "getState":
          result(self.collectPushDebugState())
        case "register":
          self.registerRemoteNotifications(application: application)
          result(self.collectPushDebugState())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return launchResult
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    defaults.set(token, forKey: "push_apns_token")
    defaults.removeObject(forKey: "push_apns_error")
    defaults.set("did_register_apns", forKey: "push_last_event")
    defaults.set(Date().timeIntervalSince1970, forKey: "push_apns_updated_at")
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    defaults.set(error.localizedDescription, forKey: "push_apns_error")
    defaults.set("did_fail_apns", forKey: "push_last_event")
    defaults.set(Date().timeIntervalSince1970, forKey: "push_apns_error_at")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    defaults.set(fcmToken ?? "", forKey: "push_fcm_token")
    defaults.set("did_receive_fcm", forKey: "push_last_event")
    defaults.set(Date().timeIntervalSince1970, forKey: "push_fcm_updated_at")
  }

  private func registerRemoteNotifications(application: UIApplication) {
    defaults.set("requested_remote_notifications", forKey: "push_last_event")
    defaults.set(Date().timeIntervalSince1970, forKey: "push_requested_at")
    application.registerForRemoteNotifications()
  }

  private func collectPushDebugState() -> [String: Any] {
    return [
      "apnsToken": defaults.string(forKey: "push_apns_token") ?? "",
      "fcmToken": defaults.string(forKey: "push_fcm_token") ?? "",
      "apnsError": defaults.string(forKey: "push_apns_error") ?? "",
      "lastEvent": defaults.string(forKey: "push_last_event") ?? "",
      "requestedAt": defaults.object(forKey: "push_requested_at") ?? 0,
      "apnsUpdatedAt": defaults.object(forKey: "push_apns_updated_at") ?? 0,
      "fcmUpdatedAt": defaults.object(forKey: "push_fcm_updated_at") ?? 0,
      "isRegisteredForRemoteNotifications": UIApplication.shared.isRegisteredForRemoteNotifications,
    ]
  }
}
"""


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: render_push_app_delegate.py <AppDelegate.swift>")
        return 1

    target = Path(sys.argv[1])
    target.parent.mkdir(parents=True, exist_ok=True)
    current = target.read_text(encoding="utf-8") if target.exists() else ""
    if current == APP_DELEGATE_TEMPLATE:
        print("AppDelegate ya coincide con el template APNs/FCM")
        return 0

    target.write_text(APP_DELEGATE_TEMPLATE, encoding="utf-8")
    print(f"AppDelegate APNs/FCM renderizado en {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
