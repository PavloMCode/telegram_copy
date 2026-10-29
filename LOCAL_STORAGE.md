# Local application data

The native application opens `telegram.sqlite` in the platform application-support
directory through `path_provider`. This is outside the source repository.
Android/iOS use the native sqflite driver; Windows/Linux use SQLite through FFI.

## Stored data

- SQLite: separate message rows, conversation summaries, direct/group/channel
  drafts, contacts, editable profile details and photo, notification preferences,
  blocks, group/channel metadata and memberships, and the device theme.
- Files in application documents: copied message attachments, independent of
  temporary picker paths. Database records keep their filenames and locations.
- SharedPreferences: existing debug authentication accounts and signed-in session.
  Debug accounts remain frontend test data; this is not production authentication.

Each signed-in account uses its original authentication phone as a stable local
partition. Editing the displayed phone does not move the account's stored data.
The theme is a device preference shared across accounts.

Existing SharedPreferences groups and blocks are migrated on their first database
load. Legacy preferences are retained as a backup; subsequent loads use SQLite,
including after a group has been deleted. Group metadata and messages are written
transactionally. Failed transactions leave previous database contents intact.

Drafts are saved after editing, on screen disposal and when the application moves
to the background. Logout clears the signed-in session, not the account's data.
Clearing application data removes local history. There is no backend sync yet.

`.gitignore` excludes SQLite/database files, journals and local export folders.
Do not put personal exports or selected media into source/asset directories.

## Tests

`local_database_test.dart` exercises an actual on-disk SQLite database, account
isolation, legacy migration and transaction rollback. `persistent_chat_test.dart`
checks message/draft restoration through the chat screen using real SQLite.
Existing widget tests can omit `TelegramApp.database` to use isolated test state.
