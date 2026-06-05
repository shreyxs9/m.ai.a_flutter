# Smoothness and Glitch Audit

Date: 2026-06-05

Goal: identify the issues that make the Flutter app feel less smooth than high-polish apps like WhatsApp or Instagram. This pass scanned every route target in `lib/core/router/app_router.dart` plus the modals, sheets, panels, global overlays, media widgets, and shared theme/image helpers used by those screens.

## Verification Run

- `flutter analyze` passed with no issues.
- `flutter test` passed with 19 tests.
- This is a static source audit. A logged-in browser/profile-mode walkthrough should still be run after fixes because authenticated chat/admin data volume is what exposes most frame drops.

## Screen Coverage

| Surface | Route or entry | Files scanned | Status |
| --- | --- | --- | --- |
| Landing/login | `/login`, `/welcome` | `lib/features/auth/login_screen.dart` | Scanned |
| Project dashboard | `/` | `lib/features/projects/projects_screen.dart`, `projects_provider.dart`, `project_avatar_widget.dart`, `project_icon_registry.dart` | Scanned |
| Empty workspace onboarding | Dashboard empty state | `lib/features/projects/projects_screen.dart` | Scanned |
| Project invite redirect | `/join/:code` | `lib/features/auth/invite_redirect_screen.dart` | Scanned |
| Workspace invite | `/join-workspace/:code` | `lib/features/onboarding/workspace_join_screen.dart` | Scanned |
| Profile account | `/profile/account` | `lib/features/profile/profile_screen.dart` | Scanned |
| Profile appearance | `/profile/appearance` | `lib/features/profile/profile_screen.dart`, theme files | Scanned |
| Profile notifications | `/profile/notifications` | `lib/features/profile/profile_screen.dart`, push files | Scanned |
| Profile danger | `/profile/danger` | `lib/features/profile/profile_screen.dart` | Scanned |
| Admin console | `/admin` | `lib/features/admin/admin_screen.dart` | Scanned |
| Theme preview | `/debug/theme` | `lib/features/debug/theme_preview_screen.dart` | Scanned |
| Project chat | `/project/:projectId` | `lib/features/chat/chat_screen.dart`, media preview files | Scanned |
| Global push prompt | app-level overlay | `lib/app.dart`, `lib/features/push/push_prompt_banner.dart`, `core/push/*` | Scanned |
| Dashboard sheets | Create workspace/project, join project, icon picker | `lib/features/projects/projects_screen.dart` | Scanned |
| Chat sheets/panels | Settings, relay, timeline, right panel, context, connectors | `chat_screen.dart`, `project_settings_sheet.dart`, `project_context_panel.dart`, `connectors_panel.dart` | Scanned |

## Highest Impact Issues

### 1. Chat rebuilds too much on typing and polling

Evidence:
- `ChatScreen` owns all chat state in one `ConsumerState` object and calls `setState` from many unrelated actions in `lib/features/chat/chat_screen.dart`.
- Composer typing calls `_handleComposerChanged`, which calls `setState` on every relevant text change around lines 835-853.
- `_pollThread` updates `_messages`, inference state, thinking state, timestamps, and errors in one `setState` around lines 306-354.
- The main `build` method rebuilds header, message list, composer, right panel, and bottom sheet decisions together around lines 923-1101.

Why it feels glitchy:
- Typing in the composer can rebuild the message list and right panel.
- A background poll can rebuild the composer while the user is typing.
- WhatsApp/Instagram-style smoothness requires tiny rebuild islands: composer, message list, header, and right panel should not all repaint for one state bit.

Fix direction:
- Split chat state into smaller notifiers/listenables: message timeline, composer mention state, right panel state, and async action busy state.
- Use `ref.watch(...select(...))`, `ValueListenableBuilder`, or local widgets so keystrokes only rebuild the mention popover/composer.
- Put message rows, the composer, and right panel behind stable widgets and `RepaintBoundary`.

