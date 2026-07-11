import QtQuick 2.12
import SystemSettings.ListItems 1.0 as SettingsListItems

SettingsListItems.IconProgression {
    text: i18n.tr(model.displayName)
    iconSource: model.icon
}
