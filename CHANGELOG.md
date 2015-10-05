# Changelog

## 0.0.5 (2015-10-5)

* Localized alerts are now supported

## 0.0.4 (2015-9-12)

* More flexible configs: now you can provide config values per environment or use same value for both :dev and :prod

## 0.0.3 (2015-9-11)

* Provide ability to set `support_old_ios` key individually per message via `%APNS.Message{}` struct key `support_old_ios`

## 0.0.2 (2015-9-11)

* Payload size can be increased to 2kb by setting "support_old_ios" option to false in config (Prior to iOS 8 and in OS X, the maximum payload size is 256 bytes and this limit is applied if "support_old_ios" is true which is default).
* Config key "timeout" accepts number of seconds now instead of milliseconds

## 0.0.1 (2015-9-8)

* Initial release