### 2. Chat auto-scroll can fire on every poll, even when there is no new message

Evidence:
- `_pollThread` fetches the latest message window and assigns it to `latest` around lines 313-323.
- It calls `_scrollToBottomSoon()` whenever `latest.isNotEmpty || immediate` around lines 336-338.
- For an active thread, `latest.isNotEmpty` is almost always true, even if the messages are the same as the previous poll.
- `_scrollToBottomSoon` then jumps or animates to max scroll extent around lines 902-920.

Why it feels glitchy:
- The list can tug the user toward the bottom while reading older messages.
- It can create small scroll animations every 3 seconds during active polling.

Fix direction:
- Track whether the poll actually introduced a new message id, changed the last message status, or changed inference state.
- Only auto-scroll when the user is already near bottom or when the current user just sent a message.
- Do not request focus after every inactive poll; only restore focus after send completion if the composer had focus before.

### 3. Attachment tiles refetch signed media URLs during rebuilds

Evidence:
- `_AttachmentTile` creates a new `Future` inside `build`: `ref.read(mediaServiceProvider).downloadUrl(attachment.assetId)` around lines 1905-1907.
- Attachment images use `Image.network` without a loading placeholder or decode sizing around lines 1932-1942.
- Fullscreen images also use raw `Image.network` around line 1994.

Why it feels glitchy:
- Parent rebuilds from polling or typing can re-run URL futures.
- Thumbnails can blink from placeholder to image repeatedly.
- Large images can decode at full size and hitch the UI thread.

Fix direction:
- Cache media URL futures or resolved URLs by `assetId`.
- Use stable thumbnail widgets with `loadingBuilder`, `errorBuilder`, `gaplessPlayback`, and size-aware decode hints.
- Consider a real image cache package if mobile/web behavior needs parity.

### 4. Avatars load network images without stable loading/error behavior

Evidence:
- Chat avatar helper uses raw `Image.network` around lines 3783-3796.
- Dashboard/admin/profile/settings avatars use `NetworkImage` in `CircleAvatar` around `projects_screen.dart` lines 1737-1742, `admin_screen.dart` lines 1427-1431, `profile_screen.dart` lines 1297-1301, and `project_settings_sheet.dart` lines 981-985.

Why it feels glitchy:
- Avatar loads can pop in after layout paint.
- Failed or slow images do not all share the same polished fallback behavior.
- Rebuilding lists can restart or re-resolve images.

Fix direction:
- Create one shared cached avatar widget used everywhere.
- Keep the same fallback visible while the network image loads.
- Add consistent error handling and avoid rebuilding avatar image providers unnecessarily.

### 5. Admin console renders large tables/lists eagerly

Evidence:
- Admin state loads all tenant members and all projects together around `admin_screen.dart` lines 83-104.
- Desktop members and projects use full `DataTable` row lists around lines 831-846 and 1077-1090.
- Mobile members/projects are built with `for` loops inside `Column` around lines 796-805 and 1046-1054.
- Search filtering/sorting is recomputed in an `AnimatedBuilder` on every search text change around lines 678-694.

Why it feels glitchy:
- Large tenants will build too many row widgets in one frame.
- Search typing can rebuild and sort the full visible console.
- `DataTable` is convenient but not virtualized.

Fix direction:
- Debounce search input.
- Use lazy lists for mobile cards.
- For desktop, switch to paginated/virtualized table behavior or limit visible rows.
- Move filtering/sorting into memoized derived state.

### 6. Project settings sheet rebuilds the whole sheet for small field changes

Evidence:
- `ProjectSettingsSheet` owns tab, form, members, save bar, delete state, and settings values in one state class.
- Field changes call `setState` from the main sheet around lines 349-380.
- `_panel()` returns a whole `SingleChildScrollView` for every tab around lines 357-385.
- The save bar visibility depends on `_dirty`, which reads controller text during each build around lines 135-141 and 326-340.

