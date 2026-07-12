# About page credit

Added a small "by Craftparking" credit line under the device name on the About page, linking to
`github.com/CraftParking`.

`PageComponent.qml` (the stock UBports `about` panel) had no existing credits section to edit -
just added a new `Label` right under the existing `deviceLabel` (which shows manufacturer+model),
using `textFormat: Text.StyledText` with an `<a href="...">` link and `onLinkActivated:
Qt.openUrlExternally(link)` to make it tappable.

## Deploying

Replaces `/usr/share/ubuntu/settings/system/qml-plugins/about/PageComponent.qml` (root:root, 644).
