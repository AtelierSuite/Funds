# Funds

Funds is a visual budget management app for iOS 26.0+. Users define budget templates for the kinds of days they have (working from office, working from home, not working), assign a template to each weekday, and record spending per category each day. Daily, weekly, monthly, and yearly views show budget health with charts instead of forms and tables.

## Things you cannot tell from the code

- The app was renamed from Fundsee to Funds. Only user-facing names changed; targets, folders, schemes, the bundle ID and the App Group (`group.com.tsubuzaki.Fundsee`) keep the old name so existing data and CloudKit identity are preserved. The name "Funds" is not localized; keep it in Latin script in every language.
- The `.xcodeproj` was written by hand with synchronized folder groups. Adding a file to a target's folder adds it to that target; there are no per-file build entries to maintain.
- **BudgetKit/** is intentionally a shared source folder, not a framework. Its files compile into both targets.
- Widget UIs are inspected through the per-family `FundseeWidgets (…)` schemes, which run the extension in the Simulator's widget preview host. There is no in-app debug surface for them; keep debug-only affordances out of the app.
- The models look over-constrained (every property defaulted, relationships optional, no unique attributes) because CloudKit requires it. Keep that shape.
- Carryover math is deliberately bounded: next-day carry resets at week boundaries, next-week carry reaches back exactly one week. These are product decisions, not bugs.
- Two past bugs to not reintroduce: `DateInterval.contains` includes its end instant, so day-in-week checks must be half-open; and two BarMarks at the same x silently stack in Swift Charts, which is why charts use `yStart`/`yEnd`.
- Notification report content is computed at schedule time and refreshed on foreground, so it is only as current as the last app launch. Accepted limitation to avoid an extension.
- There is no `AppIcon.appiconset`; the Icon Composer document `Fundsee/AppIcon.icon` is the only icon source.
- `DEVELOPMENT_TEAM` is intentionally empty. Simulator-only for now; devices and real CloudKit sync need a team plus the App Group and iCloud container registered.
- Localization keys are `Pascal.Case.Dotted`, never the English text. Strings with arguments use `String(localized: "Key.Path", defaultValue: "English with \(value)")` so the key stays symbolic and the English lives in one place. Plain SwiftUI literals (`Text("Tab.Today")`) take their English from the catalog's `en` entry.
- `Localizable.xcstrings` exists once per target. BudgetKit compiles into both, so any BudgetKit string must be present in both catalogs.
- Spending links to a category through `SpendEntry.categoryID` (the category's `uuid`); `categoryName` is only a snapshot. An entry whose category isn't part of that day's plan still matches by name, so switching a day's plan after logging keeps the tiles filled. Rows from before IDs existed are backfilled at launch with IDs derived from synced data (`DefaultData.legacyCategoryID`), so two devices upgrading at once write identical values instead of fighting over them in CloudKit. Never backfill with random UUIDs.
- Weekly and monthly overall-budget entries are identified by `scope` alone; their `categoryName` is a localized label and must not be used for lookups.
- Views get numbers from `BudgetStore` (in the environment), which caches one `BudgetEngine` per calendar year, padded by two weeks each side for carryover and boundary weeks. It invalidates on `ModelContext.didSave`, remote CloudKit changes, and foregrounding. Don't add whole-table `@Query`s for `SpendEntry` in views; spending history grows forever.
- Seeded template and category names are translated at insert time and then stored, so they are the user's data afterwards. `DefaultData.originalCategoryNames` keeps the pre-localization English names purely so the icon backfill still matches rows already on disk.

## User preferences (established in review, keep them)

- No comments in the source, including doc comments; write code that reads on its own instead. Anything genuinely non-obvious belongs in this file. `// MARK: -` section dividers are the one exception and stay.
- No em-dashes in user-facing copy.
- No status pills; convey state with progress bars and color.
- Toolbar Cancel/Done are label-less `Button(role: .cancel)` / `Button(role: .confirm)`.
- Navigation titles use `.toolbarTitleDisplayMode`, never `.navigationBarTitleDisplayMode`. The five tab roots are `.inlineLarge`; everything pushed or presented is `.inline`.
- Card/tile shadows appear in light mode only.

## Schemes

All schemes are shared, in `Fundsee.xcodeproj/xcshareddata/xcschemes`.

- **Fundsee** runs the app. Its launch arguments are pre-filled but disabled; tick them in the scheme editor instead of retyping.
- **FundseeWidgets** and **FundseeWidgets (Medium / Circular / Rectangular / Inline)** each run the extension in the Simulator's widget preview host, one per `WidgetFamily`. They differ only in the `_XCWidgetFamily` environment variable. Plain **FundseeWidgets** is `systemSmall`.

Adding a widget kind means updating `_XCWidgetKind` in all five.

## Working on this machine

Simulator tap injection is broken (SimulatorKit is missing under the Xcode-beta path), so verify UI headlessly: `xcodebuild` to the simulator by device ID, `simctl install/launch`, `simctl io screenshot`, then read the screenshot. The app reads launch arguments to make this possible:

- `-hasCompletedOnboarding YES`, `-onboardingStep N`, `-initialTab today|week|month|year|more`
- `-ringGuides YES` overlays the budget ring's outer edge, centerline and inner edge in thin red, for checking segment geometry.
- `-seedSampleData YES` fills the past 4 months with plausible entries; it skips today and any day that already has data, so it is safe on real data.
- `-AppleLanguages "(ja)"` (or `ko`, `zh-Hans`, `zh-Hant`) launches in that language, which is how the CJK layouts get checked.

`simctl uninstall` does **not** clear the data. The store lives in the App Group container (`group.com.tsubuzaki.Fundsee`), which survives uninstall; only `hasCompletedOnboarding` and friends go with the app container, so the app looks freshly installed while still holding old plans. To actually reset, delete `Library/Application Support/default.store*` from the group container under `~/Library/Developer/CoreSimulator/Devices/<device>/data/Containers/Shared/AppGroup/`.