Why it feels glitchy:
- Typing a project name or changing schedule values can rebuild the tab rail, active panel, and save bar together.
- Keyboard inset changes animate the whole modal.

Fix direction:
- Split each settings tab into its own stateful widget.
- Use a form model or `ValueNotifier` for dirty state.
- Keep the save bar as a small listener, not a reason to rebuild the whole dialog.

### 7. Project context/history panel fetches too much on refresh ticks

Evidence:
- `ProjectContextPanel` reloads goals, state, and admin-only history when `projectId` or `refreshTick` changes around lines 47-73.
- The right panel passes `refreshTick: _projectUpdateTick` from chat around `chat_screen.dart` lines 1059-1067.

Why it feels glitchy:
- Project updates can cause the right panel to show spinners and re-layout even if only one small setting changed.
- Admin users pay for history requests whenever the panel reloads.

Fix direction:
- Split current context and history into separate lazy loads.
- Load history only when the history control opens.
- Keep previous content visible while refreshing instead of replacing it with loading movement.

### 8. Global push prompt can appear abruptly over core workflows

Evidence:
- `MaiaApp` overlays `PushPromptBanner` in a global `Stack` around `lib/app.dart` lines 34-41.
- The banner performs a silent push subscription check in `initState` and later changes visibility with `setState` around `push_prompt_banner.dart` lines 23-40 and 80-99.

Why it feels glitchy:
- The banner can appear after the first screen is already usable.
- It is globally positioned at the bottom, the same area used by chat composers and sheets.

Fix direction:
- Animate banner entrance/exit with `AnimatedSlide`/`AnimatedOpacity`.
- Reserve safe bottom spacing or suppress it on chat/modal-heavy screens.
- Delay prompt display until after first-route settle or only show from profile notifications/dashboard.

### 9. Router is recreated from auth state

Evidence:
- `appRouterProvider` watches `authControllerProvider` and returns a new `GoRouter` around `app_router.dart` lines 14-18.
- `MaiaApp` watches `appRouterProvider` and passes it into `MaterialApp.router` around `app.dart` lines 22-31.

Why it feels glitchy:
- Auth/session refreshes can recreate router state.
- This can cause subtle route rebuilds or lost transition state during login, tenant switch, or session refresh.

Fix direction:
- Keep one stable router instance and connect auth changes via a refresh listenable or explicit redirect notifier.
- Avoid rebuilding `MaterialApp.router`'s router object when only auth data changes.

### 10. Google Fonts can cause first-load text jank

Evidence:
- Theme construction uses `GoogleFonts.*TextTheme()` and `GoogleFonts.*().fontFamily` around `app_theme.dart` lines 242-284.

Why it feels glitchy:
- On web/mobile cold start, fonts can arrive after first paint and shift text metrics.
- Theme switching can rebuild text styles across the whole app.

Fix direction:
- Bundle the chosen fonts as local Flutter assets.
- Keep runtime font switching if needed, but make font files local and predeclared.

## Medium Impact Issues

### 11. Landing page is heavy for a login screen

Evidence:
- Login is a long `SingleChildScrollView` with many decorative/product sections around `login_screen.dart` lines 27-71.
- Product surfaces use nested `GridView.count` with `shrinkWrap` and disabled scrolling around lines 361-379.
- Several sections use shadowed surface decorations.

Why it feels glitchy:
- Initial unauthenticated startup has to build a marketing-style page before the user can sign in.
- Nested shrink-wrapped grids measure all children immediately.

Fix direction:
- Defer below-the-fold sections or split them into lazy slivers.
- Keep the sign-in hero first and cheap.
- Avoid heavy shadows and nested grids during first route paint.

### 12. Dashboard/project icon picker builds many icon chips eagerly

Evidence:
- The project icon dialog filters all icon keys on every search change around `projects_screen.dart` lines 1322-1358.
- Categories and `Wrap` children are built eagerly inside a `ListView` around lines 1358-1370.
- The registry has a large static icon map in `project_icon_registry.dart`.

