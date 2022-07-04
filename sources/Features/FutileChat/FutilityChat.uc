/**
 *      Config object for `FutilityChat_Feature`.
 *      Copyright 2022 Anton Tarasenko
 *------------------------------------------------------------------------------
 * This file is part of Acedia.
 *
 * Acedia is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License, or
 * (at your option) any later version.
 *
 * Acedia is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Acedia.  If not, see <https://www.gnu.org/licenses/>.
 */
class FutilityChat extends FeatureConfig
    perobjectconfig
    config(FutilityChat);

enum ChatColorSetting
{
    CCS_DoNothing,
    CCS_TeamColorForced,
    CCS_ConfigColorForced,
    CCS_TeamColorCustom,
    CCS_ConfigColorCustom
};

var public config ChatColorSetting  colorSetting;
var public config Color             configuredColor;
var public config float             teamColorModifier;

protected function HashTable ToData()
{
    local HashTable data;
    local Text      colorAsText;
    data = __().collections.EmptyHashTable();
    data.SetString(P("colorSetting"), string(colorSetting));
    colorAsText = _.color.ToText(configuredColor);
    data.SetItem(P("configuredColor"), colorAsText);
    _.memory.Free(colorAsText);
    data.SetFloat(P("teamColorModifier"), teamColorModifier);
    return data;
}

protected function FromData(HashTable source)
{
    local Text storedText;
    if (source == none) {
        return;
    }
    storedText = source.GetText(P("colorSetting"));
    colorSetting = ColorSettingFromText(storedText);
    _.memory.Free(storedText);
    storedText = source.GetText(P("configuredColor"));
    _.color.Parse(storedText, configuredColor);
    _.memory.Free(storedText);
    teamColorModifier = source.GetFloat(P("teamColorModifier"), 0.5);
}

private function ChatColorSetting ColorSettingFromText(
    BaseText permissions)
{
    if (permissions == none) {
        return CCS_DoNothing;
    }
    if (permissions.EndsWith(P("TeamColorForced"), SCASE_INSENSITIVE)) {
        return CCS_TeamColorForced;
    }
    if (permissions.EndsWith(P("ConfigColorForced"), SCASE_INSENSITIVE)) {
        return CCS_ConfigColorForced;
    }
    if (permissions.EndsWith(P("TeamColorCustom"), SCASE_INSENSITIVE)) {
        return CCS_TeamColorCustom;
    }
    if (permissions.EndsWith(P("ConfigColorCustom"), SCASE_INSENSITIVE)) {
        return CCS_ConfigColorCustom;
    }
    return CCS_DoNothing;
}

protected function DefaultIt()
{
    colorSetting        = CCS_DoNothing;
    configuredColor     = _.color.RGB(255, 255, 255);
    teamColorModifier   = 0.6;
}

defaultproperties
{
    configName = "FutilityChat"
    colorSetting        = CCS_DoNothing
    configuredColor     = (R=255,G=255,B=255,A=255)
    teamColorModifier   = 0.6
}