# Changelog

## 0.9.6 (2017-03-14)
A bigger than usual update
- merged PR#49, PR#53, PR#54
- Added a backoff timeout, it will use `timeout` from config instead just 1 seconds
- Minor clean up and test fixes
- Better logging when connection fails
- Elixir 1.4 compatibility (removed warnings)
- Library/dependency updates

## 0.9.3 (2016-07-19)
* A fix for certificate keys parsing (thanks @tuvistavie)

## 0.9.2 (2016-05-16)
* Poison version updated to 2.1

## 0.9.1 (2016-05-12)
* Merged PR #38 which deals with a cornercase condition when Apple returns messages with 0 id

## 0.9.0 MAJOR UPDATE (2016-04-22)
* Merged PR #32 which introducec major rearchitecture of the library hence the version update
* Resend notifications on failures
* Tests
* Better message expiration support
* SSL retry limit
* And more smaller enhancements

Note that old version is available in `0.0.x-stable` branch

## 0.0.13 (2016-03-23)

* Merged PR #26 with README update
* Merged PR #27 with a better logging which now includes a message id

## 0.0.12 (2016-03-10)

* Merged PR #23 which stop a reconnect spam if SSl connect fails
* Merged PR #22 which allows cert/key to be loaded from a string
* Merged PR #24 which adds extra logging for sending SSL messages

## 0.0.11 (2016-01-04)

* Fixed Loc-messages formating/truncating
* (optional) category field added to APNS message
* cert_password can be given in both "binary" and 'char list' formats
* Now you can dynamically add workers to pool with APNS.connect_pool/2
* `cert: "plaintext certfile contents"` and `key: "plaintext keyfile contents"` options can be provided instead of `cert: "path/to/certfile"` and `keyfile: "path/to/keyfile"`

## 0.0.10 (2015-11-24)

* Option to specify certfile location relative to app's priv dir added
* Removed Hexate dependency

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