Why it feels glitchy:
- Search typing in the dialog can hitch as many icon widgets are rebuilt.

Fix direction:
- Debounce search.
- Use a grid/list builder instead of large eager wraps.
- Precompute searchable metadata.

### 13. Profile edits rebuild larger sections than necessary

Evidence:
- Profile account/title inline edits use local `setState` and then update auth state around `profile_screen.dart` lines 532-558 and 659-680.
- `ProfileScreen` watches auth and tenant members at the route level around lines 40-49.

Why it feels glitchy:
- Updating one profile field can rebuild the full profile route and navigation.

Fix direction:
- Keep field-level optimistic state local.
- Use provider selectors so the nav does not rebuild for account field saves.

### 14. Loading states are inconsistent and often replace layout

Evidence:
- Some screens use centered `CircularProgressIndicator`, others use animated Maia marks, and some panels show small inline spinners.
- Examples: workspace join lines 143-147, admin lines 255-257, chat lines 927-933, connectors lines 232-267, context panel lines 313-317.

Why it feels glitchy:
- Layout jumps between content, full-screen loaders, inline loaders, and empty placeholders.

Fix direction:
- Use skeletons or keep previous content visible during refresh.
- Standardize loader duration/size and avoid replacing whole surfaces for small refreshes.

### 15. Repeated animated custom painters can repaint without boundaries

Evidence:
- `MaiaMarkWidget` repeats an animation and repaints a `CustomPaint` around `chat_screen.dart` lines 3668-3713.
- `SkeletonWidget` has an always-repeating animation around lines 3819-3845.
- Dashboard has another `_MaiaMark` animation around `projects_screen.dart` lines 1755-1784.

Why it feels glitchy:
- These are fine in isolation, but repeated in lists/loading states without `RepaintBoundary` they can repaint nearby UI.

Fix direction:
- Wrap animated marks/skeleton blocks in `RepaintBoundary`.
- Avoid multiple infinite animations on the same route.

## Visual/Text Glitches

### 16. Connectors panel has mojibake text

Evidence:
- `connectors_panel.dart` line 256 renders `Google Sheets Â· ${_sheets.length}/$_maxSheets`.

Why it feels glitchy:
- Users may see a broken character in the UI.

Fix direction:
- Replace the mojibake with a normal ASCII separator or a correctly encoded bullet.

### 17. Some route transitions are abrupt

Evidence:
- Routes are declared with `builder` only in `app_router.dart`; there are no custom page transitions.

Why it feels glitchy:
- Chat/dashboard/profile/admin route changes can feel like hard swaps.

Fix direction:
- Add short, consistent fade/slide transitions for route changes.
- Keep modal/sheet transitions aligned with Material motion but reduce layout work during the transition.

## Recommended Fix Order

1. Stabilize router and global overlay behavior.
2. Refactor chat into smaller rebuild zones: message list, composer, right panel, poll state.
3. Fix chat auto-scroll and focus restoration rules.
4. Cache media signed URLs and create shared cached image/avatar widgets.
5. Virtualize/debounce admin tables and icon picker search.
6. Split project settings/context panels into smaller state widgets and lazy history loads.
7. Standardize loading/skeleton behavior and add repaint boundaries around repeated animations.
8. Fix visual polish items, including the connectors mojibake and route transitions.
9. Run `flutter analyze`, `flutter test`, and a profile-mode web/mobile walkthrough across every route above.

## Acceptance Checklist For The Fix Pass

- Typing in chat does not rebuild the message list.
- Polling does not move scroll position unless there is a new message and the user is near the bottom.
- Attachments and avatars do not flicker during polling or typing.
- Admin search remains responsive with large member/project lists.
- Project settings field edits do not rebuild unrelated tabs.
- Push prompt never covers the chat composer or active modal controls.
- Route changes feel intentional, not like hard flashes.
- `flutter analyze` and `flutter test` stay green.
