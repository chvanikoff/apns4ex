# Changelog

## 0.0.9 (2015-11-21)

* Message IDs generation improved. Previous implementation based on timestamp could cause bugs under load.
* This release is mostly refactoring. If you use any of modules directly (e.g. you define your own pool of workers using APNS.Connection.Worker), please take a look at new modules names and the structure.

## 0.0.8 (2015-11-18)

* Fixed renamed variable
* Include poolboy in the apps list

## 0.0.7 (2015-11-17)

* Now APNS will automatically start pools defined in config. (see README)
* Updated config structure (see README)
* Renamed feedback_timeout config key to feedback_interval as more appropriate (see README)
* Deprecated manual connection start (see README)

## 0.0.6 (2015-10-14)

* In case when token size is incorrect (!= 64), error callback will be triggered
* In case when payload size is too big and can't be adjusted by truncating alert, error callback will be triggered

